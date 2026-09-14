extends Node
## Autoload: GameManager
## Player registry and core gameplay actions: annexation, forest harvesting,
## territory takeover. All prestige changes go through here - implementation
## plan section 7 ("centralized prestige-change function").
##
## Balance constants (thresholds, penalties, costs) now live in
## scripts/game_balance.gd - tweak them there.

var players: Dictionary = {}  # player_id(int) -> PlayerData


func register_player(player_data: PlayerData) -> void:
	players[player_data.player_id] = player_data


func get_player(player_id: int) -> PlayerData:
	return players.get(player_id, null)


## Centralized prestige change - implementation plan section 7.
func change_prestige(player_id: int, delta: int) -> void:
	var player = get_player(player_id)
	if player == null:
		return
	player.modify_prestige(delta)


## Annexation - GDD section 2.2/3: entering a hex and annexing it are separate
## actions; this call represents the annexation action itself, performed
## while standing on the hex (unlike the rest of the field actions, which
## after the update work from any distance on already-annexed territory -
## see game_map_controller.gd, the "field actions" section).
##
## The movement-point cost (GDD section 2.2) is checked and deducted BEFORE
## calling this function, at the game_map_controller.gd level - because MP
## now belongs to a specific unit (a scene node), not to the player, and
## GameManager deliberately knows nothing about units/the scene.
##
## Annexing a protected area by itself no longer incurs a prestige penalty
## (update) - the penalty is only charged once someone actually builds/
## repairs a building on such terrain (see `repair_building`).
##
## Update: a hex can ONLY be annexed if it's adjacent to a hex already owned
## by the same player (territory must grow contiguously, not "jump" around
## the map) - `require_adjacency` defaults to true. The only exception is the
## INITIAL annexation of a player's capital (`game_map_controller._setup_players()`),
## where the player doesn't own anything yet, so the adjacency requirement
## would be impossible to satisfy - that call explicitly passes `false`.
func annex_hex(hex_id: String, player_id: int, require_adjacency: bool = true) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return {"success": false, "reason": "hex_not_found"}
	if hex.owner_id != -1:
		return {"success": false, "reason": "already_owned"}
	if require_adjacency and not has_adjacent_owned_hex(hex_id, player_id):
		return {"success": false, "reason": "not_adjacent"}

	hex.owner_id = player_id
	hex.set_fog_state(player_id, HexData.FogState.ANNEXED)

	return {"success": true, "terrain": hex.terrain_type, "resource": hex.resource_type}


## Whether `hex_id` has at least one neighbor owned by `player_id` - the
## condition for annexation (above) and the basis for the "Zaanektuj" (annex)
## button's state in game_map_controller.gd (`_can_annex_selected_hex()`), so
## the UI and the actual rule always agree.
func has_adjacent_owned_hex(hex_id: String, player_id: int) -> bool:
	for neighbor in MapData.get_neighbors(hex_id):
		if neighbor.owner_id == player_id:
			return true
	return false


## Forest harvesting - GDD section 6.1.
## harvest_percent: what % of the hex's CURRENT resource level (not of 100%!)
## the player harvests.
func harvest_forest(hex_id: String, player_id: int, harvest_percent: float) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	var player = get_player(player_id)

	if hex == null or player == null:
		return {"success": false, "reason": "invalid_hex_or_player"}
	if not hex.is_forest():
		return {"success": false, "reason": "not_a_forest_hex"}
	if hex.owner_id != player_id:
		return {"success": false, "reason": "not_owner"}

	harvest_percent = clampf(harvest_percent, 0.0, 100.0)

	# Resource: always granted per the player's choice, regardless of penalty.
	# IMPORTANT: the harvested amount comes off the hex's resource_level (GDD
	# section 6.1 - "how much wood is currently AVAILABLE to harvest") -
	# without this deduction the forest would never deplete and would give
	# the same amount of wood forever, independent of the regrowth in
	# turn_manager.gd.
	var wood_gained: float = hex.resource_level * (harvest_percent / 100.0)
	hex.resource_level -= wood_gained
	player.add_resource(HexData.ResourceType.WOOD, wood_gained)

	# Prestige: penalty and disabling generation ONLY when the threshold is
	# exceeded. The threshold is raised by any skill-tree bonus (skill
	# "advanced_logging" - see scripts/skill_tree_data.gd), 0.0 by default.
	var safe_threshold = GameBalance.FOREST_SAFE_THRESHOLD_PERCENT + player.forest_safe_threshold_bonus
	var over_harvest: float = harvest_percent - safe_threshold
	var prestige_penalty = 0
	if over_harvest > 0.0:
		prestige_penalty = roundi(over_harvest * GameBalance.FOREST_OVERHARVEST_PENALTY_PER_PERCENT)
		change_prestige(player_id, -prestige_penalty)
		hex.generates_prestige = false

	# Logging on protected terrain (GDD section 4) - in the current terrain
	# model (one type per hex) a hex can't be both "forest" and
	# "protected_area" at once, so this branch is currently dead, but it
	# stays in case future terrain data starts marking such overlap with a
	# separate flag instead of an exclusive terrain type.
	if hex.is_protected():
		var protection_result = damage_protected_area(hex_id, player_id, 1.0)
		prestige_penalty += protection_result.get("prestige_penalty", 0)

	return {
		"success": true,
		"wood_gained": wood_gained,
		"prestige_penalty": prestige_penalty,
		"safe_threshold": safe_threshold,
	}


## Destruction/development of a protected area - GDD section 4 (penalty
## proportional to the extent of the damage; the damage_scale parameter in
## the 0-1 range is a placeholder for "how much was destroyed" - the exact
## definition of "extent of damage" is an open GDD question). Called from
## `repair_building` (building/repairing on protected terrain) and
## defensively from `harvest_forest` - see there.
func damage_protected_area(hex_id: String, player_id: int, damage_scale: float) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null or not hex.is_protected():
		return {"success": false, "reason": "not_protected"}

	damage_scale = clampf(damage_scale, 0.0, 1.0)
	var penalty = roundi(GameBalance.PROTECTED_AREA_BASE_PENALTY * damage_scale)
	change_prestige(player_id, -penalty)

	return {"success": true, "prestige_penalty": penalty}


## Territory takeover - GDD section 5 (update). Requires physical presence on
## the hex (checked by game_map_controller.gd, same as annexation -
## GameManager deliberately knows nothing about units) - this is the only
## reason two different players can never stand on the same hex at the same
## time, so a separate check for "is the defending unit currently standing
## here" is no longer needed (the attacker's mere physical presence already
## rules that out).
##
## An attempt can always be MADE - unlike the previous version, where
## insufficient prestige was a hard block with no effect at all. Now:
## - Attacker's prestige STRICTLY greater than the defender's -> success: the
##   defender loses `TAKEOVER_DEFENDER_LOSS_RATIO` of their OWN prestige (the
##   cost of being conquered), the attacker pays `TAKEOVER_COST_RATIO` of the
##   defender's prestige (as before).
## - Otherwise -> failed attempt: the defender LOSES NOTHING, but the
##   attacker pays a penalty proportional to the defender's advantage (the
##   more lopsided the fight, the more expensive the failure) - a "good
##   formula" to discourage desperate attempts without actually punishing the
##   stronger side for someone weaker having tried.
func attempt_takeover(hex_id: String, attacker_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	if hex == null or hex.owner_id == -1:
		return {"success": false, "reason": "no_owner"}
	if hex.owner_id == attacker_id:
		return {"success": false, "reason": "already_owner"}
	if hex.is_capital:
		return {"success": false, "reason": "capital_protected"}

	var attacker = get_player(attacker_id)
	var defender = get_player(hex.owner_id)
	if attacker == null or defender == null:
		return {"success": false, "reason": "invalid_players"}

	if attacker.prestige <= defender.prestige:
		var penalty = maxi(1, roundi((defender.prestige - attacker.prestige) * GameBalance.FAILED_TAKEOVER_PENALTY_RATIO))
		change_prestige(attacker_id, -penalty)
		return {"success": false, "reason": "insufficient_prestige", "attacker_penalty": penalty}

	var cost = roundi(defender.prestige * GameBalance.TAKEOVER_COST_RATIO)
	var defender_loss = roundi(defender.prestige * GameBalance.TAKEOVER_DEFENDER_LOSS_RATIO)
	change_prestige(attacker_id, -cost)
	change_prestige(hex.owner_id, -defender_loss)

	var previous_owner = hex.owner_id
	hex.owner_id = attacker_id

	return {"success": true, "cost": cost, "defender_loss": defender_loss, "previous_owner": previous_owner}


## Unlocking a City Card landmark building - GDD section 7. Centralized here
## (rather than in the City Card UI) so that - like other actions - paying
## with resources and granting prestige (section 7: "main foundation for a
## future win condition - prestige points for completed buildings") goes
## through one place.
func unlock_city_building(player_id: int, building: Building) -> Dictionary:
	var player = get_player(player_id)
	if player == null or building == null:
		return {"success": false, "reason": "invalid_player_or_building"}
	if player.unlocked_city_buildings.has(building.building_name):
		return {"success": false, "reason": "already_unlocked"}
	if not player.pay_costs(building.required_resources):
		return {"success": false, "reason": "cannot_afford"}

	player.unlocked_city_buildings.append(building.building_name)
	if building.prestige_value != 0:
		change_prestige(player_id, building.prestige_value)

	return {"success": true, "prestige_gained": building.prestige_value}


## Unlocking a skill tree node (scripts/skill_tree_data.gd) - the same
## payment mechanism as unlock_city_building() above. "Pure data" effects
## (no need for scene node access) are applied directly here, on PlayerData's
## accumulators - so they're active immediately and readable everywhere we
## already read GameBalance constants (harvest_forest above,
## _reveal_around/_on_annex_pressed in game_map_controller.gd). EXTRA_UNIT
## and the retroactive MP bonus on existing units DO need scene nodes, which
## GameManager deliberately doesn't know about (same as MP for annexation) -
## those are applied by game_map_controller._on_skill_unlocked() in reaction
## to the SkillTreePanel.skill_unlocked signal, using the `effect_type`
## returned here.
func unlock_skill(player_id: int, skill: SkillData) -> Dictionary:
	var player = get_player(player_id)
	if player == null or skill == null:
		return {"success": false, "reason": "invalid_player_or_skill"}
	if player.unlocked_skills.has(skill.skill_id):
		return {"success": false, "reason": "already_unlocked"}
	if not player.pay_costs(skill.required_resources):
		return {"success": false, "reason": "cannot_afford"}

	player.unlocked_skills.append(skill.skill_id)
	match skill.effect_type:
		SkillData.EffectType.VISION_RADIUS_BONUS:
			player.vision_radius_bonus += int(skill.effect_amount)
		SkillData.EffectType.FOREST_THRESHOLD_BONUS:
			player.forest_safe_threshold_bonus += skill.effect_amount
		SkillData.EffectType.ANNEX_COST_REDUCTION:
			player.annex_cost_reduction += int(skill.effect_amount)
		SkillData.EffectType.MOVEMENT_POINTS_BONUS:
			player.movement_points_bonus += int(skill.effect_amount)
		SkillData.EffectType.EXTRA_UNIT:
			pass  # entirely handled by game_map_controller.gd

	return {"success": true, "effect_type": skill.effect_type}


## Repairing a building - GDD section 3 ("can repair it and make it generate
## resources starting next round"). Cost comes from
## Building.required_resources (currently a placeholder = {} for
## auto-generated buildings, see MapData._attach_placeholder_building - Phase
## 5, temporary).
##
## If the building stands on protected terrain, the repair/build itself is
## what the GDD (section 4) calls "exploiting/damaging a protected hex" - and
## it is THAT, not the annexation, that incurs the prestige penalty (update).
func repair_building(hex_id: String, player_id: int) -> Dictionary:
	var hex = MapData.get_hex(hex_id)
	var player = get_player(player_id)

	if hex == null or player == null:
		return {"success": false, "reason": "invalid_hex_or_player"}
	if hex.owner_id != player_id:
		return {"success": false, "reason": "not_owner"}
	if hex.building == null:
		return {"success": false, "reason": "no_building"}
	if not hex.building_damaged:
		return {"success": false, "reason": "already_repaired"}
	if not player.pay_costs(hex.building.required_resources):
		return {"success": false, "reason": "cannot_afford"}

	hex.building_damaged = false

	var result = {"success": true, "prestige_penalty": 0}
	if hex.is_protected():
		var protection_result = damage_protected_area(hex_id, player_id, 1.0)
		result["prestige_penalty"] = protection_result.get("prestige_penalty", 0)

	return result
