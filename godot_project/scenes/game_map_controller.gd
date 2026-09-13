extends Node2D
## Fazy 4-9 planu implementacji: ruch (pathfinding + mgła), akcje na polu
## (aneksacja, naprawa budynku, wydobycie lasu), pełna struktura tur
## wielu graczy (Faza 6), Karta Miasta (Faza 8) i przejęcie terytorium
## PvP (Faza 9).
##
## Hotseat: 2 graczy na jednym ekranie, na przemian (sekcja 8 GDD - "ruchy
## graczy na przemian... następnie przeliczenie rundy"). Gracz 1 startuje we
## Wrocławiu (H14, jedyny heks oznaczony jako "city" w obecnym wycinku KML),
## gracz 2 w Szczecinie (A3 - oznaczony w danych jako miasto etykietą, ale
## nie osobnym typem terenu; wystarczające dla testu multiplayer/PvP, dopóki
## KML nie obejmie reszty Polski z kolejnymi miastami startowymi).

const VISION_RADIUS = 2
const STEP_DELAY_SEC = 0.25

## Gracze startowi hotseat - id, nazwa, miasto, heks bazowy, kolor pionka.
const PLAYER_SETUP := [
	{"id": 1, "name": "Gracz 1", "city": "Wrocław", "start_hex": "H14", "color": Color(0.9, 0.2, 0.2)},
	{"id": 2, "name": "Gracz 2", "city": "Szczecin", "start_hex": "A3", "color": Color(0.2, 0.4, 0.9)},
]

@onready var hex_map_view: HexMapView = $HexMapView
@onready var city_card_panel: CityCardPanel = $CityCardPanel
@onready var info_label: Label = $UI/InfoLabel
@onready var turn_label: Label = $UI/TurnLabel
@onready var mp_label: Label = $UI/MPLabel
@onready var prestige_label: Label = $UI/PrestigeLabel
@onready var hex_info_label: Label = $UI/ActionPanel/VBox/HexInfoLabel
@onready var annex_button: Button = $UI/ActionPanel/VBox/AnnexButton
@onready var takeover_button: Button = $UI/ActionPanel/VBox/TakeoverButton
@onready var repair_button: Button = $UI/ActionPanel/VBox/RepairButton
@onready var harvest_slider: HSlider = $UI/ActionPanel/VBox/HarvestRow/HarvestSlider
@onready var harvest_value_label: Label = $UI/ActionPanel/VBox/HarvestRow/HarvestValueLabel
@onready var harvest_button: Button = $UI/ActionPanel/VBox/HarvestButton
@onready var city_card_button: Button = $UI/ActionPanel/VBox/CityCardButton
@onready var end_turn_button: Button = $UI/ActionPanel/VBox/EndTurnButton

var players: Array[PlayerData] = []
var ludziks: Dictionary = {}  # player_id(int) -> Ludzik
var active_player: PlayerData

var pathfinder = HexPathfinder.new()
var current_path: Array[String] = []
var _moving = false


func _ready() -> void:
	_setup_players()
	pathfinder.build()

	hex_map_view.hex_clicked.connect(_on_hex_clicked)
	hex_map_view.hex_hovered.connect(_on_hex_hovered)

	annex_button.pressed.connect(_on_annex_pressed)
	takeover_button.pressed.connect(_on_takeover_pressed)
	repair_button.pressed.connect(_on_repair_pressed)
	harvest_button.pressed.connect(_on_harvest_pressed)
	harvest_slider.value_changed.connect(_on_harvest_slider_changed)
	city_card_button.pressed.connect(_on_city_card_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	city_card_panel.building_unlocked.connect(_on_city_building_unlocked)

	TurnManager.player_turn_started.connect(_on_player_turn_started)
	var player_ids: Array[int] = []
	for p in players:
		player_ids.append(p.player_id)
	TurnManager.setup_player_order(player_ids)

	_on_harvest_slider_changed(harvest_slider.value)


## Tworzy graczy, ich ludziki i aneksuje im heks startowy - odpowiednik
## Fazy 0-1 test setupu z main_test.gd, ale dla wielu graczy naraz.
func _setup_players() -> void:
	var existing_ludzik: Ludzik = $Ludzik

	for i in range(PLAYER_SETUP.size()):
		var setup: Dictionary = PLAYER_SETUP[i]

		var player := PlayerData.new()
		player.player_id = setup["id"]
		player.player_name = setup["name"]
		player.starting_city = setup["city"]
		GameManager.register_player(player)
		players.append(player)

		var ludzik: Ludzik
		if i == 0:
			ludzik = existing_ludzik  # scena już ma jeden węzeł Ludzik gotowy
		else:
			ludzik = Ludzik.new()
			add_child(ludzik)

		ludzik.player_id = player.player_id
		ludzik.color = setup["color"]
		ludziks[player.player_id] = ludzik

		var start_hex_id: String = setup["start_hex"]
		if MapData.get_hex(start_hex_id) == null:
			push_warning("GameMapController: brak heksa startowego %s dla %s" % [start_hex_id, player.player_name])
			start_hex_id = MapData.hexes.keys()[0]

		GameManager.annex_hex(start_hex_id, player.player_id)
		ludzik.place_on_hex(start_hex_id)
		_reveal_around(start_hex_id, player.player_id)


func _get_active_ludzik() -> Ludzik:
	return ludziks[active_player.player_id]


## Heksy aktualnie zajęte przez ludziki INNYCH graczy - sekcja 3 GDD,
## "funkcja obronna": dopóki tam stoją, nie można przez nie przejść ani na
## nich wylądować.
func _blocked_hexes_for(player_id: int) -> Array[String]:
	var blocked: Array[String] = []
	for pid in ludziks:
		if pid == player_id:
			continue
		blocked.append(ludziks[pid].current_hex_id)
	return blocked


func _on_player_turn_started(player_id: int) -> void:
	active_player = GameManager.get_player(player_id)
	hex_map_view.viewing_player_id = player_id
	_moving = false
	current_path = []

	turn_label.text = "Tura gracza: %s (%s) | Runda: %d" % [
		active_player.player_name, active_player.starting_city, TurnManager.round_number
	]
	info_label.text = "Kliknij widoczny heks, aby przesunąć ludzika (PPM = przesuń widok, scroll = zoom)."

	hex_map_view.queue_redraw()
	_update_mp_label()
	_update_prestige_label()
	_refresh_action_panel()


func _on_hex_clicked(hex_id: String) -> void:
	if _moving:
		return

	var ludzik := _get_active_ludzik()
	if hex_id == ludzik.current_hex_id:
		_refresh_action_panel()
		return

	var blocked := _blocked_hexes_for(active_player.player_id)
	pathfinder.build(blocked)
	var path = pathfinder.find_path(ludzik.current_hex_id, hex_id)
	if path.size() < 2:
		if blocked.has(hex_id):
			info_label.text = "Pole %s jest bronione przez ludzika innego gracza - nie można tam wejść." % hex_id
		else:
			info_label.text = "Brak dostępnej trasy do %s." % hex_id
		return

	current_path = path
	_moving = true
	_step_movement()


func _step_movement() -> void:
	var ludzik := _get_active_ludzik()

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
	if not active_player.spend_movement_points(cost):
		info_label.text = (
			"Brak punktów ruchu: wejście na %s kosztuje %d, zostało %d. Trasa przerwana."
			% [next_hex_id, cost, active_player.movement_points_current]
		)
		_moving = false
		_update_mp_label()
		_refresh_action_panel()
		return

	ludzik.place_on_hex(next_hex_id)
	_reveal_around(next_hex_id, active_player.player_id)
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
func _reveal_around(center_hex_id: String, player_id: int) -> void:
	var center = MapData.get_hex(center_hex_id)
	if center == null:
		return

	center.set_fog_state(
		player_id,
		"annexed" if center.owner_id == player_id else "seen"
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
			if hex != null and hex.get_fog_state(player_id) == "unexplored":
				hex.set_fog_state(player_id, "seen")
			queue.append(n)


func _on_hex_hovered(hex_id: String) -> void:
	if _moving or hex_id == "":
		return
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return

	var fog = hex.get_fog_state(active_player.player_id)
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


## --- Akcje na polu (Faza 5, 8, 9) ---

func _on_annex_pressed() -> void:
	var hex_id = _get_active_ludzik().current_hex_id
	var result = GameManager.annex_hex(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)  # "seen" -> "annexed" + ujawnia budynek
		info_label.text = "Zaanektowano %s." % hex_id
		if result.get("prestige_penalty", 0) > 0:
			info_label.text += " Strefa chroniona: kara prestiżowa -%d." % result["prestige_penalty"]
		hex_map_view.queue_redraw()
		_update_prestige_label()
	else:
		info_label.text = "Nie udało się zaanektować %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


## Przejęcie terytorium (PvP) - sekcja 5 GDD / Faza 9. Dostępne tylko, gdy
## aktywny gracz aktualnie stoi na heksie należącym do innego gracza -
## co (dzięki blokadzie ruchu w _on_hex_clicked) jest możliwe wyłącznie
## wtedy, gdy broniący ludzik akurat go NIE patroluje.
func _on_takeover_pressed() -> void:
	var hex_id = _get_active_ludzik().current_hex_id
	var result = GameManager.attempt_takeover(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)
		info_label.text = "Przejęto %s (koszt: -%d prestiżu)." % [hex_id, result["cost"]]
		hex_map_view.queue_redraw()
		_update_prestige_label()
	else:
		var reason_text := {
			"no_owner": "pole nie ma właściciela - użyj Aneksacji.",
			"already_owner": "to już twoje pole.",
			"insufficient_prestige": "za mało prestiżu względem obrońcy.",
		}.get(result["reason"], result["reason"])
		info_label.text = "Nie udało się przejąć %s (%s)." % [hex_id, reason_text]
	_refresh_action_panel()


func _on_repair_pressed() -> void:
	var hex_id = _get_active_ludzik().current_hex_id
	var result = GameManager.repair_building(hex_id, active_player.player_id)
	if result["success"]:
		info_label.text = "Naprawiono budynek na %s. Zacznie generować zasoby od kolejnej rundy." % hex_id
	else:
		info_label.text = "Nie udało się naprawić budynku na %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


func _on_harvest_slider_changed(value: float) -> void:
	harvest_value_label.text = "%d%%" % int(value)


func _on_harvest_pressed() -> void:
	var hex_id = _get_active_ludzik().current_hex_id
	var percent = harvest_slider.value
	var result = GameManager.harvest_forest(hex_id, active_player.player_id, percent)
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


## --- Karta Miasta (Faza 8) ---

func _on_city_card_pressed() -> void:
	city_card_panel.open_for_player(active_player)


func _on_city_building_unlocked() -> void:
	_update_prestige_label()


## --- Tura (Faza 6) ---

func _on_end_turn_pressed() -> void:
	TurnManager.advance_to_next_player()  # emit-uje player_turn_started -> odświeża cały UI


## Aktualizuje panel akcji wg heksa, na którym aktualnie stoi ludzik gracza.
func _refresh_action_panel() -> void:
	var hex = MapData.get_hex(_get_active_ludzik().current_hex_id)
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

	var is_owned_by_me = hex.owner_id == active_player.player_id
	var is_owned_by_enemy = hex.owner_id != -1 and not is_owned_by_me

	annex_button.disabled = hex.owner_id != -1

	takeover_button.visible = is_owned_by_enemy
	takeover_button.disabled = not is_owned_by_enemy

	repair_button.disabled = not (is_owned_by_me and hex.building != null and hex.building_damaged)

	var is_forest = hex.is_forest()
	harvest_slider.visible = is_forest
	harvest_value_label.visible = is_forest
	harvest_button.visible = is_forest
	harvest_button.disabled = not is_owned_by_me


func _update_mp_label() -> void:
	mp_label.text = "Punkty ruchu: %d / %d" % [active_player.movement_points_current, active_player.movement_points_max]


func _update_prestige_label() -> void:
	prestige_label.text = "Prestiż: %d | Drewno: %.0f | Runda: %d" % [
		active_player.prestige,
		active_player.get_resource_amount(HexData.ResourceType.WOOD),
		TurnManager.round_number,
	]
