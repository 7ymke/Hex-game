extends Node
## Autoload: GameManager
## Rejestr graczy i akcje rdzenia rozgrywki: aneksacja, wydobycie lasu,
## przejęcie terytorium. Wszystkie zmiany prestiżu przechodzą przez tu -
## sekcja 7 planu implementacji ("scentralizowana funkcja zmiany prestiżu").
##
## Stałe balansu (progi, kary, koszty) mieszkają teraz w scripts/game_balance.gd
## - patrz tam, żeby je stroić.

signal prestige_changed(player_id: int, new_value: int, delta: int)
signal hex_ownership_changed(hex_id: String, new_owner_id: int)

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
	prestige_changed.emit(player_id, player.prestige, delta)


## Aneksacja - sekcja 2.2/3 GDD: wejście na pole i aneksacja to osobne czynności,
## to wywołanie reprezentuje samą akcję aneksacji (już stojąc na polu, albo -
## po update z Fazy 6+ - w zasięgu GameBalance.ACTION_RANGE od ludzika).
##
## Koszt w punktach ruchu (sekcja 2.2 GDD) jest sprawdzany i pobierany PRZED
## wywołaniem tej funkcji, na poziomie game_map_controller.gd - stamtąd, bo
## MP należą teraz do konkretnego ludzika (węzła sceny), a nie do gracza, i
## GameManager celowo nic nie wie o ludzikach/scenie.
##
## Same aneksacja strefy chronionej NIE karze już prestiżem (update) - kara
## nalicza się dopiero, gdy ktoś faktycznie zabuduje/naprawi budynek na takim
## terenie (patrz `repair_building`).
func annex_hex(hex_id: String, player_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return {"success": false, "reason": "hex_not_found"}
	if hex.owner_id != -1:
		return {"success": false, "reason": "already_owned"}

	hex.owner_id = player_id
	hex.set_fog_state(player_id, "annexed")
	hex_ownership_changed.emit(hex_id, player_id)

	return {"success": true, "terrain": hex.terrain_type, "resource": hex.resource_type}


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
	var wood_gained: float = hex.resource_level * (harvest_percent / 100.0)
	player.add_resource(HexData.ResourceType.WOOD, wood_gained)

	# Prestiż: kara i wyłączenie generowania TYLKO przy przekroczeniu progu.
	var over_harvest: float = harvest_percent - GameBalance.FOREST_SAFE_THRESHOLD_PERCENT
	var prestige_penalty = 0
	if over_harvest > 0.0:
		prestige_penalty = int(round(over_harvest * GameBalance.FOREST_OVERHARVEST_PENALTY_PER_PERCENT))
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
	var penalty = int(round(GameBalance.PROTECTED_AREA_BASE_PENALTY * damage_scale))
	change_prestige(player_id, -penalty)

	return {"success": true, "prestige_penalty": penalty}


## Przejęcie terytorium - sekcja 5 GDD.
func attempt_takeover(hex_id: String, attacker_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null or hex.owner_id == -1:
		return {"success": false, "reason": "no_owner"}
	if hex.owner_id == attacker_id:
		return {"success": false, "reason": "already_owner"}

	var attacker = get_player(attacker_id)
	var defender = get_player(hex.owner_id)
	if attacker == null or defender == null:
		return {"success": false, "reason": "invalid_players"}

	if attacker.prestige <= defender.prestige:
		return {"success": false, "reason": "insufficient_prestige"}

	var cost = int(round(defender.prestige * GameBalance.TAKEOVER_COST_RATIO))
	change_prestige(attacker_id, -cost)

	var previous_owner = hex.owner_id
	hex.owner_id = attacker_id
	hex_ownership_changed.emit(hex_id, attacker_id)

	return {"success": true, "cost": cost, "previous_owner": previous_owner}


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
