extends Control
## Ekran startowy - wybór, ile i które miasta (gracze) wezmą udział w
## rozgrywce, przed przejściem do scenes/main.tscn. Lista miast pochodzi ze
## wspólnego scripts/player_setup.gd (PlayerSetup.LIST), tego samego źródła,
## z którego korzysta game_map_controller.gd, więc oba miejsca zawsze się
## zgadzają.
##
## Wybór jest przekazywany dalej przez autoload GameSetup
## (selected_player_ids), bo zwykłe węzły sceny nie przeżywają
## change_scene_to_file().

@onready var city_list: VBoxContainer = $CenterContainer/Panel/VBox/CityList
@onready var start_button: Button = $CenterContainer/Panel/VBox/StartButton
@onready var hint_label: Label = $CenterContainer/Panel/VBox/HintLabel

var checkboxes: Dictionary = {}  # player_id(int) -> CheckBox


func _ready() -> void:
	for setup in PlayerSetup.LIST:
		var checkbox = CheckBox.new()
		checkbox.text = "%s (%s)" % [setup["name"], setup["city"]]
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_city_toggled)
		city_list.add_child(checkbox)
		checkboxes[setup["id"]] = checkbox

	start_button.pressed.connect(_on_start_pressed)
	_update_start_button_state()


func _on_city_toggled(_pressed: bool) -> void:
	_update_start_button_state()


func _selected_ids() -> Array[int]:
	var ids: Array[int] = []
	for player_id in checkboxes:
		if checkboxes[player_id].button_pressed:
			ids.append(player_id)
	return ids


## Wymaga co najmniej 2 miast - rozgrywka jednoosobowa nie ma sensu (nie ma
## z kim rywalizować o terytorium/prestiż).
func _update_start_button_state() -> void:
	var count = _selected_ids().size()
	start_button.disabled = count < 2
	hint_label.text = (
		"Wybierz co najmniej 2 miasta." if count < 2
		else "Wybrano miast: %d" % count
	)


func _on_start_pressed() -> void:
	GameSetup.selected_player_ids = _selected_ids()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
