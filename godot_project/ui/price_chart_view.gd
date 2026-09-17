class_name PriceChartView
extends Control
## Simple sparkline of a resource's price history - line + a lightly
## filled area underneath, matching UI_Gry_Makieta_11.html's
## `#mChartLine`/`#mChartArea` exactly (min/max of the shown history
## normalized to the drawing height, a small fixed pixel margin on every
## side - no reference line, no axis labels; the market page deliberately
## shows nothing about WHY the price is what it is, see market_panel.gd).
## Godot has no charting widget, so this is a plain `_draw()` polyline +
## filled polygon - the market page just assigns `values` and calls
## `queue_redraw()`, this control has no idea what a "resource" or a
## "round" is.
##
## Handles two cases the makieta's own hard-coded 8-round `history` arrays
## never hit, but the real game does: a single price (round 1, right at
## the very start of a game, before `MarketManager.process_round_end()`
## has run even once) and an unchanged price (min == max across the whole
## shown window). Both are drawn as a flat line/area at MID-HEIGHT rather
## than left to fall out of the normal min→max normalization (which would
## divide by ~0 and pin everything to one edge) - a real, currently-set
## price should always read as a visible line, never as a blank chart or
## one glued to the bottom.
##
## Hover readout ("Zrób aby... zobaczyć cenę i numer rundy"): `values[i]`
## on its own doesn't say WHICH round it's from, so `end_round` (the round
## number of the LAST/rightmost point - market_panel.gd sets it to
## `TurnManager.round_number`, matching the header's own "Runda X") lets
## every other index's round be derived by counting backwards. Drawn
## as a vertical guide + dot + a small floating label that follows the
## cursor, all in `_draw()` (no separate popup/native tooltip - this reacts
## instantly to mouse movement, a native `tooltip_text` only refreshes
## after Godot's hover delay).

@export var values: Array = []
@export var line_color: Color = Palette.GOLD
@export var area_color: Color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.18)

## The round number of `values[-1]` (the most recent/rightmost point) -
## see the class comment above.
@export var end_round: int = 0

const MARGIN = 4.0
const HOVER_LABEL_FONT_SIZE = 12
const HOVER_LABEL_PADDING = Vector2(6, 4)

## Index into `values` the mouse is currently nearest to, or -1 when the
## mouse isn't hovering the chart at all.
var _hover_index: int = -1


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_exited() -> void:
	_hover_index = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or values.is_empty():
		return
	var plot_width = maxf(1.0, size.x - MARGIN * 2.0)
	var denom = maxf(1.0, values.size() - 1.0)
	var t = (event.position.x - MARGIN) / plot_width * denom
	var index = clampi(roundi(t), 0, values.size() - 1)
	if index != _hover_index:
		_hover_index = index
		queue_redraw()


func _draw() -> void:
	if values.is_empty():
		return

	var lo: float = values.min()
	var hi: float = values.max()
	var flat = (hi - lo) < 0.001

	var plot_size = Vector2(maxf(1.0, size.x - MARGIN * 2.0), maxf(1.0, size.y - MARGIN * 2.0))
	var denom = maxf(1.0, values.size() - 1.0)

	var points = PackedVector2Array()
	for i in range(values.size()):
		var x = MARGIN + plot_size.x * (float(i) / denom)
		var y: float
		if flat:
			y = MARGIN + plot_size.y * 0.5
		else:
			y = MARGIN + plot_size.y * (1.0 - (float(values[i]) - lo) / (hi - lo))
		points.append(Vector2(x, y))
	if points.size() == 1:
		points.append(Vector2(MARGIN + plot_size.x, points[0].y))

	var area_points = points.duplicate()
	area_points.append(Vector2(points[-1].x, size.y - MARGIN))
	area_points.append(Vector2(points[0].x, size.y - MARGIN))
	draw_colored_polygon(area_points, area_color)

	draw_polyline(points, line_color, 2.5, true)

	if _hover_index >= 0 and _hover_index < points.size():
		_draw_hover_readout(points[_hover_index], _hover_index)


func _draw_hover_readout(point: Vector2, index: int) -> void:
	draw_line(Vector2(point.x, 0.0), Vector2(point.x, size.y), Palette.CREAM_DIM, 1.0)
	draw_circle(point, 3.5, Palette.GOLD_BRIGHT)

	var round_number = end_round - (values.size() - 1 - index)
	var text = "Runda %d: %.2f" % [round_number, values[index]]

	var font: Font = get_theme_default_font()
	var font_size = HOVER_LABEL_FONT_SIZE
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box_size = text_size + HOVER_LABEL_PADDING * 2.0

	# Keep the label fully inside the chart horizontally, and flip it below
	# the point instead of above when there isn't room at the top.
	var box_pos = Vector2(
		clampf(point.x - box_size.x / 2.0, 0.0, maxf(0.0, size.x - box_size.x)),
		point.y - box_size.y - 6.0 if point.y - box_size.y - 6.0 >= 0.0 else point.y + 6.0
	)

	draw_rect(Rect2(box_pos, box_size), Palette.BORDER, true)
	draw_string(
		font, box_pos + Vector2(HOVER_LABEL_PADDING.x, HOVER_LABEL_PADDING.y + font.get_ascent(font_size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.CREAM
	)
