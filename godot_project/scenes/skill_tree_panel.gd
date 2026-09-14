class_name SkillTreePanel
extends CanvasLayer
## Drzewko umiejętności - osobny ekran UI, analogiczny do Karty Miasta
## (city_card_panel.gd), tylko WSPÓLNY dla wszystkich graczy/miast (to
## ogólne usprawnienia gracza, nie zabytki charakterystyczne dla miasta).
## Na razie płaskie (bez prerequisitów) - lista 5 upgrade'ów z
## scripts/skill_tree_data.gd, każdy płatny surowcami zdobytymi z mapy.

signal closed
signal skill_unlocked(skill: SkillData)

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var skill_list: VBoxContainer = $Panel/VBox/ScrollContainer/SkillList
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
	for child in skill_list.get_children():
		child.queue_free()

	if _current_player == null:
		return

	title_label.text = "Drzewko Umiejętności: %s" % _current_player.player_name

	for skill in SkillTreeData.get_skills():
		skill_list.add_child(_build_row(skill))


func _build_row(skill: SkillData) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info_label = Label.new()
	info_label.custom_minimum_size = Vector2(500, 0)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.text = "%s\n%s\nKoszt: %s" % [
		skill.skill_name, skill.description, _format_costs(skill.required_resources)
	]
	row.add_child(info_label)

	var unlocked = _current_player.unlocked_skills.has(skill.skill_id)
	var action_button = Button.new()
	if unlocked:
		action_button.text = "Odblokowano"
		action_button.disabled = true
	else:
		action_button.text = "Odblokuj"
		action_button.disabled = not _current_player.can_afford(skill.required_resources)
		action_button.pressed.connect(_on_unlock_pressed.bind(skill))
	row.add_child(action_button)

	return row


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
