extends Node
## Manualny test dymny (smoke test) Fazy 0-1 planu implementacji.
## Uruchom tę scenę (F6 / "Run Current Scene"), żeby zobaczyć w konsoli,
## czy wczytywanie mapy, aneksacja, wydobycie lasu i przeliczenie rundy działają.

func _ready() -> void:
	print("=== Test Fazy 0-1: dane, aneksacja, wydobycie lasu, tura ===")
	print("Liczba wczytanych heksów: ", MapData.hexes.size())

	var player := PlayerData.new()
	player.player_id = 1
	player.player_name = "Gracz testowy"
	player.starting_city = "Wrocław"
	GameManager.register_player(player)

	# Aneksacja heksa bazowego Wrocławia (H14 wg konwencji z KML)
	if MapData.get_hex("H14") != null:
		var result := GameManager.annex_hex("H14", 1)
		print("Aneksacja H14 (Wrocław): ", result)
	else:
		print("UWAGA: nie znaleziono heksa H14 - sprawdź dane mapy.")

	# Znajdź pierwszy dostępny heks leśny i przetestuj oba warianty wydobycia
	var forest_hex_id := ""
	for hex_id in MapData.hexes:
		var hex: HexData = MapData.hexes[hex_id]
		if hex.is_forest():
			forest_hex_id = hex_id
			break

	if forest_hex_id != "":
		GameManager.annex_hex(forest_hex_id, 1)

		var safe_result := GameManager.harvest_forest(forest_hex_id, 1, 50.0)
		print("Wydobycie 50%% z lasu %s (bezpieczne, brak kary): %s" % [forest_hex_id, safe_result])

		var over_result := GameManager.harvest_forest(forest_hex_id, 1, 90.0)
		print("Wydobycie 90%% z lasu %s (przekroczenie progu 60%%): %s" % [forest_hex_id, over_result])

		print("Prestiż gracza po nadmiernej wycince: ", player.prestige)
		print("Zasoby drewna gracza: ", player.get_resource_amount(HexData.ResourceType.WOOD))

		var hex_after: HexData = MapData.get_hex(forest_hex_id)
		print("Pole %s generuje prestiż? %s (powinno być false po przekroczeniu)" % [forest_hex_id, hex_after.generates_prestige])

		# Przeliczenie rundy - sprawdzenie regeneracji
		TurnManager.setup_player_order([1])
		TurnManager._end_round()
		print("--- Po przeliczeniu rundy ---")
		print("Poziom zasobu %s po regeneracji: %.1f%%" % [forest_hex_id, hex_after.resource_level])
		print("Pole generuje prestiż po regeneracji? ", hex_after.generates_prestige)
	else:
		print("UWAGA: nie znaleziono żadnego heksa lasu w danych mapy.")

	print("=== Koniec testu ===")
