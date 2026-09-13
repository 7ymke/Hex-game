class_name Ludzik
extends Node2D
## Wizualny reprezentant gracza na mapie - sekcja 3 GDD.
## Sama logika ruchu/akcji siedzi w GameManager i grid_map_controller.gd;
## ten skrypt tylko rysuje pionek i trzyma, na jakim heksie aktualnie stoi.

const HEX_SIZE := HexPathfinder.HEX_SIZE

@export var player_id: int = -1
@export var color: Color = Color(0.9, 0.2, 0.2)

var current_hex_id: String = ""


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, color)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color.BLACK, 2.0)


## Ustawia pozycję ludzika na środku danego heksa (teleport, bez animacji -
## animacja krok-po-kroku jest odpowiedzialnością kontrolera, sekcja "Faza 4").
func place_on_hex(hex_id: String) -> void:
	var hex := MapData.get_hex(hex_id)
	if hex == null:
		push_warning("Ludzik: nie znaleziono heksa %s" % hex_id)
		return
	current_hex_id = hex_id
	position = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, HEX_SIZE)
