class_name HexPathfinder
extends RefCounted
## A* na siatce heksów - sekcja 3 GDD ("Pathfinding: A* po heksach lądowych,
## z uwzględnieniem wag terenowych, omijający wodę i tereny zablokowane").
##
## Implementacja: AStar2D Godota, gdzie każdy przejezdny heks to punkt.
## Koszt wejścia na heks ~ HexData.get_movement_cost() poprzez weight_scale
## punktu (AStar2D liczy koszt krawędzi jako odległość euklidesową razy
## weight_scale punktu docelowego; ponieważ odległość między sąsiednimi
## środkami heksów jest zawsze taka sama, w praktyce daje to koszt
## proporcjonalny do kosztu terenowego heksa, do którego się wchodzi).

const HEX_SIZE := 40.0

var _astar := AStar2D.new()
var _id_to_hex: Dictionary = {}   # int -> String hex_id
var _hex_to_id: Dictionary = {}   # String hex_id -> int


## `blocked_hex_ids`: heksy wyłączone z grafu ruchu - sekcja 3 GDD, "funkcja
## obronna" (dopóki ludzik innego gracza stoi na heksie, nikt inny nie może
## na niego wejść, więc taki heks nie może być ani przystankiem, ani
## tranzytem trasy). Wywołujące (game_map_controller.gd) przebudowuje graf
## przed każdym wyszukaniem trasy z aktualnym zestawem heksów zajętych przez
## PRZECIWNYCH graczy.
func build(blocked_hex_ids: Array[String] = []) -> void:
	_astar.clear()
	_id_to_hex.clear()
	_hex_to_id.clear()

	var next_id := 0
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		if not hex.is_passable():
			continue
		if blocked_hex_ids.has(hex_id):
			continue
		_id_to_hex[next_id] = hex_id
		_hex_to_id[hex_id] = next_id
		var pos := HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, HEX_SIZE)
		_astar.add_point(next_id, pos, float(hex.get_movement_cost()))
		next_id += 1

	for hex_id in _hex_to_id:
		var hex: HexData = MapData.hexes[hex_id]
		var from_id: int = _hex_to_id[hex_id]
		for neighbor_coord in HexGridUtils.offset_neighbors(hex.axial_q, hex.axial_r):
			var neighbor_hex := MapData.get_hex_at(neighbor_coord.x, neighbor_coord.y)
			if neighbor_hex == null or not neighbor_hex.is_passable():
				continue
			var to_id: int = _hex_to_id.get(neighbor_hex.hex_id, -1)
			if to_id == -1:
				continue
			if not _astar.are_points_connected(from_id, to_id):
				_astar.connect_points(from_id, to_id)


## Zwraca listę hex_id od `from_hex_id` do `to_hex_id` (włącznie z obydwoma
## końcami), albo pustą tablicę, jeśli nie ma połączenia.
func find_path(from_hex_id: String, to_hex_id: String) -> Array[String]:
	var result: Array[String] = []
	if not _hex_to_id.has(from_hex_id) or not _hex_to_id.has(to_hex_id):
		return result

	var from_id: int = _hex_to_id[from_hex_id]
	var to_id: int = _hex_to_id[to_hex_id]
	var id_path := _astar.get_id_path(from_id, to_id)
	for id in id_path:
		result.append(_id_to_hex[id])
	return result
