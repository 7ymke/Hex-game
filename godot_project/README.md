# Heksagonalna Strategia Ekonomiczna — Polska

Godot 4.2.2. Zaimplementowane: **Fazy 0-9** z `Plan_Implementacji_Godot.md`
(fundament, import mapy, wizualizacja, mgła wojny, ludzik i ruch, akcje na
polu, pełna struktura tur wielu graczy, prestiż jako centralna waluta, Karta
Miasta, przejęcie terytorium PvP). Gra jest w pełni grywalna w trybie
jednoosobowym-na-jednym-ekranie (**hotseat**, 2 graczy) — dokładnie to, co
plan implementacji zakłada jako cel Faz 0-9, zanim dojdzie warstwa sieciowa
(Faza 10).

Wszystkie liczby do tweakowania balansu (prędkość ludzika, punkty ruchu,
zasięg akcji, progi/kary lasu i stref chronionych, koszt przejęcia
terytorium...) mieszkają w jednym pliku: `scripts/game_balance.gd`.

Uwaga stylistyczna: kod celowo NIE używa operatora `:=` (type inference) -
tylko zwykłego `=` - bo w niektórych konfiguracjach Godota 4.2.2 potrafi on
sypać błędami parsera. Trzymaj się tej konwencji w nowym kodzie.

## Jak to uruchomić

1. Otwórz folder `godot_project/` w Godot 4.2.2 (Import → wskaż `project.godot`).
2. Naciśnij **F5** (Run Project) — scena `scenes/main.tscn` jest ustawiona jako
   główna, więc powinna wystartować od razu.
3. Gra hotseat, **2 graczy**: Gracz 1 startuje we Wrocławiu (`H14`), Gracz 2
   w Szczecinie (`A3`) — każdy widzi tylko odkryty przez siebie fragment mapy
   (osobna mgła wojny per gracz). Siatka jest **flat-top** (płaski bok na
   górze/dole heksa).
4. **Sterowanie** (dotyczy aktualnie aktywnego gracza — patrz etykieta "Tura
   gracza" w lewym górnym rogu):
   - **Lewy klik na własnego ludzika** → zaznacza go (biały pierścień) albo
     odznacza, jeśli już był zaznaczony. Zaznaczenie jest tylko o WYDAWANIU
     ROZKAZU RUCHU - akcje na polu (patrz niżej) działają niezależnie od
     zaznaczenia, o ile jakiś twój ludzik jest wystarczająco blisko.
   - **Lewy klik na dowolny inny heks**, mając ludzika zaznaczonego → ludzik
     płynnie (animowany ruch, konfigurowalna prędkość -
     `GameBalance.LUDZIK_MOVE_SPEED_PX_PER_SEC`) idzie tam po trasie z
     pathfindingu, krok po kroku, zużywając punkty ruchu WG KOSZTU TERENU.
     Punkty ruchu (MP) należą teraz do ludzika, nie do gracza - każdy ludzik
     ma własną pulę (przygotowane pod przyszły upgrade "więcej ludzików na
     gracza"). Heks zajęty aktualnie przez ludzika PRZECIWNIKA jest
     nieprzejezdny - ani jako przystanek, ani jako tranzyt trasy (sekcja 3
     GDD, "funkcja obronna").
   - **Lewy klik na heks bez zaznaczonego ludzika** → tylko zaznacza to pole
     (żółta obwódka) do inspekcji/akcji - NIE przesuwa nikogo. Dzięki temu np.
     wydobycie drewna nie wymaga fizycznego wejścia na pole lasu.
   - **Prawy przycisk myszy + przeciąganie** → przesuwanie widoku kamery.
   - **Scroll** → zoom.
   - Najedź myszą na heks, żeby zobaczyć w górnym lewym rogu, co o nim wiadomo
     (nic / tylko typ terenu / pełne dane) — zgodnie z dwupoziomową mgłą wojny.
   - Panel w lewym dolnym rogu pokazuje ZAZNACZONE pole i udostępnia akcje -
     każda z nich wymaga, żeby jakiś twój ludzik był w zasięgu
     `GameBalance.ACTION_RANGE` heksów od zaznaczonego pola (domyślnie: pole
     lub sąsiad) - nie trzeba stać dokładnie na nim:
     - **Zaanektuj** — przejmuje niczyj heks. Kosztuje punkty ruchu
       (`GameBalance.ANNEX_MP_COST`) pobierane z puli najbliższego/zaznaczonego
       ludzika (sekcja 2.2 GDD: "Aneksacja - płatna akcja").
     - **Przejmij teren** — widoczny tylko, gdy zaznaczony heks należy do
       innego gracza; wymaga DODATKOWO, żeby broniący go ludzik akurat na nim
       nie stał (inaczej to nadal "funkcja obronna" z sekcji 3 GDD, sam zasięg
       jej nie omija); przejęcie następuje, jeśli twój prestiż jest ściśle
       większy niż obrońcy, kosztem prestiżu proporcjonalnym do jego siły
       (sekcja 5 GDD).
     - **Napraw budynek** (jeśli jest uszkodzony budynek). Na terenie
       chronionym ta akcja NALICZA karę prestiżową (patrz sekcja niżej) -
       sama aneksacja strefy chronionej już nie karze.
     - **Wydobądź drewno** (suwak % — tylko na lasach, w zasięgu, bez
       konieczności stania na polu).
     - **Karta Miasta** — osobny ekran: lista budynków charakterystycznych
       dla miasta aktywnego gracza, każdy z kosztem w zasobach i wartością
       prestiżową po odblokowaniu (sekcja 7 GDD).
   - **Zmiana gracza** — przełącza kontrolę na kolejnego zarejestrowanego
     gracza BEZ kończenia czyjejkolwiek tury - swobodne przełączanie się tam
     i z powrotem, np. żeby dokończyć ruch ludzikiem danego gracza później.
   - **Zakończ turę** — oznacza aktywnego gracza jako "gotowego" na tę rundę i
     przełącza na kolejnego, który jeszcze nie skończył. Runda (regeneracja
     lasu, dochód, odnowienie MP wszystkich ludzików) przelicza się dopiero,
     gdy WSZYSCY gracze są gotowi - do tego czasu gracze mogą kończyć/wracać
     do swoich tur w dowolnej kolejności (sekcja 8 GDD dopuszcza "na przemian
     LUB jednocześnie"). Licznik "Gotowi: x/y" w etykiecie tury pokazuje postęp.
5. Dla testu niższego poziomu (bez UI/kamery/grafiki) nadal działa
   `scenes/main_test.tscn` (F6 na tej scenie) — smoke test Fazy 0-1 (dane,
   aneksacja, wydobycie lasu, tura) **plus** Faz 6-9 (drugi gracz, blokada
   ruchu przez `HexPathfinder`, przejęcie terytorium, kara za strefę
   chronioną, odblokowanie budynku Karty Miasta) — wszystko jako czytelne
   logi w konsoli, bo w tym trybie nie ma węzłów `Ludzik`/kamery do klikania.

## Co jest w środku

```
godot_project/
├── project.godot            # main_scene = scenes/main.tscn, autoloady
├── autoloads/
│   ├── map_data.gd           # wczytuje data/map_data.json, sąsiedzi, auto-tworzy
│   │                          # placeholder Building na heksach z zasobem
│   ├── game_manager.gd       # gracze, aneksacja, naprawa, wydobycie lasu,
│   │                          # przejęcia, kara za strefy chronione, Karta Miasta
│   └── turn_manager.gd       # kolejność graczy, przeliczenie rundy
├── resources/
│   ├── hex_data.gd              # class_name HexData (Resource)
│   ├── building.gd               # class_name Building (Resource)
│   ├── player_data.gd            # class_name PlayerData (Resource)
│   └── city_buildings_data.gd    # statyczne dane Karty Miasta per miasto startowe
├── scripts/
│   ├── game_balance.gd          # WSZYSTKIE stałe balansu w jednym miejscu -
│   │                              # tu tweakuj prędkość ludzika, MP, zasięg akcji...
│   ├── hex_grid_utils.gd        # matematyka siatki - offset "even-q", flat-top,
│   │                              # + odległość heksowa (zasięg akcji)
│   └── hex_pathfinder.gd        # A* (AStar2D) po heksach, wg kosztu terenu,
│                                  # z opcjonalną listą heksów wykluczonych (blokada PvP)
├── scenes/
│   ├── main.tscn                # scena grywalna (Fazy 2-9) - kamera, mapa,
│   │                              # 2x ludzik, UI, panel Karty Miasta
│   ├── game_map_controller.gd   # orchestracja: ruch, mgła, akcje na polu,
│   │                              # tury wielu graczy, PvP, Karta Miasta,
│   │                              # zaznaczanie ludzików, zasięg akcji
│   ├── hex_map_view.gd          # rysowanie siatki + mgła wojny + klikanie/hover
│   │                              # + podświetlenie zaznaczonego pola
│   ├── camera_controller.gd     # pan (PPM) / zoom (scroll)
│   ├── ludzik.gd                 # wizualny pionek gracza: płynny ruch (Tween),
│   │                              # własne MP, zaznaczenie - jeden na gracza na
│   │                              # razie, ale player_ludziks w kontrolerze to
│   │                              # już Array[Ludzik] per gracz (gotowe pod upgrade)
│   ├── city_card_panel.gd        # UI Karty Miasta (osobny ekran, sekcja 7 GDD)
│   └── main_test.tscn / main_test.gd   # smoke test Fazy 0-1 + Faz 6-9 (bez grafiki)
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

## Decyzje projektowe podjęte przy domykaniu Faz 6-9

- **Drugi gracz startuje w Szczecinie (`A3`).** Obecny wycinek KML (63 heksy,
  trasa Świnoujście→Szczecin→Dolny Śląsk) ma tylko jeden heks oznaczony
  faktycznym typem terenu `city` (Wrocław, `H14`) — ale `A3` ma w danych
  etykietę "Szczecin", więc to naturalny, prawdziwy drugi punkt startowy do
  testu hotseat/PvP, zanim KML obejmie resztę miast z sekcji 7 GDD (Warszawa,
  Kraków, Gdańsk...). Dodaj kolejnych graczy w `PLAYER_SETUP`
  (`game_map_controller.gd`) i kolejne miasta w `city_buildings_data.gd`, gdy
  KML urośnie do pełnej skali 6 graczy.
- **Kara za strefę chronioną nalicza się przy budowie/naprawie, NIE przy
  aneksacji** (update). Pierwsza wersja karała już samo przejęcie własności
  heksa chronionego - to się okazało zbyt agresywne (samo "zaklepanie" pola
  nie jest jeszcze "eksploatacją/zniszczeniem" z sekcji 4 GDD). Teraz
  `GameManager.annex_hex()` jest neutralne prestiżowo, a karę nalicza
  `repair_building()`, gdy naprawiany/budowany budynek stoi na heksie
  chronionym - to faktyczny akt "zagospodarowania" terenu. Analogiczny hak w
  `harvest_forest()` (wycinka na chronionym lesie) zostaje jako defensywny -
  obecny model terenu (jeden typ na heks) nie pozwala, żeby heks był
  jednocześnie "forest" i "protected_area", więc na razie jest martwy, ale
  gotowy, gdyby przyszłe dane terenu zaczęły to rozróżniać osobną flagą.
- **Blokada heksa przez cudzego ludzika** jest wpięta w `HexPathfinder`:
  `game_map_controller.gd` przebudowuje graf A* przed każdym rozkazem ruchu,
  wykluczając heksy aktualnie zajęte przez ludziki INNYCH graczy — więc taki
  heks nie może być ani przystankiem, ani tranzytem trasy. Przy przejęciu
  terytorium (Faza 9) jest dodatkowo sprawdzane wprost (`_ludzik_at()`),
  bo update "akcje działają w zasięgu" (niżej) inaczej pozwoliłby przejąć
  heks patrolowany przez broniącego ludzika z sąsiedniego pola - zgodnie z
  "jedynym mechanizmem obrony terytorium" z sekcji 3 GDD to musi pozostać
  niemożliwe.
- **Akcje na polu działają w zasięgu, nie tylko stojąc na heksie** (update).
  `_own_ludzik_in_range()` w `game_map_controller.gd` sprawdza odległość
  heksową (`HexGridUtils.offset_distance`, licząca po prawdziwej matematyce
  axial/cube) między zaznaczonym polem a każdym ludzikiem aktywnego gracza;
  akcja jest dostępna, jeśli jakikolwiek z nich mieści się w
  `GameBalance.ACTION_RANGE`. Aneksacja dodatkowo kosztuje punkty ruchu
  (`GameBalance.ANNEX_MP_COST`) pobierane z konkretnego ludzika, który
  akurat się kwalifikuje (preferowany: aktualnie zaznaczony).
- **Punkty ruchu przeniesione z gracza na ludzika** (`scenes/ludzik.gd`),
  celowo z myślą o przyszłym upgrade "więcej ludzików na gracza" - każdy
  ludzik ma niezależną pulę, więc dodanie kolejnego to tylko dopisanie go do
  `player_ludziks[player_id]` (już `Array[Ludzik]`, nie pojedynczy węzeł).
  Reset puli na nową rundę przenosi się analogicznie: `TurnManager` już nic
  nie wie o ludzikach - emituje `round_ended`, a `game_map_controller.gd`
  resetuje w reakcji na ten sygnał każdemu ludzikowi z osobna.
- **Tura oparta o gotowość, nie sztywną alternację** (update, sekcja 8 GDD
  explicite dopuszcza "na przemian LUB jednocześnie"). "Zakończ turę"
  oznacza aktywnego gracza jako gotowego i przełącza na kolejnego
  niegotowego; runda przelicza się dopiero, gdy WSZYSCY są gotowi. Nowy
  przycisk "Zmiana gracza" pozwala dowolnie przełączać kontrolę bez
  kończenia tury - skoro MP żyje teraz na ludzikach (nie resetuje się przy
  każdej zmianie kontroli, tylko raz na rundę), przełączanie tam i z powrotem
  jest bezpieczne.
- **Zaznaczanie/odznaczanie ludzików** (`Ludzik.selected` + biały pierścień w
  `_draw()`) jest rozdzielone od zaznaczenia HEKSA do akcji
  (`game_map_controller.selected_hex_id`, podświetlanego w `hex_map_view.gd`)
  - to dwie osobne, świadomie nieskoordynowane wprost rzeczy: zaznaczenie
  ludzika steruje tylko rozkazami ruchu, a akcje na polu działają na
  zaznaczonym heksie niezależnie od tego, czy jakiś ludzik jest akurat
  zaznaczony (patrz "akcje w zasięgu" wyżej).
- **Płynny ruch** (`Ludzik.animate_to_hex()`) używa `Tween` per krok trasy,
  z prędkością `GameBalance.LUDZIK_MOVE_SPEED_PX_PER_SEC` (edytowalną też
  per-instancja przez eksportowane `move_speed_px_per_sec`). Stan logiczny
  (`current_hex_id`, mgła, blokady) aktualizuje się natychmiast na starcie
  animacji kroku - tylko wizualna pozycja dogania go płynnie w tle, więc
  szybkość animacji nie wpływa na poprawność logiki (blokad, MP, mgły).
- **Karta Miasta** to nowy `CanvasLayer` (`city_card_panel.gd`) rysowany nad
  resztą UI, z treścią budowaną w kodzie na podstawie
  `CityBuildingsData.get_buildings(miasto_gracza)` — niezależny od siatki
  heksów, zgodnie z sekcją 7 GDD. Koszty budynków celowo rozsiane po różnych
  typach zasobów (gaz, miedź, węgiel, drewno, żywność), żeby skompletowanie
  Karty wymagało kontroli wielu regionów.

## Uproszczenia i rzeczy do zweryfikowania dalej

- **Kształt siatki jest wyidealizowany, nie geograficznie dokładny.** Do
  renderowania i sąsiedztwa używamy czystej matematyki heksagonalnej opartej
  WYŁĄCZNIE na literze/numerze z ID heksa — nie na rzeczywistych
  współrzędnych lon/lat. Mapa w grze będzie miała równy kształt heksagonalny,
  ale nie odwzoruje 1:1 proporcji prawdziwej Polski. Świadomy kompromis na
  tym etapie.
- **Koszt naprawy budynków na mapie = 0** (`required_resources` puste w
  placeholderowym `Building` tworzonym automatycznie w `map_data.gd`). To
  celowe uproszczenie, dopóki nie ustalimy treści/kosztów konkretnych
  budynków surowcowych — repair działa więc już teraz "za darmo", tylko żeby
  przetestować przepływ aneksacja → naprawa → dochód. Budynki Karty Miasta
  (Faza 8) MAJĄ już zdefiniowane, niezerowe koszty (`city_buildings_data.gd`).
- **Koszt ścieżki w `HexPathfinder` przez `AStar2D.weight_scale`** to
  przybliżenie (Godot liczy koszt krawędzi na podstawie dystansu i
  weight_scale OBU połączonych punktów, nie tylko punktu docelowego) —
  w praktyce powinno dawać rozsądne wyniki (dystans między sąsiadami jest
  zawsze taki sam), ale warto to zwizualizować/przetestować w edytorze.
- Klasyfikacja terenu/zasobu w konwerterze KML→JSON działa na słowach
  kluczowych — dla nietypowych etykiet (fabryki, atrakcje UNESCO) może
  wymagać ręcznej korekty w JSON albo rozbudowy listy słów kluczowych.
- Siatka obejmuje na razie tylko heksy z dostarczonego wycinka KML (63 sztuk),
  nie całą Polskę — więc i multiplayer docelowo na 6 graczy (Faza 10) poczeka
  na resztę danych.
- **Ludziki obu graczy są zawsze widoczne**, niezależnie od mgły wojny
  aktywnego gracza (rysują się jako zwykłe węzły `Node2D` nad warstwą mgły).
  W hotseat na jednym ekranie to nieszkodliwe uproszczenie — obaj gracze i tak
  widzą ten sam monitor między turami, więc "ukrywanie pionka przeciwnika"
  nie chroni żadnej realnej informacji. Nabierze znaczenia dopiero przy
  prawdziwym multiplayerze sieciowym z osobnymi klientami (Faza 10), gdzie
  wymagałoby też decyzji projektowej, czy pozycja ludzika w ogóle powinna być
  tajna (GDD tego nie precyzuje).
- **Otwarte pytania z sekcji 11 GDD** wciąż nierozstrzygnięte (nie blokują
  Faz 0-9, ale wpłyną na balans): czy typ strefy chronionej (UNESCO vs zwykły
  PN) różnicuje karę prestiżową; czy surowce wymagają przetworzenia w
  budynkach przemysłowych zanim zasilą Kartę Miasta; dokładne wartości stałych
  wzoru regeneracji lasu; ostateczny warunek zwycięstwa (Faza 11).
- **Jeszcze nie zaimplementowane**: multiplayer sieciowy (Faza 10 — ENet,
  klient-serwer, lobby 6 graczy), warunek zwycięstwa i polish końcowy
  (Faza 11).
