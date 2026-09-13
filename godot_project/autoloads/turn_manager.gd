extends Node
## Autoload: TurnManager
## Struktura tur (sekcja 8 GDD: "ruchy graczy na przemian LUB jednocześnie,
## następnie przeliczenie rundy" - GDD explicite dopuszcza obie kolejności).
##
## Update: kontrola nad graczem i przeliczenie rundy to teraz dwie CAŁKOWICIE
## niezależne rzeczy. "Zmiana gracza" w UI wybiera KONKRETNEGO gracza wprost
## (`switch_to_player`) - nie ma już cyklicznego "następny gracz" ani pojęcia
## "tura gracza" blokującej resztę. "Zakończ rundę" (`end_round`) przelicza
## rundę (regeneracja lasu, dochód, odnowienie MP wszystkich ludzików) w
## dowolnym momencie, niezależnie od tego, który gracz jest akurat kontrolowany
## - runda nie zmienia, kto jest aktywny.

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


## Przełącza kontrolę na WYBRANEGO gracza (np. z listy w UI) - swobodny wybór,
## nie cykliczne przechodzenie po kolei.
func switch_to_player(player_id: int) -> void:
	var index = player_order.find(player_id)
	if index == -1:
		return
	current_player_index = index
	player_turn_started.emit(get_current_player_id())


## Przelicza rundę na żądanie (przycisk "Zakończ rundę") - NIE zmienia, który
## gracz jest aktualnie kontrolowany.
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
