extends Node
## Autoload: TurnManager
## Turn structure (GDD section 8: "players move in alternation OR
## simultaneously, then the round is resolved" - the GDD explicitly allows
## either order).
##
## Update: control over the active player and round resolution are now two
## COMPLETELY independent things. The "Zmiana gracza" (change player) UI
## control switches control to a SPECIFIC player directly
## (`switch_to_player`) - there is no more cyclic "next player", nor a
## "player's turn" concept blocking everything else. "Zakończ rundę" (end
## round) (`end_round`) resolves the round (forest regrowth, income,
## refreshing MP for all units) at any moment, independent of which player
## is currently in control - resolving a round does not change who is active.

signal round_ended(round_number: int)
signal player_turn_started(player_id: int)

var round_number: int = 1
var player_order: Array[int] = []
var current_player_index: int = 0


func setup_player_order(ids: Array[int]) -> void:
	player_order = ids
	current_player_index = 0
	if not player_order.is_empty():
		player_turn_started.emit(get_current_player_id())


func get_current_player_id() -> int:
	if player_order.is_empty():
		return -1
	return player_order[current_player_index]


## Switches control to the CHOSEN player (e.g. from a list in the UI) - a
## free choice, not cycling through them in order.
func switch_to_player(player_id: int) -> void:
	var index = player_order.find(player_id)
	if index == -1:
		return
	current_player_index = index
	player_turn_started.emit(get_current_player_id())


## Resolves the round on demand (the "Zakończ rundę" / end round button) -
## does NOT change which player is currently in control.
##
## RandomEventManager runs FIRST (a no-op if GameBalance.RANDOM_EVENTS_ENABLED
## is false) - before forest regeneration, so a freshly-ignited/decayed
## burning hex doesn't ALSO regrow in the very same round, and before
## resource income, so a freshly-rolled event (pest plague, mining strike,
## record harvest, mild winter) already affects THIS round's numbers instead
## of only the next one.
func end_round() -> void:
	RandomEventManager.process_round_end()
	_process_forest_regeneration()
	_process_resource_income()
	MarketManager.process_round_end()
	round_number += 1
	round_ended.emit(round_number)


## Current season, derived directly from `round_number` (GameBalance.Season:
## round_number % 4) - see the comment there for the ordering/rationale.
## Deliberately computed on demand rather than stored, so it can never drift
## out of sync with the round counter. Typed as plain `int` (a
## GameBalance.Season value) rather than the enum type itself, since it's
## only ever used as a dictionary key (SEASON_DISPLAY_NAMES/
## SEASON_FOOD_MULTIPLIER) or printed - both work identically either way,
## and enums are ints at runtime regardless.
func get_current_season() -> int:
	return round_number % 4


func _process_forest_regeneration() -> void:
	for hex: HexData in MapData.hexes.values():
		# A burning hex already lost resource_level THIS round via
		# RandomEventManager._process_burning_fires() (called before this,
		# in end_round()) - it doesn't also regrow while on fire.
		if not hex.is_forest() or hex.is_on_fire:
			continue

		var current = hex.resource_level
		var growth = maxf(
			GameBalance.FOREST_REGEN_MIN,
			GameBalance.FOREST_REGEN_BASE * pow(current / 100.0, GameBalance.FOREST_REGEN_EXPONENT)
		)
		hex.resource_level = minf(100.0, current + growth)

		if hex.resource_level >= GameBalance.FOREST_SAFE_THRESHOLD_PERCENT:
			hex.generates_prestige = true


## Steady income from resources other than forest (GDD section 6 - forest is
## the exception). Agricultural hexes (HexData.is_agricultural()) are scaled
## by the current season (GameBalance.SEASON_FOOD_MULTIPLIER) - everything
## else produces its usual flat amount, season or not. Uses THIS round's
## season (round_number has not been incremented yet at this point in
## end_round()), i.e. the harvest reflects the season of the round that is
## being resolved.
##
## Random events (RandomEventManager) can override this per-player, on top
## of the season: Plaga szkodników zeruje food income outright (checked
## first - a plague ruins the crop regardless of how good the harvest would
## otherwise have been), Rekordowe żniwa multiplies it, and Strajk górniczy
## zeroes mining income (MINING_RESOURCE_TYPES - anything that isn't food or
## wood). "Rozwój gospodarczy" (skill tree, player.industrial_income_bonus)
## is applied LAST, as a flat % bonus on top of whatever the amount already
## is - safe to apply unconditionally (multiplying a zeroed-out amount by
## anything is still zero, so a plague/strike isn't accidentally undone).
func _process_resource_income() -> void:
	var season = get_current_season()
	var food_multiplier = GameBalance.SEASON_FOOD_MULTIPLIER[season]

	for hex: HexData in MapData.hexes.values():
		if hex.owner_id == -1 or hex.is_forest():
			continue
		if hex.building == null or hex.building_damaged:
			continue

		var player = GameManager.get_player(hex.owner_id)
		if player == null:
			continue

		var resource = hex.building.produced_resource
		var amount = hex.building.produced_amount_per_turn

		if hex.is_agricultural():
			amount *= food_multiplier
			if RandomEventManager.is_pest_plague_active(player.player_id):
				amount = 0.0
			elif RandomEventManager.is_record_harvest_active(player.player_id):
				amount *= GameBalance.RECORD_HARVEST_MULTIPLIER
		elif (
			RandomEventManager.MINING_RESOURCE_TYPES.has(resource)
			and RandomEventManager.is_mining_disabled(player.player_id)
		):
			amount = 0.0

		amount *= 1.0 + player.industrial_income_bonus / 100.0
		player.add_resource(resource, amount)
