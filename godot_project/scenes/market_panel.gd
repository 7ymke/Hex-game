class_name MarketPanel
extends CanvasLayer
## The market page for a single resource (autoloads/market_manager.gd) -
## price chart over recent rounds, plus buy/sell. Opened by clicking that
## resource's chip in the top bar (game_map_controller.gd) - one panel
## instance reused for whichever resource is currently open
## (`open_for_resource`), same pattern as CityCardPanel/SkillTreePanel.

signal closed
signal traded

## How many of the most recent rounds the chart shows - the model itself
## keeps the FULL history (for momentum math elsewhere), this is purely a
## display choice so the chart doesn't get unreadably dense in a long game.
const CHART_ROUNDS = 24

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var mid_price_label: Label = $Panel/VBox/PriceRow/MidPriceLabel
@onready var buy_price_label: Label = $Panel/VBox/PriceRow/BuyPriceLabel
@onready var sell_price_label: Label = $Panel/VBox/PriceRow/SellPriceLabel
@onready var chart_view: PriceChartView = $Panel/VBox/ChartArea
@onready var limit_label: Label = $Panel/VBox/LimitLabel
@onready var amount_spinbox: SpinBox = $Panel/VBox/TradeRow/AmountSpinBox
@onready var buy_button: Button = $Panel/VBox/TradeRow/BuyButton
@onready var sell_button: Button = $Panel/VBox/TradeRow/SellButton
@onready var feedback_label: Label = $Panel/VBox/FeedbackLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

var _current_player: PlayerData
var _current_resource: HexData.ResourceType = HexData.ResourceType.NONE


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	amount_spinbox.min_value = 1
	amount_spinbox.step = 1


func open_for_resource(resource: HexData.ResourceType, player: PlayerData) -> void:
	_current_resource = resource
	_current_player = player
	feedback_label.text = ""
	visible = true
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	if _current_player == null or not MarketBalance.RESOURCE_PARAMS.has(_current_resource):
		return

	title_label.text = "Rynek: %s" % HexData.RESOURCE_DISPLAY_NAMES.get(_current_resource, "?")

	var mid = MarketManager.get_current_price(_current_resource)
	var prices = MarketManager.get_trade_prices(_current_resource)
	mid_price_label.text = "Cena środkowa: %.2f" % mid
	buy_price_label.text = "Kupno: %.2f" % prices["buy_price"]
	sell_price_label.text = "Sprzedaż: %.2f" % prices["sell_price"]

	chart_view.values = MarketManager.get_price_history(_current_resource, CHART_ROUNDS)
	chart_view.reference_value = MarketBalance.RESOURCE_PARAMS[_current_resource]["p_eq"]
	chart_view.queue_redraw()

	var limit = MarketManager.get_trade_limit(_current_resource)
	var bought = MarketManager.get_traded_this_round(_current_player.player_id, _current_resource, MarketManager.DIRECTION_BUY)
	var sold = MarketManager.get_traded_this_round(_current_player.player_id, _current_resource, MarketManager.DIRECTION_SELL)
	limit_label.text = "Limit tej rundy: kupno %d/%d, sprzedaż %d/%d | masz %.0f zasobu, %.0f pieniędzy" % [
		int(bought), limit, int(sold), limit,
		_current_player.get_resource_amount(_current_resource), _current_player.money
	]

	amount_spinbox.max_value = maxf(1.0, limit)
	sell_button.disabled = _current_player.get_resource_amount(_current_resource) < 1.0


func _on_buy_pressed() -> void:
	_trade(MarketManager.DIRECTION_BUY)


func _on_sell_pressed() -> void:
	_trade(MarketManager.DIRECTION_SELL)


func _trade(direction: String) -> void:
	var amount = amount_spinbox.value
	var result = MarketManager.attempt_trade(_current_player.player_id, _current_resource, direction, amount)
	if result["success"]:
		var verb = "Kupiono" if direction == MarketManager.DIRECTION_BUY else "Sprzedano"
		feedback_label.text = "%s %.0f szt. za %.2f (%.2f/szt.)." % [
			verb, result["amount"], result["total"], result["unit_price"]
		]
		traded.emit()
	else:
		feedback_label.text = _describe_failure(result)
	_refresh()


func _describe_failure(result: Dictionary) -> String:
	match result.get("reason", ""):
		"limit_exceeded":
			return "Przekroczono limit tej rundy (%d szt.)." % result.get("limit", 0)
		"cannot_afford":
			return "Za mało pieniędzy (potrzeba %.2f)." % result.get("cost", 0.0)
		"insufficient_stock":
			return "Za mało tego surowca do sprzedania."
		_:
			return "Nie udało się zrealizować transakcji."
