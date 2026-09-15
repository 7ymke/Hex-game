class_name HexShape
extends Control
## Flat-top hexagon shape for UI elements (Godot Controls have no CSS
## clip-path equivalent) - draws a single filled hex sized to the control's
## rect. Vertex layout matches the CSS clip-path used throughout
## UI_Gry_Makieta.html: polygon(25% 3%, 75% 3%, 100% 50%, 75% 97%, 25% 97%,
## 0% 50%). Used for the round-chip badge, MP pips, building/legend icons,
## and slider thumbs.

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


## The 6 corners of a flat-top hex inscribed in a `box_size`-sized rect,
## matching the mockup's CSS clip-path percentages exactly.
static func hex_points(box_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(box_size.x * 0.25, box_size.y * 0.03),
		Vector2(box_size.x * 0.75, box_size.y * 0.03),
		Vector2(box_size.x * 1.00, box_size.y * 0.50),
		Vector2(box_size.x * 0.75, box_size.y * 0.97),
		Vector2(box_size.x * 0.25, box_size.y * 0.97),
		Vector2(box_size.x * 0.00, box_size.y * 0.50),
	])


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
