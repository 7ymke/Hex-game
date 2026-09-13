class_name PlayerData
extends Resource
## Stan pojedynczego gracza. Prestiż jako jedna, centralna waluta (sekcja 4 GDD)
## - buduje Kartę Miasta, płaci za przejęcia terenu, i jest karana za dewastację.

@export var player_id: int = -1
@export var player_name: String = ""
@export var starting_city: String = ""

@export var prestige: int = 100

## HexData.ResourceType(int) -> ilość(float). Osobne kategorie surowców (sekcja 6 GDD)
## - np. gaz i węgiel NIE są tą samą walutą, mimo podobnego zastosowania.
@export var resources: Dictionary = {}

@export var movement_points_max: int = 5
var movement_points_current: int = 5

@export var unlocked_city_buildings: Array[String] = []


func add_resource(res_type: HexData.ResourceType, amount: float) -> void:
	if res_type == HexData.ResourceType.NONE or amount == 0.0:
		return
	resources[res_type] = resources.get(res_type, 0.0) + amount


func get_resource_amount(res_type: HexData.ResourceType) -> float:
	return resources.get(res_type, 0.0)


func can_afford(costs: Dictionary) -> bool:
	for res_type in costs:
		if resources.get(res_type, 0.0) < costs[res_type]:
			return false
	return true


func pay_costs(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for res_type in costs:
		resources[res_type] -= costs[res_type]
	return true


## Zmienia prestiż, nie pozwalając mu spaść poniżej zera.
func modify_prestige(amount: int) -> void:
	prestige = max(prestige + amount, 0)


func reset_movement_points() -> void:
	movement_points_current = movement_points_max


func spend_movement_points(amount: int) -> bool:
	if movement_points_current < amount:
		return false
	movement_points_current -= amount
	return true
