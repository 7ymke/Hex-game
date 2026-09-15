class_name Palette
extends RefCounted
## Color palette for the game's UI restyle (Godot port of UI_Gry_Makieta.html
## - the CSS custom properties in its `:root` block). One place to look up
## any color used across the theme, hex_shape drawing, and the map view, so
## the whole UI stays visually consistent and easy to re-tune.

const INK = Color(0xED / 255.0, 0xE6 / 255.0, 0xD6 / 255.0)
const INK_DIM = Color(0x9F / 255.0, 0xB0 / 255.0, 0x9A / 255.0)
const BG_DEEP = Color(0x0C / 255.0, 0x14 / 255.0, 0x0C / 255.0)
const BG_MAP = Color(0x16 / 255.0, 0x26 / 255.0, 0x1C / 255.0)
const PANEL = Color(0x18 / 255.0, 0x24 / 255.0, 0x17 / 255.0)
const PANEL_2 = Color(0x1E / 255.0, 0x2C / 255.0, 0x1C / 255.0)
const COPPER = Color(0xC9 / 255.0, 0x7A / 255.0, 0x4A / 255.0)
const COPPER_BRIGHT = Color(0xE0 / 255.0, 0x99 / 255.0, 0x5F / 255.0)
const BRASS = Color(0xC9 / 255.0, 0xA2 / 255.0, 0x4B / 255.0)
const PARCHMENT = Color(0xEF / 255.0, 0xE6 / 255.0, 0xD3 / 255.0)
const PARCHMENT_INK = Color(0x2B / 255.0, 0x26 / 255.0, 0x20 / 255.0)
## `.ludzik-card .head .mp` / `.links button` text color - a muted brown,
## lighter than PARCHMENT_INK, for secondary text on the parchment card.
const PARCHMENT_MUTED = Color(0x6B / 255.0, 0x5F / 255.0, 0x4D / 255.0)
const DANGER = Color(0xC1 / 255.0, 0x54 / 255.0, 0x3D / 255.0)
const SAFE = Color(0x7F / 255.0, 0xAE / 255.0, 0x6E / 255.0)

## rgba(201, 162, 75, alpha) - a brass hairline, used for borders/separators.
const RULE = Color(0xC9 / 255.0, 0xA2 / 255.0, 0x4B / 255.0, 0.32)
const RULE_DIM = Color(0xC9 / 255.0, 0xA2 / 255.0, 0x4B / 255.0, 0.16)

## Resource dots in the top bar (`.resource .dot.*` in the mockup).
const RESOURCE_DOT_WOOD = Color(0x7C / 255.0, 0xA8 / 255.0, 0x6A / 255.0)
const RESOURCE_DOT_FOOD = Color(0xD9 / 255.0, 0xB2 / 255.0, 0x4C / 255.0)
const RESOURCE_DOT_COPPER = COPPER_BRIGHT
const RESOURCE_DOT_COAL = Color(0x4A / 255.0, 0x46 / 255.0, 0x40 / 255.0)
const RESOURCE_DOT_COAL_BORDER = Color(0x6B / 255.0, 0x65 / 255.0, 0x5C / 255.0)
const RESOURCE_DOT_GAS = Color(0x6F / 255.0, 0xA8 / 255.0, 0xD8 / 255.0)
## Not in the mockup (which only shows the 5 core resources) - picked to fit
## the same palette, so the two rarer late-game resources still get a
## distinct dot instead of being silently dropped from the top bar.
const RESOURCE_DOT_NICKEL = Color(0.75, 0.75, 0.78)
const RESOURCE_DOT_URANIUM = Color(0.7, 0.85, 0.25)

## Map terrain colors (`.hex.*` in the mockup) - used by hex_map_view.gd
## instead of its previous ad hoc colors, so the map matches the rest of the
## restyled UI.
const TERRAIN_AGRICULTURAL = Color(0x8C / 255.0, 0x83 / 255.0, 0x52 / 255.0)
const TERRAIN_FOREST = Color(0x4C / 255.0, 0x7A / 255.0, 0x45 / 255.0)
const TERRAIN_MOUNTAIN = Color(0x6B / 255.0, 0x64 / 255.0, 0x59 / 255.0)
const TERRAIN_CITY = COPPER
const TERRAIN_PROTECTED_AREA = Color(0.18, 0.55, 0.5)
const TERRAIN_WATER = Color(0.2, 0.4, 0.75)
const TERRAIN_UNKNOWN = Color(0.6, 0.6, 0.6)
const FOG_UNEXPLORED = Color(0.08, 0.1, 0.08)
