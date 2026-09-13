extends Camera2D
## Prosta kamera 2D: przeciąganie prawym przyciskiem myszy, zoom scrollem.
## Potrzebna do eksploracji mapy Polski (Faza 2 planu implementacji).

const ZOOM_STEP := 0.1
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_cam := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			_drag_start_mouse = event.position
			_drag_start_cam = position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = (event.position - _drag_start_mouse) / zoom.x
		position = _drag_start_cam - delta


func _zoom(amount: float) -> void:
	var new_zoom: float = clampf(zoom.x + amount, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(new_zoom, new_zoom)
