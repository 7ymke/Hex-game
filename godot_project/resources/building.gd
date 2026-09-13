class_name Building
extends Resource
## Definicja budynku - zarówno tych na mapie (gazoport, kopalnia, huta),
## jak i budynków charakterystycznych w Karcie Miasta (sekcja 7 GDD).

enum BuildingType {
	RESOURCE_NODE,   # gazoport, kopalnia, złoże - stoi na heksie mapy
	INDUSTRIAL,      # huta, fabryka - przetwarza surowce (sekcja 6 GDD, otwarte)
	CITY_LANDMARK,   # budynek charakterystyczny w Karcie Miasta - nie ma go na mapie
}

@export var building_name: String = ""
@export var building_type: BuildingType = BuildingType.RESOURCE_NODE

## Co i ile produkuje na rundę, jeśli sprawny (sekcja 6 GDD - stały dochód, poza lasem)
@export var produced_resource: HexData.ResourceType = HexData.ResourceType.NONE
@export var produced_amount_per_turn: float = 0.0

## Koszt naprawy/budowy: Dictionary HexData.ResourceType(int) -> ilość(float)
## Każdy typ budynku ma własną listę - sekcja 3 GDD.
@export var required_resources: Dictionary = {}

## Ile prestiżu daje w Karcie Miasta po odblokowaniu (dotyczy CITY_LANDMARK)
@export var prestige_value: int = 0


func get_required_amount(res_type: HexData.ResourceType) -> float:
	return required_resources.get(res_type, 0.0)


func can_afford(player: PlayerData) -> bool:
	return player.can_afford(required_resources)
