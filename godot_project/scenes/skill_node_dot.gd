class_name SkillNodeDot
extends Control
## A single skill tree node - currently just a plain dot, deliberately easy
## to swap for an image in the future: set `sprite_texture` (the same
## pattern as `Unit.sprite_texture` in unit.gd) - without an image set, a
## default circle is drawn, colored by state (locked / affordable / unlocked).
##
## Doesn't know any UI details itself (the popup, etc.) - it just draws
## itself and forwards hover/click to SkillTreePanel via signals, which
## decide what to do with them.

signal dot_hovered(skill: SkillData)
signal dot_unhovered(skill: SkillData)
signal dot_clicked(skill: SkillData)

const DOT_RADIUS = 22.0
const COLOR_LOCKED = Color(0.35, 0.4, 0.5, 1)
const COLOR_AFFORDABLE = Color(0.3, 0.6, 0.9, 1)
const COLOR_UNLOCKED = Color(0.3, 0.75, 0.35, 1)
const OUTLINE_COLOR = Color(0.9, 0.95, 1.0, 0.9)
const OUTLINE_WIDTH = 2.0

## Optional node image - set from code (`dot.sprite_texture = load("res://...png")`).
## Without it, a default circle is drawn (see _draw()).
@export var sprite_texture: Texture2D = null

var skill: SkillData = null
var unlocked: bool = false
var affordable: bool = false


func _ready() -> void:
	mouse_entered.connect(func(): dot_hovered.emit(skill))
	mouse_exited.connect(func(): dot_unhovered.emit(skill))


func _draw() -> void:
	var center = size / 2.0

	if sprite_texture != null:
		var tex_size = sprite_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var scale_factor = (DOT_RADIUS * 2.0) / maxf(tex_size.x, tex_size.y)
			var draw_size = tex_size * scale_factor
			draw_texture_rect(sprite_texture, Rect2(center - draw_size / 2.0, draw_size), false)
	else:
		var color = COLOR_UNLOCKED if unlocked else (COLOR_AFFORDABLE if affordable else COLOR_LOCKED)
		draw_circle(center, DOT_RADIUS, color)

	draw_arc(center, DOT_RADIUS, 0.0, TAU, 32, OUTLINE_COLOR, OUTLINE_WIDTH)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dot_clicked.emit(skill)
		accept_event()
