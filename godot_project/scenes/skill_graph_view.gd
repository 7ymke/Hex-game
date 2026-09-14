class_name SkillGraphView
extends Control
## Rysuje POŁĄCZENIA drzewka umiejętności - centralny węzeł "START" i linie
## do każdej karty umiejętności, żeby całość wizualnie wyglądała jak graf/
## drzewko, nawet że logicznie skille są na razie płaskie (bez
## prerequisitów między sobą - patrz scripts/skill_tree_data.gd i komentarz
## w skill_tree_panel.gd). Same karty (przyciski/opisy) są zwykłymi
## Controlami dodawanymi z zewnątrz (SkillTreePanel._refresh(), jako
## rodzeństwo tego węzła, więc rysują się NAD liniami) i pozycjonowanymi
## bezpośrednio - ten skrypt tylko rysuje to, co jest POD nimi.

const HUB_RADIUS = 26.0
const HUB_COLOR = Color(0.3, 0.5, 0.85, 0.95)
const HUB_OUTLINE_COLOR = Color(0.85, 0.9, 1.0, 0.9)
const LINE_COLOR = Color(0.45, 0.6, 0.85, 0.6)
const LINE_WIDTH = 3.0

## Środki kart i węzła centralnego, w lokalnych współrzędnych tego Controla -
## ustawiane przez SkillTreePanel._refresh() po rozmieszczeniu kart, zaraz
## przed queue_redraw().
var node_centers: Array[Vector2] = []
var hub_center: Vector2 = Vector2.ZERO


func _draw() -> void:
	for p in node_centers:
		draw_line(hub_center, p, LINE_COLOR, LINE_WIDTH)

	draw_circle(hub_center, HUB_RADIUS, HUB_COLOR)
	draw_arc(hub_center, HUB_RADIUS, 0.0, TAU, 32, HUB_OUTLINE_COLOR, 2.5)
	draw_string(
		ThemeDB.fallback_font, hub_center + Vector2(-20, 5), "START",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE
	)
