class_name PriceChartView
extends Control
## Hand-drawn line chart of a resource's price history - Godot has no
## built-in charting widget, so this is a plain `_draw()` polyline through
## `values`, plus a dashed reference line at the resource's equilibrium
## price and min/max labels on the Y axis. Used by the market page
## (scenes/market_panel.gd) - the panel just assigns `values`/
## `reference_value` and calls `queue_redraw()`, this control has no idea
## what a "resource" or a "round" is.

@export var values: Array = []
@export var reference_value: float = 0.0
@export var line_color: Color = Palette.COPPER_BRIGHT
@export var reference_color: Color = Palette.RULE
@export var label_color: Color = Palette.INK_DIM

const LEFT_MARGIN = 44.0
const RIGHT_MARGIN = 8.0
const TOP_MARGIN = 8.0
const BOTTOM_MARGIN = 8.0
const DASH_LENGTH = 5.0
const DASH_GAP = 4.0


func _draw() -> void:
	if values.is_empty():
		return

	var plot_size = Vector2(
		maxf(1.0, size.x - LEFT_MARGIN - RIGHT_MARGIN), maxf(1.0, size.y - TOP_MARGIN - BOTTOM_MARGIN)
	)
	var plot_origin = Vector2(LEFT_MARGIN, TOP_MARGIN)

	var lo: float = values.min()
	var hi: float = values.max()
	lo = minf(lo, reference_value)
	hi = maxf(hi, reference_value)
	if hi - lo < 0.001:
		hi = lo + 1.0
	var pad = (hi - lo) * 0.12
	lo -= pad
	hi += pad

	var ref_y = plot_origin.y + plot_size.y * (1.0 - (reference_value - lo) / (hi - lo))
	_draw_dashed_line(Vector2(plot_origin.x, ref_y), Vector2(plot_origin.x + plot_size.x, ref_y), reference_color)

	var points = PackedVector2Array()
	var denom = maxf(1.0, values.size() - 1.0)
	for i in range(values.size()):
		var x = plot_origin.x + plot_size.x * (float(i) / denom)
		var y = plot_origin.y + plot_size.y * (1.0 - (float(values[i]) - lo) / (hi - lo))
		points.append(Vector2(x, y))

	if points.size() >= 2:
		draw_polyline(points, line_color, 2.0, true)
	draw_circle(points[-1], 3.0, line_color)

	draw_string(
		ThemeDB.fallback_font, Vector2(0, plot_origin.y + 10), "%.1f" % hi,
		HORIZONTAL_ALIGNMENT_LEFT, LEFT_MARGIN - 4.0, 11, label_color
	)
	draw_string(
		ThemeDB.fallback_font, Vector2(0, plot_origin.y + plot_size.y), "%.1f" % lo,
		HORIZONTAL_ALIGNMENT_LEFT, LEFT_MARGIN - 4.0, 11, label_color
	)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var total = from.distance_to(to)
	if total <= 0.0:
		return
	var dir = (to - from) / total
	var traveled = 0.0
	while traveled < total:
		var seg_end = minf(traveled + DASH_LENGTH, total)
		draw_line(from + dir * traveled, from + dir * seg_end, color, 1.0)
		traveled += DASH_LENGTH + DASH_GAP
