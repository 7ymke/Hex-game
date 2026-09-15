class_name HexShape
extends Control
## Flat-top hexagon shape for UI elements (Godot Controls have no CSS
## clip-path equivalent). Always draws a geometrically REGULAR hexagon (all
## 6 sides equal, matching HexGridUtils' own flat-top math) centered inside
## whatever rect it's given - it does NOT stretch to fill a non-hex-shaped
## box, unlike a naive port of the mockup's CSS clip-path percentages
## (which only looks regular for the exact box proportions the mockup
## happened to use, and looks squashed/stretched for any other box size -
## e.g. the round-chip badge). Used for the round-chip badge, MP pips,
## building/legend icons, and slider thumbs.

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


## The 6 corners of the largest REGULAR flat-top hexagon that fits inside a
## `box_size`-sized rect, centered on it. A regular flat-top hex of "radius"
## r (center to vertex) is 2r wide and r*sqrt(3) tall, so the fitting radius
## is whichever of the box's two dimensions is more constraining
## (`minf(width-based, height-based)`) - the box's own aspect ratio is
## otherwise irrelevant, which is exactly what keeps the hex regular
## regardless of what rect a container ends up giving this control. Same
## vertex order/orientation as HexGridUtils.hex_corners() (flat top/bottom,
## points left/right), just without that function's GEO_SCALE_X/Y map
## projection correction, which has nothing to do with UI icons.
static func hex_points(box_size: Vector2) -> PackedVector2Array:
	var radius = minf(box_size.x / 2.0, box_size.y / HexGridUtils.SQRT3)
	var center = box_size / 2.0
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Rasterizes a filled hex into an ImageTexture - for spots that need a
## Texture2D rather than a Control (e.g. CheckBox's icon_checked/
## icon_unchecked theme overrides, which only accept textures). Uses a plain
## scanline polygon fill: for every pixel row, intersect the hex's 6 edges
## with the row's center line, sort the crossings, and fill between each
## pair - correct for any convex polygon, no external rasterizer needed.
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
				continue  # the two horizontal edges (top/bottom) never cross a scanline
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
