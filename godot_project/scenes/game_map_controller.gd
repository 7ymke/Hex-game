extends Node2D
## Phases 4-9 of the implementation plan (+ further fixes): smooth unit
## movement with pathfinding and fog, selecting/deselecting units, choosing
## the active player directly from a list, the City Card, and PvP territory
## takeover.
##
## Hotseat: up to 6 players on one screen (GDD section 7: "Multiplayer
## scale: 6 players simultaneously on one map, each in a different starting
## city"). The full map of Poland (data/map_data.json) has all 6 starting
## cities as real "city"-type hexes: Wrocław (H18), Szczecin (A7), Warszawa
## (R12), Kraków (O22), Gdańsk (L3), Poznań (G12) - PLAYER_SETUP below (an
## alias for scripts/player_setup.gd -> PlayerSetup.LIST, shared with the
## start screen) describes them. `_setup_players()` only registers the ones
## chosen on the start screen (scenes/start_screen.gd,
## GameSetup.selected_player_ids) - an empty list (e.g. when running
## main.tscn directly, skipping the start screen) means "all of them".
## Adding another player in the future (e.g. after extending the map with a
## new city) is just a new entry in PlayerSetup.LIST + buildings in
## city_buildings_data.gd - the rest (movement, fog, turns, PvP) is already
## written generically for any number of players.
##
## Data model `player_units: player_id -> Array[Unit]` (instead of a single
## node per player) is deliberately designed so that a future "more units"
## upgrade boils down to appending a new Unit to this array - everything
## else (selection, movement blocking) already iterates over arrays and
## doesn't assume exactly one element.
##
## Action range (update): annexation AND territory takeover BOTH REQUIRE
## standing exactly on the hex (they cost movement points of the unit
## standing there - the same amount as annexation) - both live on the
## floating Unit Card ("Karta ludzika", UI restyle - see ui/unit_card.gd),
## mutually exclusive (an unclaimed hex -> Zaanektuj/Annex, an enemy hex ->
## Przejmij teren gracza/Take over territory). Repair and harvest still work
## on any already-annexed hex (your own - repair, or your own - harvest),
## regardless of where units currently stand - "remote management" of your
## own territory, without needing physical presence.
##
## Control over the active player and round resolution are now completely
## separate: "Zmiana gracza" (the OptionButton) picks a SPECIFIC player
## directly from a list, "Zakończ rundę" resolves the round independent of
## who's currently in control - see turn_manager.gd.
##
## Multi-round route (update): clicking a hex with a unit selected no longer
## moves it right away - it computes and SHOWS a route preview (a yellow
## line on the map), waiting for confirmation on the Unit Card. Once
## confirmed, the route (`Unit.queued_route`) executes as many
## steps as the current MP allow (the line turns orange while it's in
## progress) - if the route is longer than a single round's worth of MP, the
## rest is remembered and continued AUTOMATICALLY after every subsequent
## "Zakończ rundę" (`_continue_all_queued_routes`), so it doesn't need to be
## clicked again.
##
## Skill tree (new): a separate screen (SkillTreePanel, analogous to the
## City Card) with 5 upgrades paid for with resources from the map
## (scripts/skill_tree_data.gd). "Pure data" effects (vision radius, safe
## harvesting threshold, annexation cost, MP for future units) are applied
## by GameManager.unlock_skill() on PlayerData; effects that need access to
## scene nodes (a new Unit, a retroactive MP bonus on existing ones) are
## applied by `_on_skill_unlocked()` here.

const VISION_RADIUS = GameBalance.VISION_RADIUS

## Hotseat starting players - id, name, city, base hex, token color. The
## full list (all 6 cities from GDD section 7) lives in
## scripts/player_setup.gd, so scenes/start_screen.gd can build checkboxes
## from it without duplicating data. Which lineup actually plays is decided
## by the start screen (see the comment above) - entries no longer need to
## be manually removed here to play with a smaller roster.
const PLAYER_SETUP = PlayerSetup.LIST

@onready var hex_map_view: HexMapView = $HexMapView
@onready var ambient_weather_view: AmbientWeatherView = $AmbientWeatherLayer/AmbientWeatherView
@onready var notifications_panel: NotificationsPanel = $NotificationsPanel
@onready var skill_tree_panel: SkillTreePanel = $SkillTreePanel
@onready var market_panel: MarketPanel = $MarketPanel
@onready var diplomacy_panel: DiplomacyPanel = $DiplomacyPanel

## UI restyle (UI_Gry_Makieta_11.html, "wood/BTD6" visual language) - top
## bar: round badge, resource pills, prestige/money chips. No movement
## points here - MP now lives EXCLUSIVELY on the Unit Card (see the
## "unit_card_*" group below), per the mockup's own legend. The round
## chip's "RUNDA" caption is static text now (no duplicate round number
## next to the badge - restyle spec 4.1), so it needs no @onready var.
@onready var info_label: Label = $UI/Root/InfoBar/InfoLabel
@onready var round_hex_label: Label = $UI/Root/TopBar/HBox/RoundChip/HexNumBadge/RoundNumberLabel
@onready var money_value_label: Label = $UI/Root/TopBar/HBox/MoneyChip/MoneyChipBg/MoneyChipBox/MoneyValueLabel
@onready var prestige_value_label: Label = $UI/Root/TopBar/HBox/PrestigeChip/PrestigeChipBg/PrestigeChipBox/PrestigeValueLabel

## One value label per resource type, in the same left-to-right order as
## the mockup. Nickel/Ropa aren't in the mockup at all (rare, late-game
## resources), but are always shown anyway ("zrób też aby było widać ile
## dostaje się Materiałów na rundę... Pamiętaj aby dodać do tego panelu 2
## brakujące zasoby") rather than only once the player has some - a full,
## always-visible 7-resource bar reads at a glance, instead of resources
## quietly appearing/disappearing as stock crosses zero.
@onready var resource_wood_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceWood/ResourceWoodBox/ResourceWoodValue
@onready var resource_food_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceFood/ResourceFoodBox/ResourceFoodValue
@onready var resource_copper_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceCopper/ResourceCopperBox/ResourceCopperValue
@onready var resource_coal_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceCoal/ResourceCoalBox/ResourceCoalValue
@onready var resource_gas_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceGas/ResourceGasBox/ResourceGasValue
@onready var resource_nickel_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceNickel/ResourceNickelBox/ResourceNickelValue
@onready var resource_oil_value: Label = $UI/Root/TopBar/HBox/ResourcesRow/ResourceOil/ResourceOilBox/ResourceOilValue

## The small green "+X" per-round production indicator next to each
## resource's value (restyle spec 4.1) - EXCEPT wood, which has none (the
## player decides how much to cut with the harvest slider, there's no
## automatic per-round income to preview). Computed by
## `_estimate_resource_production()`, mirroring
## TurnManager._process_resource_income()'s own logic exactly (season
## multiplier included), so the preview never drifts out of sync with what
## actually gets added at round end.
@onready var resource_production_labels: Dictionary = {
	HexData.ResourceType.FOOD: $UI/Root/TopBar/HBox/ResourcesRow/ResourceFood/ResourceFoodBox/ResourceFoodProd,
	HexData.ResourceType.COPPER: $UI/Root/TopBar/HBox/ResourcesRow/ResourceCopper/ResourceCopperBox/ResourceCopperProd,
	HexData.ResourceType.COAL: $UI/Root/TopBar/HBox/ResourcesRow/ResourceCoal/ResourceCoalBox/ResourceCoalProd,
	HexData.ResourceType.GAS: $UI/Root/TopBar/HBox/ResourcesRow/ResourceGas/ResourceGasBox/ResourceGasProd,
	HexData.ResourceType.NICKEL: $UI/Root/TopBar/HBox/ResourcesRow/ResourceNickel/ResourceNickelBox/ResourceNickelProd,
	HexData.ResourceType.OIL: $UI/Root/TopBar/HBox/ResourcesRow/ResourceOil/ResourceOilBox/ResourceOilProd,
}

## Clicking any resource pill opens its market page (autoloads/market_manager.gd,
## scenes/market_panel.gd) - see `_on_resource_row_gui_input()`. One pill
## per resource type, so the click handler knows which resource was clicked.
@onready var resource_rows: Dictionary = {
	HexData.ResourceType.WOOD: $UI/Root/TopBar/HBox/ResourcesRow/ResourceWood,
	HexData.ResourceType.FOOD: $UI/Root/TopBar/HBox/ResourcesRow/ResourceFood,
	HexData.ResourceType.COPPER: $UI/Root/TopBar/HBox/ResourcesRow/ResourceCopper,
	HexData.ResourceType.COAL: $UI/Root/TopBar/HBox/ResourcesRow/ResourceCoal,
	HexData.ResourceType.GAS: $UI/Root/TopBar/HBox/ResourcesRow/ResourceGas,
	HexData.ResourceType.NICKEL: $UI/Root/TopBar/HBox/ResourcesRow/ResourceNickel,
	HexData.ResourceType.OIL: $UI/Root/TopBar/HBox/ResourcesRow/ResourceOil,
}

## Sidebar (replaces the old ActionPanel). City landmark buildings are now
## bought directly here (`_build_building_preview_row()`) instead of in a
## separate modal - `CityCardIconButton` (the old 🏛 button that opened that
## modal) is gone; `InfoIconButton` ("i") opens `notifications_panel`
## instead (currently the only source of notifications is
## RandomEventManager - see below).
@onready var city_name_label: Label = $UI/Root/Sidebar/SidebarVBox/CityBlockMargin/CityBlockVBox/CityNameRow/CityNameLabel
@onready var info_button: Button = $UI/Root/Sidebar/SidebarVBox/CityBlockMargin/CityBlockVBox/CityNameRow/InfoIconButton
@onready var info_unread_badge: PanelContainer = $UI/Root/Sidebar/SidebarVBox/CityBlockMargin/CityBlockVBox/CityNameRow/InfoIconButton/UnreadBadge
@onready var info_unread_badge_label: Label = $UI/Root/Sidebar/SidebarVBox/CityBlockMargin/CityBlockVBox/CityNameRow/InfoIconButton/UnreadBadge/UnreadBadgeLabel
@onready var skill_tree_button: Button = $UI/Root/Sidebar/SidebarVBox/CityBlockMargin/CityBlockVBox/CityNameRow/SkillTreeButton
@onready var diplomacy_button: Button = $UI/Root/Sidebar/SidebarVBox/CityBlockMargin/CityBlockVBox/CityNameRow/DiplomacyButton
@onready var buildings_preview_list: VBoxContainer = $UI/Root/Sidebar/SidebarVBox/BuildingsBlockMargin/BuildingsBlockVBox/BuildingsScroll/BuildingList
@onready var repair_button: Button = $UI/Root/Sidebar/SidebarVBox/ActionRowMargin/ActionRow/RepairButton
## Random event "Pożar lasu" - only the affected player can extinguish it,
## same convention as `repair_button` (always visible, disabled unless the
## selected hex actually qualifies - see `_refresh_action_panel()`).
@onready var extinguish_fire_button: Button = $UI/Root/Sidebar/SidebarVBox/ActionRowMargin/ActionRow/ExtinguishFireButton
@onready var harvest_slider: HSlider = $UI/Root/Sidebar/SidebarVBox/HarvestBlockMargin/HarvestBlockVBox/HarvestSlider
@onready var harvest_value_label: Label = $UI/Root/Sidebar/SidebarVBox/HarvestBlockMargin/HarvestBlockVBox/HTitleRow/HarvestValueLabel
@onready var harvest_button: Button = $UI/Root/Sidebar/SidebarVBox/HarvestBlockMargin/HarvestBlockVBox/HarvestButton
@onready var player_selector: OptionButton = $UI/Root/Sidebar/SidebarVBox/SidebarBottom/SidebarBottomMargin/SidebarBottomHBox/PlayerSelector
@onready var end_round_button: Button = $UI/Root/Sidebar/SidebarVBox/SidebarBottom/SidebarBottomMargin/SidebarBottomHBox/EndRoundButton

## Floating hex-info panel (not in either mockup, which never depicts a
## hovered/selected-hex readout at all; added here so that information isn't
## lost from the pre-restyle UI, styled to match the tan/parchment language
## used elsewhere for floating cards).
@onready var hex_info_label: Label = $UI/Root/HexInfoPanel/HexInfoLabel

## Unit Card (UI restyle - a floating, draggable tan card over the map -
## see ui/unit_card.gd). `unit_card` itself only owns positioning/dragging/
## icons AND its own close button (see there, `closed` signal) - which of
## these fields show what text is still entirely decided here, in
## `_refresh_route_panel()`, exactly like before. No numeric MP label
## anymore - only the pips (restyle spec 4.3). Closing the card (X)
## deselects the unit instead of canceling the route -
## see `_on_unit_card_closed()`.
@onready var unit_card: UnitCard = $UI/UnitCard
@onready var unit_card_status_label: Label = $UI/UnitCard/Background/VBox/StatusLabel
@onready var unit_card_confirm_button: Button = $UI/UnitCard/Background/VBox/ConfirmButton
@onready var route_annex_button: Button = $UI/UnitCard/Background/VBox/Links/AnnexButton
@onready var route_takeover_button: Button = $UI/UnitCard/Background/VBox/Links/TakeoverButton
## Cancels a CONFIRMED, in-progress route - kept as its own link even
## though the restyle spec doesn't mention it (only the unconfirmed-preview
## cancel was explicitly reassigned to the close button); dropping the only
## way to cancel a route already under way read like an oversight rather
## than an intentional cut, so it stays - see the README.
@onready var cancel_route_link: Button = $UI/UnitCard/Background/VBox/Links/CancelRouteLink
@onready var auto_annex_toggle: Button = $UI/UnitCard/Background/VBox/Links/AutoAnnexToggle

var players: Array[PlayerData] = []
var player_units: Dictionary = {}  # player_id(int) -> Array[Unit]
var active_player: PlayerData

var selected_unit: Unit = null
var selected_hex_id: String = ""

## Route preview that is still UNCONFIRMED (see the comment at the top of
## the file) - transient UI state, not the unit's: `preview_route[0]` is
## always the current hex of `preview_route_unit`. A confirmed route lives
## on the unit itself (`Unit.queued_route`), because it must survive
## selection/player changes and subsequent rounds.
var preview_route: Array[String] = []
var preview_route_unit: Unit = null

## The true destination of the preview (may differ from `preview_route[-1]`
## if the destination is currently occupied by an enemy unit - see
## `_find_path_toward`).
var preview_target_hex_id: String = ""

var pathfinder = HexPathfinder.new()

## Which resource's market page is currently open, if any (NONE = closed) -
## drives the gold highlight on its pill in the top bar, matching the
## makieta's `.resource.active` (`border-color: gold-bright`).
var _active_market_resource: HexData.ResourceType = HexData.ResourceType.NONE
var _resource_pill_normal_style: StyleBox
var _resource_pill_active_style: StyleBoxFlat


func _ready() -> void:
	# SaveManager.pending_load_data (ustawione przez scenes/main_menu.gd przed
	# zmianą sceny, analogicznie do GameSetup.selected_player_ids) - puste,
	# jeśli gracz wybrał "Nowa gra" (albo main.tscn uruchomiono wprost, z
	# pominięciem menu). Odczytane i od razu wyczyszczone, żeby ponowne
	# wejście do tej sceny (bez przejścia przez menu) nie wczytało tego
	# samego zapisu drugi raz.
	var save_data: Dictionary = SaveManager.pending_load_data
	SaveManager.pending_load_data = {}
	if save_data.is_empty():
		_setup_players()
	else:
		_load_saved_game(save_data)
	_populate_player_selector()
	pathfinder.build()

	hex_map_view.hex_clicked.connect(_on_hex_clicked)
	hex_map_view.hex_hovered.connect(_on_hex_hovered)

	repair_button.pressed.connect(_on_repair_pressed)
	extinguish_fire_button.pressed.connect(_on_extinguish_fire_pressed)
	harvest_button.pressed.connect(_on_harvest_pressed)
	harvest_slider.value_changed.connect(_on_harvest_slider_changed)
	info_button.pressed.connect(_on_info_button_pressed)
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)
	diplomacy_button.pressed.connect(_on_diplomacy_button_pressed)
	player_selector.item_selected.connect(_on_player_selected)
	end_round_button.pressed.connect(_on_end_round_pressed)
	skill_tree_panel.skill_unlocked.connect(_on_skill_unlocked)
	market_panel.traded.connect(_on_market_traded)
	market_panel.closed.connect(_on_market_closed)
	RandomEventManager.notification_added.connect(_update_info_badge)

	# Active-pill highlight style is the pill's own StyleBoxFlat_pill_bg
	# (all rows share the same one, cached here so it can be reapplied
	# explicitly when a pill stops being active - remove_theme_stylebox_override()
	# would fall through to the theme's generic, unstyled PanelContainer
	# default instead, since the tscn-declared style IS itself just an
	# override, not a separate baked-in default) with just the border
	# swapped to gold-bright - a duplicate() rather than a new main.tscn
	# sub-resource, since it's a pure derived variant of the existing style.
	_resource_pill_normal_style = resource_rows[HexData.ResourceType.FOOD].get_theme_stylebox("panel")
	_resource_pill_active_style = _resource_pill_normal_style.duplicate() as StyleBoxFlat
	_resource_pill_active_style.border_color = Palette.GOLD_BRIGHT
	_resource_pill_active_style.border_width_left = 2
	_resource_pill_active_style.border_width_top = 2
	_resource_pill_active_style.border_width_right = 2
	_resource_pill_active_style.border_width_bottom = 2

	for resource in resource_rows:
		resource_rows[resource].gui_input.connect(_on_resource_row_gui_input.bind(resource))

	unit_card_confirm_button.pressed.connect(_on_confirm_route_pressed)
	unit_card.closed.connect(_on_unit_card_closed)
	cancel_route_link.pressed.connect(_on_cancel_route_pressed)
	route_annex_button.pressed.connect(_on_annex_pressed)
	route_takeover_button.pressed.connect(_on_takeover_pressed)
	auto_annex_toggle.toggled.connect(_on_auto_annex_toggled)

	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.round_ended.connect(_on_round_ended)

	var player_ids: Array[int] = []
	for p in players:
		player_ids.append(p.player_id)
	TurnManager.setup_player_order(player_ids)

	# Wczytana gra: setup_player_order() powyżej zawsze aktywuje
	# player_order[0] (patrz turn_manager.gd) - to przywraca właściwą rundę i
	# aktywnego gracza z zapisu, NADPISUJĄC ten domyślny wybór.
	if not save_data.is_empty():
		TurnManager.round_number = int(save_data.get("round_number", 1))
		TurnManager.switch_to_player(int(save_data.get("current_player_id", player_ids[0] if not player_ids.is_empty() else -1)))

	_on_harvest_slider_changed(harvest_slider.value)
	_refresh_route_panel()
	_refresh_buildings_preview()

	# Every HSlider's grabber is a hex, matching the mockup - Godot's Slider
	# theme only exposes the grabber as an ICON (Texture2D), not a StyleBox,
	# so it can't be declared in ui_theme.tres/main.tscn directly; generated
	# once here via HexShape's rasterizer instead (fill only, no border -
	# the rasterizer doesn't support strokes, a deliberate simplification,
	# see the README). The harvest slider's track no longer shows a
	# safe/danger color split (restyle spec 4.2 - the player discovers the
	# threshold by playing, not by reading the UI), so it's just a plain
	# StyleBoxFlat background now, no separate overlay Control needed.
	var harvest_grabber_icon = HexShape.make_texture(Vector2i(15, 13), Palette.TAN_2)
	harvest_slider.add_theme_icon_override("grabber", harvest_grabber_icon)
	harvest_slider.add_theme_icon_override("grabber_highlight", harvest_grabber_icon)
	harvest_slider.add_theme_icon_override("grabber_disabled", harvest_grabber_icon)

	var market_grabber_icon = HexShape.make_texture(Vector2i(17, 15), Palette.GOLD)
	market_panel.qty_slider.add_theme_icon_override("grabber", market_grabber_icon)
	market_panel.qty_slider.add_theme_icon_override("grabber_highlight", market_grabber_icon)
	market_panel.qty_slider.add_theme_icon_override("grabber_disabled", market_grabber_icon)


## Creates the players, their units, and annexes their starting hex. Only
## includes the cities chosen on the start screen
## (GameSetup.selected_player_ids, set by scenes/start_screen.gd) - an empty
## list (e.g. when running main.tscn directly, skipping the start screen)
## means "all of them", as before.
func _setup_players() -> void:
	# Nowa rozgrywka dostaje własne, osobne id zapisu (SaveManager) - dzięki
	# temu kolejne autosave'y (_on_round_ended()) trafiają do WŁASNEGO pliku
	# tej gry, a nie nadpisują zapis innej, wcześniejszej rozgrywki. Wczytana
	# gra NIE przechodzi przez tę funkcję (patrz _load_saved_game()) -
	# current_save_id ustawia wtedy SaveManager.load_game() samo.
	SaveManager.current_save_id = SaveManager.new_save_id()

	var existing_unit: Unit = $Unit
	var existing_unit_used = false
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

		var unit: Unit
		if not existing_unit_used:
			unit = existing_unit  # the scene already has one Unit node ready to go
			existing_unit_used = true
		else:
			unit = Unit.new()
			add_child(unit)
		_configure_unit(unit, player, setup)
		player_units[player.player_id] = [unit]

		var start_hex_id = _resolve_start_hex(setup, player.player_name)

		# `require_adjacency = false`: the player doesn't own anything yet,
		# so the usual "annex only next to your own territory" requirement
		# would be impossible to satisfy here - see GameManager.annex_hex().
		# The capital is also permanently marked as protected from a forced
		# takeover (PvP) - GameManager.attempt_takeover().
		GameManager.annex_hex(start_hex_id, player.player_id, false)
		MapData.get_hex(start_hex_id).is_capital = true
		unit.place_on_hex(start_hex_id)
		_reveal_around(start_hex_id, player.player_id)


## Odpowiednik `_setup_players()` dla wczytanej gry (SaveManager -
## "Chcę abyś dodał... system saveowania gry") - zamiast tworzyć graczy/
## jednostki od zera, odtwarza je z `data` (autoloads/save_manager.gd,
## SaveManager.load_game()). Wypełnia te same `players`/`player_units`, więc
## reszta `_ready()` (populate player selector, setup_player_order...)
## działa identycznie niezależnie od tego, która z tych dwóch funkcji
## zadziałała.
##
## Tożsamość gracza (imię/miasto/kolor, sprite jednostki) NIE jest w
## zapisie - odczytywana z powrotem z PLAYER_SETUP po player_id, dokładnie
## jak w `_setup_players()` (patrz komentarz w save_manager.gd).
##
## Liczby z JSON wracają jako float (patrz save_manager.gd) - każde miejsce,
## które ma być int, jawnie rzutuje int(...).
func _load_saved_game(data: Dictionary) -> void:
	var existing_unit: Unit = $Unit
	var existing_unit_used = false

	var saved_players: Dictionary = data.get("players", {})
	for player_id_str in saved_players:
		var player_id = int(player_id_str)
		var setup = _find_player_setup(player_id)
		if setup.is_empty():
			continue
		var saved_player: Dictionary = saved_players[player_id_str]

		var player = PlayerData.new()
		player.player_id = player_id
		player.player_name = setup["name"]
		player.starting_city = setup["city"]
		player.color = setup["color"]
		player.prestige = int(saved_player.get("prestige", 100))
		player.money = saved_player.get("money", 200.0)
		for res_type_str in saved_player.get("resources", {}):
			player.resources[int(res_type_str)] = saved_player["resources"][res_type_str]
		var unlocked_city_buildings: Array[String] = []
		for building_name in saved_player.get("unlocked_city_buildings", []):
			unlocked_city_buildings.append(building_name)
		player.unlocked_city_buildings = unlocked_city_buildings
		var unlocked_skills: Array[String] = []
		for skill_id in saved_player.get("unlocked_skills", []):
			unlocked_skills.append(skill_id)
		player.unlocked_skills = unlocked_skills
		player.movement_points_bonus = int(saved_player.get("movement_points_bonus", 0))
		player.vision_radius_bonus = int(saved_player.get("vision_radius_bonus", 0))
		player.forest_safe_threshold_bonus = saved_player.get("forest_safe_threshold_bonus", 0.0)
		player.annex_cost_reduction = int(saved_player.get("annex_cost_reduction", 0))
		player.road_infrastructure = saved_player.get("road_infrastructure", false)

		GameManager.register_player(player)
		players.append(player)
		player_units[player.player_id] = []

	var saved_hexes: Dictionary = data.get("hexes", {})
	for hex_id in saved_hexes:
		var hex = MapData.get_hex(hex_id)
		if hex == null:
			continue
		var saved_hex: Dictionary = saved_hexes[hex_id]

		hex.owner_id = int(saved_hex.get("owner_id", -1))
		hex.resource_level = saved_hex.get("resource_level", 100.0)
		hex.generates_prestige = saved_hex.get("generates_prestige", true)
		hex.building_damaged = saved_hex.get("building_damaged", false)
		hex.is_capital = saved_hex.get("is_capital", false)
		hex.is_on_fire = saved_hex.get("is_on_fire", false)

		hex.fog_state.clear()
		for player_id_str in saved_hex.get("fog_state", {}):
			hex.fog_state[int(player_id_str)] = int(saved_hex["fog_state"][player_id_str])

	for saved_unit: Dictionary in data.get("units", []):
		var player_id = int(saved_unit["player_id"])
		var player = GameManager.get_player(player_id)
		var setup = _find_player_setup(player_id)
		if player == null or setup.is_empty():
			continue

		var unit: Unit
		if not existing_unit_used:
			unit = existing_unit  # the scene already has one Unit node ready to go
			existing_unit_used = true
		else:
			unit = Unit.new()
			add_child(unit)
		_configure_unit(unit, player, setup)
		unit.place_on_hex(saved_unit["current_hex_id"])
		unit.movement_points_max = int(saved_unit.get("movement_points_max", GameBalance.UNIT_MOVEMENT_POINTS_MAX))
		unit.movement_points_current = int(saved_unit.get("movement_points_current", unit.movement_points_max))
		unit.auto_annex = saved_unit.get("auto_annex", false)

		if not player_units.has(player_id):
			player_units[player_id] = []
		player_units[player_id].append(unit)

	MarketManager.load_save_state(data.get("market", {}))
	RandomEventManager.load_save_state(data.get("events", {}))
	DiplomacyManager.load_save_state(data.get("diplomacy", {}))


## Sets `unit`'s visual data/owner from the `setup` entry (color, optional
## image) - shared by `_setup_players()` (starting players, the unit may
## already be an existing scene node) and `_recruit_extra_unit()` (the
## "extra_unit" skill, the unit is always freshly created). Does NOT create
## the node or add it to the scene tree - that's up to the caller.
func _configure_unit(unit: Unit, player: PlayerData, setup: Dictionary) -> void:
	unit.player_id = player.player_id
	unit.color = setup["color"]
	if setup.has("sprite") and ResourceLoader.exists(setup["sprite"]):
		unit.sprite_texture = load(setup["sprite"])


## `setup["start_hex"]`, with a fallback to any existing hex in case the map
## data doesn't contain the expected ID (shouldn't happen with correct data,
## but it's better to get some hex with a console warning than to crash on
## null). Shared by `_setup_players()` and `_recruit_extra_unit()`.
func _resolve_start_hex(setup: Dictionary, player_name: String) -> String:
	var hex_id: String = setup["start_hex"]
	if MapData.get_hex(hex_id) == null:
		push_warning("GameMapController: starting hex %s not found for %s" % [hex_id, player_name])
		hex_id = MapData.hexes.keys()[0]
	return hex_id


## Item ID in the OptionButton = player_id, so the choice doesn't depend on
## ordering.
func _populate_player_selector() -> void:
	player_selector.clear()
	for p in players:
		player_selector.add_item("%s (%s)" % [p.player_name, p.starting_city], p.player_id)


func _primary_unit_for(player_id: int) -> Unit:
	var list: Array = player_units.get(player_id, [])
	return list[0] if not list.is_empty() else null


func _find_own_unit_at(hex_id: String) -> Unit:
	for u in player_units.get(active_player.player_id, []):
		if u.current_hex_id == hex_id:
			return u
	return null


## Hexes currently occupied by OTHER players' units - GDD section 3,
## "defensive function": as long as they stand there, no one can pass
## through or land on that hex.
func _blocked_hexes_for(player_id: int) -> Array[String]:
	var blocked: Array[String] = []
	for pid in player_units:
		if pid == player_id:
			continue
		for u in player_units[pid]:
			blocked.append(u.current_hex_id)
	return blocked


## The unit (of any player) currently standing exactly on `hex_id`, if any.
## Used to enforce the "defensive function" (GDD section 3) during territory
## takeover - distinct from `_blocked_hexes_for`, which deliberately skips a
## player's OWN units (since they don't block the player themselves).
func _unit_at(hex_id: String) -> Unit:
	for pid in player_units:
		for u in player_units[pid]:
			if u.current_hex_id == hex_id:
				return u
	return null


func _set_selected_unit(unit: Unit) -> void:
	if selected_unit == unit:
		return
	if selected_unit != null:
		selected_unit.set_selected(false)
	selected_unit = unit
	if selected_unit != null:
		selected_unit.set_selected(true)

	# Changing the selected unit drops its (not yet confirmed) route preview
	# - a confirmed, in-progress route (`queued_route`) stays untouched,
	# since it lives on the unit itself, not here.
	preview_route = []
	preview_route_unit = null
	preview_target_hex_id = ""
	hex_map_view.preview_route_hex_ids = []


func _set_selected_hex(hex_id: String) -> void:
	selected_hex_id = hex_id
	hex_map_view.selected_hex_id = hex_id
	_refresh_map_view()


func _on_player_turn_started(player_id: int) -> void:
	active_player = GameManager.get_player(player_id)
	hex_map_view.viewing_player_id = player_id
	_set_selected_unit(null)

	var selector_index = player_selector.get_item_index(player_id)
	if selector_index != -1:
		player_selector.select(selector_index)  # does not emit item_selected

	var primary = _primary_unit_for(player_id)
	_set_selected_hex(primary.current_hex_id if primary != null else "")

	# Which player is "in control" is no longer a separate label (UI
	# restyle) - the sidebar's city name IS that indicator, since every
	# player has exactly one, unique starting city (see the comment on
	# `_update_stats_labels()`).
	info_label.text = "Kliknij ludzika, żeby go zaznaczyć/odznaczyć, potem kliknij pole, żeby go tam przesunąć."

	_refresh_map_view()
	ambient_weather_view.refresh()
	_update_mp_label()
	_update_stats_labels()
	_refresh_action_panel()
	_refresh_route_panel()
	_refresh_buildings_preview()
	_maybe_popup_notifications()


## After a round is resolved, fresh movement points let all confirmed but
## not yet fully executed routes continue automatically
## (`_continue_all_queued_routes`) - hence a route can "run across several
## rounds" without being clicked again.
func _on_round_ended(round_number: int) -> void:
	for pid in player_units:
		for u in player_units[pid]:
			u.reset_movement_points()
	_update_mp_label()
	_update_stats_labels()
	# Random events (RandomEventManager) can change a player's money/resources
	# between rounds (Dotacja, Inspekcja środowiskowa...) - refresh so the
	# Sidebar's "Odblokuj" buttons never show a stale afford/can't-afford state.
	_refresh_buildings_preview()
	var season_name = GameBalance.SEASON_DISPLAY_NAMES[TurnManager.get_current_season()]
	info_label.text = "Runda zakończona. Rozpoczyna się runda %d (%s)." % [round_number, season_name]
	await _continue_all_queued_routes()
	_refresh_map_view()
	ambient_weather_view.refresh()
	_refresh_action_panel()
	_maybe_popup_notifications()
	_refresh_route_panel()
	# Autosave (SaveManager) - tu, a nie w TurnManager.end_round() samym, bo
	# scenes/main_test.gd (smoke testy) woła end_round() bezpośrednio, bez tej
	# klasy w ogóle - autosave należy do warstwy rozgrywki (ta scena), nie do
	# czystej logiki tury.
	SaveManager.save_game()


func _on_hex_clicked(hex_id: String) -> void:
	var own_unit = _find_own_unit_at(hex_id)

	if own_unit != null:
		# Clicking your own unit -> select it (or deselect, if it was
		# already selected).
		_set_selected_unit(null if selected_unit == own_unit else own_unit)
	elif selected_unit != null and not selected_unit.is_moving:
		# Clicking elsewhere with a unit selected -> ONLY previews the route
		# (a yellow line), NOT a move order - see the Unit Card.
		_preview_route_to(selected_unit, hex_id)

	_set_selected_hex(hex_id)
	_refresh_action_panel()
	_refresh_route_panel()


## Computes a route from `from_hex_id` to `target_hex_id`, taking `blocked`
## into account (hexes occupied by enemy units - see `_blocked_hexes_for`).
## If `target_hex_id` itself is blocked (an enemy unit is standing exactly
## on the destination), instead of returning "no route" it looks for the
## NEAREST reachable neighbor of the destination - this lets the player
## select an enemy-occupied hex as a route target: the unit will get as
## close as it can and wait (see `_recompute_route`) until the enemy moves
## or the player cancels the route. Returns an empty array if there's no
## route even to any neighbor.
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


## Computes a route to `target_hex_id` and shows it as a preview (does not
## move the unit) - overwrites the previous, still-unconfirmed preview. Does
## NOT touch a confirmed, in-progress route (`unit.queued_route`) until the
## player confirms this new preview on the Unit Card. The destination may
## currently be occupied by an enemy unit (see `_find_path_toward`) -
## `preview_target_hex_id` then differs from the actual end of
## `preview_route`, and the label explains that this is only "as close as
## possible".
func _preview_route_to(unit: Unit, target_hex_id: String) -> void:
	preview_route = []
	preview_route_unit = null
	preview_target_hex_id = ""
	hex_map_view.preview_route_hex_ids = []

	if target_hex_id == unit.current_hex_id:
		return

	var blocked = _blocked_hexes_for(unit.player_id)
	var path = _find_path_toward(unit.current_hex_id, target_hex_id, blocked)
	if path.size() < 2:
		info_label.text = "Brak dostępnej trasy do %s." % target_hex_id
		return

	preview_route = path
	preview_route_unit = unit
	preview_target_hex_id = target_hex_id
	hex_map_view.preview_route_hex_ids = preview_route

	if path[-1] != target_hex_id:
		info_label.text = (
			"Pole %s jest zajęte przez wrogiego ludzika - podgląd trasy do najbliższego osiągalnego pola (%s); ludzik zaczeka, aż cel się zwolni."
			% [target_hex_id, path[-1]]
		)
	else:
		info_label.text = (
			"Podgląd trasy do %s - potwierdź na Karcie ludzika, żeby ludzik ruszył." % target_hex_id
		)


func _on_confirm_route_pressed() -> void:
	if preview_route_unit == null or preview_route.size() < 2:
		return

	var unit = preview_route_unit
	unit.queued_route = preview_route.slice(1)
	unit.route_destination = preview_target_hex_id
	preview_route = []
	preview_route_unit = null
	preview_target_hex_id = ""
	hex_map_view.preview_route_hex_ids = []

	info_label.text = "Trasa zatwierdzona - ludzik rusza."
	_advance_queued_route(unit)  # fire-and-forget, like the old _command_move
	_refresh_map_view()
	_refresh_route_panel()


## Cancels a CONFIRMED, in-progress route (`cancel_route_link` - only ever
## visible while one exists, see `_refresh_route_panel()`). Canceling an
## unconfirmed PREVIEW is a separate concern now, handled by closing the
## Unit Card entirely (`_on_unit_card_closed()`) - see the comment on
## `cancel_route_link`'s declaration up top for why the two are split.
func _on_cancel_route_pressed() -> void:
	if selected_unit == null:
		return
	selected_unit.queued_route = []
	selected_unit.route_destination = ""
	info_label.text = "Trasa anulowana."

	_refresh_map_view()
	_refresh_route_panel()


## The Unit Card's close button (X, top-right corner) - closes the card by
## deselecting the unit, which as an existing side effect of
## `_set_selected_unit(null)` also clears any unconfirmed route PREVIEW.
## Does NOT touch a confirmed, in-progress route (`Unit.queued_route`) -
## that keeps running in the background exactly as before, per the restyle
## spec: "X zamyka kartę, nie anuluje trasę".
func _on_unit_card_closed() -> void:
	_set_selected_unit(null)
	_refresh_map_view()
	_refresh_action_panel()
	_refresh_route_panel()


## Continues ALL confirmed but not yet fully executed routes (of any player
## - hotseat, everyone shares the same round timeline) with fresh movement
## points - called after every round is resolved, so a route actually
## "keeps going" across rounds without being clicked again. Before
## continuing, RECOMPUTES the route (`_recompute_route`) for every unit with
## a `route_destination` set - if an opponent has moved (uncovering a
## previously blocked destination, or blocking the route so far), the route
## reacts to that automatically, with no manual intervention. Besides
## continuing actual routes (`queued_route` non-empty), this also calls
## `_advance_queued_route()` for a unit with NO active route, if it happens
## to be standing on a hex waiting for auto-annexation
## (`_current_hex_needs_auto_annex()`) - see the comment on
## `_advance_queued_route()` for why this is a separate condition,
## independent of `queued_route`/`route_destination` (e.g. a unit stuck for
## lack of MP exactly ON its route destination, with no further steps left
## in `queued_route`).
func _continue_all_queued_routes() -> void:
	for pid in player_units:
		for u in player_units[pid]:
			if u.route_destination != "":
				_recompute_route(u)
			if not u.queued_route.is_empty() or _current_hex_needs_auto_annex(u):
				await _advance_queued_route(u)


## Recomputes a unit's route to its true destination (`route_destination`)
## from scratch, with current blocking - called at the start of every round
## (`_continue_all_queued_routes`). Handles three situations: (1) the unit is
## already standing on the destination AND there's nothing left to annex
## there -> route complete; (2) there's a path (even a partial one, to the
## nearest reachable hex, if the destination is still blocked) ->
## `queued_route` gets a fresh path; (3) there's no path at all (e.g. the
## unit itself is surrounded) -> `queued_route` stays empty, the unit waits
## in place and tries again next round.
func _recompute_route(unit: Unit) -> void:
	if unit.route_destination == "" or unit.is_moving:
		return

	if unit.current_hex_id == unit.route_destination:
		# Arrived - BUT if this hex is still waiting for auto-annexation
		# (ran out of MP last round), the route is NOT finished yet -
		# `route_destination` stays set, so `_continue_all_queued_routes()`
		# keeps calling `_advance_queued_route()` every round until there's
		# enough MP to annex (see there).
		if not _current_hex_needs_auto_annex(unit):
			unit.route_destination = ""
			unit.queued_route = []
		return

	var blocked = _blocked_hexes_for(unit.player_id)
	var path = _find_path_toward(unit.current_hex_id, unit.route_destination, blocked)
	if path.size() < 2:
		unit.queued_route = []
		return

	unit.queued_route = path.slice(1)


## Executes (the next leg of) a confirmed route, as many steps as the
## CURRENT movement points allow - the rest stays in `unit.queued_route` to
## continue next round. Re-checks passability and blocking by another
## player's unit on EVERY step (not just when planning the preview) - a
## route may wait several rounds before executing, and the situation on the
## hex may have changed in the meantime.
##
## Annexing the hex the unit is CURRENTLY standing on takes PRIORITY over
## further movement - checked at the START of EVERY loop iteration (not
## just once at the start of the function), so it also covers a hex the
## unit just entered in THIS SAME round: "enter and annex" still happens as
## one sequence within a SINGLE round when there's enough MP for both, and
## only splits across two rounds when there truly isn't enough MP for the
## annexation itself - the unit has already taken a step forward instead of
## sitting idle (update - a fixed bug: previously "enter the hex +
## annexation" was ONE inseparable action checked BEFORE moving, so when MP
## was short only for the annexation, the unit didn't move AT ALL - wasting
## that round's movement points, which are lost for good at round's end
## anyway, instead of at least taking a step closer to the goal). A hex that
## doesn't qualify for annexation for some other reason (e.g. no adjacency)
## doesn't block movement - there's nothing to wait for.
##
## The same logic also handles a unit with NO movement left to do
## (`queued_route` empty) - in that case the function ONLY tries to annex
## the current hex (see `_current_hex_needs_auto_annex`/
## `_continue_all_queued_routes`, which still call it in that situation) -
## this covers both a hex that is the true route destination (arrived, but
## ran out of MP to annex it last round), and a unit with no active route at
## all that happens to be standing on a qualifying hex (e.g. another unit of
## the same player annexed a neighbor in the meantime).
func _advance_queued_route(unit: Unit) -> void:
	if unit.is_moving:
		return
	if unit.queued_route.is_empty() and not _current_hex_needs_auto_annex(unit):
		return

	unit.is_moving = true
	while true:
		if _current_hex_needs_auto_annex(unit):
			var annex_cost_here = _effective_annex_cost_for(unit.player_id)
			if unit.movement_points_current < annex_cost_here:
				info_label.text = (
					"Brak punktów ruchu na aneksację %s (potrzeba %d MP) - spróbuje ponownie w kolejnej rundzie."
					% [unit.current_hex_id, annex_cost_here]
				)
				break
			_auto_annex_hex(unit, unit.current_hex_id)
			_update_mp_label()
			# No _refresh_map_view() here - that's a purely visual refresh
			# that will happen anyway, either with the refresh after the
			# next movement step below, or (if this was the last action this
			# round) in the guaranteed _refresh_map_view() at the end of the
			# function; nothing yields control to the renderer between these
			# two points, so an extra call here wouldn't change anything
			# actually visible on screen - it would just duplicate
			# _update_unit_visibility()/_update_route_overlay().
			continue  # re-check from scratch - another hex might now qualify (not this one), or it may be possible to move on

		if unit.queued_route.is_empty():
			break

		var next_hex_id: String = unit.queued_route[0]
		var next_hex = MapData.get_hex(next_hex_id)

		if next_hex == null or not next_hex.is_passable():
			info_label.text = "Trasa przerwana: pole %s jest niedostępne dla ruchu." % next_hex_id
			unit.queued_route = []
			break

		var blocker = _unit_at(next_hex_id)
		if blocker != null and blocker.player_id != unit.player_id:
			info_label.text = "Trasa wstrzymana: pole %s jest bronione przez ludzika innego gracza." % next_hex_id
			break  # queued_route stays - will try again next round

		var move_cost = _effective_movement_cost_for(next_hex, unit.player_id)
		if unit.movement_points_current < move_cost:
			info_label.text = "Brak punktów ruchu - trasa będzie kontynuowana w kolejnej rundzie."
			break

		unit.spend_movement_points(move_cost)

		await unit.animate_to_hex(next_hex_id)
		unit.queued_route.remove_at(0)
		_reveal_around(next_hex_id, unit.player_id)

		_update_mp_label()
		_refresh_map_view()
		# The next loop iteration will immediately check
		# `_current_hex_needs_auto_annex()` for the hex the unit just
		# entered - if there's enough MP, it annexes it in THIS SAME round,
		# before trying to move on (see the function comment).

	unit.is_moving = false
	if unit == selected_unit:
		_set_selected_hex(unit.current_hex_id)
	if unit.route_destination != "" and unit.queued_route.is_empty():
		if unit.current_hex_id == unit.route_destination:
			if not _current_hex_needs_auto_annex(unit):
				unit.route_destination = ""
				info_label.text = "Ludzik dotarł do celu trasy (%s)." % unit.current_hex_id
			# Otherwise it arrived but is still waiting on MP to annex this
			# hex - `route_destination` stays set, `info_label` already has
			# the right message set above in the loop ("Brak punktów ruchu
			# na aneksację...").
		elif not _current_hex_needs_auto_annex(unit):
			info_label.text = (
				"Ludzik dotarł najbliżej jak się dało (%s) - czeka, aż pole %s stanie się osiągalne."
				% [unit.current_hex_id, unit.route_destination]
			)
			# Otherwise (`_current_hex_needs_auto_annex` == true) the unit
			# stopped here NOT because the destination is occupied, but
			# because it ran out of MP to annex THIS hex - `info_label`
			# already has the right message set above in the loop ("Brak
			# punktów ruchu na aneksację..."); don't overwrite it with a
			# misleading message about waiting for the destination to free up.
	_refresh_action_panel()
	_refresh_route_panel()
	_refresh_map_view()


## Reveals fog within the vision radius (GDD section 2.2) - a BFS over
## actual neighbors, so the number of "hops" matches the hex distance
## exactly. The base radius (VISION_RADIUS) is increased by any bonus the
## player has from the skill tree (the "reconnaissance" skill).
func _reveal_around(center_hex_id: String, player_id: int) -> void:
	var center = MapData.get_hex(center_hex_id)
	if center == null:
		return

	center.set_fog_state(
		player_id,
		HexData.FogState.ANNEXED if center.owner_id == player_id else HexData.FogState.SEEN
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
			if hex != null and hex.get_fog_state(player_id) == HexData.FogState.UNEXPLORED:
				hex.set_fog_state(player_id, HexData.FogState.SEEN)
			queue.append(n)


## Refreshes the hex grid, enemy unit visibility, AND the in-progress route
## overlay - these go together, since they all depend on state that may have
## just changed (fog, unit position, route progress). Use this instead of
## calling hex_map_view.queue_redraw() directly.
func _refresh_map_view() -> void:
	_update_unit_visibility()
	_update_route_overlay()
	hex_map_view.queue_redraw()


## The in-progress (already confirmed) route of the selected unit - always
## drawn, regardless of whether a step animation is currently playing or
## it's waiting for the next round (see the comment at the top of the file).
func _update_route_overlay() -> void:
	if selected_unit != null and not selected_unit.queued_route.is_empty():
		# NOTE: deliberately NOT `[a] + selected_unit.queued_route` -
		# concatenating an untyped Array literal with an Array[String] using
		# the `+` operator can throw a runtime typing error in Godot 4.2.
		# `append_array()` on an explicitly typed variable is safe.
		var full_route: Array[String] = [selected_unit.current_hex_id]
		full_route.append_array(selected_unit.queued_route)
		hex_map_view.queued_route_hex_ids = full_route
	else:
		hex_map_view.queued_route_hex_ids = []


## An enemy unit is visible ONLY on a hex that the active (viewing) player
## has already discovered - fog_state != FogState.UNEXPLORED. It doesn't
## need to be fully explored or annexed, it's enough for the hex to have
## once been within vision range (VISION_RADIUS) of one of your units -
## exactly the same threshold as revealing the terrain itself (GDD section
## 2.2). Your own units are always visible.
func _update_unit_visibility() -> void:
	if active_player == null:
		return

	for pid in player_units:
		var is_own = pid == active_player.player_id
		for u in player_units[pid]:
			if is_own:
				u.visible = true
				continue
			var hex = MapData.get_hex(u.current_hex_id)
			u.visible = hex != null and hex.get_fog_state(active_player.player_id) != HexData.FogState.UNEXPLORED


func _on_hex_hovered(hex_id: String) -> void:
	if hex_id == "" or active_player == null:
		return
	var hex = MapData.get_hex(hex_id)
	if hex == null:
		return

	var fog = hex.get_fog_state(active_player.player_id)
	match fog:
		HexData.FogState.UNEXPLORED:
			pass  # we show nothing - per the two-level fog rule
		HexData.FogState.SEEN:
			info_label.text = _describe_seen_hex(hex)
		HexData.FogState.ANNEXED:
			info_label.text = "%s: %s | teren: %s | budynek: %s | właściciel: %s" % [
				hex_id, hex.label_raw, HexData.TerrainType.keys()[hex.terrain_type],
				_describe_building(hex), _describe_owner(hex)
			]


## Description of a hex visible at the SEEN fog level (terrain type visible,
## not resources/buildings/owner) - shared by the hover tooltip
## (`_on_hex_hovered`) and the floating hex-info panel (`_refresh_action_panel`),
## so both always show exactly as much as the fog currently allows.
static func _describe_seen_hex(hex: HexData) -> String:
	return "%s: teren %s (koszt ruchu %d) - nieznane zasoby/budynki." % [
		hex.hex_id, HexData.TerrainType.keys()[hex.terrain_type], hex.get_movement_cost()
	]


## A hex's owner as text (ANNEXED hexes) - shared by the hover tooltip and
## the floating hex-info panel, which just arrange it differently in a sentence.
static func _describe_owner(hex: HexData) -> String:
	return "gracz %d" % hex.owner_id if hex.owner_id != -1 else "niczyj"


## A hex's building as text (ANNEXED hexes) - like `_describe_owner`.
static func _describe_building(hex: HexData) -> String:
	if hex.building == null:
		return "brak"
	return "%s (%s)" % [
		hex.building.building_name,
		"USZKODZONY" if hex.building_damaged else "sprawny"
	]


## --- Field actions (Phases 5, 8, 9) ---
## Act on `selected_hex_id`. Annexation and territory takeover (update)
## require a unit of the active player to stand exactly on that hex; Repair
## and Harvest still work on any already-annexed OWN hex, from any distance.

## UI refresh shared by EVERY way a unit action requiring physical presence
## (Zaanektuj/annex or Przejmij teren gracza/take over territory) can end
## (an early MP shortfall, success, OR failure) - MP and the hex's state may
## have changed, so the label and both panels need to keep up. Does not
## refresh `_refresh_map_view()`/`_update_stats_labels()` - those only apply
## to some outcomes (see the calls in `_on_annex_pressed`/
## `_on_takeover_pressed`), not every one.
func _refresh_unit_action_ui() -> void:
	_update_mp_label()
	_refresh_action_panel()
	_refresh_route_panel()


## The only place a player issues an annexation command - the button now
## lives EXCLUSIVELY on the Unit Card (`route_annex_button`), not the
## sidebar (removed from there - annexation is a unit's action, not a
## general action on the selected hex, unlike Take over/Repair/Harvest,
## which don't require physical presence).
func _on_annex_pressed() -> void:
	var hex_id = selected_hex_id
	var unit = _find_own_unit_at(hex_id)
	if unit == null:
		info_label.text = "Musisz stać ludzikiem na polu %s, żeby je zaanektować." % hex_id
		return

	var annex_cost = _effective_annex_cost_for(active_player.player_id)
	if not unit.spend_movement_points(annex_cost):
		info_label.text = "Brak punktów ruchu na aneksację (koszt: %d)." % annex_cost
		_refresh_unit_action_ui()
		return

	var result = GameManager.annex_hex(hex_id, active_player.player_id)
	if result["success"]:
		_reveal_around(hex_id, active_player.player_id)  # SEEN -> ANNEXED + reveals the building
		info_label.text = "Zaanektowano %s (koszt: %d MP)." % [hex_id, annex_cost]
		_refresh_map_view()
	else:
		unit.refund_movement_points(annex_cost)
		var reason_text = {
			"not_adjacent": "pole musi sąsiadować z już posiadanym.",
			"already_owned": "pole ma już właściciela.",
		}.get(result["reason"], result["reason"])
		info_label.text = "Nie udało się zaanektować %s (%s)." % [hex_id, reason_text]

	_refresh_unit_action_ui()


## Automatically annexes the hex the unit is CURRENTLY standing on - the
## "Anektuj napotkane pola" (annex hexes along the way) shortcut on the
## Unit Card (Unit.auto_annex), called from
## _advance_queued_route() (see there - ALWAYS preceded by a check of
## `_current_hex_needs_auto_annex()` + sufficient MP, so
## `spend_movement_points()` here in practice never fails for lack of MP;
## it stays as a safeguard). The same payment mechanism as manual annexation
## (_on_annex_pressed), but without touching the UI/selected_hex_id - it can
## happen for ANY unit, including during automatic route continuation after
## a round is resolved (_continue_all_queued_routes), not just the currently
## selected one.
func _auto_annex_hex(unit: Unit, hex_id: String) -> void:
	var annex_cost = _effective_annex_cost_for(unit.player_id)
	if not unit.spend_movement_points(annex_cost):
		return

	var result = GameManager.annex_hex(hex_id, unit.player_id)
	if result["success"]:
		_reveal_around(hex_id, unit.player_id)
		info_label.text = "Automatycznie zaanektowano %s." % hex_id
	else:
		unit.refund_movement_points(annex_cost)


## Whether the hex the unit is CURRENTLY standing on qualifies for automatic
## annexation ("Anektuj napotkane pola" enabled, the hex is unclaimed and
## adjacent to already-owned territory) - shared by _advance_queued_route()
## (annexation priority over further movement, see there),
## _continue_all_queued_routes() (decides whether to call
## _advance_queued_route() at all for a unit with NO active route - see
## there), and _recompute_route()/_refresh_route_panel() (so as not to
## declare the route finished too early, and not to confuse the "waiting on
## MP to annex" state with "waiting because the enemy occupies the
## destination").
func _current_hex_needs_auto_annex(unit: Unit) -> bool:
	if not unit.auto_annex:
		return false
	var hex = MapData.get_hex(unit.current_hex_id)
	return (
		hex != null and hex.owner_id == -1
		and GameManager.has_adjacent_owned_hex(unit.current_hex_id, unit.player_id)
	)


func _on_auto_annex_toggled(pressed: bool) -> void:
	if selected_unit != null:
		selected_unit.auto_annex = pressed
		_refresh_route_panel()  # the route cost preview depends on auto_annex - see _route_cost()


## Whether the selected hex can be annexed by the unit currently standing on
## it - shared logic for the "Zaanektuj" button's state in the "Trasa
## ludzika" panel. Also requires adjacency to an already-owned hex
## (GameManager.annex_hex()) - checked here too, so the button is greyed out
## instead of only failing after being clicked.
func _can_annex_selected_hex() -> bool:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null or hex.owner_id != -1:
		return false
	if _find_own_unit_at(selected_hex_id) == null:
		return false
	return GameManager.has_adjacent_owned_hex(selected_hex_id, active_player.player_id)


## Annexation cost in MP for a given player, reduced by any skill tree bonus
## (the "territorial_logistics" skill), never below 1. Parameterized by
## player (not just `active_player`), because automatic annexation
## (`_auto_annex_hex`) can happen for any player during route continuation
## after a round is resolved, not only the one currently in control.
func _effective_annex_cost_for(player_id: int) -> int:
	var player = GameManager.get_player(player_id)
	var reduction = player.annex_cost_reduction if player != null else 0
	return maxi(1, GameBalance.ANNEX_MP_COST - reduction)


## Movement cost of `hex` for `player_id`, same base cost
## (`hex.get_movement_cost()`) for everyone EXCEPT a player with the
## "road_infrastructure" skill unlocked ("Infrastruktura drogowa"), for whom
## CITY-terrain hexes cost 0 MP instead of 1 - the base cost is already the
## cheapest (1, tied with agricultural/protected terrain), so "half" rounds
## down to 0 rather than needing fractional movement points. Only the two
## places that actually SPEND/ESTIMATE movement points during a route
## (`_advance_queued_route()`, `_remaining_route_cost()`) use this - the
## pathfinder itself (scripts/hex_pathfinder.gd) keeps using the base cost,
## since a single city hex per player never changes which route is
## cheapest/shortest, only how much it costs to walk through it.
func _effective_movement_cost_for(hex: HexData, player_id: int) -> int:
	var player = GameManager.get_player(player_id)
	if player != null and player.road_infrastructure and hex.terrain_type == HexData.TerrainType.CITY:
		return 0
	return hex.get_movement_cost()


## Territory takeover (PvP) - GDD section 5 / Phase 9 (update): like
## annexation, now requires physical presence of a unit on the hex - hence
## "Przejmij teren gracza" (take over territory) lives in the "Trasa
## ludzika" panel (`route_takeover_button`), appearing where "Zaanektuj"
## normally does, but only for hexes owned by another player. Since two
## different players can never stand on the same hex at the same time
## (`_blocked_hexes_for` blocks movement symmetrically both ways), merely
## standing on an enemy hex already PROVES that the unit defending it isn't
## currently patrolling it - a separate "defensive function" check (GDD
## section 3) is no longer needed, it has effectively moved into the
## movement block.
##
## The MP cost is identical to annexation and deducted immediately - unlike
## annexation, it is NOT refunded on failure due to insufficient prestige
## (`"insufficient_prestige"`), because that's still a real attempt with a
## real (if different) penalty - see GameManager.attempt_takeover(). It is
## only refunded on "hard" errors (the hex is unclaimed/already yours).
func _on_takeover_pressed() -> void:
	var hex_id = selected_hex_id
	var unit = _find_own_unit_at(hex_id)
	if unit == null:
		info_label.text = "Musisz stać ludzikiem na polu %s, żeby przejąć je siłą." % hex_id
		return

	var cost = _effective_annex_cost_for(active_player.player_id)
	if not unit.spend_movement_points(cost):
		info_label.text = "Brak punktów ruchu na przejęcie terenu (koszt: %d)." % cost
		_refresh_unit_action_ui()
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
		unit.refund_movement_points(cost)
		var reason_text = {
			"no_owner": "pole nie ma właściciela - użyj Aneksacji.",
			"already_owner": "to już twoje pole.",
			"capital_protected": "stolica miasta jest chroniona przed przejęciem.",
			"pact_active": "obowiązuje pakt o nieagresji z tym graczem.",
		}.get(result["reason"], result["reason"])
		info_label.text = "Nie udało się przejąć %s (%s)." % [hex_id, reason_text]

	_refresh_unit_action_ui()


## Whether the selected hex can be taken over by force by the unit currently
## standing on it - shared logic for the "Przejmij teren gracza" button's
## state on the Unit Card (analogous to `_can_annex_selected_hex()`).
func _can_takeover_selected_hex() -> bool:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null or hex.owner_id == -1 or hex.owner_id == active_player.player_id or hex.is_capital:
		return false
	return _find_own_unit_at(selected_hex_id) != null


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


## Forest harvesting (Phase 5, GDD section 6.1) - works on any already
## annexed forest hex the player owns, from any distance (see the comment at
## the top of the file); the player doesn't need to stand on it.
func _on_harvest_pressed() -> void:
	var hex_id = selected_hex_id
	var percent = harvest_slider.value
	var result = GameManager.harvest_forest(hex_id, active_player.player_id, percent)
	if result["success"]:
		var msg = "Wydobyto %.1f drewna z %s." % [result["wood_gained"], hex_id]
		if result["prestige_penalty"] > 0:
			msg += " Kara prestiżowa: -%d (poziom zasobu spadł poniżej progu %.0f%%)." % [
				result["prestige_penalty"], result["safe_threshold"]
			]
		info_label.text = msg
		_update_stats_labels()
		_refresh_map_view()
	else:
		info_label.text = "Nie udało się wydobyć drewna z %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


## Random event "Pożar lasu" (autoloads/random_event_manager.gd) - acts on
## the selected hex, same convention as `_on_repair_pressed()`/
## `_on_harvest_pressed()` above. The cost is charged for the ATTEMPT, not
## for success - see RandomEventManager.extinguish_fire().
func _on_extinguish_fire_pressed() -> void:
	var hex_id = selected_hex_id
	var result = RandomEventManager.extinguish_fire(hex_id, active_player.player_id)
	if result["success"]:
		info_label.text = (
			"Pożar na %s ugaszony!" % hex_id if result["extinguished"]
			else "Próba ugaszenia pożaru na %s nie powiodła się. Spróbuj ponownie." % hex_id
		)
		_update_stats_labels()
		_refresh_map_view()
	else:
		info_label.text = "Nie udało się ugasić pożaru na %s (%s)." % [hex_id, result["reason"]]
	_refresh_action_panel()


## --- Karta Miasta / powiadomienia ---
## Budynki charakterystyczne miasta (prestiż, sekcja 7 GDD) są teraz kupowane
## WPROST w tym pasku bocznym (poprzednio: tylko podgląd tutaj, zakup w
## osobnym modalu CityCardPanel, otwieranym przyciskiem 🏛) - ten modal
## zniknął. Kropka z literką "i" (`info_button`) otwiera teraz
## `notifications_panel` zamiast Karty Miasta - na razie jedynym źródłem
## informacji w nim są losowe wydarzenia (RandomEventManager), pokazywane
## TYLKO temu graczowi, którego dotyczą (albo wszystkim - patrz
## RandomEventManager).

func _on_info_button_pressed() -> void:
	notifications_panel.open_panel(active_player.player_id)
	_update_info_badge()


func _update_info_badge() -> void:
	var count = RandomEventManager.get_unread_count_for_player(active_player.player_id)
	info_unread_badge.visible = count > 0
	info_unread_badge_label.text = str(count) if count <= 9 else "9+"


## Wołane po zakończeniu rundy i po zmianie aktywnego gracza - jeśli jakieś
## wydarzenie dotyczy TERAZ aktywnego gracza, panel powiadomień otwiera się
## sam, zamiast czekać, aż gracz zauważy licznik i kliknie "i" ("Po
## kliknięciu Zakończ rundę lub zmianie gracza powinno wyskakiwać okienko
## jeśli jakiś event cie dotyczy").
func _maybe_popup_notifications() -> void:
	_update_info_badge()
	if RandomEventManager.get_unread_count_for_player(active_player.player_id) > 0:
		_on_info_button_pressed()


func _refresh_buildings_preview() -> void:
	for child in buildings_preview_list.get_children():
		child.queue_free()

	if active_player == null:
		return

	for building: Building in CityBuildingsData.get_buildings(active_player.starting_city):
		buildings_preview_list.add_child(_build_building_preview_row(building))


func _on_building_unlock_pressed(building: Building) -> void:
	var result = GameManager.unlock_city_building(active_player.player_id, building)
	if result["success"]:
		_update_stats_labels()
	_refresh_buildings_preview()


## Two-line, narrow-sidebar-friendly layout per building: icon/name/prestige
## on top, cost + an "Odblokuj" button (disabled if unaffordable, hidden
## once unlocked) underneath - the button IS the purchase now, unlike the
## old read-only preview that only linked to the separate modal.
func _build_building_preview_row(building: Building) -> Control:
	var unlocked = active_player.unlocked_city_buildings.has(building.building_name)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	box.add_child(top_row)

	var icon = HexShape.new()
	icon.custom_minimum_size = Vector2(20, 18)
	icon.fill_color = Palette.GOLD if unlocked else Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.22)
	top_row.add_child(icon)

	var name_label = Label.new()
	name_label.text = building.building_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override(
		"font_color", Palette.CREAM if unlocked else Palette.CREAM_DIM
	)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)

	var prestige_label = Label.new()
	prestige_label.text = "+%d" % building.prestige_value
	prestige_label.add_theme_font_size_override("font_size", 11)
	prestige_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	top_row.add_child(prestige_label)

	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	box.add_child(bottom_row)

	var cost_label = Label.new()
	cost_label.text = "Odblokowano" if unlocked else HexData.format_resource_costs(building.required_resources)
	cost_label.add_theme_font_size_override("font_size", 10)
	cost_label.add_theme_color_override("font_color", Palette.CREAM_DIM)
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.clip_text = true
	bottom_row.add_child(cost_label)

	if not unlocked:
		var buy_button = Button.new()
		buy_button.text = "Odblokuj"
		buy_button.add_theme_font_size_override("font_size", 10)
		buy_button.disabled = not active_player.can_afford(building.required_resources)
		buy_button.pressed.connect(_on_building_unlock_pressed.bind(building))
		bottom_row.add_child(buy_button)

	return box


## --- Market (new) ---
## The resource market (autoloads/market_manager.gd) - clicking a resource
## chip in the top bar opens its market page (`market_panel`), a chart of
## recent prices plus buy/sell, exactly like the City Card/Skill Tree
## panels: one shared panel instance, `open_for_resource()` swaps which
## resource it's currently showing.

func _on_resource_row_gui_input(event: InputEvent, resource: HexData.ResourceType) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		market_panel.open_for_resource(resource, active_player)
		_active_market_resource = resource
		_update_resource_pill_highlight()


## Closing the panel (X) clears the highlight - see market_panel.gd's
## `closed` signal.
func _on_market_closed() -> void:
	_active_market_resource = HexData.ResourceType.NONE
	_update_resource_pill_highlight()


## A trade changes the player's money AND resource stock - both shown
## elsewhere in the UI (top bar), so they need to catch up immediately,
## not just the next time something else happens to refresh them.
func _on_market_traded() -> void:
	_update_stats_labels()


func _update_resource_pill_highlight() -> void:
	for resource in resource_rows:
		var row: PanelContainer = resource_rows[resource]
		var target = _resource_pill_active_style if resource == _active_market_resource else _resource_pill_normal_style
		row.add_theme_stylebox_override("panel", target)


## --- Skill Tree (new, see the comment at the top of the file) ---

func _on_skill_tree_pressed() -> void:
	skill_tree_panel.open_for_player(active_player)


func _on_diplomacy_button_pressed() -> void:
	diplomacy_panel.open_for_player(active_player.player_id)


## Reacts to a skill being unlocked in SkillTreePanel. "Pure data" effects
## (vision radius, safe harvesting threshold, annexation cost, MP for FUTURE
## units) are already applied to PlayerData by GameManager.unlock_skill() -
## here we only handle the two effects that need access to scene nodes,
## which GameManager deliberately doesn't know about.
func _on_skill_unlocked(skill: SkillData) -> void:
	match skill.effect_type:
		SkillData.EffectType.EXTRA_UNIT:
			_recruit_extra_unit(active_player)
		SkillData.EffectType.MOVEMENT_POINTS_BONUS:
			# The bonus for FUTURE units is already on PlayerData
			# (player.movement_points_bonus) - here we retroactively bump up
			# the ones that ALREADY EXIST, so the effect is felt immediately.
			var bonus = int(skill.effect_amount)
			for u in player_units.get(active_player.player_id, []):
				u.movement_points_max += bonus
				u.movement_points_current += bonus
			_update_mp_label()
		_:
			pass  # VISION_RADIUS_BONUS / FOREST_THRESHOLD_BONUS / ANNEX_COST_REDUCTION - nothing more to do here
	_update_stats_labels()


## The "extra_unit" skill - recruits another Unit in the player's starting
## city. The `player_units: player_id -> Array[Unit]` data model was
## designed for this from the start (see the comment at the top of the
## file) - this is the first place that actually makes use of it.
func _recruit_extra_unit(player: PlayerData) -> void:
	var setup = _find_player_setup(player.player_id)
	if setup.is_empty():
		return

	var unit = Unit.new()
	add_child(unit)
	_configure_unit(unit, player, setup)
	unit.movement_points_max = GameBalance.UNIT_MOVEMENT_POINTS_MAX + player.movement_points_bonus
	unit.reset_movement_points()

	var spawn_hex_id = _resolve_start_hex(setup, player.player_name)
	unit.place_on_hex(spawn_hex_id)

	if not player_units.has(player.player_id):
		player_units[player.player_id] = []
	player_units[player.player_id].append(unit)

	_reveal_around(spawn_hex_id, player.player_id)
	_refresh_map_view()
	info_label.text = "Zrekrutowano drugiego ludzika w %s." % player.starting_city


func _find_player_setup(player_id: int) -> Dictionary:
	for setup in PLAYER_SETUP:
		if setup["id"] == player_id:
			return setup
	return {}


## --- Active player and rounds (separated - see turn_manager.gd) ---

func _on_player_selected(index: int) -> void:
	var player_id = player_selector.get_item_id(index)
	TurnManager.switch_to_player(player_id)


func _on_end_round_pressed() -> void:
	TurnManager.end_round()  # does NOT change which player is in control


## Updates the action panel based on the currently SELECTED hex (not
## necessarily the one a unit is standing on - see `selected_hex_id`). The
## descriptive text is gated by fog of war (the same 3 levels as
## `_on_hex_hovered()` below) - until the hex is at least SEEN, only its ID
## and terrain type are visible, without the label/owner/building/resource
## level. Action buttons are NOT gated here - they act on the hex's actual
## state (so that e.g. taking over enemy territory is possible at all),
## only the text description protects information about what's on it.
func _refresh_action_panel() -> void:
	var hex = MapData.get_hex(selected_hex_id)
	if hex == null:
		hex_info_label.text = "Zaznacz pole (kliknij na mapie)."
		repair_button.disabled = true
		extinguish_fire_button.disabled = true
		harvest_slider.visible = false
		harvest_value_label.visible = false
		harvest_button.visible = false
		return

	var fog = hex.get_fog_state(active_player.player_id)
	match fog:
		HexData.FogState.UNEXPLORED:
			hex_info_label.text = "%s: nieodkryte pole." % hex.hex_id
		HexData.FogState.SEEN:
			hex_info_label.text = _describe_seen_hex(hex)
		HexData.FogState.ANNEXED:
			hex_info_label.text = "%s | %s\nteren: %s | właściciel: %s\nbudynek: %s\npoziom zasobu: %.0f%%%s" % [
				hex.hex_id, hex.label_raw, HexData.TerrainType.keys()[hex.terrain_type],
				_describe_owner(hex), _describe_building(hex), hex.resource_level,
				"\n🔥 POŻAR!" if hex.is_on_fire else ""
			]

	var is_owned_by_me = hex.owner_id == active_player.player_id

	repair_button.disabled = not (is_owned_by_me and hex.building != null and hex.building_damaged)
	extinguish_fire_button.disabled = not (is_owned_by_me and hex.is_on_fire)

	var is_forest = hex.is_forest()
	harvest_slider.visible = is_forest
	harvest_value_label.visible = is_forest
	harvest_button.visible = is_forest
	harvest_button.disabled = not is_owned_by_me


## The Unit Card ("Karta ludzika", UI restyle) - only shown with a unit
## selected, three route states: (1) an unconfirmed preview -> length/cost +
## Confirm/Cancel; (2) an already confirmed, in-progress route (may have
## been paused by lack of MP or a block - `_continue_all_queued_routes` will
## get back to it at the start of the next round) -> progress + Cancel; (3)
## nothing planned -> a hint. This is the ONLY place a hex can be
## annexed/taken over (both buttons removed from the sidebar, since both
## actions require physical presence). "Zaanektuj" and "Przejmij teren
## gracza" are mutually exclusive (exactly one visible, depending on whether
## the selected hex is unclaimed or hostile) - hence also the "Anektuj
## napotkane pola" toggle (Unit.auto_annex), which automatically annexes
## EVERY unclaimed hex this unit passes through while executing a route
## (see _advance_queued_route/_auto_annex_hex).
func _refresh_route_panel() -> void:
	if selected_unit == null:
		unit_card.hide_card()
		return

	unit_card.show_for_new_selection()
	_update_mp_label()  # keeps the MP text/pips in sync with `selected_unit` on every selection change, not just when MP itself changes

	var hex = MapData.get_hex(selected_hex_id)
	var is_unclaimed = hex != null and hex.owner_id == -1
	var is_enemy_owned = hex != null and hex.owner_id != -1 and hex.owner_id != active_player.player_id

	route_annex_button.visible = is_unclaimed
	route_annex_button.disabled = not _can_annex_selected_hex()

	route_takeover_button.visible = is_enemy_owned
	route_takeover_button.disabled = not _can_takeover_selected_hex()
	# The MP cost is known up front (the same as annexation), but the
	# prestige cost depends on the DEFENDER's prestige, which isn't shown in
	# the UI (see the "Decyzje projektowe" section of the README) - hence
	# the tooltip deliberately doesn't give an exact number.
	route_takeover_button.tooltip_text = (
		"Koszt: %d MP oraz nieznana liczba prestiżu (zależy od siły przeciwnika)."
		% _effective_annex_cost_for(active_player.player_id)
	)

	auto_annex_toggle.button_pressed = selected_unit.auto_annex

	if preview_route_unit == selected_unit and preview_route.size() > 1:
		var cost = _route_cost(preview_route, selected_unit)
		var rounds = _route_rounds_needed(cost, selected_unit)
		var target_note = ""
		if preview_target_hex_id != "" and preview_route[-1] != preview_target_hex_id:
			target_note = " (najbliżej jak się da - %s jest zajęte przez przeciwnika)" % preview_target_hex_id
		unit_card_status_label.text = (
			"Podgląd trasy do %s%s: %d pól, koszt %d MP - zajmie %s (masz %d MP)."
			% [
				preview_route[-1], target_note, preview_route.size() - 1, cost,
				_format_rounds(rounds), selected_unit.movement_points_current
			]
		)
		unit_card_confirm_button.visible = true
		# No route to cancel yet (it's still just a preview) - closing the
		# card (X, top-right corner) already clears an unconfirmed preview
		# as a side effect of deselecting the unit, so there's nothing extra
		# to offer here - see the comment on `cancel_route_link` up top.
		cancel_route_link.visible = false
	elif not selected_unit.queued_route.is_empty():
		var remaining_cost = _remaining_route_cost(selected_unit.queued_route, selected_unit)
		var rounds = _route_rounds_needed(remaining_cost, selected_unit)
		var true_target = (
			selected_unit.route_destination if selected_unit.route_destination != ""
			else selected_unit.queued_route[-1]
		)
		var target_note = ""
		if true_target != selected_unit.queued_route[-1]:
			target_note = " (na razie do %s - %s jest zajęte przez przeciwnika)" % [selected_unit.queued_route[-1], true_target]
		unit_card_status_label.text = "Trasa w toku do %s%s: pozostało %d pól, zajmie jeszcze %s." % [
			true_target, target_note, selected_unit.queued_route.size(), _format_rounds(rounds)
		]
		unit_card_confirm_button.visible = false
		cancel_route_link.visible = true
	elif selected_unit.route_destination != "":
		if selected_unit.route_destination == selected_unit.current_hex_id:
			# Arrived, but ran out of MP for automatic annexation of this
			# hex last round (see _advance_queued_route) - this is a
			# DIFFERENT state than "destination occupied by the enemy"
			# below, even though both have an empty `queued_route` and a
			# set `route_destination`.
			unit_card_status_label.text = (
				"Ludzik dotarł na miejsce (%s), ale brakuje MP na aneksację - zaanektuje automatycznie, gdy tylko starczy."
				% selected_unit.route_destination
			)
		else:
			unit_card_status_label.text = (
				"Ludzik czeka na miejscu - pole %s jest obecnie zajęte przez przeciwnika. Trasa ruszy dalej automatycznie, gdy się zwolni."
				% selected_unit.route_destination
			)
		unit_card_confirm_button.visible = false
		cancel_route_link.visible = true
	elif _current_hex_needs_auto_annex(selected_unit):
		# No active route (e.g. after Cancel), but still waiting on MP to
		# automatically annex the hex it's currently standing on - see
		# _continue_all_queued_routes(), which will try to finish this every
		# round regardless of whether a route exists.
		unit_card_status_label.text = (
			"Ludzik czeka na miejscu (%s) - zaanektuje automatycznie, gdy tylko starczy MP."
			% selected_unit.current_hex_id
		)
		unit_card_confirm_button.visible = false
		cancel_route_link.visible = false
	else:
		unit_card_status_label.text = "Kliknij pole na mapie, żeby zaplanować trasę."
		unit_card_confirm_button.visible = false
		cancel_route_link.visible = false


## Total MP cost of walking `path` (skips index 0 - the starting hex the
## unit is already standing on, entering it costs nothing).
func _route_cost(path: Array[String], unit: Unit) -> int:
	return _remaining_route_cost(path.slice(1), unit)


## Like `_route_cost`, but without skipping the first element - for use on
## `Unit.queued_route`, which (unlike the `preview_route` preview) does NOT
## include the starting hex. If `unit.auto_annex` is enabled ("Anektuj
## napotkane pola"), also adds the cost of automatically annexing EVERY
## currently unclaimed hex on the route - hence a route with auto-annexation
## enabled comes out more expensive in MP, so it "has to wait longer" (more
## rounds before actually reaching the destination). This is an upfront
## estimate: the actual annexation along the way may fail (e.g. no adjacency
## to an already-owned hex - see GameManager.annex_hex), but it's accurate
## enough as a route preview.
func _remaining_route_cost(remaining: Array[String], unit: Unit) -> int:
	var total = 0
	var annex_cost = _effective_annex_cost_for(unit.player_id)
	for hex_id in remaining:
		var hex = MapData.get_hex(hex_id)
		if hex == null:
			continue
		total += _effective_movement_cost_for(hex, unit.player_id)
		if unit.auto_annex and hex.owner_id == -1:
			total += annex_cost
	return total


## Number of rounds needed for a unit to spend `cost` movement points - 1 if
## the CURRENT points this round are enough, otherwise this round plus as
## many FULL rounds after it (each giving `movement_points_max` fresh
## points) as needed for the rest. Used to display the exact "will take X
## round(s)" instead of the old binary "fits this round" / "will take
## several rounds".
func _route_rounds_needed(cost: int, unit: Unit) -> int:
	if cost <= unit.movement_points_current:
		return 1
	var remaining = cost - unit.movement_points_current
	var per_round = maxi(1, unit.movement_points_max)
	return 1 + (remaining + per_round - 1) / per_round


## Polish inflection of "rundę"/"rundy"/"rund" (round) after a number (e.g.
## "1 rundę", "3 rundy", "5 rund", "12 rund", "22 rundy") - this label is
## player-facing, so it stays in Polish.
static func _format_rounds(n: int) -> String:
	var word: String
	if n == 1:
		word = "rundę"
	elif n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
		word = "rundy"
	else:
		word = "rund"
	return "%d %s" % [n, word]


## UI restyle: movement points are shown EXCLUSIVELY on the Unit Card, as
## hex pips (no numeric "X/Y" anywhere anymore, restyle spec 4.3) - unlike
## the old top-bar mp_label, there's no "fall back to the player's primary
## unit" case, since the card itself is only ever visible with a unit
## selected (see `_refresh_route_panel()`).
func _update_mp_label() -> void:
	if selected_unit == null:
		return
	unit_card.set_pips(selected_unit.movement_points_current, selected_unit.movement_points_max)


## Top bar: round badge + resource pills + prestige/money chips (UI
## restyle). The active player's NAME no longer has its own label - the
## sidebar's city name already identifies them uniquely, since every
## player has exactly one, distinct starting city in this hotseat game.
## The round chip's "RUNDA" caption is static text (restyle spec 4.1 - no
## duplicate round number), so the current season (GameBalance.Season,
## round_number % 4) - which directly scales agricultural food income
## (GameBalance.SEASON_FOOD_MULTIPLIER) and the player needs to plan
## around (e.g. stockpile before winter) - is surfaced as a tooltip on the
## round badge instead of a second visible label.
func _update_stats_labels() -> void:
	var season_name = GameBalance.SEASON_DISPLAY_NAMES[TurnManager.get_current_season()]
	round_hex_label.text = str(TurnManager.round_number)
	round_hex_label.tooltip_text = "Runda %d - %s" % [TurnManager.round_number, season_name]
	money_value_label.text = "%.0f" % active_player.money
	prestige_value_label.text = str(active_player.prestige)

	city_name_label.text = active_player.starting_city

	resource_wood_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.WOOD)
	resource_food_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.FOOD)
	resource_copper_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.COPPER)
	resource_coal_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.COAL)
	resource_gas_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.GAS)
	resource_nickel_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.NICKEL)
	resource_oil_value.text = "%.0f" % active_player.get_resource_amount(HexData.ResourceType.OIL)

	for resource in resource_production_labels:
		var label: Label = resource_production_labels[resource]
		label.text = "+%.0f" % _estimate_resource_production(active_player, resource)


## Estimate of how much of `resource` `player` will actually receive at the
## NEXT round's end - mirrors TurnManager._process_resource_income()'s own
## logic exactly (including the season multiplier for agricultural hexes),
## so the top bar's "+X" preview (restyle spec 4.1) never drifts out of
## sync with what actually gets added. Read-only - unlike the real income
## processing, this never touches player resources itself.
func _estimate_resource_production(player: PlayerData, resource: HexData.ResourceType) -> float:
	var season = TurnManager.get_current_season()
	var total = 0.0
	for hex: HexData in MapData.hexes.values():
		if hex.owner_id != player.player_id or hex.is_forest():
			continue
		if hex.building == null or hex.building_damaged:
			continue
		if hex.building.produced_resource != resource:
			continue
		var amount = hex.building.produced_amount_per_turn
		if hex.is_agricultural():
			amount *= GameBalance.SEASON_FOOD_MULTIPLIER[season]
		total += amount
	return total
