extends Control
## Ekran główny (menu startowe) - "Chcę abyś dodał start screen gdzie będzie
## opcja - New game, Load game, Exit game." Pierwszy ekran po uruchomieniu
## gry (project.godot -> main_scene), przed scenes/start_screen.tscn
## (wybór miast).
##
## "Wczytaj grę" jest wyszarzony, jeśli nie ma zapisu (SaveManager.has_save())
## - wczytane dane trafiają do SaveManager.pending_load_data, tak samo jak
## start_screen.gd przekazuje wybór miast przez GameSetup.selected_player_ids
## (zwykłe węzły sceny nie przeżywają change_scene_to_file()).

@onready var new_game_button: Button = $CenterContainer/Panel/VBox/NewGameButton
@onready var load_game_button: Button = $CenterContainer/Panel/VBox/LoadGameButton
@onready var exit_button: Button = $CenterContainer/Panel/VBox/ExitButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	load_game_button.disabled = not SaveManager.has_save()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_load_game_pressed() -> void:
	var data = SaveManager.load_game()
	if data.is_empty():
		return  # zapis uszkodzony/zniknął - przycisk i tak zostanie wyszarzony po odświeżeniu
	SaveManager.pending_load_data = data
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
