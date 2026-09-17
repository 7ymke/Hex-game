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
## Losowanie samo jest dwuetapowe ("Chcę aby system losowania eventówy był
## trochę zmieniony"): (1) najpierw losuje KATEGORIĘ -
## `GameBalance.RANDOM_EVENT_SINGLE_PLAYER_CHANCE` szansy, że to będzie
## wydarzenie "dla 1 gracza", inaczej "dla wszystkich". (2a) "dla
## wszystkich" -> losuje JEDNO z trzech takich wydarzeń (Łagodna zima/
## Inspekcja środowiskowa/Market Crash) i stosuje raz. (2b) "dla 1 gracza"
## -> losuje ILU graczy (1 do liczby graczy w grze) dostanie w tej samej
## turze WŁASNE wydarzenie, wybiera tylu różnych graczy, i dla KAŻDEGO z
## osobna losuje NIEZALEŻNIE jego konkretne wydarzenie (spośród tych, na
## które akurat kwalifikuje się WŁAŚNIE TEN gracz - np. Pożar lasu tylko z
## niepłonącym lasem) - więc w jednej turze może naraz wypaść kilku różnych
## graczy z różnymi wydarzeniami. Każde wydarzenie jest losowane TYLKO
## spośród aktualnie SENSOWNYCH opcji dla danego gracza (zamiast wydarzenia,
## które i tak nic by nie zrobiło) - patrz `_eligible_single_player_events()`.
## Jedyny wyjątek to "Inspekcja środowiskowa", zawsze dostępna - jej efekt to
## "brak naruszeń", jeśli akurat nikt nie nadużywa środowiska, co samo w
## sobie jest sensowną, czytelną informacją (patrz
## `_is_player_abusing_environment()`).
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
##
## Powiadomienia są SKOPOWANE do gracza, którego dotyczy dane wydarzenie
## ("Informacje powinny pokazywać się tylko graczowi którego dotyczą - lub
## wszystkim jeśli dotyczą wszystkich") - każdy wpis w `notifications` niesie
## `player_id` (konkretny gracz dla wydarzeń "tylko dla 1 gracza") albo
## `ALL_PLAYERS` (Łagodna zima/Inspekcja środowiskowa/Market Crash - patrz
## `_log()`). "Nieprzeczytane" liczy się PER GRACZ (`_last_seen_index`) - nie
## ma jednego globalnego licznika, więc odczyt przez gracza A nie chowa
## powiadomień gracza B ani nie zalicza mu jako przeczytane niczego, co go
## nie dotyczy.

signal notification_added

## Sentinel dla `notifications[i]["player_id"]` - wydarzenie dotyczące
## WSZYSTKICH graczy (Łagodna zima, Inspekcja środowiskowa, Market Crash),
## w odróżnieniu od wydarzeń "tylko dla 1 gracza" (reszta listy), które
## zapisują konkretne `player_id`. ("Informacje powinny pokazywać się tylko
## graczowi którego dotyczą - lub wszystkim jeśli dotyczą wszystkich.")
const ALL_PLAYERS = -1

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

## Każdy wpis: {"round": int, "message": String, "player_id": int - konkretny
## gracz albo ALL_PLAYERS}, od najstarszego. UI (panel powiadomień) pokazuje
## je od najnowszego - patrz notifications_panel.gd.
var notifications: Array[Dictionary] = []

## player_id(int) -> ile pierwszych wpisów `notifications` ten gracz już
## widział (nie licznik "ile nieprzeczytanych", tylko indeks odcięcia - stąd
## "nieprzeczytane dla gracza X" to wpisy notifications[seen:] przefiltrowane
## do tych, które go dotyczą, patrz `get_unread_for_player()`). Otwarcie
## panelu przez danego gracza przesuwa odcięcie do bieżącej długości listy -
## nie ma osobnego śledzenia "przeczytane/nieprzeczytane" per wpis.
var _last_seen_index: Dictionary = {}

## player_id(int) -> ostatnia runda (włącznie), w której efekt jeszcze trwa.
var _pest_plague_until_round: Dictionary = {}
var _record_harvest_until_round: Dictionary = {}
var _mining_strike_until_round: Dictionary = {}

## Czeka na najbliższą rundę zimową - patrz komentarz u góry pliku.
var _mild_winter_pending: bool = false


## Zapis stanu (autoloads/save_manager.gd) - powiadomienia (`notifications`,
## już w pełni JSON-bezpiecznym kształcie - String/int) plus wszystkie
## czasowe efekty. Klucze int(player_id) zamienione na String - JSON nie ma
## kluczy innych niż String.
func get_save_state() -> Dictionary:
	var last_seen_out = {}
	for player_id in _last_seen_index:
		last_seen_out[str(player_id)] = _last_seen_index[player_id]
	var pest_plague_out = {}
	for player_id in _pest_plague_until_round:
		pest_plague_out[str(player_id)] = _pest_plague_until_round[player_id]
	var record_harvest_out = {}
	for player_id in _record_harvest_until_round:
		record_harvest_out[str(player_id)] = _record_harvest_until_round[player_id]
	var mining_strike_out = {}
	for player_id in _mining_strike_until_round:
		mining_strike_out[str(player_id)] = _mining_strike_until_round[player_id]
	return {
		"notifications": notifications,
		"last_seen_index": last_seen_out,
		"pest_plague_until_round": pest_plague_out,
		"record_harvest_until_round": record_harvest_out,
		"mining_strike_until_round": mining_strike_out,
		"mild_winter_pending": _mild_winter_pending,
	}


## Wczytanie stanu (autoloads/save_manager.gd) - odwrotność get_save_state().
## Wartości w `notifications` (round/player_id) wracają z JSON jako float
## (JSON zna tylko typ "number") - jawnie rzutowane z powrotem na int, żeby
## reszta kodu (np. porównania player_id == ALL_PLAYERS) działała tak samo
## jak przed zapisem.
func load_save_state(data: Dictionary) -> void:
	notifications.clear()
	for entry in data.get("notifications", []):
		notifications.append({
			"round": int(entry["round"]),
			"message": entry["message"],
			"player_id": int(entry["player_id"]),
		})
	_last_seen_index.clear()
	for player_id_str in data.get("last_seen_index", {}):
		_last_seen_index[int(player_id_str)] = int(data["last_seen_index"][player_id_str])
	_pest_plague_until_round.clear()
	for player_id_str in data.get("pest_plague_until_round", {}):
		_pest_plague_until_round[int(player_id_str)] = int(data["pest_plague_until_round"][player_id_str])
	_record_harvest_until_round.clear()
	for player_id_str in data.get("record_harvest_until_round", {}):
		_record_harvest_until_round[int(player_id_str)] = int(data["record_harvest_until_round"][player_id_str])
	_mining_strike_until_round.clear()
	for player_id_str in data.get("mining_strike_until_round", {}):
		_mining_strike_until_round[int(player_id_str)] = int(data["mining_strike_until_round"][player_id_str])
	_mild_winter_pending = data.get("mild_winter_pending", false)


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


## All notifications concerning `player_id` (its own, plus every ALL_PLAYERS
## one), oldest first.
func get_notifications_for_player(player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in notifications:
		if entry["player_id"] == ALL_PLAYERS or entry["player_id"] == player_id:
			result.append(entry)
	return result


func get_unread_for_player(player_id: int) -> Array[Dictionary]:
	var seen: int = _last_seen_index.get(player_id, 0)
	var result: Array[Dictionary] = []
	for i in range(seen, notifications.size()):
		var entry = notifications[i]
		if entry["player_id"] == ALL_PLAYERS or entry["player_id"] == player_id:
			result.append(entry)
	return result


func get_unread_count_for_player(player_id: int) -> int:
	return get_unread_for_player(player_id).size()


func mark_read_for_player(player_id: int) -> void:
	_last_seen_index[player_id] = notifications.size()


func _log(message: String, player_id: int = ALL_PLAYERS) -> void:
	notifications.append({"round": TurnManager.round_number, "message": message, "player_id": player_id})
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
			_log("🔥 Pożar lasu na polu %s wypalił się doszczętnie." % hex.hex_id, hex.owner_id)
			continue

		if randf() < GameBalance.FOREST_FIRE_SPREAD_CHANCE:
			var spread_target = _pick_spread_target(hex.hex_id)
			if spread_target != null:
				newly_ignited.append(spread_target)
				# Dotyczy właściciela ŹRÓDŁA (heksa, który już płonął) - jeśli
				# ogień akurat przeskoczył na teren innego gracza, ten drugi
				# i tak dowie się, gdy ten heks sam zacznie tracić zasób.
				_log("🔥 Pożar rozprzestrzenił się z pola %s na %s!" % [hex.hex_id, spread_target.hex_id], hex.owner_id)

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

## Wydarzenia "dla wszystkich" - dokładnie jedno z nich stosowane naraz.
## (Wydarzenia "tylko dla 1 gracza" nie mają odpowiednika tej stałej - która
## z nich są dostępne zależy od KAŻDEGO wylosowanego gracza z osobna, patrz
## `_eligible_single_player_events()`.)
const ALL_PLAYERS_EVENTS: Array[EventId] = [
	EventId.MILD_WINTER, EventId.ENVIRONMENTAL_INSPECTION, EventId.MARKET_CRASH,
]


func _roll_event() -> void:
	var players: Array = GameManager.players.values()
	if players.is_empty():
		return

	if randf() < GameBalance.RANDOM_EVENT_SINGLE_PLAYER_CHANCE:
		_roll_single_player_events(players)
	else:
		_apply_all_players_event(ALL_PLAYERS_EVENTS[randi() % ALL_PLAYERS_EVENTS.size()])


## Losuje ILU graczy (1..liczba graczy) dostanie własne wydarzenie w tej
## samej turze, wybiera tylu RÓŻNYCH graczy (każdy co najwyżej raz), i dla
## KAŻDEGO z osobna losuje NIEZALEŻNIE jego konkretne wydarzenie spośród
## tych, na które akurat kwalifikuje się WŁAŚNIE TEN gracz - GRANT/
## TOURISM_BOOM nie mają żadnych wymagań, więc `_eligible_single_player_events()`
## nigdy nie zwraca pustej listy.
func _roll_single_player_events(players: Array) -> void:
	var shuffled = players.duplicate()
	shuffled.shuffle()
	var count = randi_range(1, shuffled.size())

	for i in range(count):
		var player: PlayerData = shuffled[i]
		var eligible = _eligible_single_player_events(player)
		if eligible.is_empty():
			continue
		_apply_single_player_event(eligible[randi() % eligible.size()], player)


func _eligible_single_player_events(player: PlayerData) -> Array[EventId]:
	var result: Array[EventId] = [EventId.GRANT, EventId.TOURISM_BOOM]
	if _pick_unburning_forest_hex(player.player_id) != null:
		result.append(EventId.FOREST_FIRE)
	if _pick_undamaged_mining_hex(player.player_id) != null:
		result.append(EventId.MINING_DAMAGE)
		result.append(EventId.MINING_STRIKE)
	if _player_has_agriculture(player.player_id):
		result.append(EventId.PEST_PLAGUE)
		result.append(EventId.RECORD_HARVEST)
	return result


func _apply_single_player_event(event_id: EventId, player: PlayerData) -> void:
	match event_id:
		EventId.FOREST_FIRE:
			_apply_forest_fire(player)
		EventId.MINING_DAMAGE:
			_apply_mining_damage(player)
		EventId.PEST_PLAGUE:
			_apply_pest_plague(player)
		EventId.GRANT:
			_apply_grant(player)
		EventId.MINING_STRIKE:
			_apply_mining_strike(player)
		EventId.RECORD_HARVEST:
			_apply_record_harvest(player)
		EventId.TOURISM_BOOM:
			_apply_tourism_boom(player)


func _apply_all_players_event(event_id: EventId) -> void:
	match event_id:
		EventId.MILD_WINTER:
			_apply_mild_winter()
		EventId.ENVIRONMENTAL_INSPECTION:
			_apply_environmental_inspection()
		EventId.MARKET_CRASH:
			_apply_market_crash()


func _apply_forest_fire(player: PlayerData) -> void:
	var hex = _pick_unburning_forest_hex(player.player_id)
	hex.is_on_fire = true
	_log(
		"🔥 Pożar lasu wybuchł na polu %s gracza %s! Las traci %.0f%% drzew z każdą rundą, dopóki się nie wypali albo nie zostanie ugaszony (przycisk w pasku bocznym, koszt %.0f pieniędzy, %.0f%% szansy powodzenia)." % [
			hex.hex_id, player.player_name, GameBalance.FOREST_FIRE_DECAY_RATIO * 100.0,
			GameBalance.FOREST_FIRE_EXTINGUISH_COST, GameBalance.FOREST_FIRE_EXTINGUISH_CHANCE * 100.0,
		],
		player.player_id
	)


func _apply_mining_damage(player: PlayerData) -> void:
	var hex = _pick_undamaged_mining_hex(player.player_id)
	hex.building_damaged = true
	_log(
		"⛏️ Szkody górnicze uszkodziły budynek \"%s\" (%s) gracza %s - przestał produkować. Napraw go przyciskiem w pasku bocznym." % [
			hex.building.building_name, hex.hex_id, player.player_name,
		],
		player.player_id
	)


func _apply_mild_winter() -> void:
	_mild_winter_pending = true
	_log("❄️ Łagodna zima! Plony będą rosnąć normalnie mimo zimy - premia zadziała przy najbliższej zimowej rundzie.")


func _apply_pest_plague(player: PlayerData) -> void:
	var until_round = TurnManager.round_number + GameBalance.PEST_PLAGUE_ROUNDS - 1
	_pest_plague_until_round[player.player_id] = until_round
	_log(
		"🐛 Plaga szkodników uderzyła w pola gracza %s - żywność nie urośnie przez %d rundy (do rundy %d włącznie)." % [
			player.player_name, GameBalance.PEST_PLAGUE_ROUNDS, until_round,
		],
		player.player_id
	)


func _apply_grant(player: PlayerData) -> void:
	var amount = randf_range(GameBalance.GRANT_MONEY_MIN, GameBalance.GRANT_MONEY_MAX)
	player.add_money(amount)
	_log("💶 Dotacja unijna! Gracz %s otrzymał %.0f pieniędzy." % [player.player_name, amount], player.player_id)


func _apply_mining_strike(player: PlayerData) -> void:
	var until_round = TurnManager.round_number + GameBalance.MINING_STRIKE_ROUNDS - 1
	_mining_strike_until_round[player.player_id] = until_round
	_log(
		"⚒️ Strajk górniczy u gracza %s - kopalnie i gazoporty nie produkują przez %d rundy (do rundy %d włącznie)." % [
			player.player_name, GameBalance.MINING_STRIKE_ROUNDS, until_round,
		],
		player.player_id
	)


func _apply_record_harvest(player: PlayerData) -> void:
	var until_round = TurnManager.round_number + GameBalance.RECORD_HARVEST_ROUNDS - 1
	_record_harvest_until_round[player.player_id] = until_round
	_log(
		"🌾 Rekordowe żniwa stulecia u gracza %s - produkcja żywności x%.0f przez %d rund (do rundy %d włącznie)." % [
			player.player_name, GameBalance.RECORD_HARVEST_MULTIPLIER, GameBalance.RECORD_HARVEST_ROUNDS, until_round,
		],
		player.player_id
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
func _apply_tourism_boom(player: PlayerData) -> void:
	var money = randf_range(GameBalance.TOURISM_BOOM_MONEY_MIN, GameBalance.TOURISM_BOOM_MONEY_MAX)
	var prestige = randi_range(GameBalance.TOURISM_BOOM_PRESTIGE_MIN, GameBalance.TOURISM_BOOM_PRESTIGE_MAX)
	player.add_money(money)
	GameManager.change_prestige(player.player_id, prestige)
	_log(
		"🏰 Turystyczny boom u gracza %s - +%.0f pieniędzy, +%d prestiżu." % [
			player.player_name, money, prestige,
		],
		player.player_id
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


func _player_has_agriculture(player_id: int) -> bool:
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id == player_id and hex.is_agricultural():
			return true
	return false
