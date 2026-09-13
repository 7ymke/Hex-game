extends Node
## Autoload: TurnManager
## Struktura tur (sekcja 8 GDD: "ruchy graczy na przemian LUB jednocześnie,
## następnie przeliczenie rundy" - GDD explicite dopuszcza obie kolejności).
##
## Update: gracze nie są już zablokowani sztywną alternacją. Każdy gracz kończy
## SWOJĄ turę niezależnie (`end_turn_for_current_player`), a runda przelicza
## się dopiero, gdy WSZYSCY oznaczą się jako gotowi - do tego czasu można
## dowolnie przełączać się między graczami (`switch_to_player` /
## `switch_to_next_player`), np. żeby dokończyć ruch ludzikiem, którego się
## nie zdążyło wcześniej. Punkty ruchu nie resetują się tu już wprost - żyją
## teraz na ludzikach (scenes/ludzik.gd), więc reset wykonuje
## game_map_controller.gd w reakcji na sygnał `round_ended`.

signal round_ended(round_number: int)
signal player_turn_started(player_id: int)

var round_number: int = 1
var player_order: Array[int] = []
var current_player_index: int = 0
var players_ready: Dictionary = {}  # player_id(int) -> bool


func setup_player_order(ids: Array[int]) -> void:
	player_order = ids
	current_player_index = 0
	players_ready.clear()
	for id in ids:
		players_ready[id] = false
	if not player_order.is_empty():
		player_turn_started.emit(get_current_player_id())


func get_current_player_id() -> int:
	if player_order.is_empty():
		return -1
	return player_order[current_player_index]


func is_player_ready(player_id: int) -> bool:
	return players_ready.get(player_id, false)


func ready_count() -> int:
	var count = 0
	for id in player_order:
		if players_ready.get(id, false):
			count += 1
	return count


## Przełącza kontrolę na dowolnego zarejestrowanego gracza - swobodna zmiana
## "kto teraz gra", bez wpływu na gotowość rundy.
func switch_to_player(player_id: int) -> void:
	var index = player_order.find(player_id)
	if index == -1:
		return
	current_player_index = index
	player_turn_started.emit(get_current_player_id())


## Przełącza na kolejnego gracza w kolejności (z zawinięciem) - przycisk
## "Zmiana gracza" w UI.
func switch_to_next_player() -> void:
	if player_order.is_empty():
		return
	current_player_index = (current_player_index + 1) % player_order.size()
	player_turn_started.emit(get_current_player_id())


## Wywoływane, gdy aktualny gracz kończy swoją turę. Oznacza go jako gotowego;
## jeśli WSZYSCY gracze są już gotowi, przelicza rundę i zeruje gotowość na
## nową rundę. W przeciwnym razie przełącza na kolejnego gracza, który
## jeszcze nie skończył.
func end_turn_for_current_player() -> void:
	if player_order.is_empty():
		return

	players_ready[get_current_player_id()] = true

	if _all_players_ready():
		_end_round()
		current_player_index = 0  # nowa runda zaczyna się znów od pierwszego gracza
		for id in player_order:
			players_ready[id] = false
	else:
		_advance_to_next_not_ready_player()

	player_turn_started.emit(get_current_player_id())


func _all_players_ready() -> bool:
	for id in player_order:
		if not players_ready.get(id, false):
			return false
	return true


func _advance_to_next_not_ready_player() -> void:
	for i in range(player_order.size()):
		current_player_index = (current_player_index + 1) % player_order.size()
		if not players_ready.get(get_current_player_id(), false):
			return


func _end_round() -> void:
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


## Stały dochód z zasobów poza lasem (sekcja 6 GDD - las jest wyjątkiem).
func _process_resource_income() -> void:
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id == -1 or hex.is_forest():
			continue
		if hex.building == null or hex.building_damaged:
			continue

		var player = GameManager.get_player(hex.owner_id)
		if player != null:
			player.add_resource(hex.building.produced_resource, hex.building.produced_amount_per_turn)
