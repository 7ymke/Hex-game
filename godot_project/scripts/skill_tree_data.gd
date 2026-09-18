class_name SkillTreeData
extends RefCounted
## Starting content of the skill tree - 5 upgrades proposed for the game (so
## far only the City Card gave a lasting goal for surplus resources; this is
## a second such "sink" for resource surpluses, this time with a direct
## effect on gameplay instead of just prestige). Shared by all
## players/cities (unlike the City Card) - these are general improvements,
## not landmarks specific to a given city.
##
## Costs are deliberately spread across different resource types, just like
## in city_buildings_data.gd, so that completing the tree also requires
## controlling multiple regions. Values are placeholders to be tuned during
## balance testing (GDD section 11).

static func get_skills() -> Array[SkillData]:
	var list: Array[SkillData] = [
		_make(
			"extra_unit",
			"Drugi ludzik",
			"Rekrutuje drugiego ludzika w mieście startowym - dwa niezależne ruchy i akcje na rundę zamiast jednego.",
			{
				HexData.ResourceType.FOOD: 40.0,
				HexData.ResourceType.WOOD: 40.0,
				HexData.ResourceType.COAL: 20.0,
			},
			SkillData.EffectType.EXTRA_UNIT,
			1.0
		),
		_make(
			"movement_stamina",
			"Wytrzymałość marszowa",
			"+2 punkty ruchu na rundę dla każdego ludzika (obecnego i przyszłego).",
			{
				HexData.ResourceType.FOOD: 25.0,
				HexData.ResourceType.WOOD: 15.0,
			},
			SkillData.EffectType.MOVEMENT_POINTS_BONUS,
			2.0
		),
		_make(
			"advanced_logging",
			"Zrównoważona wycinka",
			"Podnosi bezpieczny próg wycinki lasu o 15 punktów procentowych, zanim naliczy się kara prestiżowa.",
			{
				HexData.ResourceType.WOOD: 30.0,
				HexData.ResourceType.COAL: 15.0,
			},
			SkillData.EffectType.FOREST_THRESHOLD_BONUS,
			15.0
		),
		_make(
			"reconnaissance",
			"Rozpoznanie terenu",
			"+1 promień widzenia dla wszystkich ludzików gracza.",
			{
				HexData.ResourceType.NICKEL: 15.0,
				HexData.ResourceType.GAS: 20.0,
			},
			SkillData.EffectType.VISION_RADIUS_BONUS,
			1.0
		),
		_make(
			"territorial_logistics",
			"Logistyka terytorialna",
			"Zmniejsza koszt aneksacji o 1 punkt ruchu (minimum 1).",
			{
				HexData.ResourceType.COPPER: 20.0,
				HexData.ResourceType.OIL: 5.0,
			},
			SkillData.EffectType.ANNEX_COST_REDUCTION,
			1.0
		),
		_make(
			"road_infrastructure",
			"Infrastruktura drogowa",
			"Ulepszone drogi w mieście - ludzik zużywa o połowę mniej punktów ruchu, przechodząc przez pole miasta.",
			{
				HexData.ResourceType.COAL: 25.0,
				HexData.ResourceType.COPPER: 15.0,
			},
			SkillData.EffectType.ROAD_INFRASTRUCTURE,
			1.0
		),
	]
	return list


static func _make(
	id: String, name: String, description: String, costs: Dictionary,
	effect_type: SkillData.EffectType, effect_amount: float
) -> SkillData:
	var skill = SkillData.new()
	skill.skill_id = id
	skill.skill_name = name
	skill.description = description
	skill.required_resources = costs
	skill.effect_type = effect_type
	skill.effect_amount = effect_amount
	return skill
