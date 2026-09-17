extends Control
## Ekran główny (menu startowe) - "Chcę abyś dodał start screen gdzie będzie
## opcja - New game, Load game, Exit game." Pierwszy ekran po uruchomieniu
## gry (project.godot -> main_scene), przed scenes/start_screen.tscn
## (wybór miast).
##
## "Wczytaj grę" jest wyszarzony, jeśli nie ma żadnego zapisu
## (SaveManager.has_save()) - w przeciwnym razie prowadzi do
## scenes/load_game_screen.tscn, gdzie widać listę WSZYSTKICH zapisanych
## rozgrywek do wyboru (na życzenie: "Chcę aby opcja wczytaj grę
## wyświetlała listę wszystkich gier jakie były grane"), zamiast cicho
## wczytywać jeden domyślny zapis.

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
	get_tree().change_scene_to_file("res://scenes/load_game_screen.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
