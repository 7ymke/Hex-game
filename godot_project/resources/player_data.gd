class_name PlayerData
extends Resource
## Stan pojedynczego gracza. Prestiż jako jedna, centralna waluta (sekcja 4 GDD)
## - buduje Kartę Miasta, płaci za przejęcia terenu, i jest karana za dewastację.

@export var player_id: int = -1
@export var player_name: String = ""
@export var starting_city: String = ""

@export var prestige: int = 100

## Kolor drużyny - ten sam co pionek Ludzika (patrz PLAYER_SETUP w
## game_map_controller.gd), używany też do obrysowania posiadanych heksów na
## mapie (hex_map_view.gd), żeby terytorium było widoczne bez klikania.
@export var color: Color = Color.WHITE

## HexData.ResourceType(int) -> ilość(float). Osobne kategorie surowców (sekcja 6 GDD)
## - np. gaz i węgiel NIE są tą samą walutą, mimo podobnego zastosowania.
@export var resources: Dictionary = {}

@export var unlocked_city_buildings: Array[String] = []

## Drzewko umiejętności (scripts/skill_tree_data.gd) - id-ki odblokowanych
## skilli, plus akumulatory efektów "czysto danowych" (bez potrzeby dostępu
## do węzłów sceny), aplikowane wprost przez GameManager.unlock_skill().
## Efekty, które WYMAGAJĄ dostępu do sceny (nowy węzeł Ludzik, retroaktywny
## bonus MP na już istniejących ludzikach), aplikuje zamiast tego
## game_map_controller._on_skill_unlocked() - patrz SkillData.EffectType.
@export var unlocked_skills: Array[String] = []
@export var movement_points_bonus: int = 0
@export var vision_radius_bonus: int = 0
@export var forest_safe_threshold_bonus: float = 0.0
@export var annex_cost_reduction: int = 0


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
