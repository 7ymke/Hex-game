class_name GameBalance
extends RefCounted
## Jedno miejsce na stałe do tweakowania rozgrywki/balansu. Zamiast szukać
## liczb rozsianych po autoloadach i scenach, zmieniaj je tutaj.
##
## Nie trzymamy tu WSZYSTKICH stałych w projekcie - tylko te, które wpływają
## na balans/tempo rozgrywki (i dlatego regularnie się je tweakuje podczas
## testów). Stałe czysto strukturalne (np. mapowanie string->enum terenu w
## hex_data.gd, paleta kolorów w hex_map_view.gd) zostają lokalnie przy
## kodzie, który z nich korzysta - tam mają więcej sensu.

## Rozmiar heksa w pikselach - współdzielony przez pathfinding (AStar2D),
## rysowanie siatki i pozycjonowanie ludzików, żeby wszystkie trzy się zgadzały.
const HEX_SIZE = 40.0

## Ruch ludzika (Faza 4+) ---------------------------------------------------
## Prędkość płynnej animacji ruchu ludzika, w pikselach na sekundę.
const LUDZIK_MOVE_SPEED_PX_PER_SEC = 220.0
## Promień widzenia (w "skokach" heksów) odsłaniany podczas ruchu - sekcja 2.2 GDD.
const VISION_RADIUS = 2

## Zaznaczenie ludzika (klik na własnego ludzika) -----------------------------
## O ile większy (mnożnik skali) jest zaznaczony ludzik.
const LUDZIK_SELECTED_SCALE = 1.3
## Kolor pierścienia podświetlenia wokół zaznaczonego ludzika.
const LUDZIK_SELECTED_HIGHLIGHT_COLOR = Color(1.0, 0.95, 0.3, 1.0)
## Grubość pierścienia podświetlenia (px).
const LUDZIK_SELECTED_HIGHLIGHT_WIDTH = 4.0

## Średnica (px), do jakiej skalowany jest opcjonalny obrazek ludzika
## (`Ludzik.sprite_texture`), niezależnie od oryginalnego rozmiaru pliku.
const LUDZIK_SPRITE_DIAMETER = 32.0

## Punkty ruchu (MP) - teraz własność ludzika, nie gracza (Faza 6+ update).
const LUDZIK_MOVEMENT_POINTS_MAX = 5
## Koszt aneksacji w punktach ruchu - sekcja 2.2/3 GDD ("Aneksacja - płatna
## akcja, koszt: punkty ruchu"). Aneksacja wymaga stania DOKŁADNIE na polu
## (w przeciwieństwie do reszty akcji na polu - patrz game_map_controller.gd).
const ANNEX_MP_COST = 2

## Las - zrównoważone wydobycie (sekcja 6.1 GDD) ----------------------------
const FOREST_SAFE_THRESHOLD_PERCENT = 60.0
const FOREST_OVERHARVEST_PENALTY_PER_PERCENT = 2.0  # kara prestiżu za każdy % nadwyżki
const FOREST_REGEN_BASE = 20.0
const FOREST_REGEN_MIN = 1.0
const FOREST_REGEN_EXPONENT = 2.0

## Przejęcie terytorium PvP (sekcja 5 GDD) ----------------------------------
const TAKEOVER_COST_RATIO = 0.5  # jaki % prestiżu obrońcy płaci atakujący

## Strefy chronione (sekcja 4 GDD) ------------------------------------------
## Kara nalicza się dopiero, gdy ktoś faktycznie "zagospodaruje" (zbuduje/
## naprawi budynek na) strefie chronionej - NIE za samą aneksację.
const PROTECTED_AREA_BASE_PENALTY = 50

## Budynki na mapie (sekcja 6 GDD - "każdy posiadany heks z zasobem daje
## stały dochód co turę") ----------------------------------------------------
## Ile jednostek surowca produkuje NAPRAWIONY budynek na rundę. Jeden wspólny
## poziom dla wszystkich budynków na mapie na razie - zróżnicowanie wg typu
## budynku to temat do dalszego balansowania (sekcja 11 GDD).
const BUILDING_RESOURCE_INCOME_PER_TURN = 10.0
