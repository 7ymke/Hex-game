class_name SkillGraphView
extends Control
## Rysuje POŁĄCZENIA drzewka umiejętności (węzeł centralny "START" i linie do
## kart) i obsługuje nawigację myszką po grafie - przeciąganie prawym
## przyciskiem (pan) i scroll (zoom), DOKŁADNIE jak kamera mapy
## (camera_controller.gd). W przeciwieństwie do kamery mapy (która łapie
## zdarzenia przez `_unhandled_input`, więc działa na całej scenie), ten
## skrypt używa `_gui_input()` - standardowego sposobu, w jaki Controle w
## Godocie obsługują mysz - dzięki czemu zdarzenie jest pochłonięte TUTAJ i
## nie leci dalej do kamery mapy/klikania heksów pod spodem (patrz też
## InputBlocker w scenes/main.tscn, który domyka pozostałą część ekranu).
##
## Karty umiejętności żyją w `content_node` (osobny Control - dziecko tego
## samego `GraphArea`, ale z `mouse_filter = IGNORE`, żeby kliknięcia na
## PUSTYM tle przechodziły do tego skryptu - leżącego POD nim - a kliknięcia
## na samych kartach zostawały na kartach). Pan/zoom przesuwa i skaluje CAŁY
## `content_node` naraz (jego `position`/`scale`) - linie (rysowane tu przez
## `draw_set_transform` z tymi samymi wartościami) i karty (prawdziwe węzły
## Control) zawsze się dzięki temu zgadzają.

const HUB_RADIUS = 26.0
const HUB_COLOR = Color(0.3, 0.5, 0.85, 0.95)
const HUB_OUTLINE_COLOR = Color(0.85, 0.9, 1.0, 0.9)
const LINE_COLOR = Color(0.45, 0.6, 0.85, 0.6)
const LINE_WIDTH = 3.0

const ZOOM_STEP = 0.1
const MIN_ZOOM = 0.5
const MAX_ZOOM = 2.0

## Środki kart i węzła centralnego, w LOKALNYCH (nieprzeskalowanych)
## współrzędnych `content_node` - ustawiane przez SkillTreePanel._refresh()
## po rozmieszczeniu kart, zaraz przed queue_redraw().
var node_centers: Array[Vector2] = []
var hub_center: Vector2 = Vector2.ZERO

## Kontener na karty, którym ten skrypt steruje (position = pan, scale =
## zoom) - przypisywany przez SkillTreePanel zaraz po utworzeniu węzłów.
var content_node: Control = null

var _dragging = false
var _drag_start_mouse = Vector2.ZERO
var _drag_start_content_pos = Vector2.ZERO


func _draw() -> void:
	if content_node != null:
		draw_set_transform(content_node.position, 0.0, content_node.scale)

	for p in node_centers:
		draw_line(hub_center, p, LINE_COLOR, LINE_WIDTH)

	draw_circle(hub_center, HUB_RADIUS, HUB_COLOR)
	draw_arc(hub_center, HUB_RADIUS, 0.0, TAU, 32, HUB_OUTLINE_COLOR, 2.5)
	draw_string(
		ThemeDB.fallback_font, hub_center + Vector2(-20, 5), "START",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE
	)


## Resetuje pan/zoom do stanu początkowego - wołane przez SkillTreePanel przy
## każdym otwarciu ekranu, żeby zawsze startować z tym samym, przewidywalnym
## widokiem (środek grafu na środku obszaru, bez przybliżenia).
func reset_view() -> void:
	if content_node == null:
		return
	content_node.position = Vector2.ZERO
	content_node.scale = Vector2.ONE
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if content_node == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			_drag_start_mouse = event.position
			_drag_start_content_pos = content_node.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(-ZOOM_STEP)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		content_node.position = _drag_start_content_pos + (event.position - _drag_start_mouse)
		queue_redraw()
		accept_event()


## Zoom trzyma `hub_center` wizualnie w tym samym miejscu na ekranie (tak jak
## zoom kamery mapy trzyma środek widoku w miejscu) - stąd korekta pozycji
## obok samej zmiany skali.
func _zoom(amount: float) -> void:
	var old_scale = content_node.scale.x
	var new_scale = clampf(old_scale + amount, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_scale, old_scale):
		return
	content_node.position += hub_center * (old_scale - new_scale)
	content_node.scale = Vector2(new_scale, new_scale)
	queue_redraw()
