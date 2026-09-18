class_name HexMapView
extends Node2D
## Phase 2 (visualization) + Phase 3 (fog of war) of the implementation plan.
## Draws the hex grid colored by terrain type, with three-level fog of war
## (GDD section 2.2, HexData.FogState): UNEXPLORED = fully hidden, SEEN =
## terrain type visible but dimmed (no details), ANNEXED = fully revealed
## (ID label, building/resource). Owned hexes additionally get a thicker
## outline in the team's color (visible from the SEEN threshold onward -
## the same threshold used for enemy unit visibility in
## game_map_controller.gd).

signal hex_clicked(hex_id: String)
signal hex_hovered(hex_id: String)  # empty string = cursor outside the grid

@export var viewing_player_id: int = 1

## The hex currently selected in the UI (Phase 6+ update - field actions act
## on the selected hex, not necessarily the one a unit is standing on) -
## drawn with a highlighted outline, so it's clear what the action panel
## refers to.
@export var selected_hex_id: String = ""

## Route (Phase 10+ update, the "Trasa ludzika" (unit route) panel in
## game_map_controller.gd) - two separate hex_id lists, so the preview
## (not yet confirmed) and the confirmed/in-progress route (which can span
## several rounds) look clearly different. The first element is always the
## unit's current hex.
@export var preview_route_hex_ids: Array[String] = []
@export var queued_route_hex_ids: Array[String] = []

## UI restyle: matches the map hex colors from UI_Gry_Makieta.html
## (theme/palette.gd) instead of the old ad hoc placeholder colors. FOREST/
## AGRICULTURAL entries here are the SUMMER color and the fallback for an
## unrecognized season - "Sezonowa szata mapy" (see TERRAIN_SEASONAL_COLORS
## + _terrain_color() below) overrides them for the other three seasons.
const TERRAIN_COLORS = {
	HexData.TerrainType.UNKNOWN: Palette.TERRAIN_UNKNOWN,
	HexData.TerrainType.AGRICULTURAL: Palette.TERRAIN_AGRICULTURAL,
	HexData.TerrainType.FOREST: Palette.TERRAIN_FOREST,
	HexData.TerrainType.MOUNTAIN: Palette.TERRAIN_MOUNTAIN,
	HexData.TerrainType.PROTECTED_AREA: Palette.TERRAIN_PROTECTED_AREA,
	HexData.TerrainType.CITY: Palette.TERRAIN_CITY,
	HexData.TerrainType.WATER: Palette.TERRAIN_WATER,
}

## Sezonowa szata mapy (nowość: "śnieg zimą, złota jesień, zielone lato —
## czysto wizualna zmiana skórki heksów zgodna z rundą sezonową") - tylko
## las i pola uprawne (patrz uzasadnienie w theme/palette.gd). SUMMER
## celowo pominięte tutaj - `_terrain_color()` spada wtedy na TERRAIN_COLORS
## powyżej, więc nie ma dwóch miejsc definiujących ten sam kolor.
const TERRAIN_SEASONAL_COLORS = {
	HexData.TerrainType.FOREST: {
		GameBalance.Season.SPRING: Palette.TERRAIN_FOREST_SPRING,
		GameBalance.Season.AUTUMN: Palette.TERRAIN_FOREST_AUTUMN,
		GameBalance.Season.WINTER: Palette.TERRAIN_FOREST_WINTER,
	},
	HexData.TerrainType.AGRICULTURAL: {
		GameBalance.Season.SPRING: Palette.TERRAIN_AGRICULTURAL_SPRING,
		GameBalance.Season.AUTUMN: Palette.TERRAIN_AGRICULTURAL_AUTUMN,
		GameBalance.Season.WINTER: Palette.TERRAIN_AGRICULTURAL_WINTER,
	},
}

const FOG_UNEXPLORED = Palette.FOG_UNEXPLORED
const FOG_SEEN_OVERLAY = Color(0, 0, 0, 0.4)
## Random event "Pożar lasu" (autoloads/random_event_manager.gd, HexData.is_on_fire) -
## a translucent red wash drawn on top of the terrain, same technique as
## FOG_SEEN_OVERLAY, so a burning hex is visible on the map itself, not just
## in the notification log / hex-info text.
const FIRE_OVERLAY = Color(0.878431, 0.313725, 0.227451, 0.45)
const OUTLINE_COLOR = Color(0, 0, 0, 0.5)
## Distinct from PREVIEW_ROUTE_COLOR below (see Palette.SELECTION) - a
## selected hex used to be visually indistinguishable from one merely on a
## previewed route, since both were GOLD_BRIGHT.
const SELECTED_OUTLINE_COLOR = Palette.SELECTION
const OWNER_OUTLINE_WIDTH = 4.0

## How many segments each map hex's rounded corner is tessellated into
## (ui/hex_shape.gd's HexShape.round_corners()) - fewer than the default
## used for small UI icons, since there can be hundreds of map hexes
## redrawn together and the rounding is barely visible at this size anyway.
const HEX_CORNER_ARC_SEGMENTS = 4

const PREVIEW_ROUTE_COLOR = Palette.GOLD_BRIGHT
const QUEUED_ROUTE_COLOR = Color(1, 0.5, 0.05, 0.9)
const ROUTE_LINE_WIDTH = 4.0
const ROUTE_DOT_RADIUS = 5.0


## Bieżący kolor terenu, uwzględniający porę roku dla lasu/pól uprawnych
## (`TERRAIN_SEASONAL_COLORS`) - czytana na nowo przy KAŻDYM `_draw()`, więc
## kolor zawsze odpowiada aktualnej `TurnManager.get_current_season()` bez
## żadnego dodatkowego odświeżania przy zmianie rundy (mapa i tak jest
## przerysowywana po każdej rundzie, patrz `_refresh_map_view()` w
## game_map_controller.gd).
func _terrain_color(terrain_type: HexData.TerrainType) -> Color:
	var seasonal: Dictionary = TERRAIN_SEASONAL_COLORS.get(terrain_type, {})
	return seasonal.get(TurnManager.get_current_season(), TERRAIN_COLORS.get(terrain_type, Color.WHITE))


func _draw() -> void:
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		_draw_hex(hex)

	_draw_route(queued_route_hex_ids, QUEUED_ROUTE_COLOR)
	_draw_route(preview_route_hex_ids, PREVIEW_ROUTE_COLOR)


func _draw_hex(hex: HexData) -> void:
	var center = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE)
	var hex_radius = GameBalance.HEX_SIZE * 0.92
	var sharp_corners = HexGridUtils.hex_corners(center, hex_radius)
	# Rounded corners (ui/hex_shape.gd) - matches UI_Gry_Makieta_11.html's
	# shared hex shape, now used everywhere in the UI, map tiles included.
	var corners = HexShape.round_corners(
		sharp_corners, hex_radius * HexShape.CORNER_TRIM_RATIO, HEX_CORNER_ARC_SEGMENTS
	)
	var fog = hex.get_fog_state(viewing_player_id)

	if fog == HexData.FogState.UNEXPLORED:
		draw_colored_polygon(corners, FOG_UNEXPLORED)
	else:
		draw_colored_polygon(corners, _terrain_color(hex.terrain_type))
		if fog == HexData.FogState.SEEN:
			draw_colored_polygon(corners, FOG_SEEN_OVERLAY)
		if hex.is_on_fire:
			draw_colored_polygon(corners, FIRE_OVERLAY)

	var outline = corners.duplicate()
	outline.append(corners[0])

	# Team color around hexes it has annexed - the same fog threshold as
	# enemy unit visibility (fog != UNEXPLORED, GDD section 2.2): it's enough
	# for the hex to have once been within vision range, it doesn't need to
	# be annexed by you yourself. Drawn as a thicker line UNDER the
	# normal/selected outline, so both are visible at once.
	if fog != HexData.FogState.UNEXPLORED and hex.owner_id != -1:
		var owner = GameManager.get_player(hex.owner_id)
		if owner != null:
			draw_polyline(outline, owner.color, OWNER_OUTLINE_WIDTH)

	var is_selected = hex.hex_id == selected_hex_id
	draw_polyline(outline, SELECTED_OUTLINE_COLOR if is_selected else OUTLINE_COLOR, 3.0 if is_selected else 1.5)

	if fog == HexData.FogState.ANNEXED:
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-14, 4), hex.hex_id,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE
		)


## Draws a route as a line connecting the centers of consecutive hexes, plus
## a dot on each of them (the first list element is always the unit's
## current hex). The preview and the in-progress route are drawn separately
## (see _draw()), so both can be visible at once when the player is
## previewing a different route than the one currently executing.
func _draw_route(route_hex_ids: Array[String], color: Color) -> void:
	if route_hex_ids.size() < 2:
		return

	var points: PackedVector2Array = []
	for hex_id in route_hex_ids:
		var hex = MapData.get_hex(hex_id)
		if hex == null:
			continue
		points.append(HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE))

	if points.size() >= 2:
		draw_polyline(points, color, ROUTE_LINE_WIDTH)
	for p in points:
		draw_circle(p, ROUTE_DOT_RADIUS, color)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hex = _hex_under_mouse()
		if hex != null:
			hex_clicked.emit(hex.hex_id)
	elif event is InputEventMouseMotion:
		var hex = _hex_under_mouse()
		hex_hovered.emit(hex.hex_id if hex != null else "")


## Uses get_global_mouse_position() (correctly accounts for the camera
## transform - zoom/pan from camera_controller.gd), not the raw
## event.position/global_position, which are screen/window coordinates and
## do NOT account for the camera.
func _hex_under_mouse() -> HexData:
	var local_pos: Vector2 = to_local(get_global_mouse_position())
	var coord = HexGridUtils.pixel_to_offset(local_pos, GameBalance.HEX_SIZE)
	return MapData.get_hex_at(coord.x, coord.y)
