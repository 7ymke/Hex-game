extends Node2D
## Fazy 4-9 planu implementacji (+ dalsze poprawki): płynny ruch ludzika z
## pathfindingiem i mgłą, akcje na polu działające w zasięgu (nie tylko stojąc
## dokładnie na polu), zaznaczanie/odznaczanie ludzików, pełna struktura tur
## wielu graczy oparta o gotowość, Karta Miasta i przejęcie terytorium PvP.
##
## Hotseat: 2 graczy na jednym ekranie. Gracz 1 startuje we Wrocławiu (H14,
## jedyny heks oznaczony jako "city" w obecnym wycinku KML), gracz 2 w
## Szczecinie (A3 - oznaczony w danych jako miasto etykietą, ale nie osobnym
## typem terenu; wystarczające dla testu multiplayer/PvP, dopóki KML nie
## obejmie reszty Polski z kolejnymi miastami startowymi).
##
## Model danych `player_ludziks: player_id -> Array[Ludzik]` (zamiast
## pojedynczego węzła na gracza) jest tak zaprojektowany, żeby przyszły
## upgrade "więcej ludzików" sprowadzał się do dopisania nowego Ludzika do
## tej tablicy - cała reszta (zaznaczanie, blokady ruchu, zasięg akcji)
## już iteruje po tablicach, nie zakłada dokładnie jednego elementu.

const VISION_RADIUS = GameBalance.VISION_RADIUS

## Gracze startowi hotseat - id, nazwa, miasto, heks bazowy, kolor pionka.
const PLAYER_SETUP = [
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
@onready var switch_player_button: Button = $UI/ActionPanel/VBox/SwitchPlayerButton
@onready var end_turn_button: Button = $UI/ActionPanel/VBox/EndTurnButton

var players: Array[PlayerData] = []
var player_ludziks: Dictionary = {}  # player_id(int) -> Array[Ludzik]
var active_player: PlayerData

var selected_ludzik: Ludzik = null
var selected_hex_id: String = ""

var pathfinder = HexPathfinder.new()


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
	switch_player_button.pressed.connect(_on_switch_player_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	city_card_panel.building_unlocked.connect(_on_city_building_unlocked)

	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.round_ended.connect(_on_round_ended)

	var player_ids: Array[int] = []
	for p in players:
		player_ids.append(p.player_id)
	TurnManager.setup_player_order(player_ids)

	_on_harvest_slider_changed(harvest_slider.value)


## Tworzy graczy, ich ludziki i aneksuje im heks startowy.
func _setup_players() -> void:
	var existing_ludzik: Ludzik = $Ludzik

	for i in range(PLAYER_SETUP.size()):
		var setup: Dictionary = PLAYER_SETUP[i]

		var player = PlayerData.new()
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
		player_ludziks[player.player_id] = [ludzik]

		var start_hex_id: String = setup["start_hex"]
		if MapData.get_hex(start_hex_id) == null:
			push_warning("GameMapController: brak heksa startowego %s dla %s" % [start_hex_id, player.player_name])
			start_hex_id = MapData.hexes.keys()[0]

		GameManager.annex_hex(start_hex_id, player.player_id)
		ludzik.place_on_hex(start_hex_id)
		_reveal_around(start_hex_id, player.player_id)


func _primary_ludzik_for(player_id: int) -> Ludzik:
	var list: Array = player_ludziks.get(player_id, [])
	return list[0] if not list.is_empty() else null


func _find_own_ludzik_at(hex_id: String) -> Ludzik:
	for l in player_ludziks.get(active_player.player_id, []):
		if l.current_hex_id == hex_id:
			return l
	return null


## Zwraca ludzika aktywnego gracza, który może wykonać akcję na `hex_id`
## (w promieniu GameBalance.ACTION_RANGE) - preferując aktualnie zaznaczonego
## ludzika, jeśli on sam się kwalifikuje, a w przeciwnym razie pierwszego
## pasującego. Zwraca null, jeśli żaden ludzik gracza nie jest wystarczająco
## blisko.
func _own_ludzik_in_range(hex_id: String) -> Ludzik:
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return null

	if selected_ludzik != null and selected_ludzik.player_id == active_player.player_id:
		if _hex_distance(hex_id, selected_ludzik.current_hex_id) <= GameBalance.ACTION_RANGE:
			return selected_ludzik

	for l in player_ludziks.get(active_player.player_id, []):
		if _hex_distance(hex_id, l.current_hex_id) <= GameBalance.ACTION_RANGE:
			return l
	return null


func _hex_distance(hex_id_a: String, hex_id_b: String) -> int:
	var a = MapData.get_hex(hex_id_a)
	var b = MapData.get_hex(hex_id_b)
	if a == null or b == null:
		return 9999
	return HexGridUtils.offset_distance(a.axial_q, a.axial_r, b.axial_q, b.axial_r)


## Heksy aktualnie zajęte przez ludziki INNYCH graczy - sekcja 3 GDD,
## "funkcja obronna": dopóki tam stoją, nie można przez nie przejść ani na
## nich wylądować.
func _blocked_hexes_for(player_id: int) -> Array[String]:
	var blocked: Array[String] = []
	for pid in player_ludziks:
		if pid == player_id:
			continue
		for l in player_ludziks[pid]:
			blocked.append(l.current_hex_id)
	return blocked


## Ludzik (dowolnego gracza) aktualnie stojący dokładnie na `hex_id`, jeśli
## jakiś tam jest. Używane do egzekwowania "funkcji obronnej" (sekcja 3 GDD)
## przy przejęciu terytorium - odróżnij od `_blocked_hexes_for`, które celowo
## pomija ludziki WŁASNE gracza (bo nie blokują jego samego).
func _ludzik_at(hex_id: String) -> Ludzik:
	for pid in player_ludziks:
		for l in player_ludziks[pid]:
			if l.current_hex_id == hex_id:
				return l
	return null


func _set_selected_ludzik(ludzik: Ludzik) -> void:
	if selected_ludzik == ludzik:
		return
	if selected_ludzik != null:
		selected_ludzik.set_selected(false)
	selected_ludzik = ludzik
	if selected_ludzik != null:
		selected_ludzik.set_selected(true)


func _set_selected_hex(hex_id: String) -> void:
	selected_hex_id = hex_id
	hex_map_view.selected_hex_id = hex_id
	hex_map_view.queue_redraw()


func _on_player_turn_started(player_id: int) -> void:
	active_player = GameManager.get_player(player_id)
	hex_map_view.viewing_player_id = player_id
	_set_selected_ludzik(null)

	var primary = _primary_ludzik_for(player_id)
	_set_selected_hex(primary.current_hex_id if primary != null else "")

	turn_label.text = "Tura gracza: %s (%s) | Gotowi: %d/%d | Runda: %d" % [
		active_player.player_name, active_player.starting_city,
		TurnManager.ready_count(), players.size(), TurnManager.round_number
	]
	info_label.text = "Kliknij ludzika, żeby go zaznaczyć/odznaczyć, potem kliknij pole, żeby go tam przesunąć."

	hex_map_view.queue_redraw()
	_update_mp_label()
	_update_prestige_label()
	_refresh_action_panel()


func _on_round_ended(_round_number: int) -> void:
	for pid in player_ludziks:
		for l in player_ludziks[pid]:
			l.reset_movement_points()
	_update_mp_label()


func _on_hex_clicked(hex_id: String) -> void:
	var own_ludzik = _find_own_ludzik_at(hex_id)

	if own_ludzik != null:
		# Klik na własnego ludzika -> zaznacz go (albo odznacz, jeśli już
		# był zaznaczony).
		_set_selected_ludzik(null if selected_ludzik == own_ludzik else own_ludzik)
	elif selected_ludzik != null and not selected_ludzik.is_moving:
		# Klik gdzie indziej, mając zaznaczonego ludzika -> rozkaz ruchu.
		_command_move(selected_ludzik, hex_id)

	_set_selected_hex(hex_id)
	_refresh_action_panel()


func _command_move(ludzik: Ludzik, target_hex_id: String) -> void:
	if target_hex_id == ludzik.current_hex_id:
		return

	var blocked = _blocked_hexes_for(ludzik.player_id)
	pathfinder.build(blocked)
	var path = pathfinder.find_path(ludzik.current_hex_id, target_hex_id)
	if path.size() < 2:
		if blocked.has(target_hex_id):
			info_label.text = "Pole %s jest bronione przez ludzika innego gracza - nie można tam wejść." % target_hex_id
		else:
			info_label.text = "Brak dostępnej trasy do %s." % target_hex_id
		return

	await _move_along_path(ludzik, path)


func _move_along_path(ludzik: Ludzik, path: Array[String]) -> void:
	ludzik.is_moving = true

	var i = 1
	while i < path.size():
		var next_hex_id: String = path[i]
		var next_hex = MapData.get_hex(next_hex_id)

		if next_hex == null or not next_hex.is_passable():
			info_label.text = "Pole %s jest niedostępne dla ruchu." % next_hex_id
			break

		var cost = next_hex.get_movement_cost()
		if not ludzik.spend_movement_points(cost):
			info_label.text = (
				"Brak punktów ruchu: wejście na %s kosztuje %d, zostało %d. Trasa przerwana."
				% [next_hex_id, cost, ludzik.movement_points_current]
			)
			break

		await ludzik.animate_to_hex(next_hex_id)
		_reveal_around(next_hex_id, ludzik.player_id)
		_update_mp_label()
		hex_map_view.queue_redraw()
		i += 1

	ludzik.is_moving = false
	if ludzik == selected_ludzik:
		_set_selected_hex(ludzik.current_hex_id)
	info_label.text = "Ludzik dotarł do %s." % ludzik.current_hex_id
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
	if hex_id == "" or active_player == null:
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
## Działają na `selected_hex_id`, o ile jakiś ludzik aktywnego gracza jest w
## zasięgu GameBalance.ACTION_RANGE - niekoniecznie stojąc dokładnie na polu.

func _on_annex_pressed() -> void:
	var hex_id = selected_hex_id
	var ludzik = _own_ludzik_in_range(hex_id)
	if ludzik == null:
		info_label.text = "Żaden twój ludzik nie jest wystarczająco blisko %s." % hex_id
		return

	if not ludzik.spend_movement_points(GameBalance.ANNEX_MP_COST):
		info_label.text = "Brak punktów ruchu na aneksację (koszt: %d)." % GameBalance.ANNEX_MP_COST
		_refresh_action_panel()
		return

	var result = GameManager.annex_hex(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)  # "seen" -> "annexed" + ujawnia budynek
		info_label.text = "Zaanektowano %s (koszt: %d MP)." % [hex_id, GameBalance.ANNEX_MP_COST]
		hex_map_view.queue_redraw()
	else:
		ludzik.refund_movement_points(GameBalance.ANNEX_MP_COST)
		info_label.text = "Nie udało się zaanektować %s (%s)." % [hex_id, result["reason"]]

	_update_mp_label()
	_refresh_action_panel()


## Przejęcie terytorium (PvP) - sekcja 5 GDD / Faza 9. Dostępne tylko, gdy
## jakiś ludzik aktywnego gracza jest blisko heksu należącego do innego
## gracza - co (dzięki blokadzie ruchu w `_command_move`) jest w ogóle
## możliwe wyłącznie wtedy, gdy broniący ludzik akurat go NIE patroluje.
func _on_takeover_pressed() -> void:
	var hex_id = selected_hex_id
	if _own_ludzik_in_range(hex_id) == null:
		info_label.text = "Żaden twój ludzik nie jest wystarczająco blisko %s." % hex_id
		return

	# Zasięg akcji ("blisko") pozwala przejmować bez stania dokładnie na polu,
	# ale "funkcja obronna" z sekcji 3 GDD musi zostać zachowana: jeśli
	# broniący ludzik AKURAT stoi na tym heksie, przejęcie się nie udaje,
	# niezależnie od zasięgu.
	if _ludzik_at(hex_id) != null:
		info_label.text = "Pole %s jest bronione przez stojącego na nim ludzika - nie można go przejąć." % hex_id
		return

	var result = GameManager.attempt_takeover(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)
		info_label.text = "Przejęto %s (koszt: -%d prestiżu)." % [hex_id, result["cost"]]
		hex_map_view.queue_redraw()
		_update_prestige_label()
	else:
		var reason_text = {
			"no_owner": "pole nie ma właściciela - użyj Aneksacji.",
			"already_owner": "to już twoje pole.",
			"insufficient_prestige": "za mało prestiżu względem obrońcy.",
		}.get(result["reason"], result["reason"])
		info_label.text = "Nie udało się przejąć %s (%s)." % [hex_id, reason_text]
	_refresh_action_panel()


func _on_repair_pressed() -> void:
	var hex_id = selected_hex_id
	if _own_ludzik_in_range(hex_id) == null:
		info_label.text = "Żaden twój ludzik nie jest wystarczająco blisko %s." % hex_id
		return

	var result = GameManager.repair_building(hex_id, active_player.player_id)
	if result["success"]:
		info_label.text = "Naprawiono budynek na %s. Zacznie generować zasoby od kolejnej rundy." % hex_id
		if result.get("prestige_penalty", 0) > 0:
			info_label.text += " Strefa chroniona: kara prestiżowa -%d." % result["prestige_penalty"]
			_update_prestige_label()
	else:
		info_label.text = "Nie udało się naprawić budynku na %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


func _on_harvest_slider_changed(value: float) -> void:
	harvest_value_label.text = "%d%%" % int(value)


## Wydobycie lasu (Faza 5, sekcja 6.1 GDD) - NIE wymaga stania dokładnie na
## polu (update): wystarczy zaznaczyć pole leśne w zasięgu jednego z twoich
## ludzików. Można też podejść ludzikiem i wejść na pole - obie ścieżki
## finalnie sprowadzają się do tego samego sprawdzenia zasięgu.
func _on_harvest_pressed() -> void:
	var hex_id = selected_hex_id
	if _own_ludzik_in_range(hex_id) == null:
		info_label.text = "Żaden twój ludzik nie jest wystarczająco blisko %s." % hex_id
		return

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


## --- Tura (Faza 6, oparta o gotowość - patrz turn_manager.gd) ---

func _on_switch_player_pressed() -> void:
	TurnManager.switch_to_next_player()


func _on_end_turn_pressed() -> void:
	TurnManager.end_turn_for_current_player()  # emit-uje player_turn_started -> odświeża cały UI


## Aktualizuje panel akcji wg aktualnie ZAZNACZONEGO heksu (niekoniecznie
## tego, na którym stoi ludzik - patrz `selected_hex_id`).
func _refresh_action_panel() -> void:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null:
		hex_info_label.text = "Zaznacz pole (kliknij na mapie)."
		annex_button.disabled = true
		takeover_button.visible = false
		repair_button.disabled = true
		harvest_slider.visible = false
		harvest_value_label.visible = false
		harvest_button.visible = false
		return

	var acting_ludzik = _own_ludzik_in_range(selected_hex_id)
	var in_range = acting_ludzik != null

	var owner_text = "gracz %d" % hex.owner_id if hex.owner_id != -1 else "niczyj"
	var building_text = "brak"
	if hex.building != null:
		building_text = "%s (%s)" % [
			hex.building.building_name,
			"USZKODZONY" if hex.building_damaged else "sprawny"
		]

	hex_info_label.text = "%s | %s\nteren: %s | właściciel: %s\nbudynek: %s\npoziom zasobu: %.0f%%%s" % [
		hex.hex_id, hex.label_raw, HexData.TerrainType.keys()[hex.terrain_type],
		owner_text, building_text, hex.resource_level,
		"" if in_range else "\n(za daleko na akcje - podejdź bliżej)"
	]

	var is_owned_by_me = hex.owner_id == active_player.player_id
	var is_owned_by_enemy = hex.owner_id != -1 and not is_owned_by_me

	annex_button.disabled = not (in_range and hex.owner_id == -1)

	takeover_button.visible = is_owned_by_enemy
	takeover_button.disabled = not (in_range and is_owned_by_enemy and _ludzik_at(selected_hex_id) == null)

	repair_button.disabled = not (in_range and is_owned_by_me and hex.building != null and hex.building_damaged)

	var is_forest = hex.is_forest()
	harvest_slider.visible = is_forest
	harvest_value_label.visible = is_forest
	harvest_button.visible = is_forest
	harvest_button.disabled = not (in_range and is_owned_by_me)


func _update_mp_label() -> void:
	var ludzik = selected_ludzik
	if ludzik == null or ludzik.player_id != active_player.player_id:
		ludzik = _primary_ludzik_for(active_player.player_id)
	if ludzik == null:
		mp_label.text = "Punkty ruchu: -"
	else:
		mp_label.text = "Punkty ruchu: %d / %d" % [ludzik.movement_points_current, ludzik.movement_points_max]


func _update_prestige_label() -> void:
	prestige_label.text = "Prestiż: %d | Drewno: %.0f | Runda: %d" % [
		active_player.prestige,
		active_player.get_resource_amount(HexData.ResourceType.WOOD),
		TurnManager.round_number,
	]
