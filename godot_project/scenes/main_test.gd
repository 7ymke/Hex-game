extends Node
## Manualny test dymny (smoke test) Fazy 0-1 planu implementacji.
## Uruchom tę scenę (F6 / "Run Current Scene"), żeby zobaczyć w konsoli,
## czy wczytywanie mapy, aneksacja, wydobycie lasu i przeliczenie rundy działają.

func _ready() -> void:
	print("=== Test Fazy 0-1: dane, aneksacja, wydobycie lasu, tura ===")
	print("Liczba wczytanych heksów: ", MapData.hexes.size())

	var player = PlayerData.new()
	player.player_id = 1
	player.player_name = "Gracz testowy"
	player.starting_city = "Wrocław"
	GameManager.register_player(player)

	# Aneksacja heksa bazowego Wrocławia (H18 wg konwencji z KML)
	if MapData.get_hex("H18") != null:
		var result = GameManager.annex_hex("H18", 1)
		print("Aneksacja H18 (Wrocław): ", result)
	else:
		print("UWAGA: nie znaleziono heksa H18 - sprawdź dane mapy.")

	# Znajdź pierwszy dostępny heks leśny i przetestuj oba warianty wydobycia
	var forest_hex_id = ""
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		if hex.is_forest():
			forest_hex_id = hex_id
			break

	if forest_hex_id != "":
		GameManager.annex_hex(forest_hex_id, 1)

		var safe_result = GameManager.harvest_forest(forest_hex_id, 1, 50.0)
		print("Wydobycie 50%% z lasu %s (bezpieczne, brak kary): %s" % [forest_hex_id, safe_result])

		var over_result = GameManager.harvest_forest(forest_hex_id, 1, 90.0)
		print("Wydobycie 90%% z lasu %s (przekroczenie progu 60%%): %s" % [forest_hex_id, over_result])

		print("Prestiż gracza po nadmiernej wycince: ", player.prestige)
		print("Zasoby drewna gracza: ", player.get_resource_amount(HexData.ResourceType.WOOD))

		var hex_after: HexData = MapData.get_hex(forest_hex_id)
		print(
			"Poziom zasobu %s po dwóch wydobyciach: %.1f%% (powinno być WYRAŹNIE poniżej 100%% - wydobycie musi wyczerpywać pole, nie tylko naliczać karę)"
			% [forest_hex_id, hex_after.resource_level]
		)
		print("Pole %s generuje prestiż? %s (powinno być false po przekroczeniu)" % [forest_hex_id, hex_after.generates_prestige])

		# Przeliczenie rundy - sprawdzenie regeneracji
		TurnManager.setup_player_order([1])
		TurnManager.end_round()
		print("--- Po przeliczeniu rundy ---")
		print("Poziom zasobu %s po regeneracji: %.1f%%" % [forest_hex_id, hex_after.resource_level])
		print("Pole generuje prestiż po regeneracji? ", hex_after.generates_prestige)
	else:
		print("UWAGA: nie znaleziono żadnego heksa lasu w danych mapy.")

	print("=== Koniec testu Fazy 0-1 ===")
	_test_phase_6_to_9(player)


## Manualny test dymny Faz 6-9 (+ update po dalszych poprawkach): pełna
## struktura tur wielu graczy oparta o gotowość (nie sztywną alternację),
## blokada ruchu przez broniącego ludzika, przejęcie terytorium (PvP), Karta
## Miasta i (zaktualizowana) kara za strefę chronioną - dopiero za
## budowę/naprawę na niej, NIE za samą aneksację.
## Testowane na poziomie logiki (GameManager/TurnManager/HexPathfinder),
## bez tworzenia widocznych węzłów Ludzik - te żyją w game_map_controller.gd
## i wymagają uruchomienia sceny scenes/main.tscn (patrz README). Punkty
## ruchu (teraz własność Ludzika, nie gracza) i koszt MP aneksacji dlatego
## też nie są tu testowane - to logika na poziomie kontrolera/sceny.
func _test_phase_6_to_9(player: PlayerData) -> void:
	print("=== Test Faz 6-9: tury wielu graczy, blokada, przejęcie, Karta Miasta ===")

	# --- Faza 6 (update): drugi gracz + wybór aktywnego gracza wprost,
	# niezależny od przeliczenia rundy (patrz turn_manager.gd) ---
	var player2 = PlayerData.new()
	player2.player_id = 2
	player2.player_name = "Gracz 2 testowy"
	player2.starting_city = "Szczecin"
	GameManager.register_player(player2)

	if MapData.get_hex("A7") != null:
		print("Aneksacja A7 (Szczecin) dla gracza 2: ", GameManager.annex_hex("A7", 2))

	TurnManager.setup_player_order([1, 2])
	print(
		"Aktywny gracz po setup_player_order: %d (oczekiwano 1)" % TurnManager.get_current_player_id()
	)

	TurnManager.switch_to_player(2)
	print(
		"Aktywny gracz po switch_to_player(2) (wybór wprost, nie cykl): %d (oczekiwano 2)"
		% TurnManager.get_current_player_id()
	)
	TurnManager.switch_to_player(1)
	print(
		"Aktywny gracz po switch_to_player(1) z powrotem: %d (oczekiwano 1)"
		% TurnManager.get_current_player_id()
	)

	var round_before = TurnManager.round_number
	TurnManager.end_round()  # nie zmienia aktywnego gracza, tylko przelicza rundę
	print(
		"Aktywny gracz po end_round (bez zmiany, oczekiwano 1): %d" % TurnManager.get_current_player_id()
	)
	print(
		"Runda po end_round: %d -> %d (oczekiwano +1)"
		% [round_before, TurnManager.round_number]
	)

	# --- Faza 9: blokada ruchu przez broniącego ludzika (sekcja 3 GDD) ---
	# H18 (Wrocław) ma sześciu sąsiadów w obecnych danych, w tym H17 - użyty
	# tu jako "zajęty przez broniącego ludzika" heks.
	var pathfinder = HexPathfinder.new()
	pathfinder.build(["H17"])
	var blocked_target = pathfinder.find_path("H18", "H17")
	print(
		"Trasa H18->H17 gdy H17 jest bronione: %s (oczekiwano pustej listy)" % [blocked_target]
	)
	var reroutable = pathfinder.find_path("H18", "G17")
	print("Trasa H18->G17 mimo blokady H17 (inny sąsiad, powinna istnieć): ", reroutable)

	# --- Faza 9: przejęcie terytorium ---
	if MapData.get_hex("H19") != null:
		GameManager.annex_hex("H19", 1)

		# Wyrównaj prestiż obu graczy (niezależnie od kar naliczonych wcześniej
		# w teście Fazy 0-1), żeby jednoznacznie pokazać odrzucenie próby przy
		# prestiżu ataku <= prestiżu obrony (sekcja 5 GDD: musi być ŚCIŚLE większy).
		player2.modify_prestige(player.prestige - player2.prestige)
		var equal_prestige_attempt = GameManager.attempt_takeover("H19", 2)
		print(
			"Próba przejęcia H19 przy równym prestiżu (%d vs %d): %s"
			% [player2.prestige, player.prestige, equal_prestige_attempt]
		)

		player2.modify_prestige(50)  # gracz 2 ma teraz przewagę prestiżową
		var winning_attempt = GameManager.attempt_takeover("H19", 2)
		print(
			"Próba przejęcia H19 z przewagą prestiżową (%d vs %d): %s"
			% [player2.prestige, player.prestige, winning_attempt]
		)
		print("Właściciel H19 po przejęciu: ", MapData.get_hex("H19").owner_id, " (oczekiwano 2)")

	# --- Faza 7 (zaktualizowane): aneksacja strefy chronionej NIE karze już
	# prestiżem - kara pojawia się dopiero przy budowie/naprawie budynku na
	# takim terenie (repair_building). ---
	if MapData.get_hex("A8") != null:
		var prestige_before_annex = player2.prestige
		var protected_annex_result = GameManager.annex_hex("A8", 2)
		print("Aneksacja A8 (Park Krajobrazowy Dolnej Odry, strefa chroniona) - BEZ kary: ", protected_annex_result)
		print(
			"Prestiż gracza 2 przed/po aneksacji: %d -> %d (oczekiwano BEZ zmian)"
			% [prestige_before_annex, player2.prestige]
		)

		# Obecny wycinek KML nie ma żadnego budynku na terenie chronionym -
		# symulujemy go tu ręcznie, żeby przetestować samą regułę "budowa na
		# terenie chronionym karze prestiż".
		var synthetic_building = Building.new()
		synthetic_building.building_name = "Testowa infrastruktura (symulacja)"
		synthetic_building.required_resources = {}
		var protected_hex: HexData = MapData.get_hex("A8")
		protected_hex.building = synthetic_building
		protected_hex.building_damaged = true

		var prestige_before_repair = player2.prestige
		var repair_result = GameManager.repair_building("A8", 2)
		print("Naprawa/budowa na strefie chronionej A8: ", repair_result)
		print(
			"Prestiż gracza 2 przed/po naprawie: %d -> %d (oczekiwana kara)"
			% [prestige_before_repair, player2.prestige]
		)

	# --- Faza 8: Karta Miasta ---
	var wroclaw_buildings = CityBuildingsData.get_buildings("Wrocław")
	print("Liczba budynków Karty Miasta dla Wrocławia: ", wroclaw_buildings.size())
	if not wroclaw_buildings.is_empty():
		var cheapest: Building = wroclaw_buildings[0]
		for res_type in cheapest.required_resources:
			player.add_resource(res_type, cheapest.required_resources[res_type])
		var unlock_result = GameManager.unlock_city_building(1, cheapest)
		print("Odblokowanie '%s': %s" % [cheapest.building_name, unlock_result])
		print("Prestiż gracza 1 po odblokowaniu: ", player.prestige)
		var repeat_unlock = GameManager.unlock_city_building(1, cheapest)
		print("Ponowna próba odblokowania tego samego budynku: ", repeat_unlock)

	print("=== Koniec testu Faz 6-9 ===")
