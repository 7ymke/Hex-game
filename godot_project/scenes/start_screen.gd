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
##
## Poprzedzony ekranem głównym (scenes/main_menu.gd - "Nowa gra/Wczytaj grę/
## Zakończ grę") - "Wstecz" wraca tam bez wybierania żadnych miast.

@onready var city_list: VBoxContainer = $CenterContainer/Panel/VBox/CityList
@onready var start_button: Button = $CenterContainer/Panel/VBox/StartButton
@onready var hint_label: Label = $CenterContainer/Panel/VBox/HintLabel
@onready var back_button: Button = $CenterContainer/Panel/VBox/BackButton

var checkboxes: Dictionary = {}  # player_id(int) -> CheckBox


func _ready() -> void:
	# Heksagonalne ikony zamiast domyślnego kwadratowego checkboksa silnika
	# (ten sam rasteryzator co ikony uchwytów suwaków w game_map_controller.gd
	# - HexShape.make_texture()) - drobny, ale spójny z motywem "wszystko
	# jest heksagonem" szczegół, zamiast jedynego miejsca w grze, które wciąż
	# pokazywało domyślny wygląd Godota.
	var checked_icon = HexShape.make_texture(Vector2i(16, 14), Palette.GOLD_BRIGHT)
	var unchecked_icon = HexShape.make_texture(Vector2i(16, 14), Color(Palette.WOOD_MID.r, Palette.WOOD_MID.g, Palette.WOOD_MID.b, 0.35))

	for setup in PlayerSetup.LIST:
		var checkbox = CheckBox.new()
		checkbox.text = "%s (%s)" % [setup["name"], setup["city"]]
		checkbox.button_pressed = true
		checkbox.toggled.connect(_on_city_toggled)
		checkbox.add_theme_icon_override("checked", checked_icon)
		checkbox.add_theme_icon_override("unchecked", unchecked_icon)
		city_list.add_child(checkbox)
		checkboxes[setup["id"]] = checkbox

	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
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


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
