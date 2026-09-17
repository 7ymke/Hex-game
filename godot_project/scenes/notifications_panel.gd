class_name NotificationsPanel
extends CanvasLayer
## Panel powiadomień - "kropka z literką i" w pasku bocznym
## (game_map_controller.gd, `info_button`), zastępująca dawną Kartę Miasta
## (budynki kupuje się teraz wprost w pasku bocznym, patrz
## `_build_building_preview_row()` tamże). Na razie jedynym źródłem
## powiadomień są losowe wydarzenia (autoloads/random_event_manager.gd) -
## stąd jeden prosty, przewijany dziennik tekstowy (najnowsze na górze), bez
## żadnej dodatkowej logiki typów/filtrowania - będzie na co to rozbudować,
## gdy pojawi się drugie źródło informacji.
##
## Pokazuje TYLKO wpisy dotyczące gracza podanego w `open_panel()`
## (`RandomEventManager.get_notifications_for_player()`) - "Informacje
## powinny pokazywać się tylko graczowi którego dotyczą - lub wszystkim
## jeśli dotyczą wszystkich". `_viewing_player_id` jest zapamiętywane, żeby
## `_refresh()` (wołane też przy nowym powiadomieniu, gdy panel jest akurat
## otwarty) wiedziało, kogo filtrować bez ponownego przekazywania id.
##
## Ten sam wzorzec co CityCardPanel/SkillTreePanel/MarketPanel: samodzielny
## CanvasLayer parentowany wprost pod korzeniem sceny, z osobnym
## `Background` (PanelContainer) i `CloseButton` jako niezależnym
## rodzeństwem - CanvasLayer nigdy nie wymusza układu swoich dzieci, więc
## przycisk zamknięcia może swobodnie siedzieć w rogu.

signal closed

@onready var background: PanelContainer = $Background
@onready var close_button: Button = $CloseButton
@onready var notification_list: VBoxContainer = $Background/VBox/ScrollContainer/NotificationList

var _viewing_player_id: int = -1


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	RandomEventManager.notification_added.connect(_refresh)


## Otwarcie od razu oznacza wszystko jako przeczytane DLA TEGO GRACZA
## (prosta, standardowa konwencja powiadomień - nie zalicza jako przeczytane
## nic, co dotyczy innych graczy) - licznik na "i" w pasku bocznym odświeża
## sam game_map_controller.gd zaraz po tym wywołaniu.
func open_panel(player_id: int) -> void:
	_viewing_player_id = player_id
	visible = true
	RandomEventManager.mark_read_for_player(player_id)
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in notification_list.get_children():
		child.queue_free()

	var relevant = RandomEventManager.get_notifications_for_player(_viewing_player_id)
	if relevant.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Brak powiadomień."
		empty_label.add_theme_color_override("font_color", Palette.CREAM_DIM)
		notification_list.add_child(empty_label)
		return

	for i in range(relevant.size() - 1, -1, -1):
		notification_list.add_child(_build_row(relevant[i]))


func _build_row(entry: Dictionary) -> Control:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var round_label = Label.new()
	round_label.text = "Runda %d" % entry["round"]
	round_label.add_theme_font_size_override("font_size", 10)
	round_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	row.add_child(round_label)

	var message_label = Label.new()
	message_label.text = entry["message"]
	message_label.custom_minimum_size = Vector2(360, 0)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(message_label)

	return row
