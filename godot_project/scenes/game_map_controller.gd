extends Node2D
## Fazy 4-9 planu implementacji (+ dalsze poprawki): płynny ruch ludzika z
## pathfindingiem i mgłą, zaznaczanie/odznaczanie ludzików, wybór aktywnego
## gracza wprost z listy, Karta Miasta i przejęcie terytorium PvP.
##
## Hotseat: do 6 graczy na jednym ekranie (sekcja 7 GDD: "Skala multiplayer:
## 6 graczy jednocześnie na jednej mapie, każdy w innym mieście startowym").
## Pełna mapa Polski (data/map_data.json) ma wszystkie 6 miast startowych
## jako realne heksy typu "city": Wrocław (H18), Szczecin (A7), Warszawa
## (R12), Kraków (O22), Gdańsk (L3), Poznań (G12) - PLAYER_SETUP niżej (alias
## na scripts/player_setup.gd -> PlayerSetup.LIST, współdzielone z ekranem
## startowym) je opisuje. `_setup_players()` rejestruje tylko te wybrane na
## ekranie startowym (scenes/start_screen.gd, GameSetup.selected_player_ids)
## - pusta lista (np. przy uruchomieniu main.tscn wprost, z pominięciem
## ekranu startowego) oznacza "wszystkich". Dodanie kolejnego gracza w
## przyszłości (np. po rozszerzeniu mapy o nowe miasto) to tylko nowy wpis w
## PlayerSetup.LIST + budynki w city_buildings_data.gd - reszta (ruch, mgła,
## tury, PvP) jest już napisana generycznie dla dowolnej liczby graczy.
##
## Model danych `player_ludziks: player_id -> Array[Ludzik]` (zamiast
## pojedynczego węzła na gracza) jest tak zaprojektowany, żeby przyszły
## upgrade "więcej ludzików" sprowadzał się do dopisania nowego Ludzika do
## tej tablicy - cała reszta (zaznaczanie, blokady ruchu) już iteruje po
## tablicach, nie zakłada dokładnie jednego elementu.
##
## Zasięg akcji (update): aneksacja I przejęcie terenu gracza WYMAGAJĄ stania
## dokładnie na polu (płacą punkty ruchu ludzika, który tam stoi - tyle samo
## co aneksacja) - oba żyją w panelu "Trasa ludzika", wzajemnie się
## wykluczając (niczyje pole -> Zaanektuj, wrogie -> Przejmij teren gracza).
## Naprawa i wydobycie nadal działają na dowolnym już zaanektowanym polu
## (swoim - naprawa, albo swoim - wydobycie), niezależnie od tego, gdzie
## akurat stoją ludziki - "zarządzanie zdalne" własnym terytorium, bez
## potrzeby fizycznej obecności.
##
## Kontrola gracza i przeliczenie rundy są teraz całkowicie rozdzielone:
## "Zmiana gracza" (OptionButton) wybiera KONKRETNEGO gracza wprost z listy,
## "Zakończ rundę" przelicza rundę niezależnie od tego, kto jest kontrolowany
## - patrz turn_manager.gd.
##
## Trasa wielorundowa (update): klik na polu z zaznaczonym ludzikiem już NIE
## rusza go od razu - liczy i POKAZUJE podgląd trasy (żółta linia na mapie),
## czeka na potwierdzenie w nowym panelu "Trasa ludzika". Po potwierdzeniu
## trasa (`Ludzik.queued_route`) wykonuje się na tyle kroków, ile starczy
## bieżących MP (linia w kolorze pomarańczowym, dopóki trwa) - jeśli trasa
## jest dłuższa niż jednorazowy zapas MP, reszta zostaje zapamiętana i
## kontynuowana AUTOMATYCZNIE po każdym kolejnym "Zakończ rundę"
## (`_continue_all_queued_routes`), więc nie trzeba jej klikać ponownie.
##
## Drzewko umiejętności (nowość): osobny ekran (SkillTreePanel, analogiczny
## do Karty Miasta) z 5 upgrade'ami płatnymi surowcami z mapy
## (scripts/skill_tree_data.gd). Efekty "czysto danowe" (promień widzenia,
## próg bezpiecznej wycinki, koszt aneksacji, MP przyszłych ludzików)
## aplikuje GameManager.unlock_skill() na PlayerData; efekty wymagające
## dostępu do węzłów sceny (nowy Ludzik, retroaktywny bonus MP na już
## istniejących) aplikuje `_on_skill_unlocked()` tutaj.

const VISION_RADIUS = GameBalance.VISION_RADIUS

## Gracze startowi hotseat - id, nazwa, miasto, heks bazowy, kolor pionka.
## Pełna lista (wszystkie 6 miast z sekcji 7 GDD) żyje w
## scripts/player_setup.gd, żeby scenes/start_screen.gd mógł z niej budować
## checkboxy bez duplikowania danych. Który skład faktycznie gra decyduje
## ekran startowy (patrz komentarz wyżej), NIE trzeba już ręcznie usuwać
## wpisów stąd, żeby zagrać w mniejszym składzie.
const PLAYER_SETUP = PlayerSetup.LIST

@onready var hex_map_view: HexMapView = $HexMapView
@onready var city_card_panel: CityCardPanel = $CityCardPanel
@onready var skill_tree_panel: SkillTreePanel = $SkillTreePanel
@onready var info_label: Label = $UI/InfoLabel
@onready var turn_label: Label = $UI/TurnLabel
@onready var mp_label: Label = $UI/MPLabel
@onready var prestige_label: Label = $UI/PrestigeLabel
@onready var resources_label: Label = $UI/ResourcesLabel
@onready var hex_info_label: Label = $UI/ActionPanel/VBox/HexInfoLabel
@onready var repair_button: Button = $UI/ActionPanel/VBox/RepairButton
@onready var harvest_slider: HSlider = $UI/ActionPanel/VBox/HarvestRow/HarvestSlider
@onready var harvest_value_label: Label = $UI/ActionPanel/VBox/HarvestRow/HarvestValueLabel
@onready var harvest_button: Button = $UI/ActionPanel/VBox/HarvestButton
@onready var city_card_button: Button = $UI/ActionPanel/VBox/CityCardButton
@onready var skill_tree_button: Button = $UI/ActionPanel/VBox/SkillTreeButton
@onready var player_selector: OptionButton = $UI/ActionPanel/VBox/PlayerSelector
@onready var end_round_button: Button = $UI/ActionPanel/VBox/EndRoundButton
@onready var route_panel: PanelContainer = $UI/RoutePanel
@onready var route_info_label: Label = $UI/RoutePanel/VBox/RouteInfoLabel
@onready var confirm_route_button: Button = $UI/RoutePanel/VBox/ConfirmRouteButton
@onready var cancel_route_button: Button = $UI/RoutePanel/VBox/CancelRouteButton
@onready var route_annex_button: Button = $UI/RoutePanel/VBox/RouteAnnexButton
@onready var route_takeover_button: Button = $UI/RoutePanel/VBox/RouteTakeoverButton
@onready var auto_annex_checkbox: CheckBox = $UI/RoutePanel/VBox/AutoAnnexCheckBox

var players: Array[PlayerData] = []
var player_ludziks: Dictionary = {}  # player_id(int) -> Array[Ludzik]
var active_player: PlayerData

var selected_ludzik: Ludzik = null
var selected_hex_id: String = ""

## Podgląd trasy jeszcze NIEPOTWIERDZONY (patrz komentarz na górze pliku) -
## transientny stan UI, nie ludzika: `preview_route[0]` to zawsze bieżący
## heks `preview_route_ludzik`. Trasa już zatwierdzona żyje na samym
## ludziku (`Ludzik.queued_route`), bo musi przetrwać zmianę
## zaznaczenia/gracza i kolejne rundy.
var preview_route: Array[String] = []
var preview_route_ludzik: Ludzik = null

## Prawdziwy cel podglądu (może się różnić od `preview_route[-1]`, jeśli cel
## jest w danej chwili zajęty przez wrogiego ludzika - patrz `_find_path_toward`).
var preview_target_hex_id: String = ""

var pathfinder = HexPathfinder.new()


func _ready() -> void:
	_setup_players()
	_populate_player_selector()
	pathfinder.build()

	hex_map_view.hex_clicked.connect(_on_hex_clicked)
	hex_map_view.hex_hovered.connect(_on_hex_hovered)

	repair_button.pressed.connect(_on_repair_pressed)
	harvest_button.pressed.connect(_on_harvest_pressed)
	harvest_slider.value_changed.connect(_on_harvest_slider_changed)
	city_card_button.pressed.connect(_on_city_card_pressed)
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	player_selector.item_selected.connect(_on_player_selected)
	end_round_button.pressed.connect(_on_end_round_pressed)
	city_card_panel.building_unlocked.connect(_on_city_building_unlocked)
	skill_tree_panel.skill_unlocked.connect(_on_skill_unlocked)

	confirm_route_button.pressed.connect(_on_confirm_route_pressed)
	cancel_route_button.pressed.connect(_on_cancel_route_pressed)
	route_annex_button.pressed.connect(_on_annex_pressed)
	route_takeover_button.pressed.connect(_on_takeover_pressed)
	auto_annex_checkbox.toggled.connect(_on_auto_annex_toggled)

	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.round_ended.connect(_on_round_ended)

	var player_ids: Array[int] = []
	for p in players:
		player_ids.append(p.player_id)
	TurnManager.setup_player_order(player_ids)

	_on_harvest_slider_changed(harvest_slider.value)
	_refresh_route_panel()


## Tworzy graczy, ich ludziki i aneksuje im heks startowy. Uwzględnia tylko
## miasta wybrane na ekranie startowym (GameSetup.selected_player_ids,
## ustawione przez scenes/start_screen.gd) - pusta lista (np. przy
## uruchomieniu main.tscn bezpośrednio, z pominięciem ekranu startowego)
## oznacza "wszystkie", tak jak dotychczas.
func _setup_players() -> void:
	var existing_ludzik: Ludzik = $Ludzik
	var existing_ludzik_used = false
	var allowed_ids: Array = GameSetup.selected_player_ids

	for i in range(PLAYER_SETUP.size()):
		var setup: Dictionary = PLAYER_SETUP[i]
		if not allowed_ids.is_empty() and not allowed_ids.has(setup["id"]):
			continue

		var player = PlayerData.new()
		player.player_id = setup["id"]
		player.player_name = setup["name"]
		player.starting_city = setup["city"]
		player.color = setup["color"]
		GameManager.register_player(player)
		players.append(player)

		var ludzik: Ludzik
		if not existing_ludzik_used:
			ludzik = existing_ludzik  # scena już ma jeden węzeł Ludzik gotowy
			existing_ludzik_used = true
		else:
			ludzik = Ludzik.new()
			add_child(ludzik)

		ludzik.player_id = player.player_id
		ludzik.color = setup["color"]
		if setup.has("sprite") and ResourceLoader.exists(setup["sprite"]):
			ludzik.sprite_texture = load(setup["sprite"])
		player_ludziks[player.player_id] = [ludzik]

		var start_hex_id: String = setup["start_hex"]
		if MapData.get_hex(start_hex_id) == null:
			push_warning("GameMapController: brak heksa startowego %s dla %s" % [start_hex_id, player.player_name])
			start_hex_id = MapData.hexes.keys()[0]

		# `require_adjacency = false`: gracz jeszcze nic nie posiada, więc
		# zwykły wymóg "aneksuj tylko sąsiada własnego pola" byłby tu
		# niespełnialny - patrz GameManager.annex_hex(). Stolica jest też
		# trwale oznaczona jako chroniona przed przejęciem siłą (PvP) -
		# GameManager.attempt_takeover().
		GameManager.annex_hex(start_hex_id, player.player_id, false)
		MapData.get_hex(start_hex_id).is_capital = true
		ludzik.place_on_hex(start_hex_id)
		_reveal_around(start_hex_id, player.player_id)


## Item ID w OptionButton = player_id, żeby wybór nie zależał od kolejności.
func _populate_player_selector() -> void:
	player_selector.clear()
	for p in players:
		player_selector.add_item("%s (%s)" % [p.player_name, p.starting_city], p.player_id)


func _primary_ludzik_for(player_id: int) -> Ludzik:
	var list: Array = player_ludziks.get(player_id, [])
	return list[0] if not list.is_empty() else null


func _find_own_ludzik_at(hex_id: String) -> Ludzik:
	for l in player_ludziks.get(active_player.player_id, []):
		if l.current_hex_id == hex_id:
			return l
	return null


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

	# Zmiana zaznaczenia ludzika porzuca jego (jeszcze niepotwierdzony)
	# podgląd trasy - zatwierdzona, trwająca trasa (`queued_route`) zostaje
	# nietknięta, bo żyje na samym ludziku, nie tu.
	preview_route = []
	preview_route_ludzik = null
	preview_target_hex_id = ""
	hex_map_view.preview_route_hex_ids = []


func _set_selected_hex(hex_id: String) -> void:
	selected_hex_id = hex_id
	hex_map_view.selected_hex_id = hex_id
	_refresh_map_view()


func _on_player_turn_started(player_id: int) -> void:
	active_player = GameManager.get_player(player_id)
	hex_map_view.viewing_player_id = player_id
	_set_selected_ludzik(null)

	var selector_index = player_selector.get_item_index(player_id)
	if selector_index != -1:
		player_selector.select(selector_index)  # nie emituje item_selected

	var primary = _primary_ludzik_for(player_id)
	_set_selected_hex(primary.current_hex_id if primary != null else "")

	turn_label.text = "Kontrolujesz: %s (%s) | Runda: %d" % [
		active_player.player_name, active_player.starting_city, TurnManager.round_number
	]
	info_label.text = "Kliknij ludzika, żeby go zaznaczyć/odznaczyć, potem kliknij pole, żeby go tam przesunąć."

	_refresh_map_view()
	_update_mp_label()
	_update_stats_labels()
	_refresh_action_panel()
	_refresh_route_panel()


## Po przeliczeniu rundy świeże punkty ruchu pozwalają automatycznie
## kontynuować wszystkie zatwierdzone, ale jeszcze nie w pełni wykonane
## trasy (`_continue_all_queued_routes`) - stąd trasa może "iść przez parę
## rund" bez ponownego klikania.
func _on_round_ended(round_number: int) -> void:
	for pid in player_ludziks:
		for l in player_ludziks[pid]:
			l.reset_movement_points()
	_update_mp_label()
	_update_stats_labels()
	info_label.text = "Runda zakończona. Rozpoczyna się runda %d." % round_number
	await _continue_all_queued_routes()
	_refresh_map_view()
	_refresh_action_panel()
	_refresh_route_panel()


func _on_hex_clicked(hex_id: String) -> void:
	var own_ludzik = _find_own_ludzik_at(hex_id)

	if own_ludzik != null:
		# Klik na własnego ludzika -> zaznacz go (albo odznacz, jeśli już
		# był zaznaczony).
		_set_selected_ludzik(null if selected_ludzik == own_ludzik else own_ludzik)
	elif selected_ludzik != null and not selected_ludzik.is_moving:
		# Klik gdzie indziej, mając zaznaczonego ludzika -> TYLKO podgląd
		# trasy (żółta linia), NIE rozkaz ruchu - patrz panel "Trasa ludzika".
		_preview_route_to(selected_ludzik, hex_id)

	_set_selected_hex(hex_id)
	_refresh_action_panel()
	_refresh_route_panel()


## Liczy trasę od `from_hex_id` do `target_hex_id` z uwzględnieniem `blocked`
## (heksy zajęte przez wrogich ludzików - patrz `_blocked_hexes_for`). Jeśli
## sam `target_hex_id` jest zablokowany (wrogi ludzik stoi dokładnie na
## celu), zamiast zwracać "brak trasy" szuka NAJBLIŻSZEGO osiągalnego
## sąsiada celu - pozwala to zaznaczyć pole przeciwnika jako cel trasy: ludzik
## dojdzie tak blisko, jak się da, i będzie czekał (patrz `_recompute_route`)
## aż przeciwnik się ruszy albo gracz anuluje trasę. Zwraca pustą tablicę,
## jeśli nie ma drogi nawet do żadnego sąsiada.
func _find_path_toward(from_hex_id: String, target_hex_id: String, blocked: Array[String]) -> Array[String]:
	pathfinder.build(blocked)

	if not blocked.has(target_hex_id):
		return pathfinder.find_path(from_hex_id, target_hex_id)

	var best_path: Array[String] = []
	for neighbor in MapData.get_neighbors(target_hex_id):
		if blocked.has(neighbor.hex_id) or not neighbor.is_passable():
			continue
		var candidate = pathfinder.find_path(from_hex_id, neighbor.hex_id)
		if candidate.size() < 2:
			continue
		if best_path.is_empty() or candidate.size() < best_path.size():
			best_path = candidate
	return best_path


## Liczy trasę do `target_hex_id` i pokazuje ją jako podgląd (nie rusza
## ludzika) - nadpisuje poprzedni, jeszcze niepotwierdzony podgląd. NIE
## dotyka zatwierdzonej, trwającej trasy (`ludzik.queued_route`), dopóki
## gracz nie potwierdzi tego nowego podglądu w panelu. Cel może być w danej
## chwili zajęty przez wrogiego ludzika (patrz `_find_path_toward`) -
## `preview_target_hex_id` wtedy różni się od faktycznego końca
## `preview_route`, a etykieta informuje, że to tylko "najbliżej jak się da".
func _preview_route_to(ludzik: Ludzik, target_hex_id: String) -> void:
	preview_route = []
	preview_route_ludzik = null
	preview_target_hex_id = ""
	hex_map_view.preview_route_hex_ids = []

	if target_hex_id == ludzik.current_hex_id:
		return

	var blocked = _blocked_hexes_for(ludzik.player_id)
	var path = _find_path_toward(ludzik.current_hex_id, target_hex_id, blocked)
	if path.size() < 2:
		info_label.text = "Brak dostępnej trasy do %s." % target_hex_id
		return

	preview_route = path
	preview_route_ludzik = ludzik
	preview_target_hex_id = target_hex_id
	hex_map_view.preview_route_hex_ids = preview_route

	if path[-1] != target_hex_id:
		info_label.text = (
			"Pole %s jest zajęte przez wrogiego ludzika - podgląd trasy do najbliższego osiągalnego pola (%s); ludzik zaczeka, aż cel się zwolni."
			% [target_hex_id, path[-1]]
		)
	else:
		info_label.text = (
			"Podgląd trasy do %s - potwierdź w panelu \"Trasa ludzika\", żeby ludzik ruszył." % target_hex_id
		)


func _on_confirm_route_pressed() -> void:
	if preview_route_ludzik == null or preview_route.size() < 2:
		return

	var ludzik = preview_route_ludzik
	ludzik.queued_route = preview_route.slice(1)
	ludzik.route_destination = preview_target_hex_id
	preview_route = []
	preview_route_ludzik = null
	preview_target_hex_id = ""
	hex_map_view.preview_route_hex_ids = []

	info_label.text = "Trasa zatwierdzona - ludzik rusza."
	_advance_queued_route(ludzik)  # fire-and-forget, jak dawniej _command_move
	_refresh_map_view()
	_refresh_route_panel()


func _on_cancel_route_pressed() -> void:
	if preview_route_ludzik == selected_ludzik and not preview_route.is_empty():
		preview_route = []
		preview_route_ludzik = null
		preview_target_hex_id = ""
		hex_map_view.preview_route_hex_ids = []
	elif selected_ludzik != null:
		selected_ludzik.queued_route = []
		selected_ludzik.route_destination = ""
		info_label.text = "Trasa anulowana."

	_refresh_map_view()
	_refresh_route_panel()


## Kontynuuje WSZYSTKIE zatwierdzone, ale jeszcze nie w pełni wykonane trasy
## (dowolnego gracza - hotseat, wszyscy dzielą tę samą oś rund) świeżymi
## punktami ruchu - wołane po każdym przeliczeniu rundy, żeby trasa
## faktycznie "szła" przez kolejne rundy bez ponownego klikania. Przed
## kontynuacją PRZELICZA trasę na nowo (`_recompute_route`) dla każdego
## ludzika z ustawionym `route_destination` - jeśli przeciwnik zmienił
## pozycję (odsłonił poprzednio zablokowany cel albo zablokował dotychczasową
## ścieżkę), trasa się na to reaguje automatycznie, bez ręcznej interwencji.
func _continue_all_queued_routes() -> void:
	for pid in player_ludziks:
		for l in player_ludziks[pid]:
			if l.route_destination != "":
				_recompute_route(l)
			if not l.queued_route.is_empty():
				await _advance_queued_route(l)


## Przelicza trasę ludzika do jego prawdziwego celu (`route_destination`) na
## nowo, aktualnymi blokadami - wołane na starcie każdej rundy
## (`_continue_all_queued_routes`). Obsługuje trzy sytuacje: (1) ludzik już
## stoi na celu (np. dotarł tam skądinąd) -> trasa skończona; (2) jest droga
## (choćby częściowa, do najbliższego osiągalnego pola, jeśli cel wciąż
## zablokowany) -> `queued_route` dostaje świeżą ścieżkę; (3) nie ma żadnej
## drogi (np. ludzik sam jest otoczony) -> `queued_route` pozostaje puste,
## ludzik czeka w miejscu, spróbuje ponownie w kolejnej rundzie.
func _recompute_route(ludzik: Ludzik) -> void:
	if ludzik.route_destination == "" or ludzik.is_moving:
		return

	if ludzik.current_hex_id == ludzik.route_destination:
		ludzik.route_destination = ""
		ludzik.queued_route = []
		return

	var blocked = _blocked_hexes_for(ludzik.player_id)
	var path = _find_path_toward(ludzik.current_hex_id, ludzik.route_destination, blocked)
	if path.size() < 2:
		ludzik.queued_route = []
		return

	ludzik.queued_route = path.slice(1)


## Wykonuje (dalszy ciąg) zatwierdzonej trasy, tyle kroków, na ile starczy
## AKTUALNYCH punktów ruchu - reszta zostaje w `ludzik.queued_route` do
## kontynuacji w kolejnej rundzie. Re-weryfikuje przejezdność i blokadę przez
## ludzika innego gracza PRZY KAŻDYM kroku (nie tylko przy planowaniu
## podglądu) - trasa może czekać na wykonanie kilka rund, w międzyczasie
## sytuacja na polu mogła się zmienić.
##
## Aneksacja ma PIERWSZEŃSTWO nad samym przejściem: jeśli "Anektuj napotkane
## pola" jest włączone i pole faktycznie kwalifikuje się do aneksacji
## (niczyje i sąsiadujące z już posiadanym - patrz GameManager.has_adjacent_owned_hex),
## ruch na nie i aneksacja liczą się jako JEDNA nierozdzielna akcja - ludzik
## WOLI POCZEKAĆ do kolejnej rundy (więcej MP), niż wejść na pole i pominąć
## jego aneksację z braku MP. Pole, które i tak nie kwalifikuje się do
## aneksacji (np. brak sąsiedztwa), nie blokuje ruchu - nie ma na co czekać.
func _advance_queued_route(ludzik: Ludzik) -> void:
	if ludzik.queued_route.is_empty() or ludzik.is_moving:
		return

	ludzik.is_moving = true
	while not ludzik.queued_route.is_empty():
		var next_hex_id: String = ludzik.queued_route[0]
		var next_hex = MapData.get_hex(next_hex_id)

		if next_hex == null or not next_hex.is_passable():
			info_label.text = "Trasa przerwana: pole %s jest niedostępne dla ruchu." % next_hex_id
			ludzik.queued_route = []
			break

		var blocker = _ludzik_at(next_hex_id)
		if blocker != null and blocker.player_id != ludzik.player_id:
			info_label.text = "Trasa wstrzymana: pole %s jest bronione przez ludzika innego gracza." % next_hex_id
			break  # queued_route zostaje - spróbuje ponownie w kolejnej rundzie

		var move_cost = next_hex.get_movement_cost()
		var will_annex = (
			ludzik.auto_annex and next_hex.owner_id == -1
			and GameManager.has_adjacent_owned_hex(next_hex_id, ludzik.player_id)
		)
		var annex_cost = _effective_annex_cost_for(ludzik.player_id) if will_annex else 0
		var required = move_cost + annex_cost

		if ludzik.movement_points_current < required:
			if will_annex:
				info_label.text = (
					"Brak punktów ruchu na wejście i aneksację %s (potrzeba %d MP) - trasa będzie kontynuowana w kolejnej rundzie."
					% [next_hex_id, required]
				)
			else:
				info_label.text = "Brak punktów ruchu - trasa będzie kontynuowana w kolejnej rundzie."
			break

		ludzik.spend_movement_points(move_cost)

		await ludzik.animate_to_hex(next_hex_id)
		ludzik.queued_route.remove_at(0)
		_reveal_around(next_hex_id, ludzik.player_id)

		if will_annex:
			_auto_annex_hex(ludzik, next_hex_id)

		_update_mp_label()
		_refresh_map_view()

	ludzik.is_moving = false
	if ludzik == selected_ludzik:
		_set_selected_hex(ludzik.current_hex_id)
	if ludzik.queued_route.is_empty():
		if ludzik.current_hex_id == ludzik.route_destination or ludzik.route_destination == "":
			ludzik.route_destination = ""
			info_label.text = "Ludzik dotarł do celu trasy (%s)." % ludzik.current_hex_id
		else:
			info_label.text = (
				"Ludzik dotarł najbliżej jak się dało (%s) - czeka, aż pole %s stanie się osiągalne."
				% [ludzik.current_hex_id, ludzik.route_destination]
			)
	_refresh_action_panel()
	_refresh_route_panel()
	_refresh_map_view()


## Odsłania mgłę w promieniu widzenia (sekcja 2.2 GDD) - BFS po realnych
## sąsiadach, więc liczba "skoków" odpowiada dokładnie odległości heksowej.
## Promień bazowy (VISION_RADIUS) powiększony o ewentualny bonus danego
## gracza z drzewka umiejętności (skill "reconnaissance").
func _reveal_around(center_hex_id: String, player_id: int) -> void:
	var center = MapData.get_hex(center_hex_id)
	if center == null:
		return

	center.set_fog_state(
		player_id,
		"annexed" if center.owner_id == player_id else "seen"
	)

	var player = GameManager.get_player(player_id)
	var vision_radius = VISION_RADIUS + (player.vision_radius_bonus if player != null else 0)

	var start_coord = Vector2i(center.axial_q, center.axial_r)
	var queue: Array[Vector2i] = [start_coord]
	var distance = {start_coord: 0}

	while not queue.is_empty():
		var coord: Vector2i = queue.pop_front()
		var dist: int = distance[coord]
		if dist >= vision_radius:
			continue
		for n in HexGridUtils.offset_neighbors(coord.x, coord.y):
			if distance.has(n):
				continue
			distance[n] = dist + 1
			var hex = MapData.get_hex_at(n.x, n.y)
			if hex != null and hex.get_fog_state(player_id) == "unexplored":
				hex.set_fog_state(player_id, "seen")
			queue.append(n)


## Odświeża siatkę heksów, widoczność ludzików przeciwników I podgląd trasy w
## toku - te rzeczy idą razem, bo wszystkie zależą od stanu, który mógł się
## właśnie zmienić (mgła, pozycja ludzika, postęp trasy). Używaj tego zamiast
## bezpośredniego hex_map_view.queue_redraw().
func _refresh_map_view() -> void:
	_update_ludzik_visibility()
	_update_route_overlay()
	hex_map_view.queue_redraw()


## Trasa w toku (już zatwierdzona) zaznaczonego ludzika - rysowana zawsze,
## niezależnie od tego, czy akurat trwa animacja kroku, czy czeka na kolejną
## rundę (patrz komentarz na górze pliku).
func _update_route_overlay() -> void:
	if selected_ludzik != null and not selected_ludzik.queued_route.is_empty():
		# UWAGA: celowo NIE `[a] + selected_ludzik.queued_route` - konkatenacja
		# operatorem `+` literału (nietypowanego Array) z Array[String] potrafi
		# w Godot 4.2 rzucić błędem typowania w runtime. `append_array()` na
		# jawnie otypowanej zmiennej jest bezpieczne.
		var full_route: Array[String] = [selected_ludzik.current_hex_id]
		full_route.append_array(selected_ludzik.queued_route)
		hex_map_view.queued_route_hex_ids = full_route
	else:
		hex_map_view.queued_route_hex_ids = []


## Ludzik przeciwnika jest widoczny TYLKO na polu, które aktywny (oglądający)
## gracz już odkrył - fog_state != "unexplored". Nie trzeba go w pełni zbadać
## ani zaanektować, wystarczy, że heks kiedyś znalazł się w promieniu
## widzenia (VISION_RADIUS) jednego z Twoich ludzików - dokładnie ten sam
## próg, co ujawnienie samego terenu (sekcja 2.2 GDD). Własne ludziki są
## widoczne zawsze.
func _update_ludzik_visibility() -> void:
	if active_player == null:
		return

	for pid in player_ludziks:
		var is_own = pid == active_player.player_id
		for l in player_ludziks[pid]:
			if is_own:
				l.visible = true
				continue
			var hex = MapData.get_hex(l.current_hex_id)
			l.visible = hex != null and hex.get_fog_state(active_player.player_id) != "unexplored"


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
## Działają na `selected_hex_id`. Aneksacja i przejęcie terenu gracza (update)
## wymagają, żeby ludzik aktywnego gracza stał dokładnie na tym polu; Napraw
## i Wydobądź działają na dowolnym już zaanektowanym WŁASNYM polu, z dowolnej
## odległości.

## Jedyne miejsce, gdzie gracz wydaje polecenie aneksacji - przycisk żyje
## teraz WYŁĄCZNIE w panelu "Trasa ludzika" (`route_annex_button`), nie w
## głównym panelu akcji (usunięty stamtąd - aneksacja to czynność ludzika,
## nie ogólna akcja na zaznaczonym polu, w odróżnieniu od Przejmij/Napraw/
## Wydobądź, które nie wymagają fizycznej obecności).
func _on_annex_pressed() -> void:
	var hex_id = selected_hex_id
	var ludzik = _find_own_ludzik_at(hex_id)
	if ludzik == null:
		info_label.text = "Musisz stać ludzikiem na polu %s, żeby je zaanektować." % hex_id
		return

	var annex_cost = _effective_annex_cost_for(active_player.player_id)
	if not ludzik.spend_movement_points(annex_cost):
		info_label.text = "Brak punktów ruchu na aneksację (koszt: %d)." % annex_cost
		_refresh_action_panel()
		_refresh_route_panel()
		return

	var result = GameManager.annex_hex(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)  # "seen" -> "annexed" + ujawnia budynek
		info_label.text = "Zaanektowano %s (koszt: %d MP)." % [hex_id, annex_cost]
		_refresh_map_view()
	else:
		ludzik.refund_movement_points(annex_cost)
		var reason_text = {
			"not_adjacent": "pole musi sąsiadować z już posiadanym.",
			"already_owned": "pole ma już właściciela.",
		}.get(result["reason"], result["reason"])
		info_label.text = "Nie udało się zaanektować %s (%s)." % [hex_id, reason_text]

	_update_mp_label()
	_refresh_action_panel()
	_refresh_route_panel()


## Aneksuje automatycznie napotkany po drodze heks - skrót "Anektuj napotkane
## pola" w panelu "Trasa ludzika" (Ludzik.auto_annex), wołany z
## _advance_queued_route() po KAŻDYM kroku trasy. Ten sam mechanizm płatności
## co ręczna aneksacja (_on_annex_pressed), ale bez dotykania UI/selected_hex_id
## - może zajść dla DOWOLNEGO ludzika, w tym w trakcie automatycznej
## kontynuacji trasy po przeliczeniu rundy (_continue_all_queued_routes),
## niekoniecznie tego aktualnie zaznaczonego. Brak MP na samą aneksację nie
## przerywa trasy - po prostu pomija to pole i jedzie dalej.
func _auto_annex_hex(ludzik: Ludzik, hex_id: String) -> void:
	var annex_cost = _effective_annex_cost_for(ludzik.player_id)
	if not ludzik.spend_movement_points(annex_cost):
		return

	var result = GameManager.annex_hex(hex_id, ludzik.player_id)
	if result["success"]:
		_reveal_around(hex_id, ludzik.player_id)
		info_label.text = "Automatycznie zaanektowano %s." % hex_id
	else:
		ludzik.refund_movement_points(annex_cost)


func _on_auto_annex_toggled(pressed: bool) -> void:
	if selected_ludzik != null:
		selected_ludzik.auto_annex = pressed
		_refresh_route_panel()  # podgląd kosztu trasy zależy od auto_annex - patrz _route_cost()


## Czy zaznaczony heks da się zaanektować ludzikiem, który akurat go stoi -
## wspólna logika dla stanu przycisku "Zaanektuj" w panelu "Trasa ludzika".
## Wymaga też sąsiedztwa z już posiadanym polem (GameManager.annex_hex()) -
## sprawdzone tu też, żeby przycisk był wyszarzony zamiast dawać błąd dopiero
## po kliknięciu.
func _can_annex_selected_hex() -> bool:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null or hex.owner_id != -1:
		return false
	if _find_own_ludzik_at(selected_hex_id) == null:
		return false
	return GameManager.has_adjacent_owned_hex(selected_hex_id, active_player.player_id)


## Koszt aneksacji w MP dla danego gracza, pomniejszony o ewentualny bonus z
## drzewka umiejętności (skill "territorial_logistics"), nigdy poniżej 1.
## Parametryzowane graczem (nie tylko `active_player`), bo automatyczna
## aneksacja (`_auto_annex_hex`) może zajść dla dowolnego gracza podczas
## kontynuacji trasy po przeliczeniu rundy, nie tylko aktualnie kontrolowanego.
func _effective_annex_cost_for(player_id: int) -> int:
	var player = GameManager.get_player(player_id)
	var reduction = player.annex_cost_reduction if player != null else 0
	return maxi(1, GameBalance.ANNEX_MP_COST - reduction)


## Przejęcie terytorium (PvP) - sekcja 5 GDD / Faza 9 (update): tak jak
## aneksacja, wymaga teraz fizycznej obecności ludzika na polu - stąd
## "Przejmij teren gracza" żyje w panelu "Trasa ludzika"
## (`route_takeover_button`), pojawiając się TAM, gdzie zwykle "Zaanektuj",
## tylko dla pól należącego do innego gracza. Skoro dwóch różnych graczy nie
## może nigdy stać jednocześnie na tym samym heksie (`_blocked_hexes_for`
## blokuje ruch symetrycznie w obie strony), samo stanie na wrogim polu już
## DOWODZI, że broniący go ludzik akurat go nie patroluje - osobne
## sprawdzenie "funkcji obronnej" (sekcja 3 GDD) nie jest już potrzebne,
## efektywnie przeniosło się do blokady ruchu.
##
## Koszt MP jest identyczny jak przy aneksacji i pobierany od razu - w
## przeciwieństwie do aneksacji NIE jest zwracany przy porażce z powodu
## niewystarczającego prestiżu (`"insufficient_prestige"`), bo to wciąż
## realna próba z realną (choć inną) karą - patrz GameManager.attempt_takeover().
## Zwracany jest tylko przy "twardych" błędach (pole niczyje/już twoje).
func _on_takeover_pressed() -> void:
	var hex_id = selected_hex_id
	var ludzik = _find_own_ludzik_at(hex_id)
	if ludzik == null:
		info_label.text = "Musisz stać ludzikiem na polu %s, żeby przejąć je siłą." % hex_id
		return

	var cost = _effective_annex_cost_for(active_player.player_id)
	if not ludzik.spend_movement_points(cost):
		info_label.text = "Brak punktów ruchu na przejęcie terenu (koszt: %d)." % cost
		_refresh_action_panel()
		_refresh_route_panel()
		return

	var result = GameManager.attempt_takeover(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)
		info_label.text = "Przejęto %s (koszt: %d MP, -%d prestiżu; obrońca stracił %d prestiżu)." % [
			hex_id, cost, result["cost"], result["defender_loss"]
		]
		_refresh_map_view()
		_update_stats_labels()
	elif result["reason"] == "insufficient_prestige":
		info_label.text = (
			"Nieudana próba przejęcia %s - za mało prestiżu względem obrońcy (-%d prestiżu za ryzykowną próbę)."
			% [hex_id, result.get("attacker_penalty", 0)]
		)
		_update_stats_labels()
	else:
		ludzik.refund_movement_points(cost)
		var reason_text = {
			"no_owner": "pole nie ma właściciela - użyj Aneksacji.",
			"already_owner": "to już twoje pole.",
			"capital_protected": "stolica miasta jest chroniona przed przejęciem.",
		}.get(result["reason"], result["reason"])
		info_label.text = "Nie udało się przejąć %s (%s)." % [hex_id, reason_text]

	_update_mp_label()
	_refresh_action_panel()
	_refresh_route_panel()


## Czy zaznaczony heks da się przejąć siłą ludzikiem, który akurat go stoi -
## wspólna logika dla stanu przycisku "Przejmij teren gracza" w panelu
## "Trasa ludzika" (analogicznie do `_can_annex_selected_hex()`).
func _can_takeover_selected_hex() -> bool:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null or hex.owner_id == -1 or hex.owner_id == active_player.player_id or hex.is_capital:
		return false
	return _find_own_ludzik_at(selected_hex_id) != null


func _on_repair_pressed() -> void:
	var hex_id = selected_hex_id
	var result = GameManager.repair_building(hex_id, active_player.player_id)
	if result["success"]:
		info_label.text = "Naprawiono budynek na %s. Zacznie generować zasoby od kolejnej rundy." % hex_id
		if result.get("prestige_penalty", 0) > 0:
			info_label.text += " Strefa chroniona: kara prestiżowa -%d." % result["prestige_penalty"]
			_update_stats_labels()
	else:
		info_label.text = "Nie udało się naprawić budynku na %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


func _on_harvest_slider_changed(value: float) -> void:
	harvest_value_label.text = "%d%%" % int(value)


## Wydobycie lasu (Faza 5, sekcja 6.1 GDD) - działa na dowolnym, już
## zaanektowanym polu leśnym gracza, z dowolnej odległości (patrz komentarz
## na górze pliku); nie trzeba na nim stać.
func _on_harvest_pressed() -> void:
	var hex_id = selected_hex_id
	var percent = harvest_slider.value
	var result = GameManager.harvest_forest(hex_id, active_player.player_id, percent)
	if result["success"]:
		var msg = "Wydobyto %.1f drewna z %s." % [result["wood_gained"], hex_id]
		if result["prestige_penalty"] > 0:
			msg += " Kara prestiżowa: -%d (przekroczono próg %.0f%%)." % [
				result["prestige_penalty"], result["safe_threshold"]
			]
		info_label.text = msg
		_update_stats_labels()
		_refresh_map_view()
	else:
		info_label.text = "Nie udało się wydobyć drewna z %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


## --- Karta Miasta (Faza 8) ---

func _on_city_card_pressed() -> void:
	city_card_panel.open_for_player(active_player)


func _on_city_building_unlocked() -> void:
	_update_stats_labels()


## --- Drzewko Umiejętności (nowość, patrz komentarz na górze pliku) ---

func _on_skill_tree_pressed() -> void:
	skill_tree_panel.open_for_player(active_player)


## Reaguje na odblokowanie skilla w SkillTreePanel. Efekty "czysto danowe"
## (promień widzenia, próg bezpiecznej wycinki, koszt aneksacji, MP
## PRZYSZŁYCH ludzików) są już zaaplikowane na PlayerData przez
## GameManager.unlock_skill() - tu dopinamy tylko te dwa efekty, które
## wymagają dostępu do węzłów sceny, których GameManager celowo nie zna.
func _on_skill_unlocked(skill: SkillData) -> void:
	match skill.effect_type:
		SkillData.EffectType.EXTRA_LUDZIK:
			_recruit_extra_ludzik(active_player)
		SkillData.EffectType.MOVEMENT_POINTS_BONUS:
			# Bonus dla PRZYSZŁYCH ludzików już jest na PlayerData
			# (player.movement_points_bonus) - tu retroaktywnie podbijamy
			# JUŻ ISTNIEJĄCYCH, żeby efekt był odczuwalny od razu.
			var bonus = int(skill.effect_amount)
			for l in player_ludziks.get(active_player.player_id, []):
				l.movement_points_max += bonus
				l.movement_points_current += bonus
			_update_mp_label()
		_:
			pass  # VISION_RADIUS_BONUS / FOREST_THRESHOLD_BONUS / ANNEX_COST_REDUCTION - nic więcej do zrobienia tutaj
	_update_stats_labels()


## Skill "extra_ludzik" - rekrutuje kolejnego Ludzika w mieście startowym
## gracza. Model danych `player_ludziks: player_id -> Array[Ludzik]` był od
## początku na to przygotowany (patrz komentarz na górze pliku) - to
## pierwsze miejsce, które faktycznie z tego korzysta.
func _recruit_extra_ludzik(player: PlayerData) -> void:
	var setup = _find_player_setup(player.player_id)
	if setup.is_empty():
		return

	var ludzik = Ludzik.new()
	add_child(ludzik)
	ludzik.player_id = player.player_id
	ludzik.color = setup["color"]
	if setup.has("sprite") and ResourceLoader.exists(setup["sprite"]):
		ludzik.sprite_texture = load(setup["sprite"])
	ludzik.movement_points_max = GameBalance.LUDZIK_MOVEMENT_POINTS_MAX + player.movement_points_bonus
	ludzik.reset_movement_points()

	var spawn_hex_id: String = setup["start_hex"]
	if MapData.get_hex(spawn_hex_id) == null:
		spawn_hex_id = MapData.hexes.keys()[0]
	ludzik.place_on_hex(spawn_hex_id)

	if not player_ludziks.has(player.player_id):
		player_ludziks[player.player_id] = []
	player_ludziks[player.player_id].append(ludzik)

	_reveal_around(spawn_hex_id, player.player_id)
	_refresh_map_view()
	info_label.text = "Zrekrutowano drugiego ludzika w %s." % player.starting_city


func _find_player_setup(player_id: int) -> Dictionary:
	for setup in PLAYER_SETUP:
		if setup["id"] == player_id:
			return setup
	return {}


## --- Gracz aktywny i runda (rozdzielone - patrz turn_manager.gd) ---

func _on_player_selected(index: int) -> void:
	var player_id = player_selector.get_item_id(index)
	TurnManager.switch_to_player(player_id)


func _on_end_round_pressed() -> void:
	TurnManager.end_round()  # NIE zmienia, który gracz jest kontrolowany


## Aktualizuje panel akcji wg aktualnie ZAZNACZONEGO heksu (niekoniecznie
## tego, na którym stoi ludzik - patrz `selected_hex_id`). Tekst opisowy jest
## bramkowany mgłą wojny (te same 3 poziomy co `_on_hex_hovered()` niżej) -
## dopóki pole nie jest choć "seen", widać wyłącznie jego ID i typ terenu, bez
## etykiety/właściciela/budynku/poziomu zasobu. Przyciski akcji NIE są tu
## bramkowane - działają na prawdziwym stanie pola (żeby np. przejęcie
## terenu przeciwnika było w ogóle możliwe), tylko opis tekstowy chroni
## informację o tym, co się na nim znajduje.
func _refresh_action_panel() -> void:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null:
		hex_info_label.text = "Zaznacz pole (kliknij na mapie)."
		repair_button.disabled = true
		harvest_slider.visible = false
		harvest_value_label.visible = false
		harvest_button.visible = false
		return

	var fog = hex.get_fog_state(active_player.player_id)
	match fog:
		"unexplored":
			hex_info_label.text = "%s: nieodkryte pole." % hex.hex_id
		"seen":
			hex_info_label.text = "%s: teren %s (koszt ruchu %d) - nieznane zasoby/budynki." % [
				hex.hex_id, HexData.TerrainType.keys()[hex.terrain_type], hex.get_movement_cost()
			]
		"annexed":
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

	repair_button.disabled = not (is_owned_by_me and hex.building != null and hex.building_damaged)

	var is_forest = hex.is_forest()
	harvest_slider.visible = is_forest
	harvest_value_label.visible = is_forest
	harvest_button.visible = is_forest
	harvest_button.disabled = not is_owned_by_me


## Panel "Trasa ludzika" - widoczny tylko przy zaznaczonym ludziku, trzy
## stany trasy: (1) niepotwierdzony podgląd -> długość/koszt + Potwierdź/
## Anuluj; (2) trasa już zatwierdzona i w toku (mogła zostać wstrzymana
## brakiem MP albo blokadą - wróci do niej `_continue_all_queued_routes` na
## starcie kolejnej rundy) -> postęp + Anuluj; (3) nic zaplanowane ->
## podpowiedź. To JEDYNE miejsce, gdzie da się zaanektować/przejąć pole
## (oba przyciski usunięte z głównego panelu akcji, bo obie akcje wymagają
## fizycznej obecności). "Zaanektuj" i "Przejmij teren gracza" są wzajemnie
## wykluczające się (widoczny dokładnie jeden, zależnie od tego, czy
## zaznaczony heks jest niczyj czy wrogi) - stąd też przełącznik "Anektuj
## napotkane pola" (Ludzik.auto_annex), zaznaczający automatycznie KAŻDY
## niczyj heks, przez który ten ludzik przejdzie podczas wykonywania trasy
## (patrz _advance_queued_route/_auto_annex_hex).
func _refresh_route_panel() -> void:
	if selected_ludzik == null:
		route_panel.visible = false
		return

	route_panel.visible = true

	var hex = MapData.get_hex(selected_hex_id)
	var is_unclaimed = hex != null and hex.owner_id == -1
	var is_enemy_owned = hex != null and hex.owner_id != -1 and hex.owner_id != active_player.player_id

	route_annex_button.visible = is_unclaimed
	route_annex_button.disabled = not _can_annex_selected_hex()

	route_takeover_button.visible = is_enemy_owned
	route_takeover_button.disabled = not _can_takeover_selected_hex()
	# Koszt MP jest znany z góry (tyle co aneksacja), ale koszt prestiżowy
	# zależy od prestiżu OBROŃCY, którego nie widać w UI (sekcja "Decyzje
	# projektowe" w README) - stąd dymek celowo nie podaje dokładnej liczby.
	route_takeover_button.tooltip_text = (
		"Koszt: %d MP oraz nieznana liczba prestiżu (zależy od siły przeciwnika)."
		% _effective_annex_cost_for(active_player.player_id)
	)

	auto_annex_checkbox.button_pressed = selected_ludzik.auto_annex

	if preview_route_ludzik == selected_ludzik and preview_route.size() > 1:
		var cost = _route_cost(preview_route, selected_ludzik)
		var rounds = _route_rounds_needed(cost, selected_ludzik)
		var target_note = ""
		if preview_target_hex_id != "" and preview_route[-1] != preview_target_hex_id:
			target_note = " (najbliżej jak się da - %s jest zajęte przez przeciwnika)" % preview_target_hex_id
		route_info_label.text = (
			"Podgląd trasy do %s%s: %d pól, koszt %d MP - zajmie %s (masz %d MP)."
			% [
				preview_route[-1], target_note, preview_route.size() - 1, cost,
				_format_rounds(rounds), selected_ludzik.movement_points_current
			]
		)
		confirm_route_button.visible = true
		cancel_route_button.visible = true
		cancel_route_button.text = "Anuluj podgląd"
	elif not selected_ludzik.queued_route.is_empty():
		var remaining_cost = _remaining_route_cost(selected_ludzik.queued_route, selected_ludzik)
		var rounds = _route_rounds_needed(remaining_cost, selected_ludzik)
		var true_target = (
			selected_ludzik.route_destination if selected_ludzik.route_destination != ""
			else selected_ludzik.queued_route[-1]
		)
		var target_note = ""
		if true_target != selected_ludzik.queued_route[-1]:
			target_note = " (na razie do %s - %s jest zajęte przez przeciwnika)" % [selected_ludzik.queued_route[-1], true_target]
		route_info_label.text = "Trasa w toku do %s%s: pozostało %d pól, zajmie jeszcze %s." % [
			true_target, target_note, selected_ludzik.queued_route.size(), _format_rounds(rounds)
		]
		confirm_route_button.visible = false
		cancel_route_button.visible = true
		cancel_route_button.text = "Anuluj trasę"
	elif selected_ludzik.route_destination != "":
		route_info_label.text = (
			"Ludzik czeka na miejscu - pole %s jest obecnie zajęte przez przeciwnika. Trasa ruszy dalej automatycznie, gdy się zwolni."
			% selected_ludzik.route_destination
		)
		confirm_route_button.visible = false
		cancel_route_button.visible = true
		cancel_route_button.text = "Anuluj trasę"
	else:
		route_info_label.text = "Kliknij pole na mapie, żeby zaplanować trasę."
		confirm_route_button.visible = false
		cancel_route_button.visible = false


## Sumaryczny koszt MP przejścia `path` (pomija indeks 0 - to heks startowy,
## na którym ludzik już stoi, wejście na niego nic nie kosztuje).
func _route_cost(path: Array[String], ludzik: Ludzik) -> int:
	return _remaining_route_cost(path.slice(1), ludzik)


## Jak `_route_cost`, ale bez pomijania pierwszego elementu - do użycia na
## `Ludzik.queued_route`, który (w odróżnieniu od podglądu `preview_route`)
## NIE zawiera heksa startowego. Jeśli `ludzik.auto_annex` jest włączone
## ("Anektuj napotkane pola"), dolicza też koszt automatycznej aneksacji
## KAŻDEGO obecnie niczyjego pola na trasie - stąd trasa z włączonym
## auto-anektowaniem wychodzi droższa w MP, więc "musi czekać dłużej" (więcej
## rund, zanim faktycznie dotrze do celu). To oszacowanie z góry: faktyczna
## aneksacja po drodze może się nie udać (np. brak sąsiedztwa z już
## posiadanym polem - patrz GameManager.annex_hex), ale jako podgląd trasy
## jest wystarczająco dokładne.
func _remaining_route_cost(remaining: Array[String], ludzik: Ludzik) -> int:
	var total = 0
	var annex_cost = _effective_annex_cost_for(ludzik.player_id)
	for hex_id in remaining:
		var hex = MapData.get_hex(hex_id)
		if hex == null:
			continue
		total += hex.get_movement_cost()
		if ludzik.auto_annex and hex.owner_id == -1:
			total += annex_cost
	return total


## Liczba rund potrzebnych, żeby ludzik zdołał wydać `cost` punktów ruchu -
## 1, jeśli starczy AKTUALNYCH punktów w tej rundzie, inaczej ta runda plus
## tyle KOLEJNYCH pełnych rund (każda dająca `movement_points_max` świeżych
## punktów), ile trzeba na resztę. Używane do dokładnego wyświetlenia "zajmie
## X rund(ę)" zamiast dotychczasowego binarnego "starczy w tej rundzie" /
## "potrwa kilka rund".
func _route_rounds_needed(cost: int, ludzik: Ludzik) -> int:
	if cost <= ludzik.movement_points_current:
		return 1
	var remaining = cost - ludzik.movement_points_current
	var per_round = maxi(1, ludzik.movement_points_max)
	return 1 + (remaining + per_round - 1) / per_round


## Polska odmiana "rundę"/"rundy"/"rund" po liczebniku (np. "1 rundę",
## "3 rundy", "5 rund", "12 rund", "22 rundy").
static func _format_rounds(n: int) -> String:
	var word: String
	if n == 1:
		word = "rundę"
	elif n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		word = "rundy"
	else:
		word = "rund"
	return "%d %s" % [n, word]


func _update_mp_label() -> void:
	var ludzik = selected_ludzik
	if ludzik == null or ludzik.player_id != active_player.player_id:
		ludzik = _primary_ludzik_for(active_player.player_id)
	if ludzik == null:
		mp_label.text = "Punkty ruchu: -"
	else:
		mp_label.text = "Punkty ruchu: %d / %d" % [ludzik.movement_points_current, ludzik.movement_points_max]


## Prestiż + runda w jednej etykiecie, WSZYSTKIE zasoby gracza w drugiej
## (update - wcześniej pokazywało tylko drewno, reszta zdobytych surowców
## była niewidoczna w UI mimo że gracz faktycznie je posiadał).
func _update_stats_labels() -> void:
	prestige_label.text = "Prestiż: %d | Runda: %d" % [active_player.prestige, TurnManager.round_number]

	var parts: Array[String] = []
	for res_type in HexData.RESOURCE_DISPLAY_NAMES:
		var amount = active_player.get_resource_amount(res_type)
		parts.append("%s: %.0f" % [HexData.RESOURCE_DISPLAY_NAMES[res_type], amount])
	resources_label.text = "Surowce: " + " | ".join(parts)
