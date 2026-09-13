class_name Ludzik
extends Node2D
## Wizualny reprezentant gracza na mapie - sekcja 3 GDD.
##
## Punkty ruchu (MP) należą do ludzika, nie do gracza (update po Fazie 6) -
## każdy ludzik ma własną pulę, więc gracz z wieloma ludzikami (przyszły
## upgrade - patrz komentarz przy `selected` niżej) rozdziela ruch między nie
## niezależnie. Resetowane raz na rundę przez game_map_controller.gd w
## reakcji na TurnManager.round_ended.
##
## Sama logika wysokopoziomowa (ścieżka, blokady, koszt akcji) siedzi w
## game_map_controller.gd; ten skrypt odpowiada za wygląd, stan lokalny
## (MP, zaznaczenie, aktualny heks) i płynną animację ruchu.

@export var player_id: int = -1
@export var color: Color = Color(0.9, 0.2, 0.2)
@export var move_speed_px_per_sec: float = GameBalance.LUDZIK_MOVE_SPEED_PX_PER_SEC
@export var movement_points_max: int = GameBalance.LUDZIK_MOVEMENT_POINTS_MAX

var current_hex_id: String = ""
var movement_points_current: int = movement_points_max

## Zaznaczenie (Faza 6+ update - "selectować/deselectować ludzika"). Trzymane
## tu, a nie tylko w game_map_controller.gd, żeby ludzik sam wiedział, że ma
## narysować pierścień zaznaczenia - i żeby dodanie kolejnych ludzików na
## gracza (upgrade "więcej ludzików") nie wymagało osobnej struktury danych
## do śledzenia, który z wielu jest wybrany - to zwykłe query po dzieciach
## gracza (`for l in ludziki_gracza: if l.selected`).
var selected: bool = false

## Ustawiane przez game_map_controller.gd na czas animowanego ruchu, żeby
## zablokować wydawanie nowego rozkazu ruchu w trakcie trwającego.
var is_moving: bool = false


func _ready() -> void:
	movement_points_current = movement_points_max


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, color)
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color.BLACK, 2.0)
	if selected:
		draw_arc(
			Vector2.ZERO, 20.0, 0.0, TAU, 32,
			GameBalance.LUDZIK_SELECTED_HIGHLIGHT_COLOR, GameBalance.LUDZIK_SELECTED_HIGHLIGHT_WIDTH
		)


## Zaznaczenie: lekkie powiększenie + pierścień podświetlenia, oba tweakowalne
## w scripts/game_balance.gd (LUDZIK_SELECTED_SCALE / _HIGHLIGHT_COLOR / _WIDTH).
func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	scale = Vector2.ONE * GameBalance.LUDZIK_SELECTED_SCALE if selected else Vector2.ONE
	queue_redraw()


## Ustawia pozycję ludzika na środku danego heksa (teleport, bez animacji -
## używane tylko do początkowego rozstawienia graczy). Ruch w trakcie gry
## idzie przez `animate_to_hex()`.
func place_on_hex(hex_id: String) -> void:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		push_warning("Ludzik: nie znaleziono heksa %s" % hex_id)
		return
	current_hex_id = hex_id
	position = HexGridUtils.offset_to_pixel(hex.axial_q, hex.axial_r, GameBalance.HEX_SIZE)


## Płynnie animuje przejście na SĄSIEDNI heks (jeden krok trasy) z prędkością
## `move_speed_px_per_sec`. `current_hex_id` aktualizuje się od razu (logika
## gry - blokady, mgła - liczy heks jako "osiągnięty" natychmiast), tylko
## wizualna pozycja dogania go płynnie w tle.
func animate_to_hex(hex_id: String) -> void:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		push_warning("Ludzik: nie znaleziono heksa %s" % hex_id)
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


## Zwraca punkty ruchu (np. po akcji, która się nie powiodła już PO tym, jak
## koszt został pobrany) - nie pozwala przekroczyć puli maksymalnej.
func refund_movement_points(amount: int) -> void:
	movement_points_current = mini(movement_points_max, movement_points_current + amount)
