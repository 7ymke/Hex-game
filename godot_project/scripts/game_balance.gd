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
