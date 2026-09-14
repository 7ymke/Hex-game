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
##
## Dane trzymane jako jedna tabela (miasto -> lista wpisów `{name, costs,
## prestige}`), nie osobna funkcja na miasto - dodanie/zmiana budynku to
## edycja jednego wiersza, a przegląd wszystkich miast naraz nie wymaga
## skakania między funkcjami. `Building` (obiekt Resource, więc nie da się
## trzymać w `const`) powstaje dopiero w `get_buildings()`, na żądanie.
const CITY_BUILDINGS: Dictionary = {
	"Wrocław": [
		{"name": "Ratusz Wrocławski", "costs": {HexData.ResourceType.FOOD: 20.0}, "prestige": 10},
		{
			"name": "Ostrów Tumski",
			"costs": {HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			"prestige": 15,
		},
		{
			"name": "Panorama Racławicka",
			"costs": {HexData.ResourceType.COPPER: 10.0, HexData.ResourceType.FOOD: 10.0},
			"prestige": 15,
		},
		{
			"name": "Hala Stulecia",
			"costs": {
				HexData.ResourceType.COPPER: 20.0,
				HexData.ResourceType.COAL: 15.0,
				HexData.ResourceType.WOOD: 10.0,
			},
			"prestige": 35,
		},
	],
	"Szczecin": [
		{"name": "Wały Chrobrego", "costs": {HexData.ResourceType.FOOD: 20.0}, "prestige": 10},
		{
			"name": "Zamek Książąt Pomorskich",
			"costs": {HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.COAL: 10.0},
			"prestige": 15,
		},
		{
			"name": "Katedra św. Jakuba",
			"costs": {HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.WOOD: 15.0},
			"prestige": 15,
		},
		{
			"name": "Filharmonia Szczecińska",
			"costs": {HexData.ResourceType.GAS: 15.0, HexData.ResourceType.COPPER: 10.0},
			"prestige": 35,
		},
	],
	"Warszawa": [
		{"name": "Stare Miasto", "costs": {HexData.ResourceType.FOOD: 20.0}, "prestige": 10},
		{
			"name": "Zamek Królewski",
			"costs": {HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			"prestige": 15,
		},
		{
			"name": "Pałac Kultury i Nauki",
			"costs": {HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.COAL: 10.0},
			"prestige": 15,
		},
		{
			"name": "Uniwersytet Warszawski",
			"costs": {
				HexData.ResourceType.COPPER: 15.0,
				HexData.ResourceType.COAL: 15.0,
				HexData.ResourceType.GAS: 10.0,
			},
			"prestige": 35,
		},
	],
	"Kraków": [
		{"name": "Sukiennice", "costs": {HexData.ResourceType.FOOD: 20.0}, "prestige": 10},
		{
			"name": "Kościół Mariacki",
			"costs": {HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			"prestige": 15,
		},
		{
			"name": "Kopiec Kościuszki",
			"costs": {HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.COAL: 10.0},
			"prestige": 15,
		},
		{
			"name": "Zamek Królewski na Wawelu",
			"costs": {
				HexData.ResourceType.COPPER: 20.0,
				HexData.ResourceType.NICKEL: 10.0,
				HexData.ResourceType.URANIUM: 5.0,
			},
			"prestige": 35,
		},
	],
	"Gdańsk": [
		{"name": "Dwór Artusa", "costs": {HexData.ResourceType.FOOD: 20.0}, "prestige": 10},
		{
			"name": "Bazylika Mariacka",
			"costs": {HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			"prestige": 15,
		},
		{
			"name": "Żuraw Gdański",
			"costs": {HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.GAS: 10.0},
			"prestige": 15,
		},
		{
			"name": "Stocznia Gdańska",
			"costs": {
				HexData.ResourceType.COAL: 15.0,
				HexData.ResourceType.COPPER: 15.0,
				HexData.ResourceType.GAS: 10.0,
			},
			"prestige": 35,
		},
	],
	"Poznań": [
		{"name": "Stary Rynek", "costs": {HexData.ResourceType.FOOD: 20.0}, "prestige": 10},
		{
			"name": "Ratusz Poznański",
			"costs": {HexData.ResourceType.FOOD: 15.0, HexData.ResourceType.WOOD: 10.0},
			"prestige": 15,
		},
		{
			"name": "Ostrów Tumski",
			"costs": {HexData.ResourceType.FOOD: 10.0, HexData.ResourceType.COAL: 10.0},
			"prestige": 15,
		},
		{
			"name": "Poznańskie Koziołki",
			"costs": {
				HexData.ResourceType.COPPER: 10.0,
				HexData.ResourceType.NICKEL: 10.0,
				HexData.ResourceType.URANIUM: 5.0,
			},
			"prestige": 35,
		},
	],
}


static func get_buildings(city_name: String) -> Array[Building]:
	var list: Array[Building] = []
	for entry in CITY_BUILDINGS.get(city_name, []):
		list.append(_make(entry["name"], entry["costs"], entry["prestige"]))
	return list


static func _make(building_name: String, costs: Dictionary, prestige: int) -> Building:
	var b = Building.new()
	b.building_name = building_name
	b.building_type = Building.BuildingType.CITY_LANDMARK
	b.required_resources = costs
	b.prestige_value = prestige
	return b
