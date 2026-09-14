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

const CIRCLE_RADIUS = 14.0
const SELECTION_RING_MARGIN = 6.0

@export var player_id: int = -1
@export var color: Color = Color(0.9, 0.2, 0.2)

## Opcjonalny obrazek pionka - ustaw w edytorze (Inspector -> Sprite Texture)
## albo z kodu (`ludzik.sprite_texture = load("res://...png")`, patrz też
## klucz "sprite" w PLAYER_SETUP w game_map_controller.gd). Bez ustawionego
## obrazka rysowane jest domyślne kółko w kolorze `color` (jak dotąd).
@export var sprite_texture: Texture2D = null

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

## Zatwierdzona trasa (wielorundowa) czekająca na wykonanie - kolejne heksy
## DO ODWIEDZENIA, bez heksa startowego (ten to już `current_hex_id`).
## Ustawiana przez game_map_controller.gd po potwierdzeniu podglądu trasy w
## nowym panelu "Trasa ludzika"; opróżniana krok po kroku w miarę ruchu
## (`_advance_queued_route`), także automatycznie na starcie każdej kolejnej
## rundy, jeśli w tej nie starczyło punktów ruchu na całą trasę - stąd "będzie
## mógł iść przez parę rund". Puste = brak zaplanowanej/trwającej trasy.
var queued_route: Array[String] = []

## Przełącznik "Anektuj napotkane pola" (panel "Trasa ludzika") - gdy true,
## game_map_controller._advance_queued_route() automatycznie aneksuje KAŻDY
## niczyj heks, na który ten ludzik wejdzie podczas wykonywania trasy, bez
## potrzeby ręcznego klikania "Zaanektuj" po każdym kroku. Per-ludzik (nie
## per-gracz), bo różni ludzicy tego samego gracza mogą mieć różne role
## (jeden eksploruje/aneksuje automatycznie, drugi jedzie celowo gdzie indziej).
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
			GameBalance.LUDZIK_SELECTED_HIGHLIGHT_COLOR, GameBalance.LUDZIK_SELECTED_HIGHLIGHT_WIDTH
		)


## Rysuje `sprite_texture` wyśrodkowany na ludziku, przeskalowany do
## GameBalance.LUDZIK_SPRITE_DIAMETER (niezależnie od oryginalnego rozmiaru
## pliku obrazka). Zwraca efektywny promień - do dopasowania pierścienia
## zaznaczenia, żeby ładnie otaczał obrazek, nie tylko domyślne kółko.
func _draw_sprite() -> float:
	var tex_size = sprite_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return CIRCLE_RADIUS

	var diameter = GameBalance.LUDZIK_SPRITE_DIAMETER
	var scale_factor = diameter / max(tex_size.x, tex_size.y)
	var draw_size = tex_size * scale_factor
	draw_texture_rect(sprite_texture, Rect2(-draw_size / 2.0, draw_size), false)
	return draw_size.length() / 2.0


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
