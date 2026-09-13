class_name CityBuildingsData
extends RefCounted
## Statyczne dane Karty Miasta - sekcja 7 GDD ("lista budynków
## charakterystycznych dla danego miasta... nie pojawiają się na mapie
## heksów - to osobny, wewnętrzny system rozwoju miasta").
##
## Na razie zdefiniowane dla miast startowych faktycznie obecnych w
## bieżącym wycinku mapy (Faza 1 - tylko Pomorze Zachodnie + Dolny Śląsk,
## patrz README). Dodaj kolejne miasta tutaj w miarę rozszerzania KML o
## resztę Polski (Warszawa, Kraków, Gdańsk... - przykłady z sekcji 7 GDD).
##
## Koszty celowo używają różnych typów zasobów rozsianych po mapie (gaz,
## miedź, węgiel, drewno z lasu, żywność, nikiel, uran), żeby skompletowanie
## Karty Miasta wymagało eksploracji i kontroli wielu regionów, nie jednego
## pola. Wartości prestiżu i kosztów to placeholdery do dostrojenia podczas
## testów balansu (sekcja 11 GDD - "otwarte pytania").

static func get_buildings(city_name: String) -> Array[Building]:
	match city_name:
		"Wrocław":
			return _wroclaw()
		"Szczecin":
			return _szczecin()
		_:
			return []


static func _make(name: String, costs: Dictionary, prestige: int) -> Building:
	var b := Building.new()
	b.building_name = name
	b.building_type = Building.BuildingType.CITY_LANDMARK
	b.required_resources = costs
	b.prestige_value = prestige
	return b


static func _wroclaw() -> Array[Building]:
	var list: Array[Building] = [
		_make("Ratusz Wrocławski", {HexData.ResourceType.FOOD: 20.0}, 10),
		_make(
			"Ostrów Tumski",
			{HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			15
		),
		_make(
			"Panorama Racławicka",
			{HexData.ResourceType.COPPER: 10.0, HexData.ResourceType.FOOD: 10.0},
			15
		),
		_make(
			"Hala Stulecia",
			{
				HexData.ResourceType.COPPER: 20.0,
				HexData.ResourceType.COAL: 15.0,
				HexData.ResourceType.WOOD: 10.0,
			},
			35
		),
	]
	return list


static func _szczecin() -> Array[Building]:
	var list: Array[Building] = [
		_make("Wały Chrobrego", {HexData.ResourceType.FOOD: 20.0}, 10),
		_make(
			"Zamek Książąt Pomorskich",
			{HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.COAL: 10.0},
			15
		),
		_make(
			"Katedra św. Jakuba",
			{HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.WOOD: 15.0},
			15
		),
		_make(
			"Filharmonia Szczecińska",
			{HexData.ResourceType.GAS: 15.0, HexData.ResourceType.COPPER: 10.0},
			35
		),
	]
	return list
