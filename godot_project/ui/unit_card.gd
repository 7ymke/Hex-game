class_name UnitCard
extends PanelContainer
## Floating parchment "Karta ludzika" (Unit Card, UI restyle replacing the
## old RoutePanel) - shows the selected unit's route/MP/annexation controls,
## floating over the map instead of docked in a side panel.
##
## This script only owns what's specific to being a FLOATING, DRAGGABLE
## card: positioning at a fixed bottom-left default spot and resetting there
## every time the card goes from hidden to shown again (a fresh unit
## selection - `show_for_new_selection()`), dragging the whole card by its
## header, and generating the small brass hex icons used by the two
## annexation links + the auto-annex toggle. Which labels/buttons show what
## text, and when, is still entirely decided by game_map_controller.gd
## (`_refresh_route_panel()`), exactly like the old RoutePanel - this script
## never reads game state.

const MARGIN = 14.0
const LINK_ICON_SIZE = Vector2i(9, 8)
const PIP_SIZE = Vector2(15, 13)
const PIP_OFF_COLOR = Color(Palette.PARCHMENT_INK.r, Palette.PARCHMENT_INK.g, Palette.PARCHMENT_INK.b, 0.15)

@onready var _head: Control = $VBox/Head
@onready var pips_row: HBoxContainer = $VBox/PipsRow
@onready var annex_button: Button = $VBox/Links/AnnexButton
@onready var takeover_button: Button = $VBox/Links/TakeoverButton
@onready var auto_annex_toggle: Button = $VBox/Links/AutoAnnexToggle

var _dragging = false
var _drag_offset = Vector2.ZERO
var _shown_before = false


func _ready() -> void:
	visible = false
	_head.gui_input.connect(_on_head_gui_input)

	var icon_on = HexShape.make_texture(LINK_ICON_SIZE, Palette.BRASS)
	var icon_off = HexShape.make_texture(LINK_ICON_SIZE, Palette.RULE_DIM)
	annex_button.icon = icon_on
	takeover_button.icon = icon_on
	auto_annex_toggle.icon = icon_off
	auto_annex_toggle.toggled.connect(func(pressed): auto_annex_toggle.icon = icon_on if pressed else icon_off)


## Rebuilds the MP pips row (one hex per point of `max_points`, the first
## `current` of them filled) - a pure rendering helper, game_map_controller.gd
## just passes in the unit's current/max movement points on every refresh.
func set_pips(current: int, max_points: int) -> void:
	for child in pips_row.get_children():
		child.queue_free()
	for i in range(max_points):
		var pip = HexShape.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.fill_color = Palette.COPPER if i < current else PIP_OFF_COLOR
		pips_row.add_child(pip)


## Shows the card, resetting it to the default bottom-left spot ONLY if it
## was hidden before this call - a drag while the card is already up (e.g.
## re-selecting the same unit after moving it) must never snap back.
func show_for_new_selection() -> void:
	if not _shown_before:
		_reset_position()
	_shown_before = true
	visible = true


func hide_card() -> void:
	_shown_before = false
	visible = false


func _reset_position() -> void:
	var viewport_size = get_viewport_rect().size
	var content_height = get_combined_minimum_size().y
	position = Vector2(MARGIN, viewport_size.y - content_height - MARGIN)


func _on_head_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
