extends Node
## Manual smoke test for implementation plan Phase 0-1.
## Run this scene (F6 / "Run Current Scene") to see in the console whether
## map loading, annexation, forest harvesting, and round resolution work.

func _ready() -> void:
	print("=== Phase 0-1 test: data, annexation, forest harvesting, turn ===")
	print("Number of hexes loaded: ", MapData.hexes.size())

	print("--- Seasons: GameBalance.Season derived from round_number %% 4 ---")
	for i in range(5):
		var season = TurnManager.get_current_season()
		print(
			"Round %d -> season %s (index %d, food multiplier x%.1f)"
			% [
				TurnManager.round_number, GameBalance.SEASON_DISPLAY_NAMES[season], season,
				GameBalance.SEASON_FOOD_MULTIPLIER[season]
			]
		)
		TurnManager.end_round()
	print("(round 1 is expected to be Wiosna/Spring, and the cycle should repeat every 4 rounds)")

	var player = PlayerData.new()
	player.player_id = 1
	player.player_name = "Test player"
	player.starting_city = "Wrocław"
	GameManager.register_player(player)

	# Annex Wrocław's base hex (H18 per the KML convention)
	if MapData.get_hex("H18") != null:
		var result = GameManager.annex_hex("H18", 1)
		print("Annexing H18 (Wrocław): ", result)
	else:
		print("WARNING: hex H18 not found - check the map data.")

	# Find the first available forest hex and test both harvesting scenarios
	var forest_hex_id = ""
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		if hex.is_forest():
			forest_hex_id = hex_id
			break

	if forest_hex_id != "":
		GameManager.annex_hex(forest_hex_id, 1)
		var hex_before: HexData = MapData.get_hex(forest_hex_id)
		hex_before.resource_level = 100.0  # deterministic starting point for this test

		# Update: the prestige penalty now triggers on the RESULTING resource
		# level after harvesting, not on how big a bite harvest_percent
		# itself was. Harvesting 30%% of a full (100%%) forest leaves 70%%
		# behind, still at/above the 60%% safe threshold - no penalty.
		var safe_result = GameManager.harvest_forest(forest_hex_id, 1, 30.0)
		print("Harvesting 30%% of forest %s (100%% -> 70%%, at/above the 60%% threshold - no penalty): %s" % [forest_hex_id, safe_result])

		# Harvesting 50%% of what's left (70%%) drops the RESULTING level to
		# 35%%, below the safe threshold - THIS is what now triggers the
		# penalty, even though a 50%% harvest_percent used to be considered
		# perfectly safe under the old rule (which only looked at
		# harvest_percent itself, never at the level it left behind).
		var over_result = GameManager.harvest_forest(forest_hex_id, 1, 50.0)
		print("Harvesting 50%% of forest %s (70%% -> 35%%, below the 60%% threshold - penalty): %s" % [forest_hex_id, over_result])

		print("Player prestige after over-harvesting: ", player.prestige)
		print("Player wood resources: ", player.get_resource_amount(HexData.ResourceType.WOOD))

		var hex_after: HexData = MapData.get_hex(forest_hex_id)
		print(
			"Resource level of %s after two harvests: %.1f%% (expected 35%%)"
			% [forest_hex_id, hex_after.resource_level]
		)
		print("Does hex %s generate prestige? %s (should be false after dropping below the threshold)" % [forest_hex_id, hex_after.generates_prestige])

		# Resolve a round - check regrowth
		TurnManager.setup_player_order([1])
		TurnManager.end_round()
		print("--- After resolving the round ---")
		print("Resource level of %s after regrowth: %.1f%%" % [forest_hex_id, hex_after.resource_level])
		print("Does the hex generate prestige after regrowth? ", hex_after.generates_prestige)
	else:
		print("WARNING: no forest hex found in the map data.")

	print("=== End of Phase 0-1 test ===")
	_test_phase_6_to_9(player)


## Manual smoke test for Phases 6-9 (+ updates from later fixes): the full
## readiness-based (not strict alternation) multi-player turn structure,
## movement blocked by a defending unit, territory takeover (PvP), the City
## Card, and the (updated) protected-area penalty - now only for
## building/repairing on it, NOT for the annexation itself.
## Tested at the logic level (GameManager/TurnManager/HexPathfinder), without
## creating visible Unit nodes - those live in game_map_controller.gd and
## require running the scenes/main.tscn scene (see README). Movement points
## (now owned by the Unit, not the player) and the annexation MP cost are
## therefore not tested here either - that's logic at the
## controller/scene level.
func _test_phase_6_to_9(player: PlayerData) -> void:
	print("=== Phase 6-9 test: multi-player turns, blocking, takeover, City Card ===")

	# --- Phase 6 (update): a second player + choosing the active player
	# directly, independent of round resolution (see turn_manager.gd) ---
	var player2 = PlayerData.new()
	player2.player_id = 2
	player2.player_name = "Test player 2"
	player2.starting_city = "Szczecin"
	GameManager.register_player(player2)

	if MapData.get_hex("A7") != null:
		print("Annexing A7 (Szczecin) for player 2: ", GameManager.annex_hex("A7", 2))

	TurnManager.setup_player_order([1, 2])
	print(
		"Active player after setup_player_order: %d (expected 1)" % TurnManager.get_current_player_id()
	)

	TurnManager.switch_to_player(2)
	print(
		"Active player after switch_to_player(2) (direct choice, not cycling): %d (expected 2)"
		% TurnManager.get_current_player_id()
	)
	TurnManager.switch_to_player(1)
	print(
		"Active player after switch_to_player(1) back again: %d (expected 1)"
		% TurnManager.get_current_player_id()
	)

	var round_before = TurnManager.round_number
	TurnManager.end_round()  # does not change the active player, only resolves the round
	print(
		"Active player after end_round (unchanged, expected 1): %d" % TurnManager.get_current_player_id()
	)
	print(
		"Round after end_round: %d -> %d (expected +1)"
		% [round_before, TurnManager.round_number]
	)

	# --- Phase 9: movement blocked by a defending unit (GDD section 3) ---
	# H18 (Wrocław) has six neighbors in the current data, including H17 -
	# used here as the "occupied by a defending unit" hex.
	var pathfinder = HexPathfinder.new()
	pathfinder.build(["H17"])
	var blocked_target = pathfinder.find_path("H18", "H17")
	print(
		"Route H18->H17 while H17 is defended: %s (expected an empty list)" % [blocked_target]
	)
	var reroutable = pathfinder.find_path("H18", "G17")
	print("Route H18->G17 despite the H17 block (a different neighbor, should exist): ", reroutable)

	# --- Phase 9: territory takeover ---
	if MapData.get_hex("H19") != null:
		GameManager.annex_hex("H19", 1)

		# Equalize both players' prestige (regardless of penalties accrued
		# earlier in the Phase 0-1 test), to unambiguously demonstrate the
		# attempt being rejected when attacker prestige <= defender prestige
		# (GDD section 5: must be STRICTLY greater).
		player2.modify_prestige(player.prestige - player2.prestige)
		var equal_prestige_attempt = GameManager.attempt_takeover("H19", 2)
		print(
			"Attempt to take H19 with equal prestige (%d vs %d): %s"
			% [player2.prestige, player.prestige, equal_prestige_attempt]
		)

		player2.modify_prestige(50)  # player 2 now has a prestige advantage
		var winning_attempt = GameManager.attempt_takeover("H19", 2)
		print(
			"Attempt to take H19 with a prestige advantage (%d vs %d): %s"
			% [player2.prestige, player.prestige, winning_attempt]
		)
		print("Owner of H19 after the takeover: ", MapData.get_hex("H19").owner_id, " (expected 2)")

	# --- Phase 7 (updated): annexing a protected area NO LONGER incurs a
	# prestige penalty - the penalty only appears when a building is built/
	# repaired on such terrain (repair_building). ---
	if MapData.get_hex("A8") != null:
		var prestige_before_annex = player2.prestige
		var protected_annex_result = GameManager.annex_hex("A8", 2)
		print("Annexing A8 (Dolna Odra Landscape Park, a protected area) - NO penalty: ", protected_annex_result)
		print(
			"Player 2 prestige before/after annexation: %d -> %d (expected NO change)"
			% [prestige_before_annex, player2.prestige]
		)

		# The current KML excerpt has no building on protected terrain - we
		# simulate one here manually to test the "building on protected
		# terrain incurs a prestige penalty" rule on its own.
		var synthetic_building = Building.new()
		synthetic_building.building_name = "Test infrastructure (simulated)"
		synthetic_building.required_resources = {}
		var protected_hex: HexData = MapData.get_hex("A8")
		protected_hex.building = synthetic_building
		protected_hex.building_damaged = true

		var prestige_before_repair = player2.prestige
		var repair_result = GameManager.repair_building("A8", 2)
		print("Repairing/building on protected area A8: ", repair_result)
		print(
			"Player 2 prestige before/after repair: %d -> %d (expected a penalty)"
			% [prestige_before_repair, player2.prestige]
		)

	# --- Phase 8: City Card ---
	var wroclaw_buildings = CityBuildingsData.get_buildings("Wrocław")
	print("Number of City Card buildings for Wrocław: ", wroclaw_buildings.size())
	if not wroclaw_buildings.is_empty():
		var cheapest: Building = wroclaw_buildings[0]
		for res_type in cheapest.required_resources:
			player.add_resource(res_type, cheapest.required_resources[res_type])
		var unlock_result = GameManager.unlock_city_building(1, cheapest)
		print("Unlocking '%s': %s" % [cheapest.building_name, unlock_result])
		print("Player 1 prestige after unlocking: ", player.prestige)
		var repeat_unlock = GameManager.unlock_city_building(1, cheapest)
		print("Repeated attempt to unlock the same building: ", repeat_unlock)

	print("=== End of Phase 6-9 test ===")
