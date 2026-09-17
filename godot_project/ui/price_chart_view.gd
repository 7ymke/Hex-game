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

@export var values: Array = []
@export var line_color: Color = Palette.GOLD
@export var area_color: Color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.18)

const MARGIN = 4.0


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
