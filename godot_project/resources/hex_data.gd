class_name HexData
extends Resource
## Dane pojedynczego heksa na mapie. Sekcja 2.1-2.3 GDD.

enum TerrainType {
	UNKNOWN,
	AGRICULTURAL,
	FOREST,
	MOUNTAIN,
	PROTECTED_AREA,
	CITY,
	WATER,
}

enum ResourceType {
	NONE,
	GAS,
	COPPER,
	COAL,
	WOOD,
	FOOD,
	NICKEL,
	URANIUM,
}

## Trójpoziomowa mgła wojny, per gracz (sekcja 2.2 GDD): UNEXPLORED = całkiem
## zakryty; SEEN = widoczny typ terenu, bez zasobów/budynków/właściciela;
## ANNEXED = w pełni odkryty. Patrz `get_fog_state()`/`set_fog_state()` niżej.
enum FogState {
	UNEXPLORED,
	SEEN,
	ANNEXED,
}

const TERRAIN_FROM_STRING = {
	"unknown": TerrainType.UNKNOWN,
	"agricultural": TerrainType.AGRICULTURAL,
	"forest": TerrainType.FOREST,
	"mountain": TerrainType.MOUNTAIN,
	"protected_area": TerrainType.PROTECTED_AREA,
	"city": TerrainType.CITY,
	"water": TerrainType.WATER,
}

const RESOURCE_FROM_STRING = {
	"none": ResourceType.NONE,
	"gas": ResourceType.GAS,
	"copper": ResourceType.COPPER,
	"coal": ResourceType.COAL,
	"wood": ResourceType.WOOD,
	"food": ResourceType.FOOD,
	"nickel": ResourceType.NICKEL,
	"uranium": ResourceType.URANIUM,
}

## Polskie nazwy zasobów do UI (panel surowców gracza, koszty budynków w
## Karcie Miasta...) - NONE celowo pominięte, nie ma sensu pokazywać go
## graczowi. Kolejność kluczy = kolejność wyświetlania.
const RESOURCE_DISPLAY_NAMES = {
	ResourceType.GAS: "Gaz",
	ResourceType.COPPER: "Miedź",
	ResourceType.COAL: "Węgiel",
	ResourceType.WOOD: "Drewno",
	ResourceType.FOOD: "Żywność",
	ResourceType.NICKEL: "Nikiel",
	ResourceType.URANIUM: "Uran",
}


## Formatuje słownik kosztów (ResourceType(int) -> ilość(float), ten sam
## kształt co Building.required_resources i SkillData.required_resources) do
## czytelnego tekstu UI, np. "Drewno: 10, Węgiel: 5" - współdzielone przez
## Kartę Miasta (city_card_panel.gd) i Drzewko Umiejętności
## (skill_tree_panel.gd), bo oba pokazują koszty w dokładnie tym samym
## formacie.
static func format_resource_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "brak"
	var parts: Array[String] = []
	for res_type in costs:
		parts.append("%s: %.0f" % [RESOURCE_DISPLAY_NAMES.get(res_type, "?"), costs[res_type]])
	return ", ".join(parts)

## Koszt ruchu terenowego w punktach ruchu (sekcja 2.4 GDD)
const MOVEMENT_COST = {
	TerrainType.UNKNOWN: 1,
	TerrainType.AGRICULTURAL: 1,
	TerrainType.FOREST: 2,
	TerrainType.MOUNTAIN: 3,
	TerrainType.PROTECTED_AREA: 1,
	TerrainType.CITY: 1,
	TerrainType.WATER: -1,  # -1 = niedostępne dla ruchu lądowego
}

@export var hex_id: String = ""
@export var axial_q: int = 0
@export var axial_r: int = 0
@export var latitude: float = 0.0
@export var longitude: float = 0.0

@export var terrain_type: TerrainType = TerrainType.UNKNOWN
@export var resource_type: ResourceType = ResourceType.NONE
@export var label_raw: String = ""  # oryginalny opis z KML, do ręcznego dopracowania treści

## Poziom zasobu (%) - używany głównie dla lasów (sekcja 6.1 GDD).
## Dla pozostałych zasobów strategicznych na razie bez znaczenia (stały dochód, sekcja 6).
@export var resource_level: float = 100.0

## Czy pole leśne aktualnie generuje prestiż (fałsz po przekroczeniu progu 60%, sekcja 6.1)
@export var generates_prestige: bool = true

@export var building: Building = null
@export var building_damaged: bool = false

## -1 = niczyj
@export var owner_id: int = -1

## Czy to heks stolicy (miasta startowego) jakiegoś gracza - ustawiane raz w
## game_map_controller._setup_players() dla każdego `start_hex` z
## PlayerSetup.LIST. Stolice są chronione przed przejęciem siłą (PvP) -
## patrz GameManager.attempt_takeover().
@export var is_capital: bool = false

## Stan mgły wojny per gracz: player_id(int) -> FogState.
## Nie eksportowane celowo - stan rozgrywki, nie dane startowe heksa.
var fog_state: Dictionary = {}


func get_fog_state(player_id: int) -> FogState:
	return fog_state.get(player_id, FogState.UNEXPLORED)


func set_fog_state(player_id: int, state: FogState) -> void:
	fog_state[player_id] = state


func is_forest() -> bool:
	return terrain_type == TerrainType.FOREST


func is_protected() -> bool:
	return terrain_type == TerrainType.PROTECTED_AREA


func get_movement_cost() -> int:
	return MOVEMENT_COST.get(terrain_type, 1)


func is_passable() -> bool:
	return get_movement_cost() > 0


## Tworzy HexData z jednego wpisu wczytanego z map_data.json (patrz tools/convert_kml_to_json.py)
static func from_dict(d: Dictionary) -> HexData:
	var hex = HexData.new()
	hex.hex_id = d.get("id", "")
	hex.axial_q = d.get("q", 0)
	hex.axial_r = d.get("r", 0)
	hex.latitude = d.get("lat", 0.0)
	hex.longitude = d.get("lon", 0.0)
	hex.terrain_type = TERRAIN_FROM_STRING.get(d.get("terrain", "unknown"), TerrainType.UNKNOWN)
	hex.resource_type = RESOURCE_FROM_STRING.get(d.get("resource", "none"), ResourceType.NONE)
	hex.resource_level = d.get("resource_level", 100.0)
	hex.label_raw = d.get("label_raw", "")
	return hex
