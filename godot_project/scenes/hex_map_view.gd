class_name HexMapView
extends Node2D
## Faza 2 (wizualizacja) + Faza 3 (mgła wojny) planu implementacji.
## Rysuje siatkę heksów kolorowaną wg typu terenu, z trójpoziomową mgłą wojny
## (sekcja 2.2 GDD): "unexplored" = całkiem zakryty, "seen" = widoczny typ
## terenu ale przyciemniony (bez szczegółów), "annexed" = w pełni odkryty
## (etykieta z ID, budynek/zasób). Heksy z właścicielem dostają dodatkowo
## grubszą obwódkę w kolorze drużyny (widoczną od progu "seen" - ten sam co
## widoczność ludzika przeciwnika w game_map_controller.gd).

signal hex_clicked(hex_id: String)
signal hex_hovered(hex_id: String)  # pusty string = kursor poza siatką

@export var viewing_player_id: int = 1

## Heks aktualnie zaznaczony w UI (Faza 6+ update - akcje na polu działają na
## zaznaczonym heksie, niekoniecznie tym, na którym stoi ludzik) - rysowany z
## wyróżniającą obwódką, żeby było widać, czego dotyczy panel akcji.
@export var selected_hex_id: String = ""

const TERRAIN_COLORS = {
	HexData.TerrainType.UNKNOWN: Color(0.6, 0.6, 0.6),
	HexData.TerrainType.AGRICULTURAL: Color(0.76, 0.80, 0.35),
	HexData.TerrainType.FOREST: Color(0.13, 0.42, 0.16),
	HexData.TerrainType.MOUNTAIN: Color(0.5, 0.45, 0.4),
	HexData.TerrainType.PROTECTED_AREA: Color(0.18, 0.55, 0.5),
	HexData.TerrainType.CITY: Color(0.75, 0.25, 0.2),
	HexData.TerrainType.WATER: Color(0.2, 0.4, 0.75),
}

const FOG_UNEXPLORED = Color(0.08, 0.08, 0.08)
const FOG_SEEN_OVERLAY = Color(0, 0, 0, 0.4)
const OUTLINE_COLOR = Color(0, 0, 0, 0.5)
const SELECTED_OUTLINE_COLOR = Color(1, 0.9, 0.2, 0.9)
const OWNER_OUTLINE_WIDTH = 4.0


func _draw() -> void:
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		_draw_hex(hex)


func _draw_hex(hex: HexData) -> void:
	var center = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE)
	var corners = HexGridUtils.hex_corners(center, GameBalance.HEX_SIZE * 0.92)
	var fog = hex.get_fog_state(viewing_player_id)

	if fog == "unexplored":
		draw_colored_polygon(corners, FOG_UNEXPLORED)
	else:
		var base_color: Color = TERRAIN_COLORS.get(hex.terrain_type, Color.WHITE)
		draw_colored_polygon(corners, base_color)
		if fog == "seen":
			draw_colored_polygon(corners, FOG_SEEN_OVERLAY)

	var outline = corners.duplicate()
	outline.append(corners[0])

	# Kolor drużyny wokół pól, które przejęła - ten sam próg mgły co
	# widoczność ludzika przeciwnika (fog != "unexplored", sekcja 2.2 GDD):
	# wystarczy, że pole kiedyś znalazło się w zasięgu widzenia, nie trzeba
	# go samemu zaanektować. Rysowany grubszą linią POD zwykłą/zaznaczoną
	# obwódką, żeby obie były widoczne naraz.
	if fog != "unexplored" and hex.owner_id != -1:
		var owner = GameManager.get_player(hex.owner_id)
		if owner != null:
			draw_polyline(outline, owner.color, OWNER_OUTLINE_WIDTH)

	var is_selected = hex.hex_id == selected_hex_id
	draw_polyline(outline, SELECTED_OUTLINE_COLOR if is_selected else OUTLINE_COLOR, 3.0 if is_selected else 1.5)

	if fog == "annexed":
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-14, 4), hex.hex_id,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE
		)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hex = _hex_under_mouse()
		if hex != null:
			hex_clicked.emit(hex.hex_id)
	elif event is InputEventMouseMotion:
		var hex = _hex_under_mouse()
		hex_hovered.emit(hex.hex_id if hex != null else "")


## Używa get_global_mouse_position() (poprawnie uwzględnia transform kamery -
## zoom/pan z camera_controller.gd), a nie surowego event.position/global_position,
## które są współrzędnymi ekranu/okna i NIE uwzględniają kamery.
func _hex_under_mouse() -> HexData:
	var local_pos: Vector2 = to_local(get_global_mouse_position())
	var coord = HexGridUtils.pixel_to_offset(local_pos, GameBalance.HEX_SIZE)
	return MapData.get_hex_at(coord.x, coord.y)
