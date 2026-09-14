class_name SkillTreePanel
extends CanvasLayer
## Drzewko umiejętności - osobny ekran UI, WSPÓLNY dla wszystkich graczy/miast
## (w przeciwieństwie do Karty Miasta). Zaprojektowany jako radialny graf:
## centralny węzeł "START" i węzły umiejętności (na razie kropki -
## scenes/skill_node_dot.gd, łatwe do podmiany na obrazki w przyszłości)
## rozstawione promieniście wokół niego, połączone liniami
## (skill_graph_view.gd) - wygląda jak drzewko/graf, mimo że logicznie
## skille są na razie płaskie (bez prerequisitów/zależności między sobą -
## patrz scripts/skill_tree_data.gd; dodanie prawdziwych zależności w
## przyszłości to tylko rozszerzenie SkillData o listę wymaganych skill_id i
## odpowiednie sprawdzenie tutaj, układ graficzny już na to pozwala).
##
## Węzły są pozycjonowane RĘCZNIE (Control.position), nie w kontenerze typu
## VBoxContainer, i żyją w `graph_content` (a nie bezpośrednio w
## `graph_area`) - to `graph_content`, którego position/scale steruje
## skill_graph_view.gd, robi pan/zoom całego grafu naraz (patrz tam).
##
## Szczegóły (nazwa, opis, koszt, przycisk odblokowania) pokazują się w
## JEDNYM współdzielonym "okienku" (`skill_popup`, pozycjonowanym obok
## aktualnego węzła), nie w samych węzłach - stąd węzły mogą być tak małe
## jak kropki. Dwa niezależne wyzwalacze:
## - **Hover** (`mouse_entered`/`mouse_exited` na węźle) pokazuje okienko
##   TYMCZASOWO - znika, gdy mysz zjedzie i z węzła, i z samego okienka
##   (`_popup_hovered`), z jednoklatkowym opóźnieniem (`_schedule_hide_check`),
##   żeby przejście myszką z węzła NA okienko (żeby np. kliknąć przycisk) nie
##   powodowało migotania.
## - **Klik** na węzeł PRZYPINA okienko (`_pinned = true`) - zostaje widoczne
##   niezależnie od dalszego hovera, dopóki gracz nie kliknie w INNY węzeł
##   (który przejmuje przypięcie) - zgodnie z życzeniem: "znika dopiero jak
##   kliknę w inną [kropkę]".

signal closed
signal skill_unlocked(skill: SkillData)

const DOT_SIZE = Vector2(44, 44)
## Promień rozstawienia węzłów - część bezpiecznej przestrzeni, jaka zostaje
## po odjęciu połowy rozmiaru węzła z każdej strony (żeby węzły nie
## wystawały poza `graph_area` i się nie nakładały) - patrz wyliczenie w
## _refresh().
const RADIUS_SAFETY_MARGIN = 0.85
## Przesunięcie okienka względem środka węzła, którego dotyczy - lekko
## zachodzi na węzeł (nie zostawia "martwej strefy" między nimi), żeby
## przejście myszką z węzła na okienko nie traciło hovera.
const POPUP_OFFSET = Vector2(18, -12)
const POPUP_SIZE_ESTIMATE = Vector2(260, 160)

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var graph_area: Control = $Panel/VBox/GraphArea
@onready var graph_view: SkillGraphView = $Panel/VBox/GraphArea/SkillGraphView
@onready var graph_content: Control = $Panel/VBox/GraphArea/GraphContent
@onready var skill_popup: PanelContainer = $Panel/VBox/GraphArea/SkillPopup
@onready var popup_name_label: Label = $Panel/VBox/GraphArea/SkillPopup/VBox/PopupNameLabel
@onready var popup_info_label: Label = $Panel/VBox/GraphArea/SkillPopup/VBox/PopupInfoLabel
@onready var popup_unlock_button: Button = $Panel/VBox/GraphArea/SkillPopup/VBox/PopupUnlockButton
@onready var close_button: Button = $Panel/VBox/CloseButton

var _current_player: PlayerData
var _dots: Dictionary = {}  # skill_id(String) -> SkillNodeDot

var _shown_skill: SkillData = null
var _pinned: bool = false
var _hovered_skill: SkillData = null
var _popup_hovered: bool = false


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	graph_view.content_node = graph_content
	skill_popup.visible = false
	skill_popup.mouse_entered.connect(_on_popup_mouse_entered)
	skill_popup.mouse_exited.connect(_on_popup_mouse_exited)
	popup_unlock_button.pressed.connect(_on_popup_unlock_pressed)


func open_for_player(player: PlayerData) -> void:
	_current_player = player
	_pinned = false
	_hovered_skill = null
	_popup_hovered = false
	_shown_skill = null
	skill_popup.visible = false
	visible = true
	graph_view.reset_view()
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in graph_content.get_children():
		child.queue_free()
	_dots.clear()

	if _current_player == null:
		graph_view.node_centers = []
		graph_view.queue_redraw()
		return

	title_label.text = "Drzewko Umiejętności: %s" % _current_player.player_name

	var skills = SkillTreeData.get_skills()
	var area_size: Vector2 = graph_area.custom_minimum_size
	var center = area_size / 2.0
	# Promień, przy którym węzeł o rozmiarze DOT_SIZE wyśrodkowany na okręgu
	# wciąż w całości mieści się w `graph_area` (z zapasem RADIUS_SAFETY_MARGIN,
	# żeby sąsiednie węzły się nie stykały).
	var radius = minf(area_size.x - DOT_SIZE.x, area_size.y - DOT_SIZE.y) / 2.0 * RADIUS_SAFETY_MARGIN
	var count = skills.size()

	var centers: Array[Vector2] = []
	for i in range(count):
		var angle = TAU * i / count - PI / 2.0
		var dot_center = center + Vector2(cos(angle), sin(angle)) * radius
		centers.append(dot_center)

		var dot = _build_dot(skills[i])
		dot.position = dot_center - DOT_SIZE / 2.0
		graph_content.add_child(dot)
		_dots[skills[i].skill_id] = dot

	graph_view.hub_center = center
	graph_view.node_centers = centers
	graph_view.queue_redraw()

	# Jeśli okienko było otwarte (przypięte albo najechane) przed odświeżeniem
	# (np. zaraz po odblokowaniu skilla), pokaż je jeszcze raz dla tego samego
	# skilla, z nowym węzłem i zaktualizowanym stanem - żeby nie znikało tylko
	# dlatego, że _refresh() przebudował węzły od zera.
	if _shown_skill != null:
		_show_popup_for(_shown_skill)


func _build_dot(skill: SkillData) -> SkillNodeDot:
	var dot = SkillNodeDot.new()
	dot.custom_minimum_size = DOT_SIZE
	dot.size = DOT_SIZE
	dot.skill = skill
	dot.unlocked = _current_player.unlocked_skills.has(skill.skill_id)
	dot.affordable = _current_player.can_afford(skill.required_resources)
	dot.dot_hovered.connect(_on_dot_hovered)
	dot.dot_unhovered.connect(_on_dot_unhovered)
	dot.dot_clicked.connect(_on_dot_clicked)
	return dot


func _on_dot_hovered(skill: SkillData) -> void:
	_hovered_skill = skill
	if not _pinned:
		_show_popup_for(skill)


func _on_dot_unhovered(skill: SkillData) -> void:
	if _hovered_skill == skill:
		_hovered_skill = null
	_schedule_hide_check()


func _on_popup_mouse_entered() -> void:
	_popup_hovered = true


func _on_popup_mouse_exited() -> void:
	_popup_hovered = false
	_schedule_hide_check()


## Opóźnione o jedną klatkę sprawdzenie, czy okienko powinno zniknąć - mysz
## przechodząca z węzła NA okienko (np. żeby kliknąć przycisk) generuje
## `mouse_exited` węzła i `mouse_entered` okienka jako osobne zdarzenia; bez
## tego opóźnienia okienko potrafiłoby zniknąć na ułamek sekundy między nimi.
func _schedule_hide_check() -> void:
	await get_tree().process_frame
	if not _pinned and _hovered_skill == null and not _popup_hovered:
		_hide_popup()


func _on_dot_clicked(skill: SkillData) -> void:
	_pinned = true
	_show_popup_for(skill)


func _show_popup_for(skill: SkillData) -> void:
	var dot: SkillNodeDot = _dots.get(skill.skill_id)
	if dot == null:
		return

	_shown_skill = skill
	popup_name_label.text = skill.skill_name
	popup_info_label.text = "%s\nKoszt: %s" % [skill.description, _format_costs(skill.required_resources)]

	var unlocked = _current_player.unlocked_skills.has(skill.skill_id)
	if unlocked:
		popup_unlock_button.text = "Odblokowano"
		popup_unlock_button.disabled = true
	else:
		popup_unlock_button.text = "Odblokuj"
		popup_unlock_button.disabled = not _current_player.can_afford(skill.required_resources)

	_position_popup_near(dot)
	skill_popup.visible = true


func _hide_popup() -> void:
	_shown_skill = null
	skill_popup.visible = false


## Ustawia okienko obok środka danego węzła, w lokalnych współrzędnych
## `graph_area` - `dot.get_global_rect()` już uwzględnia bieżący pan/zoom
## grafu (position/scale `graph_content`), więc nie trzeba tej transformacji
## liczyć ręcznie. Przycięte do granic `graph_area`, żeby okienko nigdy nie
## wystawało poza (i nie ginęło) pod `clip_contents`.
func _position_popup_near(dot: SkillNodeDot) -> void:
	var dot_center_global = dot.get_global_rect().get_center()
	var local_point = graph_area.to_local(dot_center_global)
	var area_size: Vector2 = graph_area.custom_minimum_size

	var popup_pos = local_point + POPUP_OFFSET
	popup_pos.x = clampf(popup_pos.x, 0.0, maxf(0.0, area_size.x - POPUP_SIZE_ESTIMATE.x))
	popup_pos.y = clampf(popup_pos.y, 0.0, maxf(0.0, area_size.y - POPUP_SIZE_ESTIMATE.y))
	skill_popup.position = popup_pos


func _on_popup_unlock_pressed() -> void:
	if _shown_skill == null:
		return
	var result = GameManager.unlock_skill(_current_player.player_id, _shown_skill)
	if result["success"]:
		skill_unlocked.emit(_shown_skill)
	_refresh()


static func _format_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "brak"
	var parts: Array[String] = []
	for res_type in costs:
		parts.append("%s: %.0f" % [HexData.RESOURCE_DISPLAY_NAMES.get(res_type, "?"), costs[res_type]])
	return ", ".join(parts)
