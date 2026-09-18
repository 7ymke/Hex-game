class_name MarketPanel
extends CanvasLayer
## The market page for a single resource (autoloads/market_manager.gd) -
## sparkline chart over recent rounds, plus buy/sell. Opened by clicking
## that resource's pill in the top bar (game_map_controller.gd) - one
## panel instance reused for whichever resource is currently open
## (`open_for_resource`), same pattern as CityCardPanel/SkillTreePanel
## (both also `extends CanvasLayer`, parented directly at the scene root
## so they draw above the map and the main UI regardless of tree order).
##
## `Background` (the actual PanelContainer) and `CloseButton` are two
## independent children of this CanvasLayer, not of each other - a
## CanvasLayer, unlike a PanelContainer or any other Container, never
## force-fits its children into a shared rect, so the close button can sit
## in the panel's absolute corner (its own fixed offsets) while `Background`
## lays out its own content normally. (ui/unit_card.gd has a real version of
## this problem and fixes it differently - its card lives INSIDE the main
## UI's Control tree, not on its own CanvasLayer, so its root has to be a
## plain Control instead.)
##
## Deliberately shows NOTHING about how prices are computed (no mention of
## mean-reversion, background demand/supply, or the model at all) - see
## the restyle spec, section 5.1 point 5: "to wiedza projektowa, nie coś,
## co gracz ma czytać w UI". The panel only ever shows numbers. There is
## also no separate error-message area (the old UI had one) - the
## quantity HSlider structurally CANNOT exceed the per-round trade limit
## (unlike the previous SpinBox, which could be typed past the remaining
## allowance), and Kup/Sprzedaj simply DISABLE themselves when the
## current quantity isn't actually affordable/available - prevention
## instead of an error to read, matching the panel's own minimalism.

signal closed
signal traded

## How many of the most recent rounds the chart can show - picked by the
## player via `range_5_button`/`range_15_button`/`range_all_button`
## ("Chcę aby dało się zmieniać wykres - między ostatnimi 5 rundami, 15 a
## wszystkimi"). ALL is represented the same way MarketManager.
## get_price_history() itself represents "no limit" (<= 0), so it can be
## passed straight through without a special case at the call site.
const CHART_WINDOW_5 = 5
const CHART_WINDOW_15 = 15
const CHART_WINDOW_ALL = -1

@onready var background: PanelContainer = $Background
@onready var close_button: Button = $CloseButton
@onready var head_dot: Panel = $Background/VBox/HeaderRow/HeadDot
@onready var name_label: Label = $Background/VBox/HeaderRow/NameLabel
@onready var range_5_button: Button = $Background/VBox/ChartRangeRow/Range5Button
@onready var range_15_button: Button = $Background/VBox/ChartRangeRow/Range15Button
@onready var range_all_button: Button = $Background/VBox/ChartRangeRow/RangeAllButton
@onready var chart_view: PriceChartView = $Background/VBox/ChartArea
@onready var qty_value_label: Label = $Background/VBox/QtyRow/QtyValueLabel
@onready var qty_slider: HSlider = $Background/VBox/QtySlider
@onready var buy_total_label: Label = $Background/VBox/BuyRow/BuyRowHBox/BuyTotalLabel
@onready var buy_button: Button = $Background/VBox/BuyRow/BuyRowHBox/BuyButton
@onready var sell_total_label: Label = $Background/VBox/SellRow/SellRowHBox/SellTotalLabel
@onready var sell_button: Button = $Background/VBox/SellRow/SellRowHBox/SellButton

var _current_player: PlayerData
var _current_resource: HexData.ResourceType = HexData.ResourceType.NONE

## Starts on ALL rather than 5 - unlike the other two, ALL is always a
## meaningful choice no matter how young the game is (see
## `_update_chart_range_buttons()`), so it's the one default that never
## needs a fallback.
var _chart_window: int = CHART_WINDOW_ALL


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	qty_slider.min_value = 1.0
	qty_slider.step = 1.0
	qty_slider.value_changed.connect(_on_qty_changed)

	range_5_button.pressed.connect(_on_chart_range_pressed.bind(CHART_WINDOW_5))
	range_15_button.pressed.connect(_on_chart_range_pressed.bind(CHART_WINDOW_15))
	range_all_button.pressed.connect(_on_chart_range_pressed.bind(CHART_WINDOW_ALL))
	range_all_button.button_pressed = true


func open_for_resource(resource: HexData.ResourceType, player: PlayerData) -> void:
	_current_resource = resource
	_current_player = player
	visible = true
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	if _current_player == null or not MarketBalance.RESOURCE_PARAMS.has(_current_resource):
		return

	name_label.text = HexData.RESOURCE_DISPLAY_NAMES.get(_current_resource, "?")
	head_dot.self_modulate = _resource_dot_color(_current_resource)

	_update_chart_range_buttons()
	chart_view.values = MarketManager.get_price_history(_current_resource, _chart_window)
	# The last/rightmost point in `values` is always the CURRENT price
	# (TurnManager.round_number) - so the hover readout can label every
	# other point by counting backwards from here (see price_chart_view.gd).
	chart_view.end_round = TurnManager.round_number
	chart_view.queue_redraw()

	var limit = MarketManager.get_trade_limit(_current_resource)
	qty_slider.max_value = maxf(1.0, limit)
	if qty_slider.value < qty_slider.min_value:
		qty_slider.value = maxf(1.0, roundf(limit / 2.0))

	_update_totals()
	_fit_height_to_content()


## Only offers a shorter window once the game has actually run long enough
## for it to show something different from "Wszystkie" - a "15" tab that
## would display the exact same 4 rounds as "Wszystkie" is just confusing,
## not a real choice ("chyba że rundy są mniejsze od podanych przeze mnie
## liczb"). Every resource's full history is the same length (MarketManager
## advances all of them together every round), so this never needs to
## un-hide-then-hide a tab the player already has selected - once a tab
## appears, it stays available for the rest of the game.
func _update_chart_range_buttons() -> void:
	var full_size = MarketManager.get_price_history(_current_resource).size()
	range_5_button.visible = full_size > CHART_WINDOW_5
	range_15_button.visible = full_size > CHART_WINDOW_15


func _on_chart_range_pressed(window: int) -> void:
	_chart_window = window
	_refresh()


## The makieta's `.market-frame` shrink-wraps its content (no CSS height set)
## - `Background`'s width stays fixed (340..800 in main.tscn, matching the
## makieta's 460px `max-width`), but its height was a guessed fixed value
## that left a large empty gap below the Sell row. Reading Godot's own
## `get_combined_minimum_size()` after every refresh (rather than a second
## hand-guessed constant) means this can never under- or over-shoot the
## actual content, whatever its final text/font metrics turn out to be.
func _fit_height_to_content() -> void:
	var content_height = background.get_combined_minimum_size().y
	background.size = Vector2(background.size.x, content_height)


func _resource_dot_color(resource: HexData.ResourceType) -> Color:
	match resource:
		HexData.ResourceType.WOOD:
			return Palette.RESOURCE_DOT_WOOD
		HexData.ResourceType.FOOD:
			return Palette.RESOURCE_DOT_FOOD
		HexData.ResourceType.COPPER:
			return Palette.RESOURCE_DOT_COPPER
		HexData.ResourceType.COAL:
			return Palette.RESOURCE_DOT_COAL
		HexData.ResourceType.GAS:
			return Palette.RESOURCE_DOT_GAS
		HexData.ResourceType.NICKEL:
			return Palette.RESOURCE_DOT_NICKEL
		HexData.ResourceType.OIL:
			return Palette.RESOURCE_DOT_OIL
		_:
			return Palette.GOLD


func _on_qty_changed(_value: float) -> void:
	_update_totals()


## Live-updates both trade line totals (restyle spec 5.1 point 4:
## "aktualizowane na żywo przy przesuwaniu suwaka") and whether Kup/Sprzedaj
## are actually usable right now.
func _update_totals() -> void:
	var qty = qty_slider.value
	qty_value_label.text = "%d szt." % int(qty)

	var prices = MarketManager.get_trade_prices(_current_resource)
	var buy_total = qty * prices["buy_price"]
	var sell_total = qty * prices["sell_price"]
	buy_total_label.text = "%.2f" % buy_total
	sell_total_label.text = "%.2f" % sell_total

	var limit = MarketManager.get_trade_limit(_current_resource)
	var bought = MarketManager.get_traded_this_round(_current_player.player_id, _current_resource, MarketManager.DIRECTION_BUY)
	var sold = MarketManager.get_traded_this_round(_current_player.player_id, _current_resource, MarketManager.DIRECTION_SELL)

	buy_button.disabled = (bought + qty > limit) or (_current_player.money < buy_total)
	sell_button.disabled = (sold + qty > limit) or (_current_player.get_resource_amount(_current_resource) < qty)


func _on_buy_pressed() -> void:
	_trade(MarketManager.DIRECTION_BUY)


func _on_sell_pressed() -> void:
	_trade(MarketManager.DIRECTION_SELL)


func _trade(direction: String) -> void:
	var result = MarketManager.attempt_trade(_current_player.player_id, _current_resource, direction, qty_slider.value)
	if result["success"]:
		traded.emit()
	_refresh()
