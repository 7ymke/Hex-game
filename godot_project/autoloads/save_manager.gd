extends Node
## Autoload: SaveManager
## Cały system zapisu/wczytania gry (życzenie: "Zrób też system saveovania
## gry", potem "Chcę aby opcja wczytaj grę wyświetlała listę wszystkich gier
## jakie były grane") - WIELE zapisów na dysku, jeden PLIK PER ROZGRYWKA
## (`user://saves/<id>.json`), więc `scenes/load_game_screen.tscn` może
## pokazać je wszystkie do wyboru, zamiast cicho wczytywać jeden domyślny
## zapis.
##
## SaveManager to WYŁĄCZNIE warstwa I/O + serializacji (Dictionary <-> JSON
## na dysku) - NIE stosuje wczytanych danych z powrotem do gry samodzielnie.
## To robi scenes/game_map_controller.gd::_load_saved_game(), analogicznie do
## jego własnego _setup_players() (świeża gra) - tam, a nie tu, powstają
## PlayerData/Unit i wypełniają się `players`/`player_units`, bo to lokalny
## stan tamtej sceny.
##
## Podsystemy z WŁASNYM prywatnym stanem (MarketManager, RandomEventManager,
## DiplomacyManager) mają swoją parę get_save_state()/load_save_state() -
## SaveManager tylko je woła, nie sięga do ich wewnętrznych zmiennych
## bezpośrednio. Heksy/gracze/jednostki/tura nie mają (i nie potrzebują)
## własnych odpowiedników -
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

const SAVES_DIR = "user://saves"
const SAVE_VERSION = 1

## Id AKTUALNIE granej rozgrywki - ustawiane na dwa sposoby:
## - Nowa gra: `game_map_controller._setup_players()` woła `new_save_id()`
##   przy starcie, więc każda nowa rozgrywka dostaje własny, osobny plik.
## - Wczytana gra: `load_game(save_id)` ustawia to na wczytane `save_id` jako
##   efekt uboczny (patrz tam) - kolejne autosave'y tej rozgrywki nadpisują
##   TEN SAM plik, zamiast tworzyć nowy przy każdej rundzie.
## Puste ("") oznacza "żadna rozgrywka jeszcze się nie zaczęła" - save_game()
## wywołane w tym stanie (nie powinno się zdarzyć w normalnym przepływie gry)
## samo sobie generuje id, żeby nigdy nie zapisać do pliku bez nazwy.
var current_save_id: String = ""

## Ustawiane przez scenes/load_game_screen.gd PRZED
## change_scene_to_file("res://scenes/main.tscn") - scenes/game_map_controller.gd
## odczytuje i czyści to w _ready(), analogicznie do GameSetup.selected_player_ids
## (jedyny inny stan, który dziś przeżywa zmianę sceny).
var pending_load_data: Dictionary = {}


func has_save() -> bool:
	return DirAccess.dir_exists_absolute(SAVES_DIR) and not DirAccess.get_files_at(SAVES_DIR).is_empty()


## Nowe, unikalne id rozgrywki - znacznik czasu (sekundy) + losowy sufiks
## (na wypadek dwóch nowych gier w tej samej sekundzie, teoretycznie
## niemożliwe w praktyce, skoro trzeba przejść przez ekran wyboru miast, ale
## tani dodatkowy margines bezpieczeństwa). Tylko cyfry/podkreślnik - bezpieczne
## jako nazwa pliku na każdej platformie (bez dwukropków z formatu ISO).
func new_save_id() -> String:
	return "%d_%03d" % [int(Time.get_unix_time_from_system()), randi() % 1000]


func _save_path(save_id: String) -> String:
	return "%s/%s.json" % [SAVES_DIR, save_id]


## Lista WSZYSTKICH zapisanych rozgrywek (na życzenie: "Chcę aby opcja
## wczytaj grę wyświetlała listę wszystkich gier jakie były grane") - do
## zbudowania listy w scenes/load_game_screen.gd. Czyta tylko `meta` z
## każdego pliku (patrz `_gather_meta()`), nie cały zapis - najnowsze
## pierwsze.
func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return result

	for filename in DirAccess.get_files_at(SAVES_DIR):
		if not filename.ends_with(".json"):
			continue

		var file = FileAccess.open(SAVES_DIR + "/" + filename, FileAccess.READ)
		var text = file.get_as_text()
		file.close()

		var parsed = JSON.parse_string(text)
		if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
			continue  # uszkodzony zapis - pomijany na liście zamiast wywalać całą listę
		var meta: Dictionary = parsed.get("meta", {})

		var player_names: Array[String] = []
		for player_name in meta.get("player_names", []):
			player_names.append(player_name)

		result.append({
			"id": meta.get("id", filename.trim_suffix(".json")),
			"saved_at_unix": int(meta.get("saved_at_unix", 0)),
			"saved_at_display": meta.get("saved_at_display", "?"),
			"round_number": int(meta.get("round_number", 1)),
			"player_names": player_names,
		})

	result.sort_custom(func(a, b): return a["saved_at_unix"] > b["saved_at_unix"])
	return result


## Zbiera cały stan gry i zapisuje go na dysk, do pliku bieżącej rozgrywki
## (`current_save_id`). Zwraca false, jeśli nie udało się otworzyć pliku do
## zapisu (dysk pełny, brak uprawnień) - system plików to granica systemu, w
## odróżnieniu od reszty kodu, który ufa wewnętrznym niezmiennikom gry.
func save_game() -> bool:
	if current_save_id == "":
		current_save_id = new_save_id()
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)

	var data = {
		"version": SAVE_VERSION,
		"meta": _gather_meta(),
		"round_number": TurnManager.round_number,
		"current_player_id": TurnManager.get_current_player_id(),
		"player_ids": GameManager.players.keys(),
		"players": _gather_players(),
		"hexes": _gather_hexes(),
		"units": _gather_units(),
		"market": MarketManager.get_save_state(),
		"events": RandomEventManager.get_save_state(),
		"diplomacy": DiplomacyManager.get_save_state(),
	}

	var file = FileAccess.open(_save_path(current_save_id), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: nie udało się otworzyć %s do zapisu." % _save_path(current_save_id))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Zwraca surowy, sparsowany zapis o podanym `save_id` (JSON -> Dictionary,
## bez żadnej zmiany kształtu) albo pusty Dictionary, jeśli taki zapis nie
## istnieje albo plik jest uszkodzony (JSON.parse_string() zwraca null przy
## błędzie parsowania). Zastosowanie tych danych do żywej gry to zadanie
## game_map_controller._load_saved_game() - patrz komentarz na górze pliku.
##
## Efekt uboczny: przy sukcesie ustawia `current_save_id = save_id`, żeby
## kolejne autosave'y tej (teraz wczytanej) rozgrywki nadpisywały TEN SAM
## plik zamiast zakładać nowy - patrz komentarz przy `current_save_id`.
func load_game(save_id: String) -> Dictionary:
	var path = _save_path(save_id)
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: nie udało się sparsować %s" % path)
		return {}

	current_save_id = save_id
	return parsed


## Dane do listy w scenes/load_game_screen.gd - NIE część stanu rozgrywki
## (heksy/gracze/...), tylko opis samego zapisu, więc list_saves() może je
## odczytać bez parsowania/interpretowania reszty pliku.
func _gather_meta() -> Dictionary:
	var player_names: Array[String] = []
	for player: PlayerData in GameManager.players.values():
		player_names.append(player.player_name)

	var datetime = Time.get_datetime_dict_from_system()
	return {
		"id": current_save_id,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"saved_at_display": "%02d.%02d.%04d %02d:%02d" % [
			datetime["day"], datetime["month"], datetime["year"], datetime["hour"], datetime["minute"],
		],
		"round_number": TurnManager.round_number,
		"player_names": player_names,
	}


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
			"road_infrastructure": player.road_infrastructure,
			"fortifications": player.fortifications,
			"industrial_income_bonus": player.industrial_income_bonus,
			"crisis_management": player.crisis_management,
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
