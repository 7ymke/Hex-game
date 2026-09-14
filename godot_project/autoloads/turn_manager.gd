extends Node
## Autoload: TurnManager
## Turn structure (GDD section 8: "players move in alternation OR
## simultaneously, then the round is resolved" - the GDD explicitly allows
## either order).
##
## Update: control over the active player and round resolution are now two
## COMPLETELY independent things. The "Zmiana gracza" (change player) UI
## control switches control to a SPECIFIC player directly
## (`switch_to_player`) - there is no more cyclic "next player", nor a
## "player's turn" concept blocking everything else. "Zakończ rundę" (end
## round) (`end_round`) resolves the round (forest regrowth, income,
## refreshing MP for all units) at any moment, independent of which player
## is currently in control - resolving a round does not change who is active.

signal round_ended(round_number: int)
signal player_turn_started(player_id: int)

var round_number: int = 1
var player_order: Array[int] = []
var current_player_index: int = 0


func setup_player_order(ids: Array[int]) -> void:
	player_order = ids
	current_player_index = 0
	if not player_order.is_empty():
		player_turn_started.emit(get_current_player_id())


func get_current_player_id() -> int:
	if player_order.is_empty():
		return -1
	return player_order[current_player_index]


## Switches control to the CHOSEN player (e.g. from a list in the UI) - a
## free choice, not cycling through them in order.
func switch_to_player(player_id: int) -> void:
	var index = player_order.find(player_id)
	if index == -1:
		return
	current_player_index = index
	player_turn_started.emit(get_current_player_id())


## Resolves the round on demand (the "Zakończ rundę" / end round button) -
## does NOT change which player is currently in control.
func end_round() -> void:
	_process_forest_regeneration()
	_process_resource_income()
	round_number += 1
	round_ended.emit(round_number)


func _process_forest_regeneration() -> void:
	for hex: HexData in MapData.hexes.values():
		if not hex.is_forest():
			continue

		var current = hex.resource_level
		var growth = maxf(
			GameBalance.FOREST_REGEN_MIN,
			GameBalance.FOREST_REGEN_BASE * pow(current / 100.0, GameBalance.FOREST_REGEN_EXPONENT)
		)
		hex.resource_level = minf(100.0, current + growth)

		if hex.resource_level >= GameBalance.FOREST_SAFE_THRESHOLD_PERCENT:
			hex.generates_prestige = true


## Steady income from resources other than forest (GDD section 6 - forest is
## the exception).
func _process_resource_income() -> void:
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id == -1 or hex.is_forest():
			continue
		if hex.building == null or hex.building_damaged:
			continue

		var player = GameManager.get_player(hex.owner_id)
		if player != null:
			player.add_resource(hex.building.produced_resource, hex.building.produced_amount_per_turn)
