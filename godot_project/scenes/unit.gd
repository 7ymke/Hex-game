class_name Unit
extends Node2D
## Visual representation of a player on the map - GDD section 3.
##
## Movement points (MP) belong to the unit, not the player (update after
## Phase 6) - each unit has its own pool, so a player with multiple units
## (a future upgrade - see the comment next to `selected` below) splits
## movement between them independently. Reset once per round by
## game_map_controller.gd in reaction to TurnManager.round_ended.
##
## The high-level logic itself (pathing, blocking, action costs) lives in
## game_map_controller.gd; this script is responsible for appearance, local
## state (MP, selection, current hex), and smooth movement animation.

const CIRCLE_RADIUS = 14.0
const SELECTION_RING_MARGIN = 6.0

@export var player_id: int = -1
@export var color: Color = Color(0.9, 0.2, 0.2)

## Optional token image - set in the editor (Inspector -> Sprite Texture) or
## from code (`unit.sprite_texture = load("res://...png")`, see also the
## "sprite" key in PLAYER_SETUP in game_map_controller.gd). Without an image
## set, the default circle is drawn in `color` (as before).
@export var sprite_texture: Texture2D = null

@export var move_speed_px_per_sec: float = GameBalance.UNIT_MOVE_SPEED_PX_PER_SEC
@export var movement_points_max: int = GameBalance.UNIT_MOVEMENT_POINTS_MAX

var current_hex_id: String = ""
var movement_points_current: int = movement_points_max

## Selection (Phase 6+ update - "select/deselect a unit"). Kept here, not
## only in game_map_controller.gd, so the unit itself knows to draw the
## selection ring - and so that adding more units per player (the "more
## units" upgrade) doesn't require a separate data structure to track which
## of several is selected - it's just a plain query over the player's
## children (`for u in player_units: if u.selected`).
var selected: bool = false

## Set by game_map_controller.gd while the movement animation is playing, to
## block issuing a new move order while one is already in progress.
var is_moving: bool = false

## Confirmed (possibly multi-round) route waiting to be executed - the next
## hexes TO VISIT, excluding the starting hex (that one is already
## `current_hex_id`). Set by game_map_controller.gd once the route preview
## is confirmed in the "Trasa ludzika" (unit route) panel; drained step by
## step as the unit moves (`_advance_queued_route`), also automatically at
## the start of each following round if there weren't enough movement points
## to finish the whole route this round - hence a route "may take several
## rounds". Empty = no planned/in-progress route.
var queued_route: Array[String] = []

## The true destination hex of the confirmed route - as opposed to
## `queued_route`, which may end EARLIER (at the nearest reachable hex) if
## the destination is currently occupied by an enemy unit. When
## `queued_route` drains empty while `route_destination` is still set and
## different from `current_hex_id`, the unit WAITS in place -
## game_map_controller.gd tries to recompute the route at the end of every
## round (`_recompute_route`), so as soon as the destination frees up (or
## another path appears), the unit moves on automatically. Empty = no route
## destination (or the route is fully complete).
var route_destination: String = ""

## The "Anektuj napotkane pola" (annex hexes along the way) toggle (in the
## unit route panel) - when true, game_map_controller._advance_queued_route()
## automatically annexes EVERY unclaimed hex this unit enters while
## executing a route, without needing to manually click "Zaanektuj" after
## each step. Per-unit (not per-player), because different units of the same
## player may have different roles (one explores/auto-annexes, another
## heads somewhere specific on purpose).
var auto_annex: bool = false


func _ready() -> void:
	movement_points_current = movement_points_max


func _draw() -> void:
	var visual_radius = CIRCLE_RADIUS
	if sprite_texture != null:
		visual_radius = _draw_sprite()
	else:
		draw_circle(Vector2.ZERO, CIRCLE_RADIUS, color)
		draw_arc(Vector2.ZERO, CIRCLE_RADIUS, 0.0, TAU, 32, Color.BLACK, 2.0)

	if selected:
		draw_arc(
			Vector2.ZERO, visual_radius + SELECTION_RING_MARGIN, 0.0, TAU, 32,
			GameBalance.UNIT_SELECTED_HIGHLIGHT_COLOR, GameBalance.UNIT_SELECTED_HIGHLIGHT_WIDTH
		)


## Draws `sprite_texture` centered on the unit, scaled to
## GameBalance.UNIT_SPRITE_DIAMETER (regardless of the original image file's
## size). Returns the effective radius - used to fit the selection ring so
## it nicely surrounds the image, not just the default circle.
func _draw_sprite() -> float:
	var tex_size = sprite_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return CIRCLE_RADIUS

	var diameter = GameBalance.UNIT_SPRITE_DIAMETER
	var scale_factor = diameter / maxf(tex_size.x, tex_size.y)
	var draw_size = tex_size * scale_factor
	draw_texture_rect(sprite_texture, Rect2(-draw_size / 2.0, draw_size), false)
	return draw_size.length() / 2.0


## Selection: a slight scale-up + a highlight ring, both tweakable in
## scripts/game_balance.gd (UNIT_SELECTED_SCALE / _HIGHLIGHT_COLOR / _WIDTH).
func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	scale = Vector2.ONE * GameBalance.UNIT_SELECTED_SCALE if selected else Vector2.ONE
	queue_redraw()


## Sets the unit's position to the center of the given hex (a teleport,
## without animation - used only for the initial placement of players).
## In-game movement goes through `animate_to_hex()` instead.
func place_on_hex(hex_id: String) -> void:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		push_warning("Unit: hex %s not found" % hex_id)
		return
	current_hex_id = hex_id
	position = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE)


## Smoothly animates a transition to a NEIGHBORING hex (one route step) at
## `move_speed_px_per_sec`. `current_hex_id` updates right away (game logic -
## blocking, fog - treats the hex as "reached" immediately), only the visual
## position catches up smoothly in the background.
func animate_to_hex(hex_id: String) -> void:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		push_warning("Unit: hex %s not found" % hex_id)
		return

	var target = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE)
	current_hex_id = hex_id

	if move_speed_px_per_sec <= 0.0:
		position = target
		return

	var distance = position.distance_to(target)
	var duration = distance / move_speed_px_per_sec
	if duration <= 0.0:
		position = target
		return

	var tween = create_tween()
	tween.tween_property(self, "position", target, duration)
	await tween.finished


func reset_movement_points() -> void:
	movement_points_current = movement_points_max


func spend_movement_points(amount: int) -> bool:
	if movement_points_current < amount:
		return false
	movement_points_current -= amount
	return true


## Refunds movement points (e.g. after an action that failed AFTER its cost
## was already deducted) - never lets the pool exceed its maximum.
func refund_movement_points(amount: int) -> void:
	movement_points_current = mini(movement_points_max, movement_points_current + amount)
