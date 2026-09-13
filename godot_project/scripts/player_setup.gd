class_name PlayerSetup
extends RefCounted
## Lista graczy startowych hotseat - id, nazwa, miasto, heks bazowy, kolor
## pionka. Wspólne źródło prawdy dla scenes/start_screen.gd (wybór miast
## przed rozpoczęciem gry) i scenes/game_map_controller.gd (rejestracja
## graczy) - żeby oba miejsca zawsze zgadzały się co do tego, jakie miasta,
## kolejność ID i kolory istnieją.
##
## Wszystkie 6 miast z sekcji 7 GDD. Opcjonalny klucz "sprite" (ścieżka
## res://...) podmienia domyślne kółko na obrazek pionka - patrz
## Ludzik.sprite_texture w ludzik.gd. Bez tego klucza rysowane jest kółko w
## kolorze "color".
const LIST = [
	{"id": 1, "name": "Gracz 1", "city": "Wrocław", "start_hex": "H18", "color": Color(0.9, 0.2, 0.2)},
	{"id": 2, "name": "Gracz 2", "city": "Szczecin", "start_hex": "A7", "color": Color(0.2, 0.4, 0.9)},
	{"id": 3, "name": "Gracz 3", "city": "Warszawa", "start_hex": "R12", "color": Color(0.2, 0.75, 0.3)},
	{"id": 4, "name": "Gracz 4", "city": "Kraków", "start_hex": "O22", "color": Color(0.95, 0.6, 0.1)},
	{"id": 5, "name": "Gracz 5", "city": "Gdańsk", "start_hex": "L3", "color": Color(0.6, 0.25, 0.85)},
	{"id": 6, "name": "Gracz 6", "city": "Poznań", "start_hex": "G12", "color": Color(0.1, 0.75, 0.75)},
]
