class_name CityBuildingsData
extends RefCounted
## Statyczne dane Karty Miasta - sekcja 7 GDD ("lista budynków
## charakterystycznych dla danego miasta... nie pojawiają się na mapie
## heksów - to osobny, wewnętrzny system rozwoju miasta").
##
## Zdefiniowane dla wszystkich 6 miast startowych z sekcji 7 GDD, obecnych
## jako heksy typu "city" w pełnej mapie Polski (data/map_data.json).
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
		"Warszawa":
			return _warszawa()
		"Kraków":
			return _krakow()
		"Gdańsk":
			return _gdansk()
		"Poznań":
			return _poznan()
		_:
			return []


static func _make(name: String, costs: Dictionary, prestige: int) -> Building:
	var b = Building.new()
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


static func _warszawa() -> Array[Building]:
	var list: Array[Building] = [
		_make("Stare Miasto", {HexData.ResourceType.FOOD: 20.0}, 10),
		_make(
			"Zamek Królewski",
			{HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			15
		),
		_make(
			"Pałac Kultury i Nauki",
			{HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.COAL: 10.0},
			15
		),
		_make(
			"Uniwersytet Warszawski",
			{
				HexData.ResourceType.COPPER: 15.0,
				HexData.ResourceType.COAL: 15.0,
				HexData.ResourceType.GAS: 10.0,
			},
			35
		),
	]
	return list


static func _krakow() -> Array[Building]:
	var list: Array[Building] = [
		_make("Sukiennice", {HexData.ResourceType.FOOD: 20.0}, 10),
		_make(
			"Kościół Mariacki",
			{HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			15
		),
		_make(
			"Kopiec Kościuszki",
			{HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.COAL: 10.0},
			15
		),
		_make(
			"Zamek Królewski na Wawelu",
			{
				HexData.ResourceType.COPPER: 20.0,
				HexData.ResourceType.NICKEL: 10.0,
				HexData.ResourceType.URANIUM: 5.0,
			},
			35
		),
	]
	return list


static func _gdansk() -> Array[Building]:
	var list: Array[Building] = [
		_make("Dwór Artusa", {HexData.ResourceType.FOOD: 20.0}, 10),
		_make(
			"Bazylika Mariacka",
			{HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			15
		),
		_make(
			"Żuraw Gdański",
			{HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.GAS: 10.0},
			15
		),
		_make(
			"Stocznia Gdańska",
			{
				HexData.ResourceType.COAL: 15.0,
				HexData.ResourceType.COPPER: 15.0,
				HexData.ResourceType.GAS: 10.0,
			},
			35
		),
	]
	return list


static func _poznan() -> Array[Building]:
	var list: Array[Building] = [
		_make("Stary Rynek", {HexData.ResourceType.FOOD: 20.0}, 10),
		_make(
			"Ratusz Poznański",
			{HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			15
		),
		_make(
			"Ostrów Tumski",
			{HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.COAL: 10.0},
			15
		),
		_make(
			"Poznańskie Koziołki",
			{
				HexData.ResourceType.COPPER: 10.0,
				HexData.ResourceType.NICKEL: 10.0,
				HexData.ResourceType.URANIUM: 5.0,
			},
			35
		),
	]
	return list
