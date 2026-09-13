extends Node
## Autoload: TurnManager
## Klasyczne tury (sekcja 8 GDD): kolejność graczy, a na końcu rundy -
## regeneracja lasów, dochód z zasobów, odnowienie punktów ruchu (Faza 6 planu).

## Parametry regeneracji lasu - sekcja 6.1 GDD.
## przyrost%/runda = max(REGEN_MIN, REGEN_BASE * (aktualny_poziom% / 100) ^ REGEN_EXPONENT)
const FOREST_REGEN_BASE := 20.0
const FOREST_REGEN_MIN := 1.0
const FOREST_REGEN_EXPONENT := 2.0

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


## Wywoływane, gdy aktualny gracz kończy swój ruch w turze.
func advance_to_next_player() -> void:
	if player_order.is_empty():
		return

	current_player_index += 1
	if current_player_index >= player_order.size():
		current_player_index = 0
		_end_round()

	player_turn_started.emit(get_current_player_id())


func _end_round() -> void:
	_process_forest_regeneration()
	_process_resource_income()
	_reset_movement_points()
	round_number += 1
	round_ended.emit(round_number)


func _process_forest_regeneration() -> void:
	for hex: HexData in MapData.hexes.values():
		if not hex.is_forest():
			continue

		var current := hex.resource_level
		var growth: float = maxf(
			FOREST_REGEN_MIN,
			FOREST_REGEN_BASE * pow(current / 100.0, FOREST_REGEN_EXPONENT)
		)
		hex.resource_level = minf(100.0, current + growth)

		if hex.resource_level >= GameManager.FOREST_SAFE_THRESHOLD_PERCENT:
			hex.generates_prestige = true


## Stały dochód z zasobów poza lasem (sekcja 6 GDD - las jest wyjątkiem).
func _process_resource_income() -> void:
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id == -1 or hex.is_forest():
			continue
		if hex.building == null or hex.building_damaged:
			continue

		var player := GameManager.get_player(hex.owner_id)
		if player != null:
			player.add_resource(hex.building.produced_resource, hex.building.produced_amount_per_turn)


func _reset_movement_points() -> void:
	for player: PlayerData in GameManager.players.values():
		player.reset_movement_points()
