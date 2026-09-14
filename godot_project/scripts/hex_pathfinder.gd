class_name HexPathfinder
extends RefCounted
## A* on the hex grid - GDD section 3 ("Pathfinding: A* over land hexes,
## accounting for terrain weights, avoiding water and blocked terrain").
##
## Implementation: Godot's AStar2D, where each passable hex is a point.
## The cost of entering a hex ~ HexData.get_movement_cost() via the point's
## weight_scale (AStar2D computes edge cost as the Euclidean distance times
## the destination point's weight_scale; since the distance between
## neighboring hex centers is always the same, in practice this gives a
## cost proportional to the terrain cost of the hex being entered).

var _astar = AStar2D.new()
var _id_to_hex: Dictionary = {}   # int -> String hex_id
var _hex_to_id: Dictionary = {}   # String hex_id -> int


## `blocked_hex_ids`: hexes excluded from the movement graph - GDD section 3,
## "defensive function" (as long as another player's unit stands on a hex,
## no one else can enter it, so that hex can be neither a stop nor a
## transit point on a route). The caller (game_map_controller.gd) rebuilds
## the graph before every path search with the current set of hexes
## occupied by OPPOSING players.
func build(blocked_hex_ids: Array[String] = []) -> void:
	_astar.clear()
	_id_to_hex.clear()
	_hex_to_id.clear()

	var next_id = 0
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		if not hex.is_passable():
			continue
		if blocked_hex_ids.has(hex_id):
			continue
		_id_to_hex[next_id] = hex_id
		_hex_to_id[hex_id] = next_id
		var pos = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE)
		_astar.add_point(next_id, pos, float(hex.get_movement_cost()))
		next_id += 1

	for hex_id in _hex_to_id:
		var hex: HexData = MapData.hexes[hex_id]
		var from_id: int = _hex_to_id[hex_id]
		for neighbor_coord in HexGridUtils.offset_neighbors(hex.axial_q, hex.axial_r):
			var neighbor_hex = MapData.get_hex_at(neighbor_coord.x, neighbor_coord.y)
			if neighbor_hex == null or not neighbor_hex.is_passable():
				continue
			var to_id: int = _hex_to_id.get(neighbor_hex.hex_id, -1)
			if to_id == -1:
				continue
			if not _astar.are_points_connected(from_id, to_id):
				_astar.connect_points(from_id, to_id)


## Returns the list of hex_id from `from_hex_id` to `to_hex_id` (inclusive of
## both ends), or an empty array if there is no connection.
func find_path(from_hex_id: String, to_hex_id: String) -> Array[String]:
	var result: Array[String] = []
	if not _hex_to_id.has(from_hex_id) or not _hex_to_id.has(to_hex_id):
		return result

	var from_id: int = _hex_to_id[from_hex_id]
	var to_id: int = _hex_to_id[to_hex_id]
	var id_path = _astar.get_id_path(from_id, to_id)
	for id in id_path:
		result.append(_id_to_hex[id])
	return result
