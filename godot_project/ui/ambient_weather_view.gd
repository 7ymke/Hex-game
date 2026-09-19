class_name AmbientWeatherView
extends Control
## Ambientowa pogoda (nowość: "delikatny efekt wizualny na mapie (ogień,
## śnieg) odpowiadający ostatniemu wydarzeniu losowemu albo aktualnemu
## sezonowi z Sezonowej szaty mapy — czysto atmosferyczne dopełnienie").
##
## Ręcznie rysowane cząsteczki (ten sam wzorzec co reszta niestandardowego
## rysowania w tym projekcie - hex_shape.gd/hex_map_view.gd/
## skill_graph_view.gd/price_chart_view.gd - żaden z nich nie używa
## wbudowanego CPUParticles2D/GPUParticles2D silnika, więc ten plik też
## nie) - `_process()` porusza każdą cząsteczkę i zawija ją na drugą stronę
## ekranu, gdy wyjdzie poza widoczny obszar, `_draw()` rysuje bieżące
## pozycje jako małe koła. Screen-space (zwykły `Control`, nie coś
## parentowane pod kamerą mapy) - gęstość efektu jest więc stała
## niezależnie od aktualnego przybliżenia/przesunięcia widoku.
##
## Priorytet trybu (`_pick_mode()`, wołane z `refresh()` - NIE co klatkę,
## tylko przy tych samych zdarzeniach, przy których faktycznie może się
## zmienić: koniec rundy i zmiana aktywnego gracza (game_map_controller.gd)
## - żeby nie przeszukiwać wszystkich heksów pod kątem ognia 60 razy na
## sekundę bez potrzeby):
## 1. Którykolwiek heks płonie (`HexData.is_on_fire`, prawdziwy stan gry,
##    trwały dopóki pożar faktycznie płonie - dokładniejszy, bardziej
##    aktualny sygnał niż "ostatnie wydarzenie losowe było pożarem", bo
##    pożar może trwać przez wiele rund po samym wylosowaniu wydarzenia)
##    -> żar/dym unoszący się w górę (EMBER).
## 2. W przeciwnym razie: zima (ta sama pora roku co "Sezonowa szata mapy",
##    `TurnManager.get_current_season()`) -> opadający śnieg (SNOW).
## 3. W przeciwnym razie: brak efektu (NONE) - reszta pór roku nie ma
##    swojego odpowiednika w życzeniu ("ogień, śnieg" to jedyne dwa podane
##    przykłady), więc celowo nie wymyśla się trzeciego/czwartego efektu.

const PARTICLE_COUNT = 40

enum Mode { NONE, SNOW, EMBER }

var _mode: Mode = Mode.NONE
var _positions: PackedVector2Array = []
var _velocities: PackedVector2Array = []
var _radii: PackedFloat32Array = []
var _alphas: PackedFloat32Array = []


func _ready() -> void:
	_positions.resize(PARTICLE_COUNT)
	_velocities.resize(PARTICLE_COUNT)
	_radii.resize(PARTICLE_COUNT)
	_alphas.resize(PARTICLE_COUNT)
	refresh()


## Wołane z game_map_controller.gd przy końcu rundy i przy zmianie
## aktywnego gracza - jedyne momenty, w których pożar/pora roku faktycznie
## mogą się zmienić. Nie robi nic (nie resetuje cząsteczek), jeśli tryb
## wychodzi taki sam jak poprzednio, żeby ustalona pogoda nie "skakała" po
## ekranie przy każdym odświeżeniu.
func refresh() -> void:
	var new_mode = _pick_mode()
	if new_mode == _mode:
		return
	_mode = new_mode
	_reset_particles()
	# Bez tego: gdy tryb zmienia się na NONE, _process() od razu wraca (patrz
	# niżej) i nigdy więcej nie woła queue_redraw() - ostatnia narysowana
	# klatka (z cząsteczkami) zostawałaby na ekranie NA STAŁE, bo nic by już
	# nie powiedziało silnikowi, żeby przerysować (i tym samym wyczyścić)
	# tę warstwę. Jedno jawne wywołanie tutaj gwarantuje, że _draw() odpali
	# się jeszcze raz zaraz po zmianie trybu, niezależnie od tego, czy
	# _process() w ogóle je zawoła.
	queue_redraw()


func _pick_mode() -> Mode:
	for hex: HexData in MapData.hexes.values():
		if hex.is_on_fire:
			return Mode.EMBER
	if TurnManager.get_current_season() == GameBalance.Season.WINTER:
		return Mode.SNOW
	return Mode.NONE


func _reset_particles() -> void:
	var viewport_size = get_viewport_rect().size
	for i in range(PARTICLE_COUNT):
		_positions[i] = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		_radii[i] = randf_range(1.5, 3.5)
		_alphas[i] = randf_range(0.3, 0.75)
		if _mode == Mode.SNOW:
			_velocities[i] = Vector2(randf_range(-8.0, 8.0), randf_range(20.0, 45.0))
		elif _mode == Mode.EMBER:
			_velocities[i] = Vector2(randf_range(-6.0, 6.0), randf_range(-35.0, -15.0))
		else:
			_velocities[i] = Vector2.ZERO


func _process(delta: float) -> void:
	if _mode == Mode.NONE:
		return
	var viewport_size = get_viewport_rect().size
	for i in range(PARTICLE_COUNT):
		_positions[i] += _velocities[i] * delta
		_wrap_particle(i, viewport_size)
	queue_redraw()


## Zawija cząsteczkę na przeciwną krawędź ekranu, gdy wyjdzie poza widoczny
## obszar - w pionie tylko w kierunku, w którym ten tryb faktycznie się
## porusza (śnieg opada -> zawija u dołu, żar unosi się -> zawija u góry).
func _wrap_particle(i: int, viewport_size: Vector2) -> void:
	var pos = _positions[i]
	if pos.x < 0.0:
		pos.x = viewport_size.x
	elif pos.x > viewport_size.x:
		pos.x = 0.0
	if _mode == Mode.SNOW and pos.y > viewport_size.y:
		pos.y = 0.0
	elif _mode == Mode.EMBER and pos.y < 0.0:
		pos.y = viewport_size.y
	_positions[i] = pos


func _draw() -> void:
	if _mode == Mode.NONE:
		return
	var base_color = Color.WHITE if _mode == Mode.SNOW else Palette.GOLD
	for i in range(PARTICLE_COUNT):
		draw_circle(_positions[i], _radii[i], Color(base_color.r, base_color.g, base_color.b, _alphas[i]))
