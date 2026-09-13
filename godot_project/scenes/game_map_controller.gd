extends Node2D
## Faza 4-5 planu implementacji: ruch (pathfinding + mgła) oraz akcje na polu
## (aneksacja, naprawa budynku, wydobycie lasu) z prostym panelem UI.
##
## Wciąż jednoosobowy test manualny (jeden gracz, jeden ludzik) - pełna obsługa
## wielu graczy/tur na przemian to Fazy 6+9, jeszcze nie tutaj. Przycisk
## "Zakończ turę" już teraz woła TurnManager, żeby dało się przetestować
## regenerację lasu i dochód z budynków między rundami.

const VISION_RADIUS = 2
const STEP_DELAY_SEC = 0.25

@onready var hex_map_view: HexMapView = $HexMapView
@onready var ludzik: Ludzik = $Ludzik
@onready var info_label: Label = $UI/InfoLabel
@onready var mp_label: Label = $UI/MPLabel
@onready var prestige_label: Label = $UI/PrestigeLabel
@onready var hex_info_label: Label = $UI/ActionPanel/VBox/HexInfoLabel
@onready var annex_button: Button = $UI/ActionPanel/VBox/AnnexButton
@onready var repair_button: Button = $UI/ActionPanel/VBox/RepairButton
@onready var harvest_slider: HSlider = $UI/ActionPanel/VBox/HarvestRow/HarvestSlider
@onready var harvest_value_label: Label = $UI/ActionPanel/VBox/HarvestRow/HarvestValueLabel
@onready var harvest_button: Button = $UI/ActionPanel/VBox/HarvestButton
@onready var end_turn_button: Button = $UI/ActionPanel/VBox/EndTurnButton

var player: PlayerData
var pathfinder = HexPathfinder.new()
var current_path: Array[String] = []
var _moving = false


func _ready() -> void:
	player = PlayerData.new()
	player.player_id = 1
	player.player_name = "Gracz testowy"
	player.starting_city = "Wrocław"
	GameManager.register_player(player)

	pathfinder.build()

	var start_hex_id = "H14" if MapData.get_hex("H14") != null else MapData.hexes.keys()[0]
	GameManager.annex_hex(start_hex_id, player.player_id)

	ludzik.player_id = player.player_id
	ludzik.place_on_hex(start_hex_id)
	_reveal_around(start_hex_id)

	hex_map_view.viewing_player_id = player.player_id
	hex_map_view.hex_clicked.connect(_on_hex_clicked)
	hex_map_view.hex_hovered.connect(_on_hex_hovered)
	hex_map_view.queue_redraw()

	annex_button.pressed.connect(_on_annex_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	harvest_button.pressed.connect(_on_harvest_pressed)
	harvest_slider.value_changed.connect(_on_harvest_slider_changed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	TurnManager.setup_player_order([player.player_id])

	_update_mp_label()
	_update_prestige_label()
	_on_harvest_slider_changed(harvest_slider.value)
	_refresh_action_panel()
	info_label.text = "Start: %s. Kliknij widoczny heks, aby przesunąć ludzika (PPM = przesuń widok, scroll = zoom)." % start_hex_id


func _on_hex_clicked(hex_id: String) -> void:
	if _moving:
		return

	if hex_id == ludzik.current_hex_id:
		_refresh_action_panel()
		return

	var path = pathfinder.find_path(ludzik.current_hex_id, hex_id)
	if path.size() < 2:
		info_label.text = "Brak dostępnej trasy do %s." % hex_id
		return

	current_path = path
	_moving = true
	_step_movement()


func _step_movement() -> void:
	if current_path.size() <= 1:
		_moving = false
		_refresh_action_panel()
		return

	var next_hex_id: String = current_path[1]
	var next_hex = MapData.get_hex(next_hex_id)

	if next_hex == null or not next_hex.is_passable():
		info_label.text = "Pole %s jest niedostępne dla ruchu." % next_hex_id
		_moving = false
		_refresh_action_panel()
		return

	var cost = next_hex.get_movement_cost()
	if not player.spend_movement_points(cost):
		info_label.text = (
			"Brak punktów ruchu: wejście na %s kosztuje %d, zostało %d. Trasa przerwana."
			% [next_hex_id, cost, player.movement_points_current]
		)
		_moving = false
		_update_mp_label()
		_refresh_action_panel()
		return

	ludzik.place_on_hex(next_hex_id)
	_reveal_around(next_hex_id)
	_update_mp_label()
	hex_map_view.queue_redraw()

	current_path.remove_at(0)

	if current_path.size() > 1:
		await get_tree().create_timer(STEP_DELAY_SEC).timeout
		_step_movement()
	else:
		_moving = false
		info_label.text = "Dotarto do %s." % next_hex_id
		_refresh_action_panel()


## Odsłania mgłę w promieniu widzenia (sekcja 2.2 GDD) - BFS po realnych
## sąsiadach, więc liczba "skoków" odpowiada dokładnie odległości heksowej.
func _reveal_around(center_hex_id: String) -> void:
	var center = MapData.get_hex(center_hex_id)
	if center == null:
		return

	center.set_fog_state(
		player.player_id,
		"annexed" if center.owner_id == player.player_id else "seen"
	)

	var start_coord = Vector2i(center.axial_q, center.axial_r)
	var queue: Array[Vector2i] = [start_coord]
	var distance = {start_coord: 0}

	while not queue.is_empty():
		var coord: Vector2i = queue.pop_front()
		var dist: int = distance[coord]
		if dist >= VISION_RADIUS:
			continue
		for n in HexGridUtils.offset_neighbors(coord.x, coord.y):
			if distance.has(n):
				continue
			distance[n] = dist + 1
			var hex = MapData.get_hex_at(n.x, n.y)
			if hex != null and hex.get_fog_state(player.player_id) == "unexplored":
				hex.set_fog_state(player.player_id, "seen")
			queue.append(n)


func _on_hex_hovered(hex_id: String) -> void:
	if _moving or hex_id == "":
		return
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return

	var fog = hex.get_fog_state(player.player_id)
	match fog:
		"unexplored":
			pass  # nic nie pokazujemy - zgodnie z zasadą dwupoziomowej mgły
		"seen":
			info_label.text = "%s: teren %s (koszt ruchu %d) - nieznane zasoby/budynki." % [
				hex_id, HexData.TerrainType.keys()[hex.terrain_type], hex.get_movement_cost()
			]
		"annexed":
			var owner_text = "gracz %d" % hex.owner_id if hex.owner_id != -1 else "niczyj"
			var building_text = "brak"
			if hex.building != null:
				building_text = "%s (%s)" % [
					hex.building.building_name,
					"USZKODZONY" if hex.building_damaged else "sprawny"
				]
			info_label.text = "%s: %s | teren: %s | budynek: %s | właściciel: %s" % [
				hex_id, hex.label_raw, HexData.TerrainType.keys()[hex.terrain_type],
				building_text, owner_text
			]


## --- Akcje na polu (Faza 5) ---

func _on_annex_pressed() -> void:
	var hex_id = ludzik.current_hex_id
	var result = GameManager.annex_hex(hex_id, player.player_id)
	if result["success"]:
		_reveal_around(hex_id)  # podnosi fog_state z "seen" na "annexed" + ujawnia budynek
		info_label.text = "Zaanektowano %s." % hex_id
		hex_map_view.queue_redraw()
	else:
		info_label.text = "Nie udało się zaanektować %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


func _on_repair_pressed() -> void:
	var hex_id = ludzik.current_hex_id
	var result = GameManager.repair_building(hex_id, player.player_id)
	if result["success"]:
		info_label.text = "Naprawiono budynek na %s. Zacznie generować zasoby od kolejnej rundy." % hex_id
	else:
		info_label.text = "Nie udało się naprawić budynku na %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


func _on_harvest_slider_changed(value: float) -> void:
	harvest_value_label.text = "%d%%" % int(value)


func _on_harvest_pressed() -> void:
	var hex_id = ludzik.current_hex_id
	var percent = harvest_slider.value
	var result = GameManager.harvest_forest(hex_id, player.player_id, percent)
	if result["success"]:
		var msg = "Wydobyto %.1f drewna z %s." % [result["wood_gained"], hex_id]
		if result["prestige_penalty"] > 0:
			msg += " Kara prestiżowa: -%d (przekroczono próg 60%%)." % result["prestige_penalty"]
		info_label.text = msg
		_update_prestige_label()
		hex_map_view.queue_redraw()
	else:
		info_label.text = "Nie udało się wydobyć drewna z %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


func _on_end_turn_pressed() -> void:
	TurnManager.advance_to_next_player()
	_update_mp_label()
	_update_prestige_label()
	hex_map_view.queue_redraw()
	info_label.text = "Tura zakończona. Runda: %d." % TurnManager.round_number
	_refresh_action_panel()


## Aktualizuje panel akcji wg heksa, na którym aktualnie stoi ludzik.
func _refresh_action_panel() -> void:
	var hex = MapData.get_hex(ludzik.current_hex_id)
	if hex == null:
		return

	var owner_text = "gracz %d" % hex.owner_id if hex.owner_id != -1 else "niczyj"
	var building_text = "brak"
	if hex.building != null:
		building_text = "%s (%s)" % [
			hex.building.building_name,
			"USZKODZONY" if hex.building_damaged else "sprawny"
		]

	hex_info_label.text = "%s | %s\nteren: %s | właściciel: %s\nbudynek: %s\npoziom zasobu: %.0f%%" % [
		hex.hex_id, hex.label_raw, HexData.TerrainType.keys()[hex.terrain_type],
		owner_text, building_text, hex.resource_level
	]

	var is_owned_by_me = hex.owner_id == player.player_id

	annex_button.disabled = hex.owner_id != -1
	repair_button.disabled = not (is_owned_by_me and hex.building != null and hex.building_damaged)

	var is_forest = hex.is_forest()
	harvest_slider.visible = is_forest
	harvest_value_label.visible = is_forest
	harvest_button.visible = is_forest
	harvest_button.disabled = not is_owned_by_me


func _update_mp_label() -> void:
	mp_label.text = "Punkty ruchu: %d / %d" % [player.movement_points_current, player.movement_points_max]


func _update_prestige_label() -> void:
	prestige_label.text = "Prestiż: %d | Drewno: %.0f | Runda: %d" % [
		player.prestige,
		player.get_resource_amount(HexData.ResourceType.WOOD),
		TurnManager.round_number,
	]
