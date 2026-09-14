extends Node
## Autoload: GameManager
## Rejestr graczy i akcje rdzenia rozgrywki: aneksacja, wydobycie lasu,
## przejęcie terytorium. Wszystkie zmiany prestiżu przechodzą przez tu -
## sekcja 7 planu implementacji ("scentralizowana funkcja zmiany prestiżu").
##
## Stałe balansu (progi, kary, koszty) mieszkają teraz w scripts/game_balance.gd
## - patrz tam, żeby je stroić.

var players: Dictionary = {}  # player_id(int) -> PlayerData


func register_player(player_data: PlayerData) -> void:
	players[player_data.player_id] = player_data


func get_player(player_id: int) -> PlayerData:
	return players.get(player_id, null)


## Scentralizowana zmiana prestiżu - sekcja 7 planu implementacji.
func change_prestige(player_id: int, delta: int) -> void:
	var player = get_player(player_id)
	if player == null:
		return
	player.modify_prestige(delta)


## Aneksacja - sekcja 2.2/3 GDD: wejście na pole i aneksacja to osobne czynności,
## to wywołanie reprezentuje samą akcję aneksacji, wykonywaną stojąc na polu
## (w przeciwieństwie do reszty akcji na polu, które po update działają z
## dowolnej odległości na już zaanektowanym terenie - patrz
## game_map_controller.gd, sekcja "akcje na polu").
##
## Koszt w punktach ruchu (sekcja 2.2 GDD) jest sprawdzany i pobierany PRZED
## wywołaniem tej funkcji, na poziomie game_map_controller.gd - stamtąd, bo
## MP należą teraz do konkretnego ludzika (węzła sceny), a nie do gracza, i
## GameManager celowo nic nie wie o ludzikach/scenie.
##
## Same aneksacja strefy chronionej NIE karze już prestiżem (update) - kara
## nalicza się dopiero, gdy ktoś faktycznie zabuduje/naprawi budynek na takim
## terenie (patrz `repair_building`).
##
## Update: aneksować można TYLKO pole sąsiadujące z już posiadanym polem
## tego samego gracza (terytorium musi rosnąć spójnie, nie "skakać" po
## mapie) - `require_adjacency` domyślnie true. Jedyny wyjątek to POCZĄTKOWA
## aneksacja stolicy gracza (`game_map_controller._setup_players()`), gdzie
## gracz jeszcze NIC nie posiada, więc wymóg sąsiedztwa byłby niespełnialny -
## tam wywołanie jawnie przekazuje `false`.
func annex_hex(hex_id: String, player_id: int, require_adjacency: bool = true) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return {"success": false, "reason": "hex_not_found"}
	if hex.owner_id != -1:
		return {"success": false, "reason": "already_owned"}
	if require_adjacency and not has_adjacent_owned_hex(hex_id, player_id):
		return {"success": false, "reason": "not_adjacent"}

	hex.owner_id = player_id
	hex.set_fog_state(player_id, HexData.FogState.ANNEXED)

	return {"success": true, "terrain": hex.terrain_type, "resource": hex.resource_type}


## Czy `hex_id` ma choć jednego sąsiada należącego do `player_id` - warunek
## aneksacji (wyżej) i podstawa stanu przycisku "Zaanektuj" w
## game_map_controller.gd (`_can_annex_selected_hex()`), żeby UI i faktyczna
## reguła zawsze się zgadzały.
func has_adjacent_owned_hex(hex_id: String, player_id: int) -> bool:
	for neighbor in MapData.get_neighbors(hex_id):
		if neighbor.owner_id == player_id:
			return true
	return false


## Wydobycie lasu - sekcja 6.1 GDD.
## harvest_percent: ile % AKTUALNEGO poziomu zasobu (nie z 100%!) gracz wydobywa.
func harvest_forest(hex_id: String, player_id: int, harvest_percent: float) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	var player = get_player(player_id)

	if hex == null or player == null:
		return {"success": false, "reason": "invalid_hex_or_player"}
	if not hex.is_forest():
		return {"success": false, "reason": "not_a_forest_hex"}
	if hex.owner_id != player_id:
		return {"success": false, "reason": "not_owner"}

	harvest_percent = clampf(harvest_percent, 0.0, 100.0)

	# Surowiec: zawsze wydawany wg wyboru gracza, niezależnie od kary.
	# WAŻNE: wydobyta ilość schodzi z resource_level pola (sekcja 6.1 GDD -
	# "ile drewna jest obecnie DOSTĘPNE do wydobycia") - bez tego odjęcia las
	# nigdy by się nie wyczerpywał i dawałby to samo drewno w nieskończoność,
	# niezależnie od regeneracji w turn_manager.gd.
	var wood_gained: float = hex.resource_level * (harvest_percent / 100.0)
	hex.resource_level -= wood_gained
	player.add_resource(HexData.ResourceType.WOOD, wood_gained)

	# Prestiż: kara i wyłączenie generowania TYLKO przy przekroczeniu progu.
	# Próg podniesiony o ewentualny bonus z drzewka umiejętności (skill
	# "advanced_logging" - patrz scripts/skill_tree_data.gd), 0.0 domyślnie.
	var safe_threshold = GameBalance.FOREST_SAFE_THRESHOLD_PERCENT + player.forest_safe_threshold_bonus
	var over_harvest: float = harvest_percent - safe_threshold
	var prestige_penalty = 0
	if over_harvest > 0.0:
		prestige_penalty = roundi(over_harvest * GameBalance.FOREST_OVERHARVEST_PENALTY_PER_PERCENT)
		change_prestige(player_id, -prestige_penalty)
		hex.generates_prestige = false

	# Wycinka lasu na terenie chronionym (sekcja 4 GDD) - w obecnym modelu
	# terenu (jeden typ na heks) heks nie może być jednocześnie "forest" i
	# "protected_area", więc ta gałąź jest na razie martwa, ale zostaje na
	# wypadek, gdyby przyszłe dane terenu zaczęły oznaczać takie nakładanie
	# się osobną flagą zamiast wyłącznym typem terenu.
	if hex.is_protected():
		var protection_result = damage_protected_area(hex_id, player_id, 1.0)
		prestige_penalty += protection_result.get("prestige_penalty", 0)

	return {
		"success": true,
		"wood_gained": wood_gained,
		"prestige_penalty": prestige_penalty,
		"safe_threshold": safe_threshold,
	}


## Zniszczenie/zabudowa strefy chronionej - sekcja 4 GDD (kara proporcjonalna
## do skali zniszczeń, współczynnik damage_scale w zakresie 0-1 jako
## placeholder na "jak dużo zniszczono"; dokładna definicja "skali zniszczeń"
## - otwarty punkt GDD). Wywoływane z `repair_building` (budowa/naprawa na
## terenie chronionym) i defensywnie z `harvest_forest` - patrz tam.
func damage_protected_area(hex_id: String, player_id: int, damage_scale: float) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null or not hex.is_protected():
		return {"success": false, "reason": "not_protected"}

	damage_scale = clampf(damage_scale, 0.0, 1.0)
	var penalty = roundi(GameBalance.PROTECTED_AREA_BASE_PENALTY * damage_scale)
	change_prestige(player_id, -penalty)

	return {"success": true, "prestige_penalty": penalty}


## Przejęcie terytorium - sekcja 5 GDD (update). Wymaga fizycznej obecności
## na polu (sprawdzane przez game_map_controller.gd, tak jak przy aneksacji -
## GameManager celowo nic nie wie o ludzikach) - to jedyny powód, dla którego
## dwóch różnych graczy nigdy nie stoi jednocześnie na tym samym heksie, więc
## osobne sprawdzanie "czy broniący ludzik akurat tu stoi" nie jest już
## potrzebne (sama fizyczna obecność atakującego to już wyklucza).
##
## Zawsze da się PRÓBOWAĆ - w przeciwieństwie do poprzedniej wersji, gdzie
## niewystarczający prestiż był twardą blokadą bez żadnego skutku. Teraz:
## - Prestiż atakującego ŚCIŚLE większy niż obrońcy -> sukces: obrońca traci
##   `TAKEOVER_DEFENDER_LOSS_RATIO` WŁASNEGO prestiżu (koszt bycia podbitym),
##   atakujący płaci `TAKEOVER_COST_RATIO` prestiżu obrońcy (jak dotąd).
## - W przeciwnym razie -> nieudana próba: obrońca NIE TRACI NIC, ale
##   atakujący płaci karę proporcjonalną do przewagi obrońcy (im bardziej
##   nierówna walka, tym droższa porażka) - "dobry wzór" na to, żeby zniechęcać
##   do desperackich prób bez faktycznie karania silniejszej strony za to, że
##   ktoś słabszy spróbował.
func attempt_takeover(hex_id: String, attacker_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null or hex.owner_id == -1:
		return {"success": false, "reason": "no_owner"}
	if hex.owner_id == attacker_id:
		return {"success": false, "reason": "already_owner"}
	if hex.is_capital:
		return {"success": false, "reason": "capital_protected"}

	var attacker = get_player(attacker_id)
	var defender = get_player(hex.owner_id)
	if attacker == null or defender == null:
		return {"success": false, "reason": "invalid_players"}

	if attacker.prestige <= defender.prestige:
		var penalty = maxi(1, roundi((defender.prestige - attacker.prestige) * GameBalance.FAILED_TAKEOVER_PENALTY_RATIO))
		change_prestige(attacker_id, -penalty)
		return {"success": false, "reason": "insufficient_prestige", "attacker_penalty": penalty}

	var cost = roundi(defender.prestige * GameBalance.TAKEOVER_COST_RATIO)
	var defender_loss = roundi(defender.prestige * GameBalance.TAKEOVER_DEFENDER_LOSS_RATIO)
	change_prestige(attacker_id, -cost)
	change_prestige(hex.owner_id, -defender_loss)

	var previous_owner = hex.owner_id
	hex.owner_id = attacker_id

	return {"success": true, "cost": cost, "defender_loss": defender_loss, "previous_owner": previous_owner}


## Odblokowanie budynku charakterystycznego w Karcie Miasta - sekcja 7 GDD.
## Scentralizowane tu (a nie w UI Karty Miasta), żeby - tak jak inne akcje -
## płatność zasobami i przyznanie prestiżu (sekcja 7: "główny fundament pod
## przyszły warunek zwycięstwa - punkty prestiżu za skompletowane budynki")
## przechodziły przez jedno miejsce.
func unlock_city_building(player_id: int, building: Building) -> Dictionary:
	var player = get_player(player_id)
	if player == null or building == null:
		return {"success": false, "reason": "invalid_player_or_building"}
	if player.unlocked_city_buildings.has(building.building_name):
		return {"success": false, "reason": "already_unlocked"}
	if not player.pay_costs(building.required_resources):
		return {"success": false, "reason": "cannot_afford"}

	player.unlocked_city_buildings.append(building.building_name)
	if building.prestige_value != 0:
		change_prestige(player_id, building.prestige_value)

	return {"success": true, "prestige_gained": building.prestige_value}


## Odblokowanie węzła drzewka umiejętności (scripts/skill_tree_data.gd) -
## ten sam mechanizm płatności co unlock_city_building() wyżej. Efekty
## "czysto danowe" (bez potrzeby dostępu do węzłów sceny) są aplikowane
## wprost tutaj, na akumulatorach PlayerData - żeby były aktywne natychmiast
## i gotowe do odczytu wszędzie, gdzie już dziś czytamy stałe z GameBalance
## (harvest_forest wyżej, _reveal_around/_on_annex_pressed w
## game_map_controller.gd). EXTRA_LUDZIK i retroaktywny bonus MP na już
## istniejących ludzikach WYMAGAJĄ węzłów sceny, których GameManager celowo
## nie zna (tak jak MP przy aneksacji) - te aplikuje
## game_map_controller._on_skill_unlocked() w reakcji na sygnał
## SkillTreePanel.skill_unlocked, korzystając z `effect_type` zwróconego tu.
func unlock_skill(player_id: int, skill: SkillData) -> Dictionary:
	var player = get_player(player_id)
	if player == null or skill == null:
		return {"success": false, "reason": "invalid_player_or_skill"}
	if player.unlocked_skills.has(skill.skill_id):
		return {"success": false, "reason": "already_unlocked"}
	if not player.pay_costs(skill.required_resources):
		return {"success": false, "reason": "cannot_afford"}

	player.unlocked_skills.append(skill.skill_id)
	match skill.effect_type:
		SkillData.EffectType.VISION_RADIUS_BONUS:
			player.vision_radius_bonus += int(skill.effect_amount)
		SkillData.EffectType.FOREST_THRESHOLD_BONUS:
			player.forest_safe_threshold_bonus += skill.effect_amount
		SkillData.EffectType.ANNEX_COST_REDUCTION:
			player.annex_cost_reduction += int(skill.effect_amount)
		SkillData.EffectType.MOVEMENT_POINTS_BONUS:
			player.movement_points_bonus += int(skill.effect_amount)
		SkillData.EffectType.EXTRA_LUDZIK:
			pass  # w całości po stronie game_map_controller.gd

	return {"success": true, "effect_type": skill.effect_type}


## Naprawa budynku - sekcja 3 GDD ("może go naprawić i sprawić, że będzie
## generował zasoby od następnej rundy"). Koszt z Building.required_resources
## (na razie placeholder = {} dla automatycznie wygenerowanych budynków,
## patrz MapData._attach_placeholder_building - Faza 5, tymczasowe).
##
## Jeśli budynek stoi na terenie chronionym, sama naprawa/budowa jest tym,
## co GDD (sekcja 4) nazywa "eksploatacją/zniszczeniem heksa chronionego" -
## i to ONA, nie aneksacja, nalicza karę prestiżową (update).
func repair_building(hex_id: String, player_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	var player = get_player(player_id)

	if hex == null or player == null:
		return {"success": false, "reason": "invalid_hex_or_player"}
	if hex.owner_id != player_id:
		return {"success": false, "reason": "not_owner"}
	if hex.building == null:
		return {"success": false, "reason": "no_building"}
	if not hex.building_damaged:
		return {"success": false, "reason": "already_repaired"}
	if not player.pay_costs(hex.building.required_resources):
		return {"success": false, "reason": "cannot_afford"}

	hex.building_damaged = false

	var result = {"success": true, "prestige_penalty": 0}
	if hex.is_protected():
		var protection_result = damage_protected_area(hex_id, player_id, 1.0)
		result["prestige_penalty"] = protection_result.get("prestige_penalty", 0)

	return result
