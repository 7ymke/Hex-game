class_name DiplomacyPanel
extends CanvasLayer
## Panel Dyplomacji - "Pakt o nieagresji", DWUETAPOWY (update na życzenie:
## "pakt o nieagresji powinien polegać na tym że - 1 gracz wysyła prośbę a
## drugi akceptuje, dopiero wtedy można stracić [prestiż]"). Otwierany
## przyciskiem w pasku bocznym (`DiplomacyButton`, obok Informacji/Drzewka
## Umiejętności).
##
## Lista POZOSTAŁYCH graczy (bez aktualnie aktywnego, `_viewing_player_id`) -
## każdy wiersz pokazuje relację z `DiplomacyManager.get_relationship()` i
## odpowiednie przyciski:
## - **brak paktu** → "Zaproponuj pakt" (wysyła prośbę, NIE zawiera paktu).
## - **wysłałeś prośbę, czekasz** → "Anuluj prośbę".
## - **dostałeś prośbę** → "Akceptuj" (DOPIERO TERAZ pakt zaczyna
##   obowiązywać) / "Odrzuć".
## - **aktywny pakt** → "Zerwij pakt" (kara prestiżowa naliczana przez
##   `DiplomacyManager.break_pact()`, nie tutaj - patrz `pact_broken` niżej).
##
## Ten sam wzorzec co NotificationsPanel/SkillTreePanel/MarketPanel:
## samodzielny CanvasLayer parentowany wprost pod korzeniem sceny, z osobnym
## `Background` (PanelContainer) i `CloseButton` jako niezależnym
## rodzeństwem.

signal closed

## Emitowane WYŁĄCZNIE po zerwaniu aktywnego paktu - jedyna akcja w tym
## panelu, która faktycznie zmienia liczby widoczne w pasku górnym
## (prestiż). Ten sam wzorzec co `MarketPanel.traded`/
## `SkillTreePanel.skill_unlocked` - `game_map_controller.gd` nasłuchuje i
## odświeża `_update_stats_labels()`, żeby licznik prestiżu zaktualizował
## się OD RAZU, a nie dopiero przy następnej okazji.
signal pact_broken

@onready var background: PanelContainer = $Background
@onready var close_button: Button = $CloseButton
@onready var player_list: VBoxContainer = $Background/VBox/ScrollContainer/PlayerList

var _viewing_player_id: int = -1


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)


func open_for_player(player_id: int) -> void:
	_viewing_player_id = player_id
	visible = true
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in player_list.get_children():
		child.queue_free()

	var others: Array[PlayerData] = []
	for player: PlayerData in GameManager.players.values():
		if player.player_id != _viewing_player_id:
			others.append(player)

	if others.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Brak innych graczy w rozgrywce."
		empty_label.add_theme_color_override("font_color", Palette.CREAM_DIM)
		player_list.add_child(empty_label)
		return

	for other in others:
		player_list.add_child(_build_row(other))


func _build_row(other: PlayerData) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info_label = Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(info_label)

	var relationship = DiplomacyManager.get_relationship(_viewing_player_id, other.player_id)
	match relationship["state"]:
		"active":
			info_label.text = "%s (%s) - pakt do rundy %d." % [
				other.player_name, other.starting_city, relationship["expires_round"],
			]
			row.add_child(_make_button(
				"Zerwij pakt", _on_break_pressed.bind(other.player_id),
				"Zerwanie przed czasem: -%d prestiżu." % GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY
			))
		"sent":
			info_label.text = "%s (%s) - wysłano prośbę, czeka na odpowiedź." % [other.player_name, other.starting_city]
			row.add_child(_make_button("Anuluj prośbę", _on_cancel_pressed.bind(other.player_id)))
		"received":
			info_label.text = "%s (%s) proponuje Ci pakt o nieagresji." % [other.player_name, other.starting_city]
			row.add_child(_make_button("Akceptuj", _on_accept_pressed.bind(other.player_id)))
			row.add_child(_make_button("Odrzuć", _on_cancel_pressed.bind(other.player_id)))
		_:
			info_label.text = "%s (%s) - brak paktu." % [other.player_name, other.starting_city]
			row.add_child(_make_button(
				"Zaproponuj pakt", _on_propose_pressed.bind(other.player_id),
				"Trwa %d rund od akceptacji, bez kosztu wysłania." % GameBalance.NON_AGGRESSION_PACT_DURATION_ROUNDS
			))

	return row


func _make_button(text: String, callback: Callable, tooltip: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	return button


func _on_propose_pressed(other_player_id: int) -> void:
	DiplomacyManager.send_proposal(_viewing_player_id, other_player_id)
	_refresh()


func _on_accept_pressed(other_player_id: int) -> void:
	DiplomacyManager.accept_proposal(_viewing_player_id, other_player_id)
	_refresh()


func _on_cancel_pressed(other_player_id: int) -> void:
	DiplomacyManager.cancel_proposal(_viewing_player_id, other_player_id)
	_refresh()


func _on_break_pressed(other_player_id: int) -> void:
	DiplomacyManager.break_pact(_viewing_player_id, other_player_id)
	pact_broken.emit()
	_refresh()
