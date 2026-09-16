class_name PlayerData
extends Resource
## State of a single player. Prestige as one central currency (GDD section 4)
## - builds the City Card, pays for territory takeovers, and is penalized for
## environmental damage.

@export var player_id: int = -1
@export var player_name: String = ""
@export var starting_city: String = ""

@export var prestige: int = 100

## Market currency (autoloads/market_manager.gd) - separate from prestige on
## purpose: prestige is reputation/standing (territory takeovers, building
## unlocks, environmental penalties), money is purely what the resource
## market buys/sells in. Starting amount is a plain literal, same convention
## as `prestige` above (not read from a balance constant).
@export var money: float = 200.0

## Team color - the same one used for the player's Unit token (see
## PLAYER_SETUP in game_map_controller.gd), also used to outline owned hexes
## on the map (hex_map_view.gd) so territory is visible without clicking.
@export var color: Color = Color.WHITE

## HexData.ResourceType(int) -> amount(float). Separate resource categories
## (GDD section 6) - e.g. gas and coal are NOT the same currency, despite
## similar uses.
@export var resources: Dictionary = {}

@export var unlocked_city_buildings: Array[String] = []

## Skill tree (scripts/skill_tree_data.gd) - ids of unlocked skills, plus
## accumulators for "pure data" effects (no need for scene node access),
## applied directly by GameManager.unlock_skill(). Effects that DO need
## access to the scene (a new Unit node, a retroactive MP bonus on existing
## units) are instead applied by
## game_map_controller._on_skill_unlocked() - see SkillData.EffectType.
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


## Changes prestige, never letting it drop below zero.
func modify_prestige(amount: int) -> void:
	prestige = maxi(prestige + amount, 0)


## Changes money, never letting it drop below zero - a trade that would go
## negative is already rejected before this is ever called (see
## MarketManager.attempt_trade()), so this floor is purely defensive.
func add_money(amount: float) -> void:
	money = maxf(money + amount, 0.0)
