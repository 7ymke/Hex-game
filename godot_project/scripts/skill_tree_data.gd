class_name SkillTreeData
extends RefCounted
## Startowa zawartość drzewka umiejętności - 5 upgrade'ów zaproponowanych do
## gry (jak dotąd tylko Karta Miasta dawała trwały cel na zdobyte surowce;
## to drugi taki "zlew" na nadwyżki surowców, tym razem z bezpośrednim
## wpływem na rozgrywkę zamiast samego prestiżu). Wspólna dla wszystkich
## graczy/miast (w przeciwieństwie do Karty Miasta) - to ogólne usprawnienia,
## nie zabytki charakterystyczne dla konkretnego miasta.
##
## Koszty celowo rozsiane po różnych typach zasobów, tak jak w
## city_buildings_data.gd, żeby skompletowanie drzewka też wymagało kontroli
## wielu regionów. Wartości to placeholdery do dostrojenia podczas testów
## balansu (sekcja 11 GDD).

static func get_skills() -> Array[SkillData]:
	var list: Array[SkillData] = [
		_make(
			"extra_ludzik",
			"Drugi ludzik",
			"Rekrutuje drugiego ludzika w mieście startowym - dwa niezależne ruchy i akcje na rundę zamiast jednego.",
			{
				HexData.ResourceType.FOOD: 40.0,
				HexData.ResourceType.WOOD: 40.0,
				HexData.ResourceType.COAL: 20.0,
			},
			SkillData.EffectType.EXTRA_LUDZIK,
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
				HexData.ResourceType.URANIUM: 5.0,
			},
			SkillData.EffectType.ANNEX_COST_REDUCTION,
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
