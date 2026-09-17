class_name GameBalance
extends RefCounted
## One place for constants to tweak gameplay/balance. Instead of hunting for
## numbers scattered across autoloads and scenes, change them here.
##
## We don't keep ALL constants in the project here - only the ones that
## affect gameplay balance/pace (and therefore get tweaked regularly during
## testing). Purely structural constants (e.g. the string->enum terrain
## mapping in hex_data.gd, the color palette in hex_map_view.gd) stay local
## to the code that uses them - they make more sense there.

## Hex size in pixels - shared by pathfinding (AStar2D), grid rendering, and
## unit positioning, so all three stay in sync.
const HEX_SIZE = 40.0

## Unit movement (Phase 4+) --------------------------------------------------
## Speed of a unit's smooth movement animation, in pixels per second.
const UNIT_MOVE_SPEED_PX_PER_SEC = 220.0
## Vision radius (in hex "hops") revealed while moving - GDD section 2.2.
const VISION_RADIUS = 2

## Unit selection (clicking your own unit) -----------------------------------
## How much bigger (scale multiplier) a selected unit is drawn.
const UNIT_SELECTED_SCALE = 1.3
## Color of the highlight ring around a selected unit.
const UNIT_SELECTED_HIGHLIGHT_COLOR = Color(1.0, 0.95, 0.3, 1.0)
## Thickness of the highlight ring (px).
const UNIT_SELECTED_HIGHLIGHT_WIDTH = 4.0

## Diameter (px) a unit's optional sprite image (`Unit.sprite_texture`) is
## scaled to, regardless of the original file's dimensions.
const UNIT_SPRITE_DIAMETER = 32.0

## Movement points (MP) - now owned by the unit, not the player (Phase 6+
## update).
const UNIT_MOVEMENT_POINTS_MAX = 5
## Cost of annexation in movement points - GDD section 2.2/3 ("Annexation -
## a paid action, cost: movement points"). Annexation requires standing
## EXACTLY on the hex (unlike the rest of the field actions - see
## game_map_controller.gd).
const ANNEX_MP_COST = 2

## Forest - sustainable harvesting (GDD section 6.1) -------------------------
const FOREST_SAFE_THRESHOLD_PERCENT = 60.0
const FOREST_OVERHARVEST_PENALTY_PER_PERCENT = 2.0  # prestige penalty per % over the safe threshold
const FOREST_REGEN_BASE = 20.0
const FOREST_REGEN_MIN = 1.0
const FOREST_REGEN_EXPONENT = 2.0

## Territory takeover, PvP (GDD section 5) -----------------------------------
## Update: a takeover now requires physical presence (like annexation) and an
## attempt can always be MADE, even with insufficient prestige - see
## game_manager.gd (attempt_takeover) for the full logic of both branches.
const TAKEOVER_COST_RATIO = 0.5  # what % of the defender's prestige the attacker pays ON A SUCCESSFUL takeover
const TAKEOVER_DEFENDER_LOSS_RATIO = 0.25  # what % of their OWN prestige the defender loses on a successful takeover
const FAILED_TAKEOVER_PENALTY_RATIO = 0.3  # fraction of the (defender - attacker) prestige difference the attacker loses on a failed attempt

## Protected areas (GDD section 4) -------------------------------------------
## The penalty only applies once someone actually "develops" (builds/repairs
## a building on) a protected area - NOT for annexing it.
const PROTECTED_AREA_BASE_PENALTY = 50

## Buildings on the map (GDD section 6 - "every owned hex with a resource
## gives steady income each turn") ---------------------------------------------
## How much of its resource a REPAIRED building produces per round. One
## shared level for all buildings on the map for now - differentiating by
## building type is a topic for further balancing (GDD section 11).
const BUILDING_RESOURCE_INCOME_PER_TURN = 10.0

## Seasons (new) ---------------------------------------------------------------
## A 4-season cycle computed directly from the round number
## (`TurnManager.get_current_season()`: round_number % 4) - no separate state
## to keep in sync, the season is always exactly derived from the round
## counter. Ordered so that round 1 (the game's first round) lands on
## SPRING, which reads naturally as "the year starts in spring": WINTER = 0,
## SPRING = 1, SUMMER = 2, AUTUMN = 3.
##
## Currently only affects agricultural income (see SEASON_FOOD_MULTIPLIER
## below) - the rest of the economy (forest, industrial buildings) is not
## seasonal.
enum Season {
	WINTER,
	SPRING,
	SUMMER,
	AUTUMN,
}

## Polish season names for the UI.
const SEASON_DISPLAY_NAMES = {
	Season.WINTER: "Zima",
	Season.SPRING: "Wiosna",
	Season.SUMMER: "Lato",
	Season.AUTUMN: "Jesień",
}

## Multiplier applied to a hex's food income (HexData.is_agricultural() ==
## true) depending on the current season - winter is the "dead season"
## (fields lie fallow, no income), spring is sowing (a low but non-zero
## yield), summer is the growing season (the normal, full yield), and autumn
## is harvest time (peak yield). Applied on top of the regular
## BUILDING_RESOURCE_INCOME_PER_TURN in
## TurnManager._process_resource_income() - non-agricultural resources are
## unaffected.
const SEASON_FOOD_MULTIPLIER = {
	Season.WINTER: 0.0,
	Season.SPRING: 0.5,
	Season.SUMMER: 1.0,
	Season.AUTUMN: 2.0,
}

## Wydarzenia losowe (nowość, autoloads/random_event_manager.gd) -------------
## Wyłącznik dla całego systemu - ustaw na false, żeby grać bez wydarzeń
## losowych w ogóle (np. przy testowaniu reszty gry).
const RANDOM_EVENTS_ENABLED = true

## Co ile rund jest GWARANTOWANE choć jedno wydarzenie
## (`TurnManager.round_number % RANDOM_EVENT_GUARANTEED_INTERVAL == 0`).
const RANDOM_EVENT_GUARANTEED_INTERVAL = 5
## Dodatkowa, niezależna szansa na wydarzenie sprawdzana w KAŻDEJ rundzie
## (także tej z gwarantowanym wydarzeniem - może więc wypaść więcej niż
## jedno wydarzenie w tej samej rundzie).
const RANDOM_EVENT_EXTRA_CHANCE = 0.05

## Pożar lasu - ile % SWOJEGO AKTUALNEGO poziomu zasobu (nie 100%) płonący
## las traci każdą rundę, dopóki się nie wypali albo nie zostanie ugaszony.
const FOREST_FIRE_DECAY_RATIO = 0.25
## Szansa, sprawdzana raz na rundę dopóki pożar trwa, że rozprzestrzeni się
## na sąsiedni heks lasu.
const FOREST_FIRE_SPREAD_CHANCE = 0.15
## Koszt (w pieniądzach) jednej próby ugaszenia pożaru + szansa, że się uda -
## zawsze można spróbować ponownie w kolejnej rundzie, jeśli się nie uda.
const FOREST_FIRE_EXTINGUISH_COST = 50.0
const FOREST_FIRE_EXTINGUISH_CHANCE = 0.4

## Dotacja - losowa kwota pieniędzy z tego przedziału (włącznie).
const GRANT_MONEY_MIN = 400.0
const GRANT_MONEY_MAX = 800.0

## Strajk górniczy - ile rund kopalnie/gazoporty dotkniętego gracza nie
## produkują nic (patrz RandomEventManager - "kopalnia" = budynek
## produkujący GAS/COPPER/COAL/NICKEL/URANIUM, w odróżnieniu od rolnictwa).
const MINING_STRIKE_ROUNDS = 3

## Rekordowe żniwa stulecia - mnożnik produkcji żywności dotkniętego gracza
## i ile rund trwa.
const RECORD_HARVEST_MULTIPLIER = 5.0
const RECORD_HARVEST_ROUNDS = 5

## Plaga szkodników - ile rund produkcja żywności dotkniętego gracza wynosi
## zero, niezależnie od pory roku.
const PEST_PLAGUE_ROUNDS = 2

## Łagodna zima - mnożnik produkcji żywności zastępujący
## SEASON_FOOD_MULTIPLIER[WINTER] (normalnie 0.0) przy NAJBLIŻSZEJ zimie po
## wystąpieniu wydarzenia, dla WSZYSTKICH graczy.
const MILD_WINTER_FOOD_MULTIPLIER = 1.0

## Inspekcja środowiskowa - kara dla KAŻDEGO gracza, który w danym momencie
## ma choć jeden nadmiernie wyeksploatowany las lub zabudowaną strefę
## chronioną (RandomEventManager._is_player_abusing_environment()) - nie
## tylko dla jednego wylosowanego gracza, w odróżnieniu od reszty wydarzeń.
const ENVIRONMENTAL_INSPECTION_PRESTIGE_PENALTY = 20
const ENVIRONMENTAL_INSPECTION_MONEY_PENALTY = 150.0

## Turystyczny boom - gra nie modeluje osobnych "miejsc turystycznych" jako
## odrębnego typu heksa/budynku, więc to płaska, losowa premia (podobnie jak
## Dotacja) zamiast czegoś skalowanego z konkretnych pól - patrz
## RandomEventManager.
const TOURISM_BOOM_MONEY_MIN = 150.0
const TOURISM_BOOM_MONEY_MAX = 300.0
const TOURISM_BOOM_PRESTIGE_MIN = 10
const TOURISM_BOOM_PRESTIGE_MAX = 20

## Market Crash - cena jednego losowego surowca skacze o losowy mnożnik z
## jednego z tych dwóch przedziałów (losowany też kierunek: w górę albo w
## dół) - patrz MarketManager.trigger_price_shock().
const MARKET_CRASH_MULTIPLIER_UP_MIN = 1.5
const MARKET_CRASH_MULTIPLIER_UP_MAX = 2.5
const MARKET_CRASH_MULTIPLIER_DOWN_MIN = 0.4
const MARKET_CRASH_MULTIPLIER_DOWN_MAX = 0.6
