class_name HexGridUtils
extends RefCounted
## Matematyka siatki heksagonalnej "flat-top", układ współrzędnych OFFSET
## "even-q" (parzyste kolumny przesunięte w dół o pół heksa - czyli kolejna
## litera w tym samym numerze wiersza renderuje się NIŻEJ, np. H14 leży nad
## G14, tak jak sobie tego życzono).
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


static func offset_to_axial(col: int, row: int) -> Vector2i:
	var r = row - int(floor(float(col + (col & 1)) / 2.0))
	return Vector2i(col, r)


static func axial_to_offset(q: int, r: int) -> Vector2i:
	var row = r + int(floor(float(q + (q & 1)) / 2.0))
	return Vector2i(q, row)


static func axial_to_pixel(q: int, r: int, size: float) -> Vector2:
	var x = size * 1.5 * q
	var y = size * SQRT3 * (r + q / 2.0)
	return Vector2(x, y)


static func offset_to_pixel(col: int, row: int, size: float) -> Vector2:
	var axial = offset_to_axial(col, row)
	return axial_to_pixel(axial.x, axial.y, size)


static func _pixel_to_axial_raw(pixel: Vector2, size: float) -> Vector2:
	var q = (2.0 / 3.0 * pixel.x) / size
	var r = (-1.0 / 3.0 * pixel.x + SQRT3 / 3.0 * pixel.y) / size
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
static func hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(6):
		var angle_deg = 60.0 * i
		var angle_rad = deg_to_rad(angle_deg)
		points.append(center + Vector2(size * cos(angle_rad), size * sin(angle_rad)))
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


## Odległość w "skokach" heksów między dwoma polami podanymi w naszych
## współrzędnych offset (col, row) - potrzebne do sprawdzania zasięgu akcji
## (GameBalance.ACTION_RANGE: aneksacja/naprawa/wydobycie/przejęcie bez
## konieczności stania dokładnie na polu). Standardowa formuła odległości
## na siatce heksagonalnej, liczona we współrzędnych axial/cube.
static func offset_distance(col_a: int, row_a: int, col_b: int, row_b: int) -> int:
	var axial_a = offset_to_axial(col_a, row_a)
	var axial_b = offset_to_axial(col_b, row_b)
	var dq = axial_a.x - axial_b.x
	var dr = axial_a.y - axial_b.y
	return int((abs(dq) + abs(dr) + abs(dq + dr)) / 2)
