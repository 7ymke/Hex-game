# Heksagonalna Strategia Ekonomiczna — Polska

Godot 4.2.2. Zaimplementowane: **Fazy 0-5** z `Plan_Implementacji_Godot.md`
(fundament, import mapy, wizualizacja, mgła wojny, ludzik i ruch, akcje na polu).

## Jak to uruchomić

1. Otwórz folder `godot_project/` w Godot 4.2.2 (Import → wskaż `project.godot`).
2. Naciśnij **F5** (Run Project) — scena `scenes/main.tscn` jest ustawiona jako
   główna, więc powinna wystartować od razu.
3. Zobaczysz mapę: jeden odkryty heks (Wrocław, `H14`) z ludzikiem, reszta
   zakryta mgłą. Siatka jest **flat-top** (płaski bok na górze/dole heksa).
4. **Sterowanie**:
   - **Lewy klik** na widoczny heks → ludzik idzie tam pieszo (pathfinding),
     krok po kroku, zużywając punkty ruchu wg kosztu terenu.
   - **Prawy przycisk myszy + przeciąganie** → przesuwanie widoku kamery.
   - **Scroll** → zoom.
   - Najedź myszą na heks, żeby zobaczyć w górnym lewym rogu, co o nim wiadomo
     (nic / tylko typ terenu / pełne dane) — zgodnie z dwupoziomową mgłą wojny.
   - Panel w lewym dolnym rogu pokazuje pole, na którym aktualnie stoi ludzik,
     i udostępnia akcje: **Zaanektuj**, **Napraw budynek** (jeśli jest
     uszkodzony budynek), **Wydobądź drewno** (suwak % — tylko na lasach),
     **Zakończ turę** (przelicza rundę: regeneracja lasu, dochód, punkty ruchu).
5. Dla testu niższego poziomu (bez UI/kamery) nadal działa `scenes/main_test.tscn`
   z Fazy 0-1 (F6 na tej scenie).

## Co jest w środku

```
godot_project/
├── project.godot            # main_scene = scenes/main.tscn, autoloady
├── autoloads/
│   ├── map_data.gd           # wczytuje data/map_data.json, sąsiedzi, auto-tworzy
│   │                          # placeholder Building na heksach z zasobem
│   ├── game_manager.gd       # gracze, aneksacja, naprawa, wydobycie lasu, przejęcia
│   └── turn_manager.gd       # kolejność graczy, przeliczenie rundy
├── resources/
│   ├── hex_data.gd            # class_name HexData (Resource)
│   ├── building.gd            # class_name Building (Resource)
│   └── player_data.gd         # class_name PlayerData (Resource)
├── scripts/
│   ├── hex_grid_utils.gd       # matematyka siatki - offset "even-q", flat-top
│   └── hex_pathfinder.gd       # A* (AStar2D) po heksach, wg kosztu terenu
├── scenes/
│   ├── main.tscn                # scena grywalna (Fazy 2-5) - kamera, mapa, ludzik, UI
│   ├── game_map_controller.gd   # orchestracja: ruch, mgła, akcje na polu, tura
│   ├── hex_map_view.gd          # rysowanie siatki + mgła wojny + klikanie/hover
│   ├── camera_controller.gd     # pan (PPM) / zoom (scroll)
│   ├── ludzik.gd                 # wizualny pionek gracza
│   └── main_test.tscn / main_test.gd   # smoke test Fazy 0-1 (bez grafiki)
├── data/map_data.json         # wygenerowane przez tools/convert_kml_to_json.py
└── icon.svg
```

Skrypt konwertujący (`tools/convert_kml_to_json.py`) jest **poza** folderem
`godot_project/`, bo to jednorazowe narzędzie deweloperskie, nie część gry —
użyj go ponownie, gdy dodasz kolejne fragmenty KML dla reszty Polski:

```
python3 convert_kml_to_json.py nowa_mapa.kml godot_project/data/map_data.json
```

## Orientacja siatki: flat-top, offset "even-q"

Heksy mają płaski bok na górze/dole (nie ostry wierzchołek). Kolumny parzyste
(A, C, E, G, I...) są przesunięte w dół o pół heksa względem nieparzystych —
efekt: przy tym samym numerze wiersza, kolejna litera kolumny renderuje się
**wyżej** (np. H14 leży nad G14). Matematyka w `hex_grid_utils.gd` jest
zweryfikowana (round-trip piksel↔heks i odległości sąsiadów) skryptem
pomocniczym w Pythonie, bez uruchamiania samego Godota.

## ⚠️ Znaleziony problem w danych źródłowych KML

Konwerter wykrył, że w Twoim pliku KML trzy identyfikatory heksów są użyte
**dwukrotnie**, dla zupełnie różnych miejsc:

- `D12` → "Złoża miedzi" (16.057, 51.318) ORAZ "LAS" (15.696, 51.445)
- `D13` → "Zakłady Ceramiczne w Bolesławcu" ORAZ "UNESCO Kościół Pokoju w Jaworze"
- `D14` → "Karkonoski Park Narodowy" ORAZ "Jelenia Góra (Kotlina JG)"

W obecnym `map_data.json` oba warianty zostały zachowane pod sufiksami
`_conflict2` (np. `D12_conflict2`), żeby żadne dane się nie zgubiły — ale to
**tymczasowe obejście**. Popraw numerację w Google Earth (każdy heks = jeden,
unikalny identyfikator) i wygeneruj JSON ponownie.

Pominięty został też Placemark "Wałbrzych" — nie ma w nazwie identyfikatora
hexa (`A1`, `D12` itp.), więc nie dało się go przypisać do siatki. Dodaj mu
prefiks z odpowiednim ID, jeśli ma być osobnym heksem.

## Uproszczenia i rzeczy do zweryfikowania dalej

- **Kształt siatki jest wyidealizowany, nie geograficznie dokładny.** Do
  renderowania i sąsiedztwa używamy czystej matematyki heksagonalnej opartej
  WYŁĄCZNIE na literze/numerze z ID heksa — nie na rzeczywistych
  współrzędnych lon/lat. Mapa w grze będzie miała równy kształt heksagonalny,
  ale nie odwzoruje 1:1 proporcji prawdziwej Polski. Świadomy kompromis na
  tym etapie.
- **Koszt naprawy budynków = 0** (`required_resources` puste w placeholderowym
  `Building` tworzonym automatycznie w `map_data.gd`). To celowe uproszczenie,
  dopóki nie ustalimy treści/kosztów konkretnych budynków (Faza 8, Karta
  Miasta) — repair działa więc już teraz "za darmo", tylko żeby przetestować
  przepływ aneksacja → naprawa → dochód.
- **Koszt ścieżki w `HexPathfinder` przez `AStar2D.weight_scale`** to
  przybliżenie (Godot liczy koszt krawędzi na podstawie dystansu i
  weight_scale OBU połączonych punktów, nie tylko punktu docelowego) —
  w praktyce powinno dawać rozsądne wyniki (dystans między sąsiadami jest
  zawsze taki sam), ale warto to zwizualizować/przetestować w edytorze.
- **Blokada heksa przez cudzego ludzika** (sekcja 3 GDD — "nikt nie wejdzie,
  dopóki tam stoi") **nie jest jeszcze wpięta** do pathfindera/ruchu — obecna
  scena testowa ma jednego gracza. To naturalnie wejdzie w grę przy Fazie 9
  (przejęcie terytorium) albo wcześniej, jeśli zechcesz przetestować to z
  dwoma ludzikami już teraz.
- Klasyfikacja terenu/zasobu w konwerterze KML→JSON działa na słowach
  kluczowych — dla nietypowych etykiet (fabryki, atrakcje UNESCO) może
  wymagać ręcznej korekty w JSON albo rozbudowy listy słów kluczowych.
- Siatka obejmuje na razie tylko heksy z dostarczonego wycinka KML (63 sztuk),
  nie całą Polskę.
- **Jeszcze nie zaimplementowane**: pełna struktura tur wielu graczy
  (Faza 6 - obecnie jeden gracz, przycisk "Zakończ turę" po prostu przelicza
  rundę), Karta Miasta (Faza 8), przejęcie terytorium w UI (Faza 9),
  multiplayer (Faza 10).
