class_name SkillData
extends Resource
## A single skill tree node - a permanent upgrade for a player, paid for
## with resources that already exist in the game (the same mechanism as the
## City Card: PlayerData.can_afford/pay_costs, see city_buildings_data.gd).
##
## The tree is currently FLAT (no dependencies/prerequisites between nodes,
## no levels) - each of the 5 starting upgrades (scripts/skill_tree_data.gd)
## can be unlocked independently, as long as the player can afford it. The
## effect is applied ONCE, at the moment of unlocking (a permanent bonus,
## not a consumable) - see GameManager.unlock_skill() and
## game_map_controller._on_skill_unlocked() for effects that need access to
## scene nodes (EXTRA_UNIT, retroactive MP bonus).

enum EffectType {
	EXTRA_UNIT,             # adds another Unit to player_units (recruited in the starting city)
	MOVEMENT_POINTS_BONUS,  # +N to movement_points_max for each of the player's units (current and future)
	VISION_RADIUS_BONUS,    # +N to vision radius (VISION_RADIUS) for the player
	FOREST_THRESHOLD_BONUS, # +N percentage points to the safe forest harvesting threshold (FOREST_SAFE_THRESHOLD_PERCENT)
	ANNEX_COST_REDUCTION,   # -N to the MP cost of annexation (ANNEX_MP_COST), never below 1
}

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var description: String = ""

## HexData.ResourceType(int) -> amount(float) - the same resource categories
## used everywhere else in the game (GDD section 6).
@export var required_resources: Dictionary = {}

@export var effect_type: EffectType = EffectType.MOVEMENT_POINTS_BONUS
@export var effect_amount: float = 0.0
