class_name DiplomacyPanel
extends CanvasLayer
## Panel Dyplomacji - "Pakt o nieagresji" (nowość: "dwóch graczy zawiera
## czasową umowę blokującą przejęcie heksów między sobą. Bez kosztu;
## zerwanie przed czasem to duża kara prestiżu"). Otwierany przyciskiem w
## pasku bocznym (`DiplomacyButton`, obok Informacji/Drzewka Umiejętności).
##
## Lista POZOSTAŁYCH graczy (bez aktualnie aktywnego, `_viewing_player_id`) -
## każdy wiersz ma jeden przycisk: "Zawrzyj pakt" (gdy nie ma między nimi
## aktywnego paktu) albo "Zerwij pakt" (gdy jest - kara prestiżowa
## naliczana przez `DiplomacyManager.break_pact()`, nie tutaj). Zawarcie
## paktu jest NATYCHMIASTOWE (bez osobnej propozycji/akceptacji) - patrz
## uzasadnienie w autoloads/diplomacy_manager.gd (gra hotseat, obaj gracze
## siedzą przy tym samym ekranie).
##
## Ten sam wzorzec co NotificationsPanel/SkillTreePanel/MarketPanel:
## samodzielny CanvasLayer parentowany wprost pod korzeniem sceny, z osobnym
## `Background` (PanelContainer) i `CloseButton` jako niezależnym
## rodzeństwem.

signal closed

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

	var button = Button.new()
	var expires = DiplomacyManager.pact_expires_at(_viewing_player_id, other.player_id)

	if expires == -1:
		info_label.text = "%s (%s) - brak paktu." % [other.player_name, other.starting_city]
		button.text = "Zawrzyj pakt"
		button.tooltip_text = "Trwa %d rund, bez kosztu." % GameBalance.NON_AGGRESSION_PACT_DURATION_ROUNDS
		button.pressed.connect(_on_propose_pressed.bind(other.player_id))
	else:
		info_label.text = "%s (%s) - pakt do rundy %d." % [other.player_name, other.starting_city, expires]
		button.text = "Zerwij pakt"
		button.tooltip_text = "Zerwanie przed czasem: -%d prestiżu." % GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY
		button.pressed.connect(_on_break_pressed.bind(other.player_id))

	row.add_child(info_label)
	row.add_child(button)
	return row


func _on_propose_pressed(other_player_id: int) -> void:
	DiplomacyManager.propose_pact(_viewing_player_id, other_player_id)
	_refresh()


func _on_break_pressed(other_player_id: int) -> void:
	DiplomacyManager.break_pact(_viewing_player_id, other_player_id)
	_refresh()
