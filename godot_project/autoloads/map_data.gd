extends Node
## Autoload: MapData
## Wczytuje siatkę heksów z data/map_data.json (wygenerowanego przez
## tools/convert_kml_to_json.py, Faza 1 planu implementacji) i udostępnia
## dostęp do niej po ID oraz po współrzędnych osiowych.

const MAP_DATA_PATH = "res://data/map_data.json"

var hexes: Dictionary = {}          # hex_id(String) -> HexData
var _by_axial: Dictionary = {}      # Vector2i(q, r) -> hex_id(String), indeks pomocniczy


func _ready() -> void:
	load_map()


func load_map() -> void:
	hexes.clear()
	_by_axial.clear()

	if not FileAccess.file_exists(MAP_DATA_PATH):
		push_warning("MapData: brak pliku %s - mapa nie została wczytana." % MAP_DATA_PATH)
		return

	var file = FileAccess.open(MAP_DATA_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed.has("hexes"):
		push_error("MapData: nie udało się sparsować %s" % MAP_DATA_PATH)
		return

	for hex_dict in parsed["hexes"]:
		var hex = HexData.from_dict(hex_dict)
		if hex.hex_id == "":
			continue
		_attach_placeholder_building(hex)
		hexes[hex.hex_id] = hex
		_by_axial[Vector2i(hex.axial_q, hex.axial_r)] = hex.hex_id

	print("MapData: wczytano %d heksów z %s" % [hexes.size(), MAP_DATA_PATH])


## Faza 5 (TYMCZASOWE): dla heksów z przypisanym zasobem strategicznym (gaz,
## miedź, węgiel...) tworzymy placeholder Building, żeby dało się przetestować
## naprawę i dochód, zanim powstanie właściwa treść budynków (Faza 8 - Karta
## Miasta i osobne dane budynków, np. w osobnym pliku JSON/resource).
func _attach_placeholder_building(hex: HexData) -> void:
	if hex.resource_type == HexData.ResourceType.NONE:
		return
	var building = Building.new()
	building.building_name = "%s (placeholder)" % HexData.ResourceType.keys()[hex.resource_type]
	building.building_type = Building.BuildingType.RESOURCE_NODE
	building.produced_resource = hex.resource_type
	building.produced_amount_per_turn = 10.0
	building.required_resources = {}  # brak kosztu naprawy na razie - do ustalenia treściowo
	hex.building = building
	hex.building_damaged = true


func get_hex(hex_id: String) -> HexData:
	return hexes.get(hex_id, null)


func get_hex_at(q: int, r: int) -> HexData:
	var id: String = _by_axial.get(Vector2i(q, r), "")
	if id == "":
		return null
	return hexes[id]


## Sąsiedzi w siatce "offset odd-r" (pointy-top) - sekcja 2.1 GDD.
## Matematyka w scripts/hex_grid_utils.gd (HexGridUtils).
func get_neighbors(hex_id: String) -> Array[HexData]:
	var hex = get_hex(hex_id)
	var result: Array[HexData] = []
	if hex == null:
		return result

	for coord in HexGridUtils.offset_neighbors(hex.axial_q, hex.axial_r):
		var neighbor = get_hex_at(coord.x, coord.y)
		if neighbor != null:
			result.append(neighbor)
	return result
