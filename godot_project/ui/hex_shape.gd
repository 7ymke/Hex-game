class_name HexShape
extends Control
## Flat-top hexagon shape with ROUNDED CORNERS, matching
## UI_Gry_Makieta_11.html's shared SVG `#hexShape` symbol exactly (Godot
## Controls have no SVG `<path>`/clip-path equivalent, so this rasterizes
## the same geometry procedurally instead of baking texture files - see
## the README's "Decyzje projektowe" entry for why: no image-editing tool
## or live Godot editor is available in this environment to produce/verify
## baked PNGs, while the procedural approach can be reasoned about and
## cross-checked against the reference path's own numbers directly).
##
## Always draws a geometrically REGULAR hexagon (all 6 sides equal, corner
## rounding scales with it) centered inside whatever rect it's given - it
## does NOT stretch to fill a non-hex-shaped box. Used for the round-chip
## badge, MP pips, building/legend icons, and slider thumbs.

## The reference SVG path (`M 19.00 10.39 Q 25.00 0.00 37.00 0.00 L 63.00
## 0.00 Q 75.00 0.00 81.00 10.39 ...`) rounds a flat-top hexagon with
## circumradius 50 using a corner "trim" of exactly 12 units on each edge
## (verified by hand: vertex (75,0), trim toward (25,0) lands at exactly
## (63,0) = 75-12; trim toward (100,43.3) lands at exactly (81,10.39) =
## vertex + 12*unit_vector, matching the path to 2 decimals). The
## rounding itself is a quadratic Bezier with the ORIGINAL SHARP VERTEX as
## its control point - not a true circular arc - so reproducing it exactly
## just means replaying that same construction at any radius, keeping the
## ratio trim/circumradius = 12/50 constant so it scales proportionally.
const CORNER_TRIM_RATIO = 12.0 / 50.0
const DEFAULT_ARC_SEGMENTS = 6

@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()
@export var border_color: Color = Color(0, 0, 0, 0):
	set(value):
		border_color = value
		queue_redraw()
@export var border_width: float = 0.0:
	set(value):
		border_width = value
		queue_redraw()


func _draw() -> void:
	var points = hex_points(size)
	draw_colored_polygon(points, fill_color)
	if border_width > 0.0 and border_color.a > 0.0:
		var closed = points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, border_color, border_width, true)


## The corners of a regular, rounded-corner flat-top hex inscribed in a
## `box_size`-sized rect, centered on it - same orientation as
## HexGridUtils.hex_corners() (flat top/bottom, points left/right), just
## without that function's GEO_SCALE_X/Y map-projection correction, which
## has nothing to do with UI icons.
static func hex_points(box_size: Vector2, arc_segments: int = DEFAULT_ARC_SEGMENTS) -> PackedVector2Array:
	var radius = minf(box_size.x / 2.0, box_size.y / HexGridUtils.SQRT3)
	var center = box_size / 2.0
	var sharp = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i)
		sharp.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return round_corners(sharp, radius * CORNER_TRIM_RATIO, arc_segments)


## Rounds every corner of an arbitrary closed polygon (`sharp_points`,
## already in drawing order) by `trim` units, using the same "quadratic
## Bezier with the original vertex as control point" construction as
## `hex_points()` above - shared so hex_map_view.gd can apply the exact
## same rounding to HexGridUtils.hex_corners() for the actual map tiles,
## without duplicating the Bezier math.
static func round_corners(
	sharp_points: PackedVector2Array, trim: float, arc_segments: int = DEFAULT_ARC_SEGMENTS
) -> PackedVector2Array:
	var n = sharp_points.size()
	var points = PackedVector2Array()
	for i in range(n):
		var prev_v: Vector2 = sharp_points[(i - 1 + n) % n]
		var v: Vector2 = sharp_points[i]
		var next_v: Vector2 = sharp_points[(i + 1) % n]
		var trim_start = v + (prev_v - v).normalized() * trim
		var trim_end = v + (next_v - v).normalized() * trim
		for s in range(arc_segments + 1):
			var t = float(s) / arc_segments
			points.append(_quad_bezier(trim_start, v, trim_end, t))
	return points


static func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t)


## Rasterizes a filled hex into an ImageTexture - for spots that need a
## Texture2D rather than a Control (e.g. CheckBox's icon_checked/
## icon_unchecked theme overrides, which only accept textures, or an
## HSlider's grabber icon). Uses a plain scanline polygon fill: for every
## pixel row, intersect the hex's edges with the row's center line, sort
## the crossings, and fill between each pair - the standard even-odd fill
## rule, correct for any simple (non-self-intersecting) polygon, convex or
## not, so the same routine works unchanged for the rounded shape's
## many-segment outline.
static func make_texture(box_size: Vector2i, fill: Color) -> ImageTexture:
	var w = maxi(1, box_size.x)
	var h = maxi(1, box_size.y)
	var points = hex_points(Vector2(w, h))

	var image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	for y in range(h):
		var sample_y = y + 0.5
		var crossings: Array[float] = []
		for i in range(points.size()):
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[(i + 1) % points.size()]
			if p1.y == p2.y:
				continue
			var y_min = minf(p1.y, p2.y)
			var y_max = maxf(p1.y, p2.y)
			if sample_y < y_min or sample_y >= y_max:
				continue
			var t = (sample_y - p1.y) / (p2.y - p1.y)
			crossings.append(p1.x + t * (p2.x - p1.x))
		crossings.sort()

		var i = 0
		while i + 1 < crossings.size():
			var x_start = maxi(0, int(round(crossings[i])))
			var x_end = mini(w, int(round(crossings[i + 1])))
			for x in range(x_start, x_end):
				image.set_pixel(x, y, fill)
			i += 2

	return ImageTexture.create_from_image(image)
