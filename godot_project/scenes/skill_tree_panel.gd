class_name SkillTreePanel
extends CanvasLayer
## Drzewko umiejętności - osobny ekran UI, WSPÓLNY dla wszystkich graczy/miast
## (w przeciwieństwie do Karty Miasta). Zaprojektowany jako radialny graf:
## centralny węzeł "START" i karty umiejętności rozstawione promieniście
## wokół niego, połączone liniami (skill_graph_view.gd) - wygląda jak
## drzewko/graf, mimo że logicznie skille są na razie płaskie (bez
## prerequisitów/zależności między sobą - patrz scripts/skill_tree_data.gd;
## dodanie prawdziwych zależności w przyszłości to tylko rozszerzenie
## SkillData o listę wymaganych skill_id i odpowiednie sprawdzenie tutaj,
## układ graficzny już na to pozwala).
##
## Karty są pozycjonowane RĘCZNIE (Control.position), nie w kontenerze typu
## VBoxContainer - stąd `graph_area` to zwykły Control, nie ScrollContainer.

signal closed
signal skill_unlocked(skill: SkillData)

const CARD_SIZE = Vector2(210, 145)
## Promień rozstawienia kart - część bezpiecznej przestrzeni, jaka zostaje po
## odjęciu połowy rozmiaru karty z każdej strony (żeby karty nie wystawały
## poza `graph_area` i się nie nakładały) - patrz wyliczenie w _refresh().
const RADIUS_SAFETY_MARGIN = 0.85

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var graph_area: Control = $Panel/VBox/GraphArea
@onready var graph_view: SkillGraphView = $Panel/VBox/GraphArea/SkillGraphView
@onready var close_button: Button = $Panel/VBox/CloseButton

var _current_player: PlayerData


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)


func open_for_player(player: PlayerData) -> void:
	_current_player = player
	visible = true
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in graph_area.get_children():
		if child != graph_view:
			child.queue_free()

	if _current_player == null:
		graph_view.node_centers = []
		graph_view.queue_redraw()
		return

	title_label.text = "Drzewko Umiejętności: %s" % _current_player.player_name

	var skills = SkillTreeData.get_skills()
	var area_size: Vector2 = graph_area.custom_minimum_size
	var center = area_size / 2.0
	# Promień, przy którym karta o rozmiarze CARD_SIZE wyśrodkowana na okręgu
	# wciąż w całości mieści się w `graph_area` (z zapasem RADIUS_SAFETY_MARGIN,
	# żeby sąsiednie karty się nie stykały krawędziami).
	var radius = minf(area_size.x - CARD_SIZE.x, area_size.y - CARD_SIZE.y) / 2.0 * RADIUS_SAFETY_MARGIN
	var count = skills.size()

	var centers: Array[Vector2] = []
	for i in range(count):
		var angle = TAU * i / count - PI / 2.0
		var card_center = center + Vector2(cos(angle), sin(angle)) * radius
		centers.append(card_center)

		var card = _build_card(skills[i])
		card.position = card_center - CARD_SIZE / 2.0
		graph_area.add_child(card)

	graph_view.hub_center = center
	graph_view.node_centers = centers
	graph_view.queue_redraw()


func _build_card(skill: SkillData) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = skill.skill_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	var info_label = Label.new()
	info_label.custom_minimum_size = Vector2(CARD_SIZE.x - 24.0, 0)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.text = "%s\nKoszt: %s" % [skill.description, _format_costs(skill.required_resources)]
	vbox.add_child(info_label)

	var unlocked = _current_player.unlocked_skills.has(skill.skill_id)
	var action_button = Button.new()
	if unlocked:
		action_button.text = "Odblokowano"
		action_button.disabled = true
	else:
		action_button.text = "Odblokuj"
		action_button.disabled = not _current_player.can_afford(skill.required_resources)
		action_button.pressed.connect(_on_unlock_pressed.bind(skill))
	vbox.add_child(action_button)

	return card


func _on_unlock_pressed(skill: SkillData) -> void:
	var result = GameManager.unlock_skill(_current_player.player_id, skill)
	if result["success"]:
		skill_unlocked.emit(skill)
	_refresh()


static func _format_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "brak"
	var parts: Array[String] = []
	for res_type in costs:
		parts.append("%s: %.0f" % [HexData.RESOURCE_DISPLAY_NAMES.get(res_type, "?"), costs[res_type]])
	return ", ".join(parts)
