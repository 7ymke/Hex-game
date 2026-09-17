extends Node
## Autoload: SaveManager
## Cały system zapisu/wczytania gry (życzenie: "Zrób też system saveovania
## gry") - JEDEN slot na dysku (user://save.json), bez nazwanych zapisów -
## pasuje do prostego, binarnego wyboru "Nowa gra / Wczytaj grę" na ekranie
## startowym (scenes/main_menu.gd).
##
## SaveManager to WYŁĄCZNIE warstwa I/O + serializacji (Dictionary <-> JSON
## na dysku) - NIE stosuje wczytanych danych z powrotem do gry samodzielnie.
## To robi scenes/game_map_controller.gd::_load_saved_game(), analogicznie do
## jego własnego _setup_players() (świeża gra) - tam, a nie tu, powstają
## PlayerData/Unit i wypełniają się `players`/`player_units`, bo to lokalny
## stan tamtej sceny.
##
## Podsystemy z WŁASNYM prywatnym stanem (MarketManager, RandomEventManager)
## mają swoją parę get_save_state()/load_save_state() - SaveManager tylko je
## woła, nie sięga do ich wewnętrznych zmiennych bezpośrednio. Heksy/gracze/
## jednostki/tura nie mają (i nie potrzebują) własnych odpowiedników -
## save_game() czyta je wprost z MapData.hexes, GameManager.players,
## get_tree().get_nodes_in_group("units") i TurnManager.
##
## WSZYSTKIE ~496 heksów są zapisywane bezwarunkowo (nie tylko odkryte/
## zaanektowane) - inaczej pamięć mgły wojny (HexData.fog_state, niepusta też
## dla heksów tylko WIDZIANYCH, nie zaanektowanych) ginęłaby bezpowrotnie przy
## wczytaniu.
##
## Tożsamość gracza (imię/miasto/kolor/heks startowy) NIE jest zapisywana -
## to stałe dane z scripts/player_setup.gd (PlayerSetup.LIST), wspólne dla
## start_screen.gd i game_map_controller.gd - przy wczytaniu odczytywane z
## powrotem po player_id.
##
## Liczby z JSON.parse_string() wracają ZAWSZE jako float (JSON zna tylko typ
## "number", nie ma osobnego int) - każde miejsce, gdzie coś ma być int
## (player_id, round_number, owner_id, klucze zamienione na String...) musi
## jawnie rzutować int(...) przy odczycie - patrz _load_saved_game() w
## game_map_controller.gd.

const SAVE_PATH = "user://save.json"
const SAVE_VERSION = 1

## Ustawiane przez scenes/main_menu.gd (przycisk "Wczytaj grę") PRZED
## change_scene_to_file("res://scenes/main.tscn") - scenes/game_map_controller.gd
## odczytuje i czyści to w _ready(), analogicznie do GameSetup.selected_player_ids
## (jedyny inny stan, który dziś przeżywa zmianę sceny).
var pending_load_data: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Zbiera cały stan gry i zapisuje go na dysk. Zwraca false, jeśli nie udało
## się otworzyć pliku do zapisu (dysk pełny, brak uprawnień) - system plików
## to granica systemu, w odróżnieniu od reszty kodu, który ufa wewnętrznym
## niezmiennikom gry.
func save_game() -> bool:
	var data = {
		"version": SAVE_VERSION,
		"round_number": TurnManager.round_number,
		"current_player_id": TurnManager.get_current_player_id(),
		"player_ids": GameManager.players.keys(),
		"players": _gather_players(),
		"hexes": _gather_hexes(),
		"units": _gather_units(),
		"market": MarketManager.get_save_state(),
		"events": RandomEventManager.get_save_state(),
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: nie udało się otworzyć %s do zapisu." % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Zwraca surowy, sparsowany zapis (JSON -> Dictionary, bez żadnej zmiany
## kształtu) albo pusty Dictionary, jeśli nie ma zapisu albo plik jest
## uszkodzony (JSON.parse_string() zwraca null przy błędzie parsowania).
## Zastosowanie tych danych do żywej gry to zadanie
## game_map_controller._load_saved_game() - patrz komentarz na górze pliku.
func load_game() -> Dictionary:
	if not has_save():
		return {}

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: nie udało się sparsować %s" % SAVE_PATH)
		return {}
	return parsed


func _gather_players() -> Dictionary:
	var out = {}
	for player_id in GameManager.players:
		var player: PlayerData = GameManager.players[player_id]
		var resources_out = {}
		for res_type in player.resources:
			resources_out[str(res_type)] = player.resources[res_type]
		out[str(player_id)] = {
			"prestige": player.prestige,
			"money": player.money,
			"resources": resources_out,
			"unlocked_city_buildings": player.unlocked_city_buildings,
			"unlocked_skills": player.unlocked_skills,
			"movement_points_bonus": player.movement_points_bonus,
			"vision_radius_bonus": player.vision_radius_bonus,
			"forest_safe_threshold_bonus": player.forest_safe_threshold_bonus,
			"annex_cost_reduction": player.annex_cost_reduction,
		}
	return out


func _gather_hexes() -> Dictionary:
	var out = {}
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		var fog_out = {}
		for player_id in hex.fog_state:
			fog_out[str(player_id)] = hex.fog_state[player_id]
		out[hex_id] = {
			"owner_id": hex.owner_id,
			"resource_level": hex.resource_level,
			"generates_prestige": hex.generates_prestige,
			"building_damaged": hex.building_damaged,
			"is_capital": hex.is_capital,
			"is_on_fire": hex.is_on_fire,
			"fog_state": fog_out,
		}
	return out


## `get_tree().get_nodes_in_group("units")` (Unit._ready() -> add_to_group,
## scenes/unit.gd) zamiast sięgania do game_map_controller.gd's `player_units`
## - SaveManager świadomie nic nie wie o strukturze konkretnej sceny, tylko o
## drzewie węzłów, dokładnie jak reszta autoloadów w tym projekcie.
func _gather_units() -> Array:
	var out = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit: Unit = node
		out.append({
			"player_id": unit.player_id,
			"current_hex_id": unit.current_hex_id,
			"movement_points_max": unit.movement_points_max,
			"movement_points_current": unit.movement_points_current,
			"auto_annex": unit.auto_annex,
		})
	return out
