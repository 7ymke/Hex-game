class_name SkillData
extends Resource
## Pojedynczy węzeł drzewka umiejętności - permanentny upgrade dla gracza,
## płatny surowcami, które już istnieją w grze (ten sam mechanizm co Karta
## Miasta: PlayerData.can_afford/pay_costs, patrz city_buildings_data.gd).
##
## Na razie drzewko jest PŁASKIE (bez zależności/prerequisitów między
## węzłami, bez poziomów) - każdy z 5 startowych upgrade'ów (scripts/skill_tree_data.gd)
## da się odblokować niezależnie, jeśli stać na niego gracza. Efekt jest
## aplikowany RAZ, w momencie odblokowania (permanentny bonus, nie zużywalny
## przedmiot) - patrz GameManager.unlock_skill() i
## game_map_controller._on_skill_unlocked() dla efektów wymagających dostępu
## do węzłów sceny (EXTRA_LUDZIK, retroaktywny bonus MP).

enum EffectType {
	EXTRA_LUDZIK,           # dodaje kolejnego Ludzika do player_ludziks (rekrutacja w mieście startowym)
	MOVEMENT_POINTS_BONUS,  # +N do movement_points_max każdego ludzika gracza (obecnego i przyszłego)
	VISION_RADIUS_BONUS,    # +N do promienia widzenia (VISION_RADIUS) gracza
	FOREST_THRESHOLD_BONUS, # +N pkt. proc. do bezpiecznego progu wycinki lasu (FOREST_SAFE_THRESHOLD_PERCENT)
	ANNEX_COST_REDUCTION,   # -N do kosztu MP aneksacji (ANNEX_MP_COST), nie mniej niż 1
}

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var description: String = ""

## HexData.ResourceType(int) -> ilość(float) - te same kategorie surowców co
## wszędzie indziej w grze (sekcja 6 GDD).
@export var required_resources: Dictionary = {}

@export var effect_type: EffectType = EffectType.MOVEMENT_POINTS_BONUS
@export var effect_amount: float = 0.0
