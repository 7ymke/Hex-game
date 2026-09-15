class_name TwoToneTrack
extends Control
## Two-tone (safe/danger) background track behind the harvest HSlider.
## Godot's Slider only exposes a single StyleBox for its whole background,
## with no built-in mid-track color transition - so the visible track is
## actually THIS Control, drawn behind an HSlider whose own background
## stylebox is fully transparent (only its grabber is visible). Matches the
## mockup's `linear-gradient(to right, safe 0%, safe 60%, danger 60%,
## danger 100%)`.

@export var safe_ratio: float = GameBalance.FOREST_SAFE_THRESHOLD_PERCENT / 100.0


func _draw() -> void:
	var split_x = size.x * clampf(safe_ratio, 0.0, 1.0)
	if split_x > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(split_x, size.y)), Palette.SAFE)
	if split_x < size.x:
		draw_rect(Rect2(Vector2(split_x, 0.0), Vector2(size.x - split_x, size.y)), Palette.DANGER)
