class_name UnitCard
extends Control
## Floating tan/parchment "Karta ludzika" (Unit Card) - shows the selected
## unit's route/MP/annexation controls, floating over the map.
##
## Root is a plain Control, NOT a PanelContainer - a Container forces ALL
## of its direct children to fill the exact same content rect (that's how
## a single-child PanelContainer normally works), which would fight the
## close button's fixed position in the card's absolute top-right corner
## (UI_Gry_Makieta_11.html: `.cancel-x { position: absolute; top: 8px;
## right: 8px }`, relative to the whole card, not the header). A plain
## Control lets `background` (the actual PanelContainer, full-rect) and
## `close_button` (free-positioned via its own anchors) coexist as
## independent siblings.
##
## This script only owns what's specific to being a FLOATING, DRAGGABLE
## card: positioning at a fixed bottom-left default spot and resetting
## there every time the card goes from hidden to shown again (a fresh unit
## selection - see `show_for_new_selection()`), dragging the whole card by
## its header, and generating the small gold hex icons used by the
## annexation links. Which labels/buttons show what text, and when, is
## still entirely decided by game_map_controller.gd
## (`_refresh_route_panel()`) - this script never reads game state.
##
## The close button (X) now CLOSES the card outright - it no longer
## cancels a confirmed route (a meaning change from the previous UI
## iteration, per the restyle spec: "X zamyka kartę, nie anuluje trasę").
## Closing the card deselects the unit (game_map_controller.gd), which
## already clears any unconfirmed route PREVIEW as an existing side effect
## of `_set_selected_unit(null)` - so the X naturally covers "cancel an
## unconfirmed preview" too, without a separate mechanism. Canceling a
## CONFIRMED, in-progress route is a different action, preserved as its
## own conditional link on the card (`cancel_route_link`) - the spec
## doesn't mention this case explicitly, but silently removing a working
## "get unstuck" affordance seemed like an oversight rather than an
## intentional cut, so it's kept (documented in the README).

signal closed

const MARGIN = 14.0
const CARD_WIDTH = 254.0
const LINK_ICON_SIZE = Vector2i(9, 8)
const PIP_SIZE = Vector2(16, 14)

@onready var background: PanelContainer = $Background
@onready var close_button: Button = $CloseButton
@onready var _head: Control = $Background/VBox/Head
@onready var pips_row: HBoxContainer = $Background/VBox/PipsRow
@onready var annex_button: Button = $Background/VBox/Links/AnnexButton
@onready var takeover_button: Button = $Background/VBox/Links/TakeoverButton
@onready var auto_annex_toggle: Button = $Background/VBox/Links/AutoAnnexToggle
@onready var cancel_route_link: Button = $Background/VBox/Links/CancelRouteLink

var _dragging = false
var _drag_offset = Vector2.ZERO
var _shown_before = false


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_head.gui_input.connect(_on_head_gui_input)
	close_button.pressed.connect(func(): closed.emit())

	var icon_on = HexShape.make_texture(LINK_ICON_SIZE, Palette.GOLD)
	var icon_off = HexShape.make_texture(LINK_ICON_SIZE, Color(Palette.TAN_INK.r, Palette.TAN_INK.g, Palette.TAN_INK.b, 0.3))
	annex_button.icon = icon_on
	takeover_button.icon = icon_on
	cancel_route_link.icon = icon_on
	auto_annex_toggle.icon = icon_off
	auto_annex_toggle.toggled.connect(func(pressed): auto_annex_toggle.icon = icon_on if pressed else icon_off)


## Rebuilds the MP pips row (one hex per point of `max_points`, the first
## `current` of them filled) - a pure rendering helper, game_map_controller.gd
## just passes in the unit's current/max movement points on every refresh.
## No separate numeric "5/5" anywhere on the card anymore (restyle spec
## 4.3) - the pips are the only MP indicator.
func set_pips(current: int, max_points: int) -> void:
	for child in pips_row.get_children():
		child.queue_free()
	for i in range(max_points):
		var pip = HexShape.new()
		pip.custom_minimum_size = PIP_SIZE
		var on = i < current
		pip.fill_color = Palette.GOLD if on else Color(Palette.TAN_INK.r, Palette.TAN_INK.g, Palette.TAN_INK.b, 0.18)
		pip.border_color = Palette.BORDER if on else Color(0, 0, 0, 0)
		pip.border_width = 1.5 if on else 0.0
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
	var content_size = background.get_combined_minimum_size()
	content_size.x = maxf(content_size.x, CARD_WIDTH)
	size = content_size
	var viewport_size = get_viewport_rect().size
	position = Vector2(MARGIN, viewport_size.y - content_size.y - MARGIN)


func _on_head_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
