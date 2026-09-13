# Heksagonalna Strategia Ekonomiczna — Polska

Godot 4.2.2. Zaimplementowane: **Fazy 0-9** z `Plan_Implementacji_Godot.md`
(fundament, import mapy, wizualizacja, mgła wojny, ludzik i ruch, akcje na
polu, pełna struktura tur wielu graczy, prestiż jako centralna waluta, Karta
Miasta, przejęcie terytorium PvP). Gra jest w pełni grywalna w trybie
jednoosobowym-na-jednym-ekranie (**hotseat**, do 6 graczy — pełna skala
multiplayer z sekcji 7 GDD) — dokładnie to, co plan implementacji zakłada
jako cel Faz 0-9, zanim dojdzie warstwa sieciowa (Faza 10).

Wszystkie liczby do tweakowania balansu (prędkość ludzika, wygląd zaznaczenia,
punkty ruchu, progi/kary lasu i stref chronionych, koszt przejęcia
terytorium...) mieszkają w jednym pliku: `scripts/game_balance.gd`.

Uwaga stylistyczna: kod celowo NIE używa operatora `:=` (type inference) -
tylko zwykłego `=` - bo w niektórych konfiguracjach Godota 4.2.2 potrafi on
sypać błędami parsera. Trzymaj się tej konwencji w nowym kodzie.

## Jak to uruchomić

1. Otwórz folder `godot_project/` w Godot 4.2.2 (Import → wskaż `project.godot`).
2. Naciśnij **F5** (Run Project) — scena `scenes/main.tscn` jest ustawiona jako
   główna, więc powinna wystartować od razu.
3. Gra hotseat, **6 graczy**, każdy w innym mieście startowym (sekcja 7 GDD):
   Wrocław (`H18`), Szczecin (`A7`), Warszawa (`R12`), Kraków (`O22`), Gdańsk
   (`L3`), Poznań (`G12`) — każdy widzi tylko odkryty przez siebie fragment
   mapy (osobna mgła wojny per gracz). Siatka jest **flat-top** (płaski bok
   na górze/dole heksa) i pokrywa całą Polskę (496 heksów). Żeby zagrać w
   mniejszym składzie, usuń wpisy z `PLAYER_SETUP` w
   `game_map_controller.gd` (patrz "Decyzje projektowe" niżej).
4. **Sterowanie** (dotyczy aktualnie kontrolowanego gracza — patrz etykieta
   "Kontrolujesz" w lewym górnym rogu):
   - **Lewy klik na własnego ludzika** → zaznacza go: lekko się powiększa i
     podświetla pierścieniem (rozmiar/kolor/grubość tweakowalne w
     `GameBalance.LUDZIK_SELECTED_SCALE` / `_HIGHLIGHT_COLOR` / `_WIDTH`),
     albo odznacza, jeśli już był zaznaczony. Zaznaczenie służy WYŁĄCZNIE do
     wydawania rozkazów ruchu.
   - **Lewy klik na dowolny inny heks**, mając ludzika zaznaczonego → ludzik
     płynnie (animowany ruch, konfigurowalna prędkość -
     `GameBalance.LUDZIK_MOVE_SPEED_PX_PER_SEC`) idzie tam po trasie z
     pathfindingu, krok po kroku, zużywając punkty ruchu WG KOSZTU TERENU.
     Punkty ruchu (MP) należą do ludzika, nie do gracza - każdy ludzik ma
     własną pulę (przygotowane pod przyszły upgrade "więcej ludzików na
     gracza"). Heks zajęty aktualnie przez ludzika PRZECIWNIKA jest
     nieprzejezdny - ani jako przystanek, ani jako tranzyt trasy (sekcja 3
     GDD, "funkcja obronna").
   - **Lewy klik na heks bez zaznaczonego ludzika** → tylko zaznacza to pole
     (żółta obwódka) do inspekcji/akcji - NIE przesuwa nikogo.
   - **Prawy przycisk myszy + przeciąganie** → przesuwanie widoku kamery.
   - **Scroll** → zoom.
   - Najedź myszą na heks, żeby zobaczyć w górnym lewym rogu, co o nim wiadomo
     (nic / tylko typ terenu / pełne dane) — zgodnie z dwupoziomową mgłą wojny.
   - Panel w lewym dolnym rogu pokazuje ZAZNACZONE pole i udostępnia akcje:
     - **Zaanektuj** — jedyna akcja wymagająca fizycznej obecności: działa
       TYLKO gdy jeden z twoich ludzików stoi dokładnie na zaznaczonym,
       niczyim polu. Kosztuje punkty ruchu tego ludzika
       (`GameBalance.ANNEX_MP_COST`, sekcja 2.2 GDD: "Aneksacja - płatna akcja").
     - **Przejmij teren**, **Napraw budynek**, **Wydobądź drewno** — działają
       na dowolnym zaznaczonym polu (już zaanektowanym - swoim albo cudzym),
       z DOWOLNEJ odległości, bez potrzeby stania na nim ani obok niego.
       Przejęcie terenu dodatkowo wymaga, żeby broniący go ludzik AKURAT na
       nim nie stał (jedyny mechanizm obrony terytorium, sekcja 3 GDD, nie da
       się go ominąć) i żeby twój prestiż był ściśle większy niż obrońcy,
       kosztem prestiżu proporcjonalnym do jego siły (sekcja 5 GDD). Naprawa
       na terenie chronionym nalicza karę prestiżową (sekcja niżej) - sama
       aneksacja strefy chronionej już nie karze.
     - **Karta Miasta** — osobny ekran: lista budynków charakterystycznych
       dla miasta aktywnego gracza, każdy z kosztem w zasobach i wartością
       prestiżową po odblokowaniu (sekcja 7 GDD).
   - **Rozwijana lista graczy** ("Zmiana gracza") — wybierz z listy KONKRETNEGO
     gracza, na którego chcesz przełączyć kontrolę (nie ma już cyklicznego
     "następny gracz"). Nie kończy niczyjej tury, nie wpływa na rundę.
   - **Zakończ rundę** — przelicza rundę (regeneracja lasu, dochód, odnowienie
     MP wszystkich ludzików wszystkich graczy) w dowolnym momencie, NIE
     zmieniając, który gracz jest akurat kontrolowany. Kontrola gracza i
     przeliczenie rundy to dwie całkowicie niezależne rzeczy (sekcja 8 GDD
     dopuszcza "na przemian LUB jednocześnie").
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
│   │                              # tu tweakuj prędkość ludzika, MP, wygląd
│   │                              # zaznaczenia...
│   ├── hex_grid_utils.gd        # matematyka siatki - offset "even-q", flat-top
│   └── hex_pathfinder.gd        # A* (AStar2D) po heksach, wg kosztu terenu,
│                                  # z opcjonalną listą heksów wykluczonych (blokada PvP)
├── scenes/
│   ├── main.tscn                # scena grywalna (Fazy 2-9) - kamera, mapa,
│   │                              # ludzik (+5 tworzonych w kodzie), UI, Karta Miasta
│   ├── game_map_controller.gd   # orchestracja: ruch, mgła, akcje na polu,
│   │                              # wybór gracza, PvP, Karta Miasta,
│   │                              # zaznaczanie ludzików
│   ├── hex_map_view.gd          # rysowanie siatki + mgła wojny + klikanie/hover
│   │                              # + podświetlenie zaznaczonego pola
│   ├── camera_controller.gd     # pan (PPM) / zoom (scroll)
│   ├── ludzik.gd                 # wizualny pionek gracza: płynny ruch (Tween),
│   │                              # własne MP, zaznaczenie (skala + podświetlenie)
│   │                              # - jeden na gracza na razie, ale
│   │                              # player_ludziks w kontrolerze to już
│   │                              # Array[Ludzik] per gracz (gotowe pod upgrade)
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
**wyżej** (np. H18 leży nad G18). Matematyka w `hex_grid_utils.gd` jest
zweryfikowana (round-trip piksel↔heks i odległości sąsiadów) skryptem
pomocniczym w Pythonie, bez uruchamiania samego Godota.

### Korekta proporcji ("efekt zakrzywienia")

Siatka nie jest już idealnie regularnym polem heksów — jest lekko
rozciągnięta (`GEO_SCALE_X` ≈ 1,123 poziomo, `GEO_SCALE_Y` ≈ 0,891 pionowo w
`hex_grid_utils.gd`), żeby jej proporcje odpowiadały prawdziwej mapie Polski
w Google Earth. Dwa efekty złożone w jedną poprawkę:

1. **Krzywizna Ziemi** — na szerokości geograficznej Polski (~52°N) stopień
   długości geograficznej to fizycznie mniej kilometrów niż stopień
   szerokości (`cos(52°) ≈ 0,61`) - standardowa projekcja
   równoodległościowa (sekcja 10 GDD).
2. **Niedokładność ręcznie rozstawionej siatki KML** — kolumny/wiersze
   litera-cyfra były rozmieszczane "na oko" w Google Earth, więc nawet po
   korekcie z punktu 1 nie odpowiadają 1:1 rzeczywistym odległościom.

Współczynniki wyliczone jednorazowo metodą najmniejszych kwadratów
(dopasowanie pozycji siatki do rzeczywistych `lat`/`lon` wszystkich 496
heksów) — dopasowanie wyszło praktycznie czystym skalowaniem osi (bez
znaczącego ścinania/obrotu, średni błąd ~0,9% przekątnej mapy), więc
wystarczyła prosta anizotropowa zmiana skali X/Y zamiast pełnej macierzy
afinicznej. Transformacja jest stosowana identycznie do środków heksów
(`axial_to_pixel`) i ich wierzchołków (`hex_corners`), więc heksy nadal
idealnie do siebie przylegają (żadnych szczelin/nakładania) - tylko
"rozciągnięte" zamiast regularne. Odwrotność (`_pixel_to_axial_raw`, klikanie
w mapę) uwzględnia tę samą korektę, więc wykrywanie heksa pod kursorem
pozostaje dokładne (zweryfikowane round-trip na wszystkich 496 heksach).

## ✅ Mapa Polski jest już kompletna (496 heksów)

`data/map_data.json` to teraz pełna mapa całej Polski (poprzednio: wycinek
63 heksów obejmujący tylko Pomorze Zachodnie + Dolny Śląsk). Wcześniejsza
wersja KML miała trzy zduplikowane identyfikatory heksów (`D12`, `D13`,
`D14`, każdy użyty dla dwóch różnych miejsc) i pomijała Placemark
"Wałbrzych" (brak identyfikatora w nazwie) — **oba problemy są w tej wersji
naprawione**: zero duplikatów ID w `map_data.json`, a Wałbrzych ma teraz
własny heks (`E20`). Zawiera wszystkie 6 miast startowych z sekcji 7 GDD
jako heksy typu `city`: Wrocław (`H18`), Szczecin (`A7`), Warszawa (`R12`),
Kraków (`O22`), Gdańsk (`L3`), Poznań (`G12`).

## Decyzje projektowe podjęte przy domykaniu Faz 6-9

- **Hotseat na pełnych 6 graczach (sekcja 7 GDD).** `PLAYER_SETUP` w
  `game_map_controller.gd` rejestruje wszystkich 6 graczy naraz (Wrocław
  `H18`, Szczecin `A7`, Warszawa `R12`, Kraków `O22`, Gdańsk `L3`, Poznań
  `G12`), każdy z osobnym kolorem pionka i kompletem budynków Karty Miasta
  w `city_buildings_data.gd`. Cała logika ruchu/mgły/akcji/tur/PvP była od
  początku napisana generycznie (pętle po `players`/`player_ludziks`, bez
  założenia "dokładnie dwóch graczy"), więc przejście z 2 na 6 to była
  wyłącznie kwestia dopisania DANYCH (wpisów w tych dwóch plikach) - żadnych
  zmian w logice sterowania, ruchu, mgły, akcji na polu czy tur. Żeby zagrać
  w mniejszym składzie, po prostu usuń wybrane wpisy z `PLAYER_SETUP`.
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
  terytorium (Faza 9) jest dodatkowo sprawdzane wprost (`_ludzik_at()`), bo
  skoro przejęcie działa teraz z dowolnej odległości (niżej), inaczej dałoby
  się przejąć heks patrolowany przez broniącego ludzika z drugiego końca
  mapy - zgodnie z "jedynym mechanizmem obrony terytorium" z sekcji 3 GDD to
  musi pozostać niemożliwe.
- **Aneksacja wymaga fizycznej obecności, reszta akcji działa zdalnie**
  (update). Jedyna akcja, w której `game_map_controller.gd` sprawdza, czy
  jakiś ludzik aktywnego gracza stoi DOKŁADNIE na zaznaczonym polu
  (`_find_own_ludzik_at()`), to aneksacja - zgodnie z GDD to ona "odsłania
  budynek/zasób i przejmuje pole", więc wymaga fizycznego zwiadu. Naprawa,
  wydobycie i przejęcie terytorium działają na dowolnym już zaanektowanym
  polu (swoim albo cudzym) z dowolnej odległości - potraktowane jako
  "zarządzanie zdalne" terytorium, którego istnienie/właściciela gracz już
  zna. Aneksacja dodatkowo kosztuje punkty ruchu
  (`GameBalance.ANNEX_MP_COST`) pobierane z ludzika, który akurat tam stoi.
- **Punkty ruchu przeniesione z gracza na ludzika** (`scenes/ludzik.gd`),
  celowo z myślą o przyszłym upgrade "więcej ludzików na gracza" - każdy
  ludzik ma niezależną pulę, więc dodanie kolejnego to tylko dopisanie go do
  `player_ludziks[player_id]` (już `Array[Ludzik]`, nie pojedynczy węzeł).
  Reset puli na nową rundę przenosi się analogicznie: `TurnManager` już nic
  nie wie o ludzikach - emituje `round_ended`, a `game_map_controller.gd`
  resetuje w reakcji na ten sygnał każdemu ludzikowi z osobna.
- **Kontrola gracza i przeliczenie rundy są rozdzielone** (update, sekcja 8
  GDD explicite dopuszcza "na przemian LUB jednocześnie"). Rozwijana lista
  graczy ("Zmiana gracza") wybiera KONKRETNEGO gracza wprost
  (`TurnManager.switch_to_player(id)`) - nie ma już cyklicznego "następny
  gracz" ani pojęcia "kolejności tur" blokującej resztę. "Zakończ rundę"
  (`TurnManager.end_round()`) przelicza rundę w dowolnym momencie i NIE
  zmienia, kto jest kontrolowany - to dwie niezależne akcje. Bezpieczne,
  odkąd MP żyje na ludzikach (nie zeruje się przy zmianie kontroli, tylko
  raz na rundę).
- **Zaznaczanie/odznaczanie ludzików**: skala (`GameBalance.LUDZIK_SELECTED_SCALE`)
  + pierścień podświetlenia (`_HIGHLIGHT_COLOR` / `_WIDTH`) w `Ludzik.set_selected()`
  / `_draw()`, jest rozdzielone od zaznaczenia HEKSA do akcji
  (`game_map_controller.selected_hex_id`, podświetlanego w `hex_map_view.gd`)
  - to dwie osobne rzeczy: zaznaczenie ludzika steruje wyłącznie rozkazami
  ruchu, a akcje na polu (poza aneksacją) działają na zaznaczonym heksie
  niezależnie od tego, czy jakiś ludzik jest akurat zaznaczony.
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

- **Kształt siatki jest skorygowany proporcjonalnie, ale wciąż nie
  geograficznie dokładny.** Sąsiedztwo/pathfinding nadal opiera się
  WYŁĄCZNIE na literze/numerze z ID heksa (regularna siatka heksagonalna) -
  rzeczywiste `lat`/`lon` służą tylko do jednorazowego wyliczenia globalnej
  korekty proporcji X/Y (patrz "efekt zakrzywienia" wyżej), nie do
  pozycjonowania POSZCZEGÓLNYCH heksów. Mapa w grze ma więc już prawidłowe
  OGÓLNE proporcje (szerokość/wysokość), ale nie odwzorowuje dokładnego,
  nieregularnego kształtu granic Polski (wybrzeża, gór itd.) - to nadal
  regularne pole heksów, tylko poprawnie rozciągnięte. Świadomy kompromis,
  żeby nie psuć kafelkowania siatki (potrzebnego do sąsiedztwa/ruchu).
- **Koszt naprawy budynków na mapie = 0** (`required_resources` puste w
  placeholderowym `Building` tworzonym automatycznie w `map_data.gd`). To
  celowe uproszczenie, dopóki nie ustalimy treści/kosztów konkretnych
  budynków surowcowych — repair działa więc już teraz "za darmo", tylko żeby
  przetestować przepływ aneksacja → naprawa → dochód. Budynki Karty Miasta
  (Faza 8) MAJĄ już zdefiniowane, niezerowe koszty (`city_buildings_data.gd`).
- **Koszt ścieżki w `HexPathfinder` przez `AStar2D.weight_scale`** to
  przybliżenie (Godot liczy koszt krawędzi na podstawie dystansu i
  weight_scale OBU połączonych punktów, nie tylko punktu docelowego). Od
  wprowadzenia korekty proporcji ("efekt zakrzywienia" wyżej) dystans
  piksel-do-piksela między sąsiednimi heksami już NIE jest identyczny we
  wszystkich 6 kierunkach (różnica ~20% - ruchy pionowe są w AStar nieco
  "tańsze" niż ukośne) — to nie wpływa na faktyczny koszt MP płacony przez
  gracza (ten liczy się osobno, wprost z `HexData.get_movement_cost()` w
  `game_map_controller.gd`, nie z wewnętrznego kosztu AStar), tylko
  ewentualnie na to, którą z kilku równie tanich terenowo tras wybierze
  pathfinder przy remisie. Kosmetyczna nieścisłość, ale warto o niej
  pamiętać, testując/wizualizując w edytorze.
- Klasyfikacja terenu/zasobu w konwerterze KML→JSON działa na słowach
  kluczowych — dla nietypowych etykiet (fabryki, atrakcje UNESCO) może
  wymagać ręcznej korekty w JSON albo rozbudowy listy słów kluczowych.
- Siatka obejmuje już całą Polskę (496 heksów, wszystkie 6 miast startowych)
  i hotseat gra już na pełnych 6 graczach — multiplayer SIECIOWY (Faza 10)
  czeka teraz tylko na warstwę sieciową (ENet), nie na dane mapy ani na
  logikę wielu graczy, która już istnieje i działa lokalnie.
- **Ludziki wszystkich graczy są zawsze widoczne**, niezależnie od mgły
  wojny aktywnego gracza (rysują się jako zwykłe węzły `Node2D` nad warstwą
  mgły). W hotseat na jednym ekranie to nieszkodliwe uproszczenie — wszyscy
  gracze i tak widzą ten sam monitor między turami, więc "ukrywanie pionka
  przeciwnika" nie chroni żadnej realnej informacji. Nabierze znaczenia
  dopiero przy prawdziwym multiplayerze sieciowym z osobnymi klientami
  (Faza 10), gdzie wymagałoby też decyzji projektowej, czy pozycja ludzika
  w ogóle powinna być tajna (GDD tego nie precyzuje).
- **Otwarte pytania z sekcji 11 GDD** wciąż nierozstrzygnięte (nie blokują
  Faz 0-9, ale wpłyną na balans): czy typ strefy chronionej (UNESCO vs zwykły
  PN) różnicuje karę prestiżową; czy surowce wymagają przetworzenia w
  budynkach przemysłowych zanim zasilą Kartę Miasta; dokładne wartości stałych
  wzoru regeneracji lasu; ostateczny warunek zwycięstwa (Faza 11).
- **Jeszcze nie zaimplementowane**: multiplayer sieciowy (Faza 10 — ENet,
  klient-serwer, lobby 6 graczy), warunek zwycięstwa i polish końcowy
  (Faza 11).
