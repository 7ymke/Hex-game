class_name Palette
extends RefCounted
## Color palette for the game's UI - the "wood / BTD6" visual language
## (Godot port of UI_Gry_Makieta_11.html's `:root` custom properties).
## Full replacement of the earlier "elegant atlas" palette (parchment/
## copper/brass) - see the README's "Decyzje projektowe" entry for why.
## One place to look up any color used across the theme, hex_shape
## drawing, and the map view, so the whole UI stays visually consistent
## and easy to re-tune.

const WOOD_DARK = Color(0x3B / 255.0, 0x24 / 255.0, 0x15 / 255.0)
const BORDER = Color(0x2E / 255.0, 0x1B / 255.0, 0x10 / 255.0)
const WOOD_MID = Color(0x6B / 255.0, 0x44 / 255.0, 0x26 / 255.0)
const WOOD_PANEL = Color(0x7A / 255.0, 0x4F / 255.0, 0x2C / 255.0)
const WOOD_PANEL_2 = Color(0x8C / 255.0, 0x5E / 255.0, 0x36 / 255.0)

const TAN = Color(0xE4 / 255.0, 0xBE / 255.0, 0x8D / 255.0)
const TAN_2 = Color(0xEF / 255.0, 0xD3 / 255.0, 0xA8 / 255.0)
const TAN_INK = Color(0x3B / 255.0, 0x24 / 255.0, 0x15 / 255.0)

const CREAM = Color(0xFF / 255.0, 0xF3 / 255.0, 0xDD / 255.0)
const CREAM_DIM = Color(0xE3 / 255.0, 0xCD / 255.0, 0xA8 / 255.0)

const GOLD = Color(0xF5 / 255.0, 0xC2 / 255.0, 0x42 / 255.0)
const GOLD_BRIGHT = Color(0xFF / 255.0, 0xD6 / 255.0, 0x5C / 255.0)

const GREEN = Color(0x7C / 255.0, 0xB9 / 255.0, 0x3F / 255.0)
const GREEN_DARK = Color(0x4C / 255.0, 0x7A / 255.0, 0x22 / 255.0)

const RED = Color(0xE0 / 255.0, 0x50 / 255.0, 0x3A / 255.0)
const RED_DARK = Color(0xA0 / 255.0, 0x2F / 255.0, 0x1E / 255.0)

## Resource dots in the top bar (`.resource .dot.*` in the mockup).
const RESOURCE_DOT_FOOD = GOLD_BRIGHT
const RESOURCE_DOT_WOOD = Color(0x8C / 255.0, 0xC6 / 255.0, 0x3F / 255.0)
const RESOURCE_DOT_COAL = Color(0x5C / 255.0, 0x53 / 255.0, 0x4A / 255.0)
const RESOURCE_DOT_COPPER = Color(0xE0 / 255.0, 0x99 / 255.0, 0x5F / 255.0)
const RESOURCE_DOT_GAS = Color(0x6F / 255.0, 0xC1 / 255.0, 0xE8 / 255.0)
## Not in the mockup (which only shows the 5 core resources) - picked to fit
## the same palette, so the two rarer late-game resources still get a
## distinct dot instead of being silently dropped from the top bar.
const RESOURCE_DOT_NICKEL = Color(0xA9 / 255.0, 0xB7 / 255.0, 0xAC / 255.0)
const RESOURCE_DOT_URANIUM = Color(0xC7 / 255.0, 0xE0 / 255.0, 0x4C / 255.0)

## Prestige dot/star and Money dot - distinct from the resource dots above
## (a different kind of "currency").
const PRESTIGE_DOT = GOLD_BRIGHT
const MONEY_DOT = Color(0xFF / 255.0, 0xE9 / 255.0, 0xA8 / 255.0)

## Map terrain colors (`.hex.*` in the mockup) - used by hex_map_view.gd
## instead of its previous ad hoc colors, so the map matches the rest of
## the UI.
const TERRAIN_AGRICULTURAL = Color(0xB0 / 255.0, 0x8D / 255.0, 0x4F / 255.0)
const TERRAIN_FOREST = Color(0x5C / 255.0, 0x8A / 255.0, 0x2C / 255.0)
const TERRAIN_MOUNTAIN = Color(0x7A / 255.0, 0x6E / 255.0, 0x5E / 255.0)
const TERRAIN_CITY = GOLD
const TERRAIN_PROTECTED_AREA = Color(0.18, 0.55, 0.5)
const TERRAIN_WATER = Color(0.2, 0.4, 0.75)
const TERRAIN_UNKNOWN = Color(0.6, 0.6, 0.6)
const FOG_UNEXPLORED = Color(20.0 / 255.0, 14.0 / 255.0, 8.0 / 255.0, 0.92)

## The map viewport's own background (behind/around the hex field) -
## project.godot's `rendering/environment/defaults/default_clear_color`.
const MAP_BACKGROUND = BORDER
