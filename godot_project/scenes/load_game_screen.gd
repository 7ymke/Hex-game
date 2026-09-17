extends Control
## Ekran wczytywania gry - lista WSZYSTKICH zapisanych rozgrywek (na
## życzenie: "Chcę aby opcja wczytaj grę wyświetlała listę wszystkich gier
## jakie były grane"), zamiast cichego wczytania jednego domyślnego zapisu.
## Otwierany z scenes/main_menu.gd ("Wczytaj grę") - "Wstecz" wraca tam bez
## wczytywania niczego.
##
## Każdy wiersz to zwykły Button (ten sam wzorzec co miasta na
## scenes/start_screen.gd, tam checkboxy) - kliknięcie od razu wczytuje TĘ
## rozgrywkę i przechodzi do scenes/main.tscn, analogicznie do "Rozpocznij
## grę" tam. Wybór trafia do SaveManager.pending_load_data, bo zwykłe węzły
## sceny nie przeżywają change_scene_to_file().

@onready var save_list: VBoxContainer = $CenterContainer/Panel/VBox/SaveScroll/SaveList
@onready var hint_label: Label = $CenterContainer/Panel/VBox/HintLabel
@onready var back_button: Button = $CenterContainer/Panel/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_populate_list()


func _populate_list() -> void:
	var saves = SaveManager.list_saves()
	hint_label.visible = saves.is_empty()

	for save in saves:
		var button = Button.new()
		button.text = _format_save_label(save)
		button.pressed.connect(_on_save_pressed.bind(save["id"]))
		save_list.add_child(button)


func _format_save_label(save: Dictionary) -> String:
	var players_text = ", ".join(save["player_names"]) if not save["player_names"].is_empty() else "?"
	return "%s  —  Runda %d  —  %s" % [save["saved_at_display"], save["round_number"], players_text]


func _on_save_pressed(save_id: String) -> void:
	var data = SaveManager.load_game(save_id)
	if data.is_empty():
		return  # zapis zniknął/uszkodzony między odświeżeniem listy a kliknięciem
	SaveManager.pending_load_data = data
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
