extends Node
## Autoload: RandomEventManager
## Losowe wydarzenia (nowość - lista z życzenia użytkownika): jedno GWARANTOWANE
## co `GameBalance.RANDOM_EVENT_GUARANTEED_INTERVAL` rund, plus niezależna
## `GameBalance.RANDOM_EVENT_EXTRA_CHANCE` szansa na DODATKOWE wydarzenie w
## KAŻDEJ rundzie (może więc wypaść więcej niż jedno w tej samej rundzie).
## Całość wyłączalna przez `GameBalance.RANDOM_EVENTS_ENABLED` - `process_round_end()`
## od razu wraca, jeśli wyłączone, więc `TurnManager` może wołać ją bezwarunkowo
## co rundę bez własnej kopii tego samego warunku.
##
## Każde wydarzenie jest losowane TYLKO spośród aktualnie SENSOWNYCH opcji
## (np. "Pożar lasu" nigdy nie wypadnie, jeśli akurat żaden gracz nie
## posiada niepłonącego pola lasu) - zamiast wydarzenia, które i tak nic by
## nie zrobiło, patrz `_roll_event()`. Jedyny wyjątek to "Inspekcja
## środowiskowa", zawsze dostępna - jej efekt to "brak naruszeń", jeśli akurat
## nikt nie nadużywa środowiska, co samo w sobie jest sensowną, czytelną
## informacją (patrz `_is_player_abusing_environment()`).
##
## Wydarzenia trwające kilka rund (Strajk górniczy, Plaga szkodników,
## Rekordowe żniwa) są przechowywane jako "aktywne DO rundy X" (nie jako
## malejący licznik) - odczyt (`is_mining_disabled()` itd.) po prostu
## porównuje `TurnManager.round_number` z zapisaną wartością, więc nie ma
## ryzyka rozjazdu przy dekrementowaniu w złym miejscu/kolejności.
## "Łagodna zima" jest inna - nie ma ustalonego czasu trwania, tylko CZEKA na
## najbliższą rundę zimową (nawet jeśli wypadnie latem) i wtedy się zużywa
## raz (`consume_mild_winter()`), więc zawsze coś realnie zmienia, niezależnie
## od tego, w której rundzie akurat wypadnie.

signal notification_added

## Kolejność = kolejność w liście z życzenia użytkownika (żywioł/pogoda,
## gospodarka, kontrola, rzadkie/specjalne).
enum EventId {
	FOREST_FIRE,
	MINING_DAMAGE,
	MILD_WINTER,
	PEST_PLAGUE,
	GRANT,
	MINING_STRIKE,
	RECORD_HARVEST,
	ENVIRONMENTAL_INSPECTION,
	TOURISM_BOOM,
	MARKET_CRASH,
}

## "Kopalnia/gazoport" dla potrzeb wydarzeń = budynek RESOURCE_NODE
## produkujący jeden z tych surowców - odróżnia je od rolnictwa (FOOD) i od
## drewna (w ogóle nie pochodzi z budynku, tylko z ręcznego wycinania lasu).
const MINING_RESOURCE_TYPES = [
	HexData.ResourceType.COAL, HexData.ResourceType.COPPER, HexData.ResourceType.GAS,
	HexData.ResourceType.NICKEL, HexData.ResourceType.URANIUM,
]

## Poniżej tego poziomu zasobu płonący las uznajemy za doszczętnie
## wypalony - kończy pożar samoistnie, zamiast dogasać asymptotycznie w
## nieskończoność (mnożenie przez (1 - DECAY_RATIO) samo nigdy nie osiąga
## dokładnie zera).
const FIRE_BURNOUT_THRESHOLD = 5.0

## Każdy wpis: {"round": int, "message": String}, od najstarszego. UI
## (panel powiadomień) pokazuje je od najnowszego - patrz notifications_panel.gd.
var notifications: Array[Dictionary] = []
var unread_count: int = 0

## player_id(int) -> ostatnia runda (włącznie), w której efekt jeszcze trwa.
var _pest_plague_until_round: Dictionary = {}
var _record_harvest_until_round: Dictionary = {}
var _mining_strike_until_round: Dictionary = {}

## Czeka na najbliższą rundę zimową - patrz komentarz u góry pliku.
var _mild_winter_pending: bool = false


## Wywoływane raz na rundę z TurnManager.end_round(), PRZED przeliczeniem
## dochodu (żeby świeżo wylosowane wydarzenie od razu wpłynęło na wynik tej
## samej rundy, nie dopiero następnej) i PRZED regeneracją lasu (żeby
## płonący heks nie odrósł w tej samej rundzie, w której się spalił).
func process_round_end() -> void:
	if not GameBalance.RANDOM_EVENTS_ENABLED:
		return

	_process_burning_fires()

	if TurnManager.round_number % GameBalance.RANDOM_EVENT_GUARANTEED_INTERVAL == 0:
		_roll_event()
	if randf() < GameBalance.RANDOM_EVENT_EXTRA_CHANCE:
		_roll_event()


func mark_all_read() -> void:
	unread_count = 0


func _log(message: String) -> void:
	notifications.append({"round": TurnManager.round_number, "message": message})
	unread_count += 1
	notification_added.emit()


## --- Pożar lasu ------------------------------------------------------------

func _process_burning_fires() -> void:
	var newly_ignited: Array[HexData] = []
	for hex: HexData in MapData.hexes.values():
		if not hex.is_on_fire:
			continue

		hex.resource_level *= (1.0 - GameBalance.FOREST_FIRE_DECAY_RATIO)
		if hex.resource_level < FIRE_BURNOUT_THRESHOLD:
			hex.is_on_fire = false
			_log("🔥 Pożar lasu na polu %s wypalił się doszczętnie." % hex.hex_id)
			continue

		if randf() < GameBalance.FOREST_FIRE_SPREAD_CHANCE:
			var spread_target = _pick_spread_target(hex.hex_id)
			if spread_target != null:
				newly_ignited.append(spread_target)
				_log("🔥 Pożar rozprzestrzenił się z pola %s na %s!" % [hex.hex_id, spread_target.hex_id])

	# Zapalane DOPIERO po pętli, żeby nowo zapalony heks nie dostał od razu
	# tej samej rundy dodatkowego, "darmowego" tiku spadku (kolejność
	# iteracji po Dictionary.values() jest w zasadzie dowolna).
	for hex in newly_ignited:
		hex.is_on_fire = true


func _pick_spread_target(hex_id: String) -> HexData:
	var candidates: Array[HexData] = []
	for neighbor in MapData.get_neighbors(hex_id):
		if neighbor.is_forest() and not neighbor.is_on_fire:
			candidates.append(neighbor)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


## Jedyna akcja INICJOWANA przez gracza (przycisk w pasku bocznym,
## game_map_controller.gd) - koszt płacony zawsze (za samą próbę), skuteczność
## losowa, więc nieudana próba wciąż kosztuje i trzeba spróbować ponownie.
func extinguish_fire(hex_id: String, player_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	var player = GameManager.get_player(player_id)
	if hex == null or player == null or not hex.is_on_fire or hex.owner_id != player_id:
		return {"success": false, "reason": "invalid"}
	if player.money < GameBalance.FOREST_FIRE_EXTINGUISH_COST:
		return {"success": false, "reason": "cannot_afford"}

	player.add_money(-GameBalance.FOREST_FIRE_EXTINGUISH_COST)
	var extinguished = randf() < GameBalance.FOREST_FIRE_EXTINGUISH_CHANCE
	if extinguished:
		hex.is_on_fire = false
	return {"success": true, "extinguished": extinguished}


## --- Zapytania dla TurnManager._process_resource_income() ------------------

func consume_mild_winter() -> bool:
	if _mild_winter_pending:
		_mild_winter_pending = false
		return true
	return false


func is_pest_plague_active(player_id: int) -> bool:
	return TurnManager.round_number <= _pest_plague_until_round.get(player_id, -1)


func is_record_harvest_active(player_id: int) -> bool:
	return TurnManager.round_number <= _record_harvest_until_round.get(player_id, -1)


func is_mining_disabled(player_id: int) -> bool:
	return TurnManager.round_number <= _mining_strike_until_round.get(player_id, -1)


## --- Losowanie wydarzeń -----------------------------------------------------

func _roll_event() -> void:
	var players: Array = GameManager.players.values()
	if players.is_empty():
		return

	var eligible: Array[int] = [
		EventId.MILD_WINTER, EventId.GRANT, EventId.ENVIRONMENTAL_INSPECTION,
		EventId.TOURISM_BOOM, EventId.MARKET_CRASH,
	]
	if not _players_with_undamaged_mining().is_empty():
		eligible.append(EventId.MINING_DAMAGE)
		eligible.append(EventId.MINING_STRIKE)
	if not _players_with_unburning_forest().is_empty():
		eligible.append(EventId.FOREST_FIRE)
	if not _players_with_agriculture().is_empty():
		eligible.append(EventId.PEST_PLAGUE)
		eligible.append(EventId.RECORD_HARVEST)

	_apply_event(eligible[randi() % eligible.size()], players)


func _apply_event(event_id: EventId, players: Array) -> void:
	match event_id:
		EventId.FOREST_FIRE:
			_apply_forest_fire()
		EventId.MINING_DAMAGE:
			_apply_mining_damage()
		EventId.MILD_WINTER:
			_apply_mild_winter()
		EventId.PEST_PLAGUE:
			_apply_pest_plague()
		EventId.GRANT:
			_apply_grant(players)
		EventId.MINING_STRIKE:
			_apply_mining_strike()
		EventId.RECORD_HARVEST:
			_apply_record_harvest()
		EventId.ENVIRONMENTAL_INSPECTION:
			_apply_environmental_inspection()
		EventId.TOURISM_BOOM:
			_apply_tourism_boom(players)
		EventId.MARKET_CRASH:
			_apply_market_crash()


func _apply_forest_fire() -> void:
	var player: PlayerData = _players_with_unburning_forest().pick_random()
	var hex = _pick_unburning_forest_hex(player.player_id)
	hex.is_on_fire = true
	_log(
		"🔥 Pożar lasu wybuchł na polu %s gracza %s! Las traci %.0f%% drzew z każdą rundą, dopóki się nie wypali albo nie zostanie ugaszony (przycisk w pasku bocznym, koszt %.0f pieniędzy, %.0f%% szansy powodzenia)." % [
			hex.hex_id, player.player_name, GameBalance.FOREST_FIRE_DECAY_RATIO * 100.0,
			GameBalance.FOREST_FIRE_EXTINGUISH_COST, GameBalance.FOREST_FIRE_EXTINGUISH_CHANCE * 100.0,
		]
	)


func _apply_mining_damage() -> void:
	var player: PlayerData = _players_with_undamaged_mining().pick_random()
	var hex = _pick_undamaged_mining_hex(player.player_id)
	hex.building_damaged = true
	_log(
		"⛏️ Szkody górnicze uszkodziły budynek \"%s\" (%s) gracza %s - przestał produkować. Napraw go przyciskiem w pasku bocznym." % [
			hex.building.building_name, hex.hex_id, player.player_name,
		]
	)


func _apply_mild_winter() -> void:
	_mild_winter_pending = true
	_log("❄️ Łagodna zima! Plony będą rosnąć normalnie mimo zimy - premia zadziała przy najbliższej zimowej rundzie.")


func _apply_pest_plague() -> void:
	var player: PlayerData = _players_with_agriculture().pick_random()
	var until_round = TurnManager.round_number + GameBalance.PEST_PLAGUE_ROUNDS - 1
	_pest_plague_until_round[player.player_id] = until_round
	_log(
		"🐛 Plaga szkodników uderzyła w pola gracza %s - żywność nie urośnie przez %d rundy (do rundy %d włącznie)." % [
			player.player_name, GameBalance.PEST_PLAGUE_ROUNDS, until_round,
		]
	)


func _apply_grant(players: Array) -> void:
	var player: PlayerData = players.pick_random()
	var amount = randf_range(GameBalance.GRANT_MONEY_MIN, GameBalance.GRANT_MONEY_MAX)
	player.add_money(amount)
	_log("💶 Dotacja unijna! Gracz %s otrzymał %.0f pieniędzy." % [player.player_name, amount])


func _apply_mining_strike() -> void:
	var player: PlayerData = _players_with_undamaged_mining().pick_random()
	var until_round = TurnManager.round_number + GameBalance.MINING_STRIKE_ROUNDS - 1
	_mining_strike_until_round[player.player_id] = until_round
	_log(
		"⚒️ Strajk górniczy u gracza %s - kopalnie i gazoporty nie produkują przez %d rundy (do rundy %d włącznie)." % [
			player.player_name, GameBalance.MINING_STRIKE_ROUNDS, until_round,
		]
	)


func _apply_record_harvest() -> void:
	var player: PlayerData = _players_with_agriculture().pick_random()
	var until_round = TurnManager.round_number + GameBalance.RECORD_HARVEST_ROUNDS - 1
	_record_harvest_until_round[player.player_id] = until_round
	_log(
		"🌾 Rekordowe żniwa stulecia u gracza %s - produkcja żywności x%.0f przez %d rund (do rundy %d włącznie)." % [
			player.player_name, GameBalance.RECORD_HARVEST_MULTIPLIER, GameBalance.RECORD_HARVEST_ROUNDS, until_round,
		]
	)


## Sprawdza WSZYSTKICH graczy (nie losuje jednego) - każdy, kto akurat
## nadużywa środowiska, dostaje karę.
func _apply_environmental_inspection() -> void:
	var affected: Array[String] = []
	for player: PlayerData in GameManager.players.values():
		if _is_player_abusing_environment(player):
			GameManager.change_prestige(player.player_id, -GameBalance.ENVIRONMENTAL_INSPECTION_PRESTIGE_PENALTY)
			player.add_money(-GameBalance.ENVIRONMENTAL_INSPECTION_MONEY_PENALTY)
			affected.append(player.player_name)

	if affected.is_empty():
		_log("🔍 Inspekcja środowiskowa nie znalazła żadnych naruszeń.")
	else:
		_log(
			"🔍 Inspekcja środowiskowa ukarała graczy: %s (-%d prestiżu, -%.0f pieniędzy każdy)." % [
				", ".join(affected), GameBalance.ENVIRONMENTAL_INSPECTION_PRESTIGE_PENALTY,
				GameBalance.ENVIRONMENTAL_INSPECTION_MONEY_PENALTY,
			]
		)


## Gra nie modeluje osobnych "miejsc turystycznych" jako własnego typu
## heksa/budynku (patrz GameBalance) - stąd płaska, losowa premia zamiast
## czegoś skalowanego z konkretnych pól.
func _apply_tourism_boom(players: Array) -> void:
	var player: PlayerData = players.pick_random()
	var money = randf_range(GameBalance.TOURISM_BOOM_MONEY_MIN, GameBalance.TOURISM_BOOM_MONEY_MAX)
	var prestige = randi_range(GameBalance.TOURISM_BOOM_PRESTIGE_MIN, GameBalance.TOURISM_BOOM_PRESTIGE_MAX)
	player.add_money(money)
	GameManager.change_prestige(player.player_id, prestige)
	_log(
		"🏰 Turystyczny boom u gracza %s - +%.0f pieniędzy, +%d prestiżu." % [
			player.player_name, money, prestige,
		]
	)


func _apply_market_crash() -> void:
	var resource_keys = MarketBalance.RESOURCE_PARAMS.keys()
	var resource = resource_keys[randi() % resource_keys.size()]
	var crashes_up = randf() < 0.5
	var multiplier = (
		randf_range(GameBalance.MARKET_CRASH_MULTIPLIER_UP_MIN, GameBalance.MARKET_CRASH_MULTIPLIER_UP_MAX)
		if crashes_up
		else randf_range(GameBalance.MARKET_CRASH_MULTIPLIER_DOWN_MIN, GameBalance.MARKET_CRASH_MULTIPLIER_DOWN_MAX)
	)
	MarketManager.trigger_price_shock(resource, multiplier)
	_log(
		"📉 Market Crash! Cena surowca %s gwałtownie %s." % [
			HexData.RESOURCE_DISPLAY_NAMES.get(resource, "?"), "wzrosła" if crashes_up else "spadła",
		]
	)


## --- Kwalifikowalność graczy do poszczególnych wydarzeń ---------------------

func _is_player_abusing_environment(player: PlayerData) -> bool:
	var safe_threshold = GameBalance.FOREST_SAFE_THRESHOLD_PERCENT + player.forest_safe_threshold_bonus
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id != player.player_id:
			continue
		if hex.is_forest() and hex.resource_level < safe_threshold:
			return true
		if hex.is_protected() and hex.building != null:
			return true
	return false


func _pick_unburning_forest_hex(player_id: int) -> HexData:
	var candidates: Array[HexData] = []
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id == player_id and hex.is_forest() and not hex.is_on_fire:
			candidates.append(hex)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _players_with_unburning_forest() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player: PlayerData in GameManager.players.values():
		if _pick_unburning_forest_hex(player.player_id) != null:
			result.append(player)
	return result


func _pick_undamaged_mining_hex(player_id: int) -> HexData:
	var candidates: Array[HexData] = []
	for hex: HexData in MapData.hexes.values():
		if (
			hex.owner_id == player_id and hex.building != null and not hex.building_damaged
			and MINING_RESOURCE_TYPES.has(hex.building.produced_resource)
		):
			candidates.append(hex)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _players_with_undamaged_mining() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player: PlayerData in GameManager.players.values():
		if _pick_undamaged_mining_hex(player.player_id) != null:
			result.append(player)
	return result


func _players_with_agriculture() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player: PlayerData in GameManager.players.values():
		for hex: HexData in MapData.hexes.values():
			if hex.owner_id == player.player_id and hex.is_agricultural():
				result.append(player)
				break
	return result
