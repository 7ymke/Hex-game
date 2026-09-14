class_name PlayerSetup
extends RefCounted
## List of the hotseat starting players - id, name, city, base hex, token
## color. Shared source of truth for scenes/start_screen.gd (city selection
## before the game starts) and scenes/game_map_controller.gd (player
## registration) - so both places always agree on which cities, ID order,
## and colors exist.
##
## All 6 cities from GDD section 7. The optional "sprite" key (a res://...
## path) swaps the default circle for a token image - see
## Unit.sprite_texture in unit.gd. Without this key, a circle in "color" is
## drawn instead.
const LIST = [
	{"id": 1, "name": "Gracz 1", "city": "Wrocław", "start_hex": "H18", "color": Color(0.9, 0.2, 0.2)},
	{"id": 2, "name": "Gracz 2", "city": "Szczecin", "start_hex": "A7", "color": Color(0.2, 0.4, 0.9)},
	{"id": 3, "name": "Gracz 3", "city": "Warszawa", "start_hex": "R12", "color": Color(0.2, 0.75, 0.3)},
	{"id": 4, "name": "Gracz 4", "city": "Kraków", "start_hex": "O22", "color": Color(0.95, 0.6, 0.1)},
	{"id": 5, "name": "Gracz 5", "city": "Gdańsk", "start_hex": "L3", "color": Color(0.6, 0.25, 0.85)},
	{"id": 6, "name": "Gracz 6", "city": "Poznań", "start_hex": "G12", "color": Color(0.1, 0.75, 0.75)},
]
