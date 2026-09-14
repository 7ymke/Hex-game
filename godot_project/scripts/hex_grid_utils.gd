class_name HexGridUtils
extends RefCounted
## Matematyka siatki heksagonalnej "flat-top", układ współrzędnych OFFSET
## "even-q" (parzyste kolumny przesunięte w dół o pół heksa - czyli kolejna
## litera w tym samym numerze wiersza renderuje się NIŻEJ, np. H18 leży nad
## G18, tak jak sobie tego życzono).
##
## Uwaga: pola HexData.axial_q / HexData.axial_r nazywają się "axial" ze
## względów historycznych (Faza 0), ale w praktyce są to współrzędne OFFSET
## (kolumna, wiersz) wzięte wprost z identyfikatora heksa (litera=kolumna,
## numer=wiersz) - patrz tools/convert_kml_to_json.py. Wszystkie funkcje
## poniżej traktują je jako (col, row) i konwertują na axial wewnętrznie
## tam, gdzie potrzebna jest matematyka heksagonalna (odległości, piksele).
##
## Interfejs publiczny (nazwy i sygnatury funkcji) jest celowo identyczny
## jak w poprzednich wersjach - hex_map_view.gd, hex_pathfinder.gd i
## game_map_controller.gd nie wymagają żadnych zmian.

const SQRT3 = 1.7320508075688772

## Korekta proporcji "zakrzywienia" - żeby siatka miała te same proporcje co
## prawdziwa mapa Polski w Google Earth, zamiast być idealnym, regularnym
## polem heksów. Dwa nakładające się efekty złożone w jedną poprawkę:
##
## 1. Krzywizna Ziemi: na szerokości geograficznej Polski (~52°N) jeden
##    stopień długości geograficznej to fizycznie mniej kilometrów niż jeden
##    stopień szerokości (cos(52°) ≈ 0,61) - klasyczna projekcja
##    równoodległościowa (sekcja 10 GDD) kompensuje to mnożąc różnicę
##    długości geograficznej przez cos(średniej szerokości).
## 2. Siatka litera/numer z KML była ręcznie rozstawiana w Google Earth, więc
##    jej rozstaw wierszy/kolumn nie odpowiada 1:1 rzeczywistym odległościom
##    geograficznym nawet po korekcie z punktu 1.
##
## GEO_SCALE_X / GEO_SCALE_Y to wynik dopasowania metodą najmniejszych
## kwadratów (regresja liniowa bez wyrazu wolnego, na wszystkich 496 heksach
## `data/map_data.json`) pozycji siatki (axial_to_pixel przy size=1) do
## rzeczywistych współrzędnych (lon*cos(52°), -lat). Dopasowanie wyszło
## praktycznie czystym skalowaniem osi (człony ścinające pomijalnie małe -
## średni błąd dopasowania to ~0,9% przekątnej mapy), więc wystarczy prosta
## anizotropowa zmiana skali X/Y zamiast pełnej macierzy afinicznej. Iloczyn
## GEO_SCALE_X * GEO_SCALE_Y = 1, żeby zachować mniej więcej ten sam
## całkowity rozmiar mapy w pikselach (i dotychczasowe ustawienia kamery/
## prędkości ruchu) - to czysta korekta KSZTAŁTU, nie skali.
const GEO_SCALE_X = 1.122525
const GEO_SCALE_Y = 0.890849


static func offset_to_axial(col: int, row: int) -> Vector2i:
	var r = row - floori(float(col + (col & 1)) / 2.0)
	return Vector2i(col, r)


static func axial_to_offset(q: int, r: int) -> Vector2i:
	var row = r + floori(float(q + (q & 1)) / 2.0)
	return Vector2i(q, row)


static func axial_to_pixel(q: int, r: int, size: float) -> Vector2:
	var x = size * 1.5 * q * GEO_SCALE_X
	var y = size * SQRT3 * (r + q / 2.0) * GEO_SCALE_Y
	return Vector2(x, y)


static func offset_to_pixel(col: int, row: int, size: float) -> Vector2:
	var axial = offset_to_axial(col, row)
	return axial_to_pixel(axial.x, axial.y, size)


## Odwraca korektę proporcji (GEO_SCALE_X/Y) PRZED standardową matematyką
## piksel->axial poniżej, która zakłada regularną (nie "zakrzywioną") siatkę.
static func _pixel_to_axial_raw(pixel: Vector2, size: float) -> Vector2:
	var unscaled = Vector2(pixel.x / GEO_SCALE_X, pixel.y / GEO_SCALE_Y)
	var q = (2.0 / 3.0 * unscaled.x) / size
	var r = (-1.0 / 3.0 * unscaled.x + SQRT3 / 3.0 * unscaled.y) / size
	return Vector2(q, r)


static func _axial_round(q: float, r: float) -> Vector2i:
	var x = q
	var z = r
	var y = -x - z

	var rx = round(x)
	var ry = round(y)
	var rz = round(z)

	var x_diff = abs(rx - x)
	var y_diff = abs(ry - y)
	var z_diff = abs(rz - z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector2i(int(rx), int(rz))


## Zwraca współrzędne offset (col, row) heksa pod danym punktem pikselowym.
static func pixel_to_offset(pixel: Vector2, size: float) -> Vector2i:
	var raw = _pixel_to_axial_raw(pixel, size)
	var rounded = _axial_round(raw.x, raw.y)
	return axial_to_offset(rounded.x, rounded.y)


## Sześć narożników heksa "flat-top" o środku `center` i promieniu `size`.
## Wierzchołki skalowane tym samym GEO_SCALE_X/Y co pozycje środków (wyżej),
## żeby heksy pozostały idealnie do siebie przylegające (kafelkowanie) mimo
## że wizualnie są lekko "rozciągnięte" zgodnie z korektą proporcji mapy.
static func hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60.0 * i
		var angle_rad = deg_to_rad(angle_deg)
		var offset = Vector2(size * cos(angle_rad) * GEO_SCALE_X, size * sin(angle_rad) * GEO_SCALE_Y)
		points.append(center + offset)
	return points


## Sąsiedzi: konwersja do axial, dodanie 6 standardowych kierunków axial,
## konwersja z powrotem do offset - działa poprawnie niezależnie od
## parzystości kolumny, bo cała "nieregularność" siatki offset jest już
## obsłużona przez offset_to_axial/axial_to_offset.
static func offset_neighbors(col: int, row: int) -> Array[Vector2i]:
	var axial = offset_to_axial(col, row)
	var axial_dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	var result: Array[Vector2i] = []
	for d in axial_dirs:
		result.append(axial_to_offset(axial.x + d.x, axial.y + d.y))
	return result
