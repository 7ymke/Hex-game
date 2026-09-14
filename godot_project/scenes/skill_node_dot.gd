class_name SkillNodeDot
extends Control
## Pojedynczy węzeł drzewka umiejętności - na razie zwykła kropka, celowo
## łatwa do podmiany na obrazek w przyszłości: ustaw `sprite_texture` (ten
## sam wzorzec co `Ludzik.sprite_texture` w ludzik.gd) - bez ustawionego
## obrazka rysowane jest domyślne kółko w kolorze zależnym od stanu
## (zablokowany / stać cię na niego / odblokowany).
##
## Sam nie zna szczegółów UI (okienko itd.) - tylko rysuje się i przekazuje
## hover/klik do SkillTreePanel przez sygnały, które decydują, co z tym zrobić.

signal dot_hovered(skill: SkillData)
signal dot_unhovered(skill: SkillData)
signal dot_clicked(skill: SkillData)

const DOT_RADIUS = 22.0
const COLOR_LOCKED = Color(0.35, 0.4, 0.5, 1)
const COLOR_AFFORDABLE = Color(0.3, 0.6, 0.9, 1)
const COLOR_UNLOCKED = Color(0.3, 0.75, 0.35, 1)
const OUTLINE_COLOR = Color(0.9, 0.95, 1.0, 0.9)
const OUTLINE_WIDTH = 2.0

## Opcjonalny obrazek węzła - ustaw z kodu (`dot.sprite_texture = load("res://...png")`).
## Bez tego rysowane jest domyślne kółko (patrz _draw()).
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
			var scale_factor = (DOT_RADIUS * 2.0) / max(tex_size.x, tex_size.y)
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
