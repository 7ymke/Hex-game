class_name CityCardPanel
extends CanvasLayer
## Faza 8 planu implementacji: Karta Miasta - "osobny ekran UI, niezależny
## od siatki heksów" (sekcja 7 GDD). Budynki charakterystyczne miasta gracza,
## odblokowywane za zasoby zdobyte z eksploracji mapy; każdy odblokowany
## budynek daje prestiż (fundament pod przyszły warunek zwycięstwa).

signal closed
signal building_unlocked

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var building_list: VBoxContainer = $Panel/VBox/ScrollContainer/BuildingList
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
	for child in building_list.get_children():
		child.queue_free()

	if _current_player == null:
		return

	title_label.text = "Karta Miasta: %s (gracz %s)" % [
		_current_player.starting_city, _current_player.player_name
	]

	var buildings = CityBuildingsData.get_buildings(_current_player.starting_city)
	if buildings.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Brak zdefiniowanych budynków dla tego miasta."
		building_list.add_child(empty_label)
		return

	for building in buildings:
		building_list.add_child(_build_row(building))


func _build_row(building: Building) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info_label = Label.new()
	info_label.custom_minimum_size = Vector2(320, 0)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.text = "%s (+%d prestiżu)\nKoszt: %s" % [
		building.building_name, building.prestige_value, _format_costs(building.required_resources)
	]
	row.add_child(info_label)

	var unlocked = _current_player.unlocked_city_buildings.has(building.building_name)
	var action_button = Button.new()
	if unlocked:
		action_button.text = "Odblokowano"
		action_button.disabled = true
	else:
		action_button.text = "Odblokuj"
		action_button.disabled = not _current_player.can_afford(building.required_resources)
		action_button.pressed.connect(_on_unlock_pressed.bind(building))
	row.add_child(action_button)

	return row


func _on_unlock_pressed(building: Building) -> void:
	var result = GameManager.unlock_city_building(_current_player.player_id, building)
	if result["success"]:
		building_unlocked.emit()
	_refresh()


static func _format_costs(costs: Dictionary) -> String:
	if costs.is_empty():
		return "brak"
	var parts: Array[String] = []
	for res_type in costs:
		parts.append("%s: %.0f" % [HexData.ResourceType.keys()[res_type], costs[res_type]])
	return ", ".join(parts)
