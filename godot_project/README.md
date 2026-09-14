# Heksagonalna Strategia Ekonomiczna — Polska

Godot 4.2.2. Zaimplementowane: **Fazy 0-9** z `Plan_Implementacji_Godot.md`
(fundament, import mapy, wizualizacja, mgła wojny, ludzik i ruch, akcje na
polu, pełna struktura tur wielu graczy, prestiż jako centralna waluta, Karta
Miasta, przejęcie terytorium PvP) **plus dalsze funkcje ponad plan**: ekran
startowy wyboru miast, trasa wielorundowa z podglądem/potwierdzeniem,
Drzewko Umiejętności (5 startowych upgrade'ów) i UI skalujące się z oknem.
Gra jest w pełni grywalna w trybie jednoosobowym-na-jednym-ekranie
(**hotseat**, do 6 graczy — pełna skala multiplayer z sekcji 7 GDD) —
dokładnie to, co plan implementacji zakłada jako cel Faz 0-9, zanim dojdzie
warstwa sieciowa (Faza 10).

Wszystkie liczby do tweakowania balansu (prędkość ludzika, wygląd zaznaczenia,
punkty ruchu, progi/kary lasu i stref chronionych, koszt przejęcia
terytorium...) mieszkają w jednym pliku: `scripts/game_balance.gd`.

UI skaluje się z oknem (`project.godot` -> `[display]`: `window/stretch/mode
= "canvas_items"`, `window/stretch/aspect = "expand"`, bazowa rozdzielczość
1280×800) - zmiana rozmiaru okna skaluje całą scenę (mapę i UI) proporcjonalnie
zamiast przycinać ją czarnymi pasami albo zostawiać UI w stałym rozmiarze
pikselowym w rogu ekranu.

Uwaga stylistyczna: kod celowo NIE używa operatora `:=` (type inference) -
tylko zwykłego `=` - bo w niektórych konfiguracjach Godota 4.2.2 potrafi on
sypać błędami parsera. Trzymaj się tej konwencji w nowym kodzie.

## Jak to uruchomić

1. Otwórz folder `godot_project/` w Godot 4.2.2 (Import → wskaż `project.godot`).
2. Naciśnij **F5** (Run Project) — scena `scenes/start_screen.tscn` jest
   ustawiona jako główna, więc powinna wystartować od razu.
3. **Ekran startowy**: checkbox per miasto (wszystkie 6 z sekcji 7 GDD:
   Wrocław `H18`, Szczecin `A7`, Warszawa `R12`, Kraków `O22`, Gdańsk `L3`,
   Poznań `G12`, lista współdzielona ze scenę grywalną w
   `scripts/player_setup.gd` -> `PlayerSetup.LIST`), domyślnie wszystkie
   zaznaczone. Odznacz, których miast NIE chcesz w rozgrywce (min. 2 wymagane
   - przycisk "Rozpocznij grę" jest zablokowany przy mniejszej liczbie), potem
   kliknij **Rozpocznij grę** — wybór trafia do autoloadu `GameSetup`
   (`selected_player_ids`), który `game_map_controller._setup_players()`
   odczytuje przy starcie `scenes/main.tscn`. Uruchomienie `main.tscn`
   bezpośrednio (np. F6 w edytorze, z pominięciem ekranu startowego) nadal
   działa i rejestruje wszystkich 6 graczy, tak jak dotąd.
4. Gra hotseat, każdy wybrany gracz w innym mieście startowym — widzi tylko
   odkryty przez siebie fragment mapy (osobna mgła wojny per gracz). Siatka
   jest **flat-top** (płaski bok na górze/dole heksa) i pokrywa całą Polskę
   (496 heksów).
5. **HUD** (lewy górny róg): kto jest kontrolowany, punkty ruchu, prestiż i
   **wszystkie posiadane surowce** (gaz/miedź/węgiel/drewno/żywność/nikiel/
   uran naraz, nie tylko drewno jak wcześniej).
6. **Sterowanie** (dotyczy aktualnie kontrolowanego gracza — patrz etykieta
   "Kontrolujesz" w lewym górnym rogu):
   - **Lewy klik na własnego ludzika** → zaznacza go: lekko się powiększa i
     podświetla pierścieniem (rozmiar/kolor/grubość tweakowalne w
     `GameBalance.LUDZIK_SELECTED_SCALE` / `_HIGHLIGHT_COLOR` / `_WIDTH`),
     albo odznacza, jeśli już był zaznaczony. Zaznaczenie służy WYŁĄCZNIE do
     wydawania rozkazów ruchu.
   - **Lewy klik na dowolny inny heks**, mając ludzika zaznaczonego → NIE
     rusza go od razu (update) - liczy trasę z pathfindingu i pokazuje jej
     **podgląd** na mapie (żółta linia + kropki na kolejnych polach). Dopiero
     **Potwierdź trasę** w nowym panelu "Trasa ludzika" (prawy dolny róg)
     faktycznie rusza ludzika, krok po kroku, zużywając punkty ruchu WG
     KOSZTU TERENU (płynny, animowany ruch - konfigurowalna prędkość
     `GameBalance.LUDZIK_MOVE_SPEED_PX_PER_SEC`). Jeśli trasa jest dłuższa
     niż starczy jednorazowego zapasu MP, wykonana zostaje jej część, a
     reszta zostaje zapamiętana (linia zmienia kolor na pomarańczowy) i
     **kontynuowana automatycznie po każdym kolejnym "Zakończ rundę"**, aż do
     celu - bez ponownego klikania trasy. Panel pokazuje długość/koszt trasy
     (albo postęp trasy w toku) i ma przycisk **Anuluj** (podgląd - przed
     potwierdzeniem, albo całą trwającą trasę - po). Punkty ruchu (MP) należą
     do ludzika, nie do gracza - każdy ludzik ma własną pulę. Heks zajęty
     aktualnie przez ludzika PRZECIWNIKA jest nieprzejezdny - ani jako
     przystanek, ani jako tranzyt trasy (sekcja 3 GDD, "funkcja obronna") -
     sprawdzane zarówno przy planowaniu podglądu, jak i przy KAŻDYM kroku
     trwającej trasy (mogła czekać kilka rund, sytuacja mogła się zmienić).
     **Dokładna liczba rund** (nowość) - panel "Trasa ludzika" nie pokazuje
     już binarnego "starczy w tej rundzie"/"potrwa kilka rund", tylko
     WYLICZONĄ liczbę rund (`_route_rounds_needed()`: ta runda, jeśli
     starczy aktualnych MP, inaczej ta runda plus tyle kolejnych PEŁNYCH rund
     - każda dająca `movement_points_max` świeżych punktów - ile trzeba na
     resztę kosztu), z poprawną polską odmianą ("1 rundę", "3 rundy",
     "5 rund" - `_format_rounds()`). **Trasa przelicza się na nowo po każdej
     rundzie** (nowość) - `_continue_all_queued_routes()` woła
     `_recompute_route()` dla każdej trwającej trasy PRZED próbą jej
     kontynuacji, świeżymi blokadami (pozycjami wrogich ludzików) - jeśli
     przeciwnik w międzyczasie zmienił pozycję (zablokował dotychczasową
     ścieżkę albo odsłonił wcześniej niedostępny cel), trasa się na to
     automatycznie dostosowuje, bez ręcznej interwencji gracza. **Można
     zaznaczyć jako cel trasy pole, na którym aktualnie stoi wrogi ludzik**
     (nowość) - normalnie nieosiągalne, ale zamiast odmówić trasy w ogóle,
     `_find_path_toward()` liczy ścieżkę do NAJBLIŻSZEGO osiągalnego sąsiada
     tego pola; ludzik dojdzie tam i CZEKA (panel pokazuje "Ludzik czeka na
     miejscu..."), aż gracz anuluje trasę albo przeciwnik się przesunie
     (wykryte automatycznie przy kolejnym przeliczeniu rundy, patrz wyżej) -
     prawdziwy cel trasy trzyma `Ludzik.route_destination`, osobno od
     praktycznego `queued_route`, które może kończyć się wcześniej.
   - **Lewy klik na heks bez zaznaczonego ludzika** → tylko zaznacza to pole
     (żółta obwódka) do inspekcji/akcji - NIE przesuwa nikogo.
   - **Prawy przycisk myszy + przeciąganie** → przesuwanie widoku kamery.
   - **Scroll** → zoom.
   - Najedź myszą na heks, żeby zobaczyć w górnym lewym rogu, co o nim wiadomo
     (nic / tylko typ terenu / pełne dane) — zgodnie z trójpoziomową mgłą
     wojny. **Panel po kliknięciu (lewy dolny róg) pokazuje dokładnie tyle
     samo** — dopóki pole jest "unexplored" widać wyłącznie jego ID (np.
     `A13`), bez typu terenu ani niczego innego; od "seen" dochodzi typ
     terenu i koszt ruchu; pełne dane (etykieta, właściciel, budynek, poziom
     zasobu) dopiero po "annexed" (patrz `_refresh_action_panel()` w
     `game_map_controller.gd`). Przyciski akcji same w sobie NIE są tak
     bramkowane — działają na prawdziwym stanie pola niezależnie od mgły
     (np. żeby przejęcie terenu przeciwnika było w ogóle możliwe), tylko
     opis tekstowy chroni informację o tym, co się na nim znajduje.
   - **Kolor drużyny wokół pola** — każdy heks, który został przez kogoś
     zaanektowany, ma dookoła grubszą kolorową obwódkę w barwie właściciela
     (ten sam kolor co jego pionek), widoczną od razu, jak tylko pole
     przestaje być "unexplored" — ten sam próg co widoczność ludzika
     przeciwnika (patrz niżej), więc terytorium wroga, które już
     zwiadowałeś, jest widoczne na mapie bez klikania w każde pole z osobna.
     Rysowana w `hex_map_view.gd` pod zwykłą/żółtą obwódką zaznaczenia, więc
     obie są widoczne naraz.
   - Panel w lewym dolnym rogu pokazuje ZAZNACZONE pole i udostępnia akcje:
     - **Napraw budynek**, **Wydobądź drewno** — działają na dowolnym
       zaznaczonym, już zaanektowanym WŁASNYM polu, z DOWOLNEJ odległości,
       bez potrzeby stania na nim ani obok niego. Naprawa na terenie
       chronionym nalicza karę prestiżową (sekcja niżej) - sama aneksacja
       strefy chronionej już nie karze.
     - **Karta Miasta** — osobny ekran: lista budynków charakterystycznych
       dla miasta aktywnego gracza, każdy z kosztem w zasobach i wartością
       prestiżową po odblokowaniu (sekcja 7 GDD).
     - **Drzewko Umiejętności** (nowość) — osobny ekran, analogiczny do Karty
       Miasta, ale WSPÓLNY dla wszystkich miast: 5 permanentnych upgrade'ów
       płatnych surowcami z mapy (patrz sekcja niżej).
   - **Zaanektuj i Przejmij teren gracza żyją TYLKO w panelu "Trasa ludzika"**
     (update - oba usunięte z panelu akcji po lewej, żeby obie akcje
     wymagające fizycznej obecności ludzika miały miejsce wyłącznie w UI
     samego ludzika, nie ogólnego panelu pola). Wzajemnie się wykluczają,
     zależnie od tego, kto jest właścicielem zaznaczonego pola: **Zaanektuj**
     dla pola niczyjego, **Przejmij teren gracza** dla pola innego gracza -
     oba działają TYLKO gdy jeden z twoich ludzików stoi dokładnie na tym
     polu i kosztują tyle samo punktów ruchu (`GameBalance.ANNEX_MP_COST`).
     **Aneksacja wymaga też sąsiedztwa** (nowość) - da się zaanektować TYLKO
     pole graniczące z polem, które już posiadasz (terytorium rośnie spójnie,
     nie "skacze" po mapie) - `GameManager.has_adjacent_owned_hex()`, ten sam
     warunek gasi przycisk w UI i blokuje samo działanie. Jedyny wyjątek to
     startowa stolica gracza, aneksowana automatycznie na starcie gry (nie
     ma jeszcze czego sąsiadować).
     **Przejęcie terenu gracza** (update, sekcja 5 GDD) wymaga teraz - tak
     jak aneksacja - fizycznej obecności (poprzednio działało z dowolnej
     odległości) i **nie da się przejąć stolicy** żadnego gracza (chroniona
     na stałe, `HexData.is_capital`); dymek po najechaniu na przycisk pokazuje,
     że kosztuje to MP (znaną z góry liczbę) oraz "nieznaną liczbę prestiżu" -
     dokładna kwota zależy od prestiżu przeciwnika, którego gra celowo nie
     ujawnia w UI. Zawsze da się spróbować, nawet z niewystarczającym
     prestiżem:
     - **Wystarczający prestiż** (ściśle większy niż obrońcy) → sukces:
       przejmujesz pole, płacisz część prestiżu obrońcy (jak dotąd), a
       DODATKOWO obrońca traci część WŁASNEGO prestiżu (koszt bycia
       podbitym) - patrz "Decyzje projektowe" niżej po dokładny wzór.
     - **Niewystarczający prestiż** → nieudana próba: obrońca NIE TRACI NIC,
       ale ty tracisz prestiż proporcjonalnie do przewagi obrońcy (im
       bardziej nierówna próba, tym droższa porażka) - MP i tak zostaje
       wydane, bo próba faktycznie zaszła.
     Panel ma też przełącznik **Anektuj napotkane pola** - gdy włączony na
     danym ludziku, automatycznie aneksuje KAŻDE niczyje pole (i sąsiadujące
     z już posiadanym - powyższy warunek dotyczy też auto-aneksacji), przez
     które ten ludzik przejdzie podczas wykonywania trasy (także
     wielorundowej), bez ręcznego klikania po każdym kroku. **Aneksacja pola,
     na którym ludzik AKTUALNIE stoi, ma pierwszeństwo nad dalszym ruchem**
     (update) - jeśli akurat brakuje MP na aneksację, ludzik NIE idzie dalej
     pomijając to pole, tylko czeka na nim, aż starczy MP (w kolejnej
     rundzie). Ludzik NIE marnuje jednak przy tym ruchu, na który akurat MU
     starcza - wejście na pole i jego aneksacja są osobnymi krokami: gdy
     starcza MP na oba, dzieją się jedno po drugim w TEJ SAMEJ rundzie (jak
     dotąd); gdy starcza tylko na wejście, ludzik i tak robi ten krok, a samą
     aneksację dokańcza na początku kolejnej rundy - zamiast bezczynnie stać
     w miejscu przez całą rundę tylko dlatego, że nie starczyłoby na oba
     naraz (MP, których by tak czy inaczej nie zużył, i tak przepadają na
     koniec rundy). Pole, które i tak nie kwalifikuje się do aneksacji (np.
     nie sąsiaduje jeszcze z niczym posiadanym), nie wstrzymuje trasy - nie
     ma na co czekać, więc ludzik po prostu przez nie przechodzi.
     (Auto-aneksja dotyczy tylko NICZYJICH pól - przejęcie terenu gracza
     zawsze wymaga ręcznego kliknięcia, ze względu na jego karny charakter
     przy porażce.) **Podgląd kosztu trasy uwzględnia auto-aneksację**
     (nowość) - jeśli przełącznik jest włączony, "koszt X MP" pokazywany przy
     podglądzie trasy dolicza też koszt aneksacji każdego obecnie niczyjego
     pola na niej, więc trasa z włączonym auto-anektowaniem wychodzi (trafnie)
     droższa i liczba rund pokazana w panelu (patrz wyżej) rośnie odpowiednio.
   - **Rozwijana lista graczy** ("Zmiana gracza") — wybierz z listy KONKRETNEGO
     gracza, na którego chcesz przełączyć kontrolę (nie ma już cyklicznego
     "następny gracz"). Nie kończy niczyjej tury, nie wpływa na rundę.
   - **Zakończ rundę** — przelicza rundę (regeneracja lasu, dochód, odnowienie
     MP wszystkich ludzików wszystkich graczy) w dowolnym momencie, NIE
     zmieniając, który gracz jest akurat kontrolowany. Kontrola gracza i
     przeliczenie rundy to dwie całkowicie niezależne rzeczy (sekcja 8 GDD
     dopuszcza "na przemian LUB jednocześnie").
7. Dla testu niższego poziomu (bez UI/kamery/grafiki) nadal działa
   `scenes/main_test.tscn` (F6 na tej scenie) — smoke test Fazy 0-1 (dane,
   aneksacja, wydobycie lasu, tura) **plus** Faz 6-9 (drugi gracz, blokada
   ruchu przez `HexPathfinder`, przejęcie terytorium, kara za strefę
   chronioną, odblokowanie budynku Karty Miasta) — wszystko jako czytelne
   logi w konsoli, bo w tym trybie nie ma węzłów `Ludzik`/kamery do klikania.

## Co jest w środku

```
godot_project/
├── project.godot            # main_scene = scenes/start_screen.tscn, autoloady
├── autoloads/
│   ├── map_data.gd           # wczytuje data/map_data.json, sąsiedzi, dołącza
│   │                          # REALNE budynki z pola "building" w JSON
│   ├── game_manager.gd       # gracze, aneksacja, naprawa, wydobycie lasu,
│   │                          # przejęcia, kara za strefy chronione, Karta Miasta
│   ├── turn_manager.gd       # kolejność graczy, przeliczenie rundy
│   └── game_setup.gd         # GameSetup: wybór miast z ekranu startowego,
│                              # przekazany do game_map_controller.gd
├── resources/
│   ├── hex_data.gd              # class_name HexData (Resource)
│   ├── building.gd               # class_name Building (Resource)
│   ├── player_data.gd            # class_name PlayerData (Resource) - kolor
│   │                              # drużyny + akumulatory efektów skilli
│   ├── skill_data.gd             # class_name SkillData (Resource) - węzeł
│   │                              # drzewka umiejętności
│   └── city_buildings_data.gd    # statyczne dane Karty Miasta per miasto startowe
├── scripts/
│   ├── game_balance.gd          # WSZYSTKIE stałe balansu w jednym miejscu -
│   │                              # tu tweakuj prędkość ludzika, MP, wygląd
│   │                              # zaznaczenia...
│   ├── player_setup.gd          # PlayerSetup.LIST - lista miast/graczy,
│   │                              # współdzielona przez start_screen.gd i
│   │                              # game_map_controller.gd
│   ├── skill_tree_data.gd       # SkillTreeData.get_skills() - 5 startowych
│   │                              # upgrade'ów drzewka umiejętności
│   ├── hex_grid_utils.gd        # matematyka siatki - offset "even-q", flat-top
│   └── hex_pathfinder.gd        # A* (AStar2D) po heksach, wg kosztu terenu,
│                                  # z opcjonalną listą heksów wykluczonych (blokada PvP)
├── scenes/
│   ├── start_screen.tscn / start_screen.gd  # ekran startowy - wybór, ile i
│   │                              # które miasta grają (checkboxy, min. 2)
│   ├── main.tscn                # scena grywalna (Fazy 2-9) - kamera, mapa,
│   │                              # ludzik (+ do 6 tworzonych w kodzie), UI,
│   │                              # Karta Miasta, Drzewko Umiejętności
│   ├── game_map_controller.gd   # orchestracja: ruch/trasy, mgła, akcje na
│   │                              # polu, wybór gracza, PvP, Karta Miasta,
│   │                              # Drzewko Umiejętności, filtr GameSetup
│   ├── hex_map_view.gd          # rysowanie siatki + mgła wojny + klikanie/hover
│   │                              # + podświetlenie zaznaczonego pola + obwódka
│   │                              # w kolorze drużyny-właściciela + podgląd/trasa
│   ├── camera_controller.gd     # pan (PPM) / zoom (scroll)
│   ├── ludzik.gd                 # wizualny pionek gracza: płynny ruch (Tween),
│   │                              # własne MP, zaznaczenie (skala + podświetlenie),
│   │                              # zatwierdzona trasa wielorundowa (queued_route)
│   │                              # - jeden na gracza na start, ale
│   │                              # player_ludziks w kontrolerze to już
│   │                              # Array[Ludzik] per gracz (skill "Drugi ludzik"
│   │                              # dodaje kolejnego bez zmian w reszcie logiki)
│   ├── city_card_panel.gd        # UI Karty Miasta (osobny ekran, sekcja 7 GDD)
│   ├── skill_tree_panel.gd       # UI Drzewka Umiejętności - radialny graf,
│   │                              # prawie cały ekran, najwyższa warstwa UI,
│   │                              # jedno współdzielone okienko szczegółów
│   ├── skill_graph_view.gd       # rysuje węzeł centralny + linie do węzłów
│   │                              # (Drzewko Umiejętności) + pan/zoom myszką
│   ├── skill_node_dot.gd         # pojedynczy węzeł drzewka - kropka (na razie),
│   │                              # gotowa pod podmianę na obrazek (sprite_texture)
│   └── main_test.tscn / main_test.gd   # smoke test Fazy 0-1 + Faz 6-9 (bez grafiki)
├── theme/
│   └── ui_theme.tres          # WYGLĄD całego UI w jednym miejscu (panele,
│                                # przyciski, etykiety) - edytowalne wizualnie
│                                # w Godot Theme Editor, podpięte do main.tscn
├── data/map_data.json         # wygenerowane przez tools/convert_kml_to_json.py
└── icon.svg
```

Skrypt konwertujący (`tools/convert_kml_to_json.py`) jest **poza** folderem
`godot_project/`, bo to jednorazowe narzędzie deweloperskie, nie część gry —
użyj go ponownie, gdy dodasz kolejne fragmenty KML dla reszty Polski:

```
python3 convert_kml_to_json.py nowa_mapa.kml godot_project/data/map_data.json
```

### Budynki - "znajdź i napraw" (sekcja 2.3/3 GDD)

Konwerter rozpoznaje w etykietach KML realne obiekty gospodarcze (gazoport,
huta, fabryka, zakłady, elektrownia, rafineria, kopalnia, stocznia, złoża...)
i zapisuje je jako pole `"building"` przy każdym heksie w `map_data.json` -
`{"name": "<etykieta z KML>", "produces_resource": "<zasób albo none>"}`.
KAŻDY heks z rozpoznanym zasobem (włącznie ze zwykłym "obszar rolniczy" ->
food, sekcja 6 GDD: "każdy posiadany heks z zasobem daje stały dochód")
dostaje budynek; heksy z etykietą wskazującą na obiekt przemysłowy, ale bez
dopasowanego surowca (np. "LG chem - fabryka baterii") też dostają budynek -
da się go znaleźć/naprawić, tylko na razie nic nie produkuje (otwarte
pytanie GDD o przetwarzaniu surowiec→produkt, sekcja 6/11).

`map_data.gd` (`_attach_building`) czyta to pole wprost - koniec z placeholderowym
"COPPER (placeholder)"; budynek na mapie ma teraz swoją prawdziwą nazwę z KML
(np. "Huta miedzi Głogów KGHM"). Wszystkie budynki startują uszkodzone
(`building_damaged = true`) - trzeba je zaanektować i naprawić, żeby zaczęły
generować surowiec (`GameBalance.BUILDING_RESOURCE_INCOME_PER_TURN` na rundę).

### Drzewko Umiejętności (nowość)

Drugi (obok Karty Miasta) trwały cel na nadwyżki surowców - tym razem z
bezpośrednim wpływem na rozgrywkę zamiast samego prestiżu. Na razie płaskie
(bez prerequisitów/poziomów) - `scripts/skill_tree_data.gd` (`SkillTreeData.get_skills()`)
proponuje 5 startowych upgrade'ów, każdy płatny surowcami, które już są w
grze, i odblokowywany permanentnie za jednym kliknięciem w ekranie "Drzewko
Umiejętności":

| Skill | Efekt | Koszt |
|---|---|---|
| Drugi ludzik | Rekrutuje kolejnego Ludzika w mieście startowym - dwa niezależne ruchy/akcje na rundę | 40 żywności, 40 drewna, 20 węgla |
| Wytrzymałość marszowa | +2 punkty ruchu dla każdego ludzika (obecnego i przyszłego) | 25 żywności, 15 drewna |
| Zrównoważona wycinka | +15 pkt. proc. do bezpiecznego progu wycinki lasu | 30 drewna, 15 węgla |
| Rozpoznanie terenu | +1 promień widzenia dla wszystkich ludzików gracza | 15 niklu, 20 gazu |
| Logistyka terytorialna | -1 MP kosztu aneksacji (min. 1) | 20 miedzi, 5 uranu |

Ekran wygląda jak **radialny graf** (nie zwykła lista) — centralny węzeł
"START" i węzły umiejętności rozstawione promieniście wokół niego, połączone
liniami (`scenes/skill_graph_view.gd`, rysowane `_draw()`, ten sam wzorzec co
siatka heksów w `hex_map_view.gd`). Skille są na razie logicznie płaskie
(żaden nie wymaga odblokowania innego najpierw), ale układ graficzny jest
gotowy pod prawdziwe zależności w przyszłości - wystarczyłoby dodać do
`SkillData` listę wymaganych `skill_id` i sprawdzać ją przy odblokowaniu, bez
zmiany samego rysowania. Węzły są pozycjonowane RĘCZNIE
(`Control.position`, nie w kontenerze) na promieniu wyliczonym w
`SkillTreePanel._refresh()` tak, żeby zawsze mieściły się w obszarze grafu i
się nie nakładały (`RADIUS_SAFETY_MARGIN`). Ekran otwiera się jako
**osobny `CanvasLayer` na jednej z najwyższych warstw** (`layer = 100` -
wyżej niż Karta Miasta i cała reszta UI), **przykrywa większość ekranu**
(`Panel` z zakotwiczeniem na pełny prostokąt viewportu, 40px marginesu z
każdej strony - responsywne, nie sztywny rozmiar w pikselach, więc działa
poprawnie niezależnie od rozmiaru okna, patrz "UI skaluje się z oknem" niżej)
i **ma w pełni nieprzezroczyste tło** (tak jak reszta paneli - alpha=1 w
`theme/ui_theme.tres`).

**Węzły to na razie kropki** (nowość) - `scenes/skill_node_dot.gd`
(`SkillNodeDot`) rysuje domyślnie kolorowe kółko (kolor zależny od stanu:
zablokowany / stać cię na niego / odblokowany), ale ma gotowy slot
`sprite_texture` (ten sam wzorzec co `Ludzik.sprite_texture`) - podmiana na
obrazki w przyszłości to tylko przypisanie tekstur, bez zmiany reszty logiki.

**Szczegóły w jednym współdzielonym okienku** (nowość, zamiast rozwijanej
karty) - nazwa, opis, koszt i przycisk odblokowania pokazują się w
`SkillPopup`, pozycjonowanym obok aktualnego węzła (`_position_popup_near()`).
`SkillPopup` jest DZIECKIEM `GraphContent` (tak jak same węzły), nie osobnym
sąsiadem w `GraphArea` - dzięki temu automatycznie dziedziczy pan/zoom
całego grafu (`position`/`scale` sterowane przez `skill_graph_view.gd`)
dokładnie tak samo jak węzeł, którego dotyczy: **pozycja i skala okienka
względem drzewka nigdy się nie zmieniają** przy przesuwaniu/przybliżaniu
widoku (update - wcześniej okienko było osobnym sąsiadem `GraphContent` w
`GraphArea`, więc podczas pan/zoom "odklejało się" od swojego węzła, bo jego
pozycja była liczona tylko raz, w momencie pokazania). `_refresh()` (które
niszczy i buduje węzły od zera przy każdym odświeżeniu) świadomie POMIJA
`skill_popup` przy czyszczeniu starych dzieci `GraphContent` i za każdym
razem przenosi je na koniec listy dzieci (`move_child(skill_popup, -1)`),
żeby zawsze rysowało się NAD nowo dodanymi węzłami, a nie pod nimi. Dwa
niezależne wyzwalacze:
- **Najechanie myszką** na węzeł pokazuje okienko TYMCZASOWO - znika, gdy
  mysz zjedzie i z węzła, i z samego okienka, dopiero po
  `HOVER_HIDE_DELAY_SEC` (0.35s, PRAWDZIWY timer - update, wcześniej jedna
  klatka - `_schedule_hide_check()`) - żeby przejście myszką z węzła NA
  okienko (np. żeby kliknąć "Odblokuj") zdążyło faktycznie dojść do okienka,
  zanim ono zniknie, nawet jeśli po drodze jest chwila, gdy mysz nie jest
  nad żadnym z nich (jedna klatka wystarczała tylko na zbieg dwóch zdarzeń w
  tym samym momencie, nie na ruch myszką trwający dłużej).
- **Kliknięcie** węzła PRZYPINA okienko (`_pinned = true`) - zostaje
  widoczne niezależnie od dalszego hovera, dopóki gracz nie kliknie w INNY
  węzeł (który przejmuje przypięcie) - kliknięcie poza jakimkolwiek węzłem
  nic nie zmienia. Tylko kliknięcie węzła, którego okienko jest AKTUALNIE
  PRZYPIĘTE (drugi klik z rzędu na ten sam węzeł), działa jak przełącznik i
  je zamyka - pierwszy klik na węzeł, którego okienko jest na razie
  pokazane TYLKO z hovera (jeszcze nieprzypięte), tylko je przypina, zamiast
  zamykać (update - wcześniej warunek zamykania sprawdzał tylko
  `_shown_skill == skill`, prawdziwe niezależnie od `_pinned`, więc pierwszy
  klik na węzeł, którego okienko właśnie pokazał hover, zamykał je od razu).

**Nawigacja myszką po grafie** (nowość) - dokładnie jak po mapie: prawy
przycisk + przeciąganie przesuwa widok, scroll przybliża/oddala
(`scenes/skill_graph_view.gd`, `MIN_ZOOM`/`MAX_ZOOM`/`ZOOM_STEP`). Węzły
żyją w osobnym kontenerze `GraphContent`, którego `position`/`scale` steruje
ten sam skrypt - pan/zoom przesuwa i skaluje linie oraz węzły naraz, zawsze
spójnie. Nawigacja jest obsłużona przez `_gui_input()` (standardowy sposób,
w jaki Controle w Godocie łapią mysz), więc **mapa pod spodem NIE reaguje**,
dopóki ekran jest otwarty - zdarzenie zostaje pochłonięte tutaj, zanim
dotrze do kamery mapy (`camera_controller.gd`) czy klikania heksów
(`hex_map_view.gd`), które obie nasłuchują NIŻEJ (`_unhandled_input`). Żeby
domknąć też margines dookoła `Panel` (40px, poza samym grafem), doszedł
`InputBlocker` - niewidoczny, pełnoekranowy `Control` w tej samej warstwie
CanvasLayer, który pochłania wszystko, czego nie złapał już sam `Panel`.

Mechanizm płatności jest identyczny jak w Karcie Miasta
(`PlayerData.can_afford`/`pay_costs`, `GameManager.unlock_skill()` -
scentralizowana funkcja, ten sam wzorzec co `unlock_city_building()`).
Efekty dzielą się na dwie kategorie:

- **Czysto danowe** (promień widzenia, próg bezpiecznej wycinki, koszt
  aneksacji, MP PRZYSZŁYCH ludzików) - `GameManager.unlock_skill()` aplikuje
  je od razu jako akumulatory na `PlayerData` (`vision_radius_bonus`,
  `forest_safe_threshold_bonus`, `annex_cost_reduction`,
  `movement_points_bonus`), odczytywane wprost tam, gdzie wcześniej
  odczytywano odpowiednią stałą z `GameBalance` (`_reveal_around()`,
  `harvest_forest()`, `_effective_annex_cost_for()` w `game_map_controller.gd`).
- **Wymagające dostępu do węzłów sceny** (nowy Ludzik, retroaktywny bonus MP
  na już istniejących ludzikach) - `GameManager` celowo ich nie dotyka (tak
  jak przy MP przy aneksacji - patrz "Decyzje projektowe" niżej);
  `SkillTreePanel.skill_unlocked` (sygnał) doprasza o to
  `game_map_controller._on_skill_unlocked()`. "Drugi ludzik" to pierwsze
  miejsce w grze, które faktycznie korzysta z architektury
  `player_ludziks: player_id -> Array[Ludzik]`, przygotowanej pod ten
  upgrade od samego początku (patrz komentarz na górze `game_map_controller.gd`).

### Wygląd UI - jeden plik do edycji (nowość)

Zamiast kolorów/stylów rozrzuconych po każdym węźle z osobna, wygląd paneli,
przycisków i etykiet mieszka teraz w jednym pliku: `theme/ui_theme.tres`
(zasób typu `Theme`, standardowy mechanizm Godota). Otwórz go w edytorze
Godota (podwójny klik w panelu FileSystem) - dostaniesz wizualny edytor
motywu, gdzie bez pisania kodu można zmienić:

- tło/obramowanie/zaokrąglenie rogów paneli (`PanelContainer/styles/panel`),
- wygląd przycisków w 4 stanach - normalny/hover/wciśnięty/zablokowany
  (`Button/styles/...`),
- domyślny kolor i rozmiar czcionki etykiet i przycisków
  (`Label`/`Button` -> `font_colors`/`font_sizes`).

Motyw jest podpięty (`theme = ExtResource(...)`) do głównych paneli w
`scenes/main.tscn` (`ActionPanel`, `RoutePanel`, `CityCardPanel/Panel`,
`SkillTreePanel/Panel`) i do luźnych etykiet HUD-u (`InfoLabel`, `TurnLabel`,
`MPLabel`, `PrestigeLabel`, `ResourcesLabel`) - zmiana w `ui_theme.tres`
automatycznie obejmuje WSZYSTKIE z nich naraz, bez edytowania każdego węzła
osobno. Pojedyncze etykiety nadal mogą mieć własne, lokalne nadpisania
(`theme_override_colors/font_color` itp. w `main.tscn`, np. żółty
`TurnLabel`) - te wygrywają NAD motywem tam, gdzie są ustawione, więc można
zarówno zmieniać wszystko naraz (motyw), jak i dostrajać pojedyncze elementy
(lokalne nadpisanie).

### UI skaluje się z oknem

`project.godot` -> `[display]`: `window/stretch/mode = "canvas_items"`,
`window/stretch/aspect = "expand"`, bazowa rozdzielczość 1280×800 - zmiana
rozmiaru okna skaluje całą scenę (mapę i UI) proporcjonalnie, zamiast
przycinać ją czarnymi pasami albo zostawiać UI w stałym rozmiarze
pikselowym w rogu ekranu. Panele, które muszą reagować na kształt okna, a
nie tylko jego rozmiar (np. "przykryj większość ekranu" - Drzewko
Umiejętności), dodatkowo używają zakotwiczenia na pełny prostokąt
(`anchor_right = 1.0`, `anchor_bottom = 1.0`, ujemne marginesy) zamiast
sztywnych pikseli - patrz sekcja "Drzewko Umiejętności" wyżej.

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

- **Przegląd i porządki w całym kodzie** (nowość - czysto techniczny przegląd
  jakości, bez zmian w rozgrywce). Cały `godot_project/` (24 pliki `.gd`)
  przejrzany pod kątem duplikacji, martwego kodu i drobnych niespójności:
  - **Mgła wojny jako enum, nie magiczne stringi** - `HexData.FogState`
    (`UNEXPLORED`/`SEEN`/`ANNEXED`) zastępuje dotychczasowe porównania do
    stringów `"unexplored"`/`"seen"`/`"annexed"` rozsiane po
    `game_map_controller.gd`, `hex_map_view.gd` i `game_manager.gd` - ten sam
    wzorzec co `HexData.TerrainType`/`ResourceType`, chroni przed literówką w
    stringu, której kompilator by nie złapał.
  - **Usunięta duplikacja opisu pola** - `_on_hex_hovered()` (dymek) i
    `_refresh_action_panel()` (panel po lewej) budowały niemal identyczny
    tekst dla poziomów SEEN/ANNEXED; wspólna logika przeniesiona do
    `_describe_seen_hex()`/`_describe_owner()`/`_describe_building()`.
    Identyczna funkcja `_format_costs()` (formatowanie słownika kosztów
    zasobów) istniała osobno w `city_card_panel.gd` i `skill_tree_panel.gd` -
    przeniesiona na `HexData.format_resource_costs()` (bo to `HexData`
    właściciel `RESOURCE_DISPLAY_NAMES`, z którego korzysta).
  - **Usunięta duplikacja tworzenia Ludzika** - `_setup_players()` i
    `_recruit_extra_ludzik()` osobno powtarzały ten sam kod nadawania
    koloru/obrazka nowemu węzłowi Ludzik i ten sam fallback na brakujący
    heks startowy; wydzielone do `_configure_ludzik()`/`_resolve_start_hex()`.
  - **Wspólny ogon UI po akcji ludzika** - `_on_annex_pressed()` i
    `_on_takeover_pressed()` kończyły się (na każdej z czterech możliwych
    ścieżek: brak MP / sukces / porażka) tym samym trio
    `_update_mp_label()`/`_refresh_action_panel()`/`_refresh_route_panel()` -
    wydzielone do `_refresh_ludzik_action_ui()`.
  - **`city_buildings_data.gd` z 6 prawie identycznych funkcji na jedną
    tabelę** - `_wroclaw()`/`_szczecin()`/... plus `match` w
    `get_buildings()` zastąpione jedną stałą `CITY_BUILDINGS` (miasto ->
    lista wpisów) i jednym generycznym budowaniem `Building` z wpisu -
    dokładnie te same dane, łatwiej dodać/zmienić budynek albo przejrzeć
    wszystkie miasta naraz.
  - **Usunięty martwy kod**: `Building.can_afford()`/`get_required_amount()`
    (nigdy nie wywoływane - każde miejsce w kodzie i tak woła
    `player.can_afford(x.required_resources)` wprost) oraz sygnały
    `GameManager.prestige_changed`/`hex_ownership_changed` (emitowane, ale
    bez ani jednego `.connect()` w całym projekcie - UI i tak odświeża się
    przez bezpośrednie wywołania `_update_stats_labels()`/`_refresh_map_view()`
    po każdej akcji, nie przez subskrypcję tych sygnałów).
  - **Idiomatyczne funkcje Godota 4** - `int(round(x))` -> `roundi(x)`,
    `int(floor(x))` -> `floori(x)`, `max()`/`min()` na wartościach
    całkowitych/zmiennoprzecinkowych -> `maxi()`/`mini()`/`maxf()` (unikanie
    ogólnego, wolniejszego dopasowania typu Variant przez `max()`/`min()`,
    kiedy typ jest znany z góry - ten sam wzorzec, który reszta kodu już
    stosowała gdzie indziej).
  - **Naprawiony błąd w komentarzu** - `MapData.get_neighbors()` opisywał
    siatkę jako "offset odd-r (pointy-top)", mimo że cały projekt
    (hex_grid_utils.gd, ta sekcja README) konsekwentnie używa "flat-top,
    offset even-q" - stary, mylący komentarz z wcześniejszej iteracji.
  - Zweryfikowane skryptem: brak nieużywanych funkcji/stałych/sygnałów w
    całym projekcie po powyższych zmianach (grep po każdym zdefiniowanym
    identyfikatorze, licząc wystąpienia poza definicją).
- **Poprawki znikania/przypinania okienka szczegółów skilla** (dwie
  powiązane naprawy błędów w `skill_tree_panel.gd`):
  1. **Okienko znikało, zanim mysz zdążyła do niego dojechać.** Ruch myszką
     z węzła (hover, jeszcze nieprzypięte) w stronę okienka - np. żeby
     kliknąć "Odblokuj" - generuje `mouse_exited` węzła i `mouse_entered`
     okienka jako osobne zdarzenia, między którymi realnie mija czas
     ruchu myszką. `_schedule_hide_check()` czekała tylko JEDNĄ KLATKĘ przed
     sprawdzeniem, czy schować okienko - to wystarczało na zbieg dwóch
     zdarzeń w tym samym momencie, ale nie na dłuższy ruch myszką przez
     ewentualną przerwę między obszarem węzła i okienka, więc okienko
     potrafiło zniknąć, zanim kursor faktycznie dotarł do przycisku. Zmiana:
     `await get_tree().process_frame` -> `await get_tree().create_timer(
     HOVER_HIDE_DELAY_SEC).timeout` (nowa stała, 0.35s) - prawdziwe opóźnienie
     w sekundach zamiast jednej klatki. Stan (`_pinned`/`_hovered_skill`/
     `_popup_hovered`) jest i tak sprawdzany DOPIERO po odczekaniu, więc jeśli
     mysz w międzyczasie zdążyła dotrzeć do węzła/okienka, odczyt to wykryje
     i okienko zostanie - nie trzeba dodatkowo anulować wcześniej
     zaplanowanych sprawdzeń przy każdym nowym hoverze.
  2. **Pierwszy klik na węzeł, którego okienko właśnie pokazał hover, od
     razu je zamykał** (zamiast przypinać) - `_on_dot_clicked()` sprawdzał
     tylko `_shown_skill == skill`, co jest PRAWDĄ już od samego hovera
     (`_on_dot_hovered()` ustawia `_shown_skill` przez `_show_popup_for()`),
     więc "pierwszy" klik zachowywał się jak przełącznik "drugiego" kliku i
     zamykał okienko, zamiast je przypiąć. Naprawione dodaniem warunku
     `_pinned` do sprawdzenia: `if _pinned and _shown_skill == skill` -
     zamyka TYLKO drugi klik z rzędu na już PRZYPIĘTY węzeł; pierwszy klik
     na węzeł pokazany tylko z hovera teraz poprawnie przypina okienko
     (`_pinned = true`), więc odjazd myszką gdzie indziej już go nie chowa.
- **Okienko szczegółów skilla trzyma pozycję/skalę względem drzewka przy
  pan/zoom** (nowość). Wcześniej `SkillPopup` był sąsiadem `GraphContent`
  wewnątrz `GraphArea` - jego pozycja liczyła się RAZ, w momencie pokazania
  (`get_global_rect()` węzła, zamieniane na lokalne współrzędne `GraphArea`),
  więc podczas przeciągania/zoomowania grafu (które przesuwa/skaluje tylko
  `GraphContent`) okienko zostawało na starym miejscu, "odklejając się" od
  swojego węzła. Naprawione przez przeniesienie `SkillPopup` w
  `scenes/main.tscn` tak, żeby był DZIECKIEM `GraphContent`, dokładnie jak
  same węzły - automatycznie dziedziczy wtedy `position`/`scale` grafu bez
  żadnego dodatkowego kodu przy evencie pan/zoom. `_position_popup_near()`
  w `skill_tree_panel.gd` mogła się dzięki temu znacznie uprościć: zamiast
  konwersji global→local przez odwróconą transformację (`_position_popup_near`
  liczyła to explicite od czasu naprawy błędu `to_local` na `Control`),
  liczy pozycję bezpośrednio w tych samych LOKALNYCH, nieprzeskalowanych
  współrzędnych `GraphContent`, co `dot.position` (`dot_center_local =
  dot.position + DOT_SIZE / 2.0`). Reparenting wymagał dwóch dodatkowych
  poprawek w `_refresh()` (które za każdym odświeżeniem niszczy i buduje
  węzły od zera): (1) pętla czyszcząca stare dzieci `GraphContent` musi
  jawnie POMIJAĆ `skill_popup` (inaczej `_refresh()` niszczyłoby też samo
  okienko, bo teraz jest jednym z jej dzieci); (2) po dobudowaniu nowych
  węzłów `skill_popup` jest przenoszone na koniec listy dzieci
  (`graph_content.move_child(skill_popup, -1)`), żeby zawsze rysowało się
  NAD nimi, a nie pod nimi (nowe węzły trafiają na koniec listy = rysowane
  później = domyślnie na wierzchu).
- **Dokładna liczba rund do celu; trasa przelicza się co rundę; można
  celować w pole zajęte przez przeciwnika** (nowość). Trzy powiązane zmiany
  w `game_map_controller.gd`:
  1. `_route_rounds_needed(cost, ludzik)` zastępuje dawne binarne "starczy w
     tej rundzie"/"potrwa kilka rund" dokładnym wyliczeniem: 1, jeśli
     `cost <= movement_points_current`, inaczej ta runda plus
     `ceil((cost - movement_points_current) / movement_points_max)` kolejnych
     pełnych rund - z poprawną polską odmianą liczebnika przez
     `_format_rounds()` ("1 rundę" / "2-4 rundy" / "5+ rund", z wyjątkiem
     11-14 zawsze "rund"). Użyte zarówno dla podglądu, jak i trasy w toku
     (`_remaining_route_cost()` - jak `_route_cost()`, ale bez pomijania
     indeksu 0, bo `Ludzik.queued_route` nie zawiera heksa startowego).
  2. `Ludzik.route_destination` to nowe pole trzymające PRAWDZIWY cel
     zatwierdzonej trasy, osobno od `queued_route` (praktyczna, aktualnie
     wykonywana ścieżka - może kończyć się wcześniej niż prawdziwy cel, patrz
     punkt 3). `_continue_all_queued_routes()` woła nowe `_recompute_route()`
     dla każdego ludzika z ustawionym `route_destination` PRZED próbą
     kontynuacji trasy każdej rundy - liczy ścieżkę na nowo aktualnymi
     blokadami (`_blocked_hexes_for()`), więc trasa reaguje na ruch
     przeciwnika (zablokowanie dotychczasowej ścieżki, odblokowanie
     wcześniej niedostępnego celu) automatycznie, bez ponownego klikania.
  3. Nowe `_find_path_toward(from, target, blocked)` pozwala zaznaczyć jako
     cel trasy pole, na którym AKTUALNIE stoi wrogi ludzik (wcześniej taki
     klik po prostu odmawiał trasy) - jeśli cel jest zablokowany, szuka
     zamiast tego najkrótszej ścieżki do najbliższego OSIĄGALNEGO sąsiada
     celu. Ludzik dochodzi tam i czeka (`queued_route` się opróżnia, ale
     `route_destination` zostaje ustawiony) - panel "Trasa ludzika" pokazuje
     wtedy "Ludzik czeka na miejscu...", a kolejne przeliczenie rundy
     (punkt 2) automatycznie ruszy dalej, gdy tylko cel się zwolni. Ten sam
     helper liczy zwykłe trasy (gdy cel nie jest zablokowany, po prostu
     woła pathfinder bezpośrednio), więc `_preview_route_to()` i
     `_recompute_route()` dzielą jedną logikę.
- **Aneksacja wymaga sąsiedztwa z własnym terytorium; stolice chronione
  przed przejęciem** (nowość). `GameManager.annex_hex()` przyjął parametr
  `require_adjacency: bool = true` - domyślnie odmawia aneksacji pola, które
  nie graniczy z ŻADNYM polem już należącym do tego gracza
  (`has_adjacent_owned_hex()`, publiczna metoda, używana też przez
  `game_map_controller._can_annex_selected_hex()`, żeby przycisk był
  wyszarzony zamiast dawać błąd dopiero po kliknięciu). Jedyne wywołanie z
  `require_adjacency = false` to POCZĄTKOWA aneksacja stolicy gracza w
  `_setup_players()` - w tym momencie gracz jeszcze nic nie posiada, więc
  normalny wymóg byłby niespełnialny. Ta sama linijka ustawia nowe pole
  `HexData.is_capital = true` na heksie stolicy - `GameManager.attempt_takeover()`
  odmawia przejęcia siłą każdego heksa z tą flagą (`"capital_protected"`),
  więc stolica żadnego gracza nie da się nigdy podbić, niezależnie od
  przewagi prestiżowej atakującego.
- **Podgląd kosztu trasy uwzględnia auto-aneksację** (nowość).
  `_route_cost()` w `game_map_controller.gd` przyjął parametr `ludzik` - jeśli
  `ludzik.auto_annex` jest włączone, dolicza do sumy MP koszt aneksacji
  (`_effective_annex_cost_for()`) każdego OBECNIE niczyjego pola na
  podglądanej trasie, nie tylko koszt samego ruchu. To celowo tylko
  OSZACOWANIE z góry (nie symuluje kaskadowo, że wcześniejsza aneksacja może
  odblokować sąsiedztwo dla kolejnej) - wystarczająco dokładne jako
  informacja "ile MP to zajmie / ile rund to potrwa", a faktyczne
  wykonanie trasy (`_advance_queued_route`/`_auto_annex_hex`) i tak
  weryfikuje każdą aneksację osobno w momencie dotarcia na pole. Przełącznik
  "Anektuj napotkane pola" odświeża teraz też panel trasy po zmianie
  (`_on_auto_annex_toggled`), żeby podgląd kosztu był zawsze aktualny.
- **Aneksacja podczas trasy ma pierwszeństwo nad samym przejściem - ale NIE
  kosztem zbędnego czekania w miejscu** (update, druga iteracja tej reguły).
  Pierwsza wersja (opisana niżej w starszym wpisie) traktowała "wejście na
  pole + aneksacja" jako JEDNĄ nierozdzielną akcję sprawdzaną PRZED ruchem
  (`required = move_cost + annex_cost`) - to naprawiło cichy fail (ludzik
  wchodził i pomijał aneksację z braku MP), ale wprowadziło NOWY błąd: jeśli
  starczało MP na sam ruch, ale nie na aneksację, ludzik w ogóle się nie
  ruszał, mimo że stał na WŁASNYM, już zaanektowanym terytorium i próbował
  wejść na sąsiednie pole - a punkty ruchu, których i tak nie zużył, po
  prostu przepadają na koniec rundy (nie kumulują się), więc całą rundę
  marnował "na zero" zamiast zrobić chociaż krok bliżej celu. Naprawione
  przez odwrócenie kolejności sprawdzania: `_advance_queued_route()`
  sprawdza na POCZĄTKU KAŻDEJ iteracji pętli (nowe `_current_hex_needs_auto_annex()`),
  czy pole, na którym ludzik AKTUALNIE stoi, kwalifikuje się do aneksacji -
  jeśli tak i starcza MP, aneksuje je od razu (nawet jeśli to pole, na które
  dopiero co wszedł w TEJ SAMEJ rundzie - "wejdź i zaanektuj" nadal dzieje
  się jednym ciągiem, kiedy starcza MP na oba); jeśli nie starcza, pętla
  ZATRZYMUJE SIĘ TU (priorytet aneksacji wciąż obowiązuje - ludzik NIE idzie
  dalej, pomijając to pole), ale ruch, który już wykonał w tej rundzie,
  zostaje - MP nie idą na marne. Aneksacja więc rozkłada się na kolejną
  rundę TYLKO wtedy, gdy naprawdę brakuje MP na nią samą, nigdy kosztem
  niewykorzystanego ruchu. Dotyczy to też przypadku, gdy ludzik dotarł już
  do celu CAŁEJ trasy, ale zabrakło MP na aneksację tego ostatniego pola
  (`queued_route` puste, `route_destination` zostaje ustawiony, żeby
  `_continue_all_queued_routes()` próbowało dokończyć aneksację co rundę -
  patrz `_recompute_route()`), oraz ludzika bez żadnej aktywnej trasy, który
  akurat stoi na kwalifikującym się polu (np. po ręcznym "Anuluj trasę", albo
  gdy inny ludzik tego samego gracza w międzyczasie zaanektował sąsiada) -
  `_continue_all_queued_routes()` woła `_advance_queued_route()` dla KAŻDEGO
  ludzika z `_current_hex_needs_auto_annex() == true`, nie tylko tych z
  niepustym `queued_route`. Panel "Trasa ludzika" ma osobny komunikat na ten
  stan ("Ludzik dotarł na miejsce... ale brakuje MP na aneksację" /
  "Ludzik czeka na miejscu... zaanektuje automatycznie"), odróżniony od
  stanu "cel zajęty przez przeciwnika" (ten sam warunek `queued_route.is_empty()
  and route_destination != ""`, ale inny powód czekania).
  Pole, które nie kwalifikuje się do aneksacji z innego powodu (np. brak
  sąsiedztwa) nadal NIE wstrzymuje ruchu - nie ma sensu czekać na MP, które i
  tak nie rozwiążą problemu sąsiedztwa.
- **Drzewko Umiejętności: węzły to kropki (gotowe pod obrazki), szczegóły w
  jednym przypinanym okienku** (update wyglądu/UX, zastępuje karty z
  poprzedniej iteracji). `scenes/skill_node_dot.gd` (`SkillNodeDot`) rysuje
  domyślnie kolorowe kółko (kolor zależny od stanu - zablokowany/stać cię
  na niego/odblokowany), z gotowym slotem `sprite_texture` (ten sam wzorzec
  co `Ludzik.sprite_texture`) pod przyszłą podmianę na obrazki, bez zmiany
  reszty logiki. Nazwa/opis/koszt/przycisk odblokowania przeniesione z
  osobnej karty per skill do JEDNEGO współdzielonego `SkillPopup`,
  pozycjonowanego obok aktualnego węzła (`_position_popup_near()` -
  mechanizm pozycjonowania i dokładne zasady chowania/przypinania okienka
  zmieniły się w kolejnych update'ach, patrz nowsze wpisy wyżej w tej
  sekcji). Dwa niezależne wyzwalacze: najechanie myszką pokazuje okienko
  TYMCZASOWO (znika, gdy mysz zjedzie i z węzła, i z okienka -
  `_schedule_hide_check()`); kliknięcie węzła PRZYPINA okienko
  (`_pinned = true`) - zostaje widoczne niezależnie od dalszego hovera,
  dopóki gracz nie kliknie w INNY węzeł.
- **Przejęcie terenu gracza: wymaga fizycznej obecności, zawsze da się
  spróbować, nowy wzór na konsekwencje przegranej próby** (update, sekcja 5
  GDD). `GameManager.attempt_takeover()` przestał być twardą blokadą przy
  `attacker.prestige <= defender.prestige` - teraz ZAWSZE coś się dzieje:
  - **Sukces** (prestiż atakującego ściśle większy niż obrońcy, tak jak
    dotąd): atakujący płaci `TAKEOVER_COST_RATIO` (50%) prestiżu OBROŃCY
    (jak dotąd) - NOWOŚĆ: obrońca dodatkowo traci `TAKEOVER_DEFENDER_LOSS_RATIO`
    (25%) WŁASNEGO prestiżu, koszt samego bycia podbitym (poprzednio obrońca
    nie tracił nic nawet przy przegranej).
  - **Porażka** (prestiż atakującego <= obrońcy): pole NIE zmienia
    właściciela, obrońca NIE TRACI NIC, ale atakujący płaci
    `FAILED_TAKEOVER_PENALTY_RATIO` (30%) RÓŻNICY między prestiżem obrońcy a
    atakującego (`maxi(1, ...)` - zawsze co najmniej 1 punkt) - im bardziej
    nierówna próba, tym droższa porażka, ale nigdy nie karze silniejszej
    strony za to, że ktoś słabszy spróbował. Wszystkie trzy stałe w
    `scripts/game_balance.gd`.
  MP (tyle samo co aneksacja, `_effective_annex_cost_for()`) jest pobierane
  z góry i - w odróżnieniu od aneksacji - NIE zwracane przy porażce z
  powodu prestiżu (próba faktycznie zaszła, ma realny koszt), tylko przy
  "twardych" błędach stanu (pole niczyje/już twoje). Dymek na przycisku
  "Przejmij teren gracza" (panel "Trasa ludzika") pokazuje MP (znane z góry)
  i "nieznaną liczbę prestiżu" - dokładny koszt zależy od prestiżu
  przeciwnika, którego UI celowo nie ujawnia.
- **Aneksacja tylko z UI ludzika + automatyczna aneksacja napotkanych pól**
  (update). Przycisk "Zaanektuj" usunięty z głównego panelu akcji (nad
  "Napraw budynek") - aneksacja to jedyna akcja wymagająca fizycznej
  obecności ludzika (w odróżnieniu od Przejmij/Napraw/Wydobądź, które
  działają zdalnie), więc logicznie należy do UI samego ludzika (panel
  "Trasa ludzika"), nie ogólnego panelu pola. `route_annex_button` (już tam
  od poprzedniej iteracji) zostaje jedynym sposobem na ręczną aneksację.
  Nowy przełącznik `AutoAnnexCheckBox` ("Anektuj napotkane pola",
  `Ludzik.auto_annex`, per-ludzik) sprawia, że `_advance_queued_route()`
  automatycznie aneksuje KAŻDY niczyj heks, na który dany ludzik wejdzie w
  trakcie wykonywania trasy (`_auto_annex_hex()`, ten sam mechanizm
  płatności co ręczna aneksacja) - bez potrzeby zatrzymywania się i klikania
  po każdym kroku. Przy okazji: `_effective_annex_cost()` sparametryzowano
  na `player_id` (`_effective_annex_cost_for()`) - automatyczna aneksacja
  może dotyczyć DOWOLNEGO gracza podczas kontynuacji trasy po przeliczeniu
  rundy, nie tylko aktualnie kontrolowanego (`active_player`), więc musi
  czytać bonus `annex_cost_reduction` WŁAŚCIWEGO gracza, nie zawsze aktywnego.
- **Drzewko Umiejętności: nawigacja myszką, szczegóły na hover, pełna
  nieprzezroczystość, blokada mapy pod spodem** (update wyglądu/UX).
  `scenes/skill_graph_view.gd` obsługuje teraz PPM+przeciąganie (pan) i
  scroll (zoom) przez `_gui_input()` - w przeciwieństwie do kamery mapy
  (`_unhandled_input`, poziom sceny), Control-owy `_gui_input()` pochłania
  zdarzenie na miejscu, więc mapa pod spodem NIE reaguje, dopóki drzewko
  jest otwarte. Karty przeniesione do osobnego kontenera `GraphContent`
  (`mouse_filter = IGNORE`, żeby klik na pustym tle przechodził do
  `SkillGraphView` leżącego pod spodem, a klik na samej karcie - zostawał na
  karcie) - `SkillGraphView` steruje jego `position`/`scale`, więc linie
  (`_draw()` z `draw_set_transform` tymi samymi wartościami) i karty zawsze
  się zgadzają. Zoom trzyma węzeł "START" wizualnie w miejscu (korekta
  pozycji przy zmianie skali), tak jak zoom kamery mapy trzyma środek
  widoku. Dodatkowo pełnoekranowy, niewidoczny `InputBlocker` (osobny
  `Control` w tej samej warstwie `CanvasLayer`) domyka margines dookoła
  panelu (40px), żeby NIC nie przeciekało do mapy niezależnie od tego, gdzie
  dokładnie kończy się `Panel`. Szczegóły skilla (opis/koszt/przycisk) są
  teraz ukryte domyślnie i pokazują się dopiero na `mouse_entered` karty
  (znikają na `mouse_exited`) - na stałe widoczna zostaje tylko nazwa.
  Tło panelu (i reszty paneli, bo to współdzielony motyw) jest teraz w pełni
  nieprzezroczyste (`bg_color` alpha 0.92 -> 1 w `theme/ui_theme.tres`).
- **Poprawka: crash po "Potwierdź trasę"** (bug, nie feature).
  `_update_route_overlay()` w `game_map_controller.gd` budował listę heksów
  trasy operatorem `[selected_ludzik.current_hex_id] + selected_ludzik.queued_route`
  - konkatenacja `+` NIETYPOWANEGO literału Array z otypowanym
  `Array[String]` rzuca w Godot 4.2 błędem typowania w runtime (w
  przeciwieństwie do zwykłego przypisania `x: Array[String] = jakiś_array`,
  które bezpiecznie konwertuje). Naprawione przez jawnie otypowaną zmienną
  pośrednią + `append_array()` zamiast operatora `+` - patrz komentarz przy
  tej funkcji. Jedyne miejsce w kodzie, które używało tego wzorca; reszta
  łączenia list korzysta z `append()`/`append_array()`.
- **Motyw UI (`theme/ui_theme.tres`) - jedno miejsce do zmiany wyglądu**
  (nowość). Wcześniej kolory/style paneli i przycisków były (poza kilkoma
  lokalnymi nadpisaniami, np. żółty `TurnLabel`) całkowicie domyślne
  (szary Godot). Teraz jeden zasób `Theme` (`PanelContainer`/`Button`/`Label`
  - tło, obramowanie, zaokrąglenie, kolor/rozmiar czcionki) podpięty do
  wszystkich głównych paneli i etykiet HUD-u w `main.tscn` - edytowalny
  wizualnie w Godot Theme Editor, bez dotykania kodu ani pojedynczych węzłów.
  Patrz sekcja "Wygląd UI - jeden plik do edycji" wyżej.
- **Drzewko Umiejętności jako radialny graf, prawie na cały ekran, na
  najwyższej warstwie** (update wyglądu). Poprzednia wersja była zwykłą,
  przewijaną listą (`ScrollContainer`/`VBoxContainer`) w panelu o stałym
  rozmiarze pikselowym. Teraz `scenes/skill_graph_view.gd` (`Control._draw()`,
  ten sam wzorzec co `hex_map_view.gd`) rysuje węzeł centralny i linie do
  każdej karty, a `SkillTreePanel._refresh()` rozstawia karty promieniście
  wokół niego (promień wyliczony geometrycznie z rozmiaru obszaru i karty,
  żeby zawsze się mieściły i nie nakładały - `RADIUS_SAFETY_MARGIN`). Panel
  dostał zakotwiczenie na pełny prostokąt viewportu z 40px marginesem (zamiast
  sztywnych pikseli) - "przykrywa większość ekranu" niezależnie od rozmiaru
  okna - i `CanvasLayer.layer = 100`, wyraźnie ponad Kartą Miasta
  (`layer = 10`) i resztą UI, żeby zawsze renderował się na wierzchu.
- **Trasa wielorundowa z podglądem i potwierdzeniem** (nowość). Klik na polu
  z zaznaczonym ludzikiem już NIE rusza go od razu - `_preview_route_to()`
  w `game_map_controller.gd` liczy trasę z `HexPathfinder` i tylko ją
  POKAZUJE (`hex_map_view.preview_route_hex_ids`, żółta linia), czekając na
  **Potwierdź trasę** w nowym panelu "Trasa ludzika". Po potwierdzeniu trasa
  trafia na `Ludzik.queued_route` (nie do kontrolera - musi przetrwać zmianę
  zaznaczenia/gracza) i wykonuje się przez `_advance_queued_route()` na tyle
  kroków, ile starczy AKTUALNYCH punktów ruchu; jeśli trasa jest dłuższa,
  reszta zostaje zapamiętana (rysowana pomarańczową linią,
  `queued_route_hex_ids`) i **automatycznie kontynuowana** po każdym kolejnym
  `TurnManager.end_round()` (`_continue_all_queued_routes()`, wołane z
  `_on_round_ended()`) - świeże MP każdej rundy popychają trasę dalej bez
  ponownego klikania, stąd "trasa idzie przez parę rund". Blokada przez
  ludzika innego gracza jest re-weryfikowana PRZY KAŻDYM kroku wykonania
  (nie tylko przy planowaniu podglądu) - trasa mogła czekać kilka rund, w
  międzyczasie ktoś mógł wejść jej na drodze; w takim wypadku trasa się
  zatrzymuje (zostaje w `queued_route`) zamiast przejechać przez niego.
  Aneksacja jest osiągalna wprost z tego samego panelu (przycisk-skrót na
  `_on_annex_pressed()`), żeby nie trzeba było przełączać się do panelu akcji
  po dotarciu na miejsce.
- **Drzewko Umiejętności** (nowość, patrz sekcja "Drzewko Umiejętności"
  wyżej) - drugi, obok Karty Miasta, trwały cel na surowce, tym razem z
  bezpośrednim wpływem na rozgrywkę. `GameManager.unlock_skill()` to ten sam
  wzorzec płatności co `unlock_city_building()` (weryfikacja + pobranie
  kosztu + zapis do `PlayerData.unlocked_skills`), ale efekty dzielą się na
  dwie kategorie: "czysto danowe" (promień widzenia, próg wycinki, koszt
  aneksacji, MP przyszłych ludzików) aplikowane WPROST na akumulatorach
  `PlayerData` przez `GameManager` (spójnie z zasadą "GameManager nic nie wie
  o ludzikach/scenie" - patrz niżej), i te wymagające węzłów sceny (nowy
  Ludzik, retroaktywny bonus MP na istniejących), zgłaszane sygnałem
  `SkillTreePanel.skill_unlocked` do `game_map_controller._on_skill_unlocked()`.
  Skill "Drugi ludzik" to pierwsze miejsce w grze faktycznie korzystające z
  `player_ludziks: player_id -> Array[Ludzik]` - architektury przygotowanej
  pod ten upgrade od samego początku (patrz "Punkty ruchu przeniesione..."
  niżej).
- **UI skaluje się z oknem** (nowość) - `project.godot` (`[display]`)
  ustawia `window/stretch/mode = "canvas_items"` i `window/stretch/aspect =
  "expand"` z bazową rozdzielczością 1280×800 (dopasowaną do istniejących,
  ustawionych "na sztywno" w pikselach pozycji paneli UI w `main.tscn`).
  Godot skaluje wtedy CAŁY canvas (mapę 2D i UI - obie żyją w tym samym
  viewporcie) proporcjonalnie do rozmiaru okna, bez przepisywania pozycji
  poszczególnych elementów UI na jednostki względne.
- **Hotseat na pełnych 6 graczach (sekcja 7 GDD).** `PlayerSetup.LIST`
  (`scripts/player_setup.gd`) opisuje wszystkich 6 możliwych graczy (Wrocław
  `H18`, Szczecin `A7`, Warszawa `R12`, Kraków `O22`, Gdańsk `L3`, Poznań
  `G12`), każdy z osobnym kolorem pionka i kompletem budynków Karty Miasta
  w `city_buildings_data.gd`. Cała logika ruchu/mgły/akcji/tur/PvP była od
  początku napisana generycznie (pętle po `players`/`player_ludziks`, bez
  założenia "dokładnie dwóch graczy"), więc przejście z 2 na 6 to była
  wyłącznie kwestia dopisania DANYCH - żadnych zmian w logice sterowania,
  ruchu, mgły, akcji na polu czy tur. Który skład faktycznie gra wybiera się
  teraz na ekranie startowym (patrz niżej), zamiast ręcznie edytować listę.
- **Ekran startowy - wybór miast przed rozgrywką** (nowość). `scenes/start_screen.tscn`
  jest teraz sceną główną (`project.godot` -> `run/main_scene`): checkbox per
  miasto z `PlayerSetup.LIST`, wszystkie domyślnie zaznaczone, minimum 2
  wymagane do startu. Wybór trafia do nowego autoloadu `GameSetup`
  (`selected_player_ids: Array[int]`) - jedyny stan, który musi przeżyć
  `change_scene_to_file()` do `main.tscn`. `game_map_controller._setup_players()`
  filtruje `PLAYER_SETUP` (teraz alias na `PlayerSetup.LIST`) po tej liście;
  pusta lista (uruchomienie `main.tscn` z pominięciem ekranu startowego, np.
  F6 w edytorze) oznacza "wszyscy", więc stary sposób testowania nadal działa
  bez zmian. Uwaga na indeksowanie węzła `$Ludzik` już obecnego w scenie -
  przypisywany jest pierwszemu FAKTYCZNIE zarejestrowanemu graczowi (po
  filtrze), nie pierwszemu wpisowi w `PLAYER_SETUP`, żeby nie zostawał
  osierocony, gdy gracz #1 (Wrocław) nie zostanie wybrany.
- **Mgła wojny bramkuje też panel po kliknięciu, nie tylko hover** (update).
  `_refresh_action_panel()` w `game_map_controller.gd` używał wcześniej
  zawsze pełnych danych pola (etykieta, właściciel, budynek, poziom zasobu)
  niezależnie od tego, czy gracz w ogóle to pole odkrył - klikając
  niezbadane pole, dało się poznać wszystko o nim od razu, z pominięciem
  mgły wojny. Teraz stosuje dokładnie tę samą trójpoziomową logikę co
  `_on_hex_hovered()` (przy hover): "unexplored" pokazuje tylko ID heksa,
  "seen" dokłada typ terenu i koszt ruchu, "annexed" pokazuje wszystko.
  Przyciski akcji celowo NIE są bramkowane tym samym mechanizmem (patrz
  komentarz w kodzie) - to świadomy kompromis, żeby np. przejęcie terenu
  przeciwnika pozostało możliwe bez wcześniejszego pełnego zbadania pola.
- **Kolor drużyny wokół zaanektowanych pól** (nowość). `hex_map_view.gd`
  (`_draw_hex()`) rysuje dodatkową, grubszą obwódkę (`OWNER_OUTLINE_WIDTH`)
  w kolorze właściciela (`PlayerData.color`, ten sam co pionek) wokół
  każdego heksa, który ma właściciela I nie jest już "unexplored" dla
  oglądającego gracza - ten sam próg mgły co widoczność ludzika przeciwnika
  (sekcja niżej), więc oba mechanizmy są ze sobą spójne. Kolor pobierany
  przez `GameManager.get_player(hex.owner_id).color` - stąd nowe pole
  `PlayerData.color`, ustawiane w `_setup_players()` z tego samego wpisu
  `PLAYER_SETUP`, z którego już czerpał kolor pionek.
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
  heks nie może być ani przystankiem, ani tranzytem trasy. Ponieważ blokada
  działa symetrycznie (z punktu widzenia KAŻDEGO gracza z osobna), dwóch
  różnych graczy nigdy nie mogą stać jednocześnie na tym samym heksie - od
  update'u niżej (przejęcie terenu gracza wymaga fizycznej obecności
  atakującego) to WYSTARCZY jako "jedyny mechanizm obrony terytorium" z
  sekcji 3 GDD: samo stanie na wrogim polu już dowodzi, że broniący go
  ludzik akurat go nie patroluje, osobne sprawdzenie w `attempt_takeover()`
  nie jest już potrzebne.
- **Aneksacja I przejęcie terenu gracza wymagają fizycznej obecności, reszta
  akcji działa zdalnie** (update - poprzednio przejęcie terenu działało z
  dowolnej odległości; teraz, tak jak aneksacja, wymaga stania DOKŁADNIE na
  polu, sprawdzane przez `_find_own_ludzik_at()`, i kosztuje tyle samo
  punktów ruchu, co aneksacja, pobierane z ludzika, który tam stoi). Napraw
  i Wydobądź nadal działają na dowolnym już zaanektowanym WŁASNYM polu z
  dowolnej odległości - "zarządzanie zdalne" terytorium, którego istnienie
  gracz już zna.
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
- **Obrazek ludzika** (`Ludzik.sprite_texture`, `Texture2D`) - ustaw w
  edytorze (zaznacz węzeł Ludzik w `main.tscn` -> Inspector -> Sprite
  Texture) albo z kodu (`ludzik.sprite_texture = load("res://...png")`).
  Bez ustawionego obrazka rysowane jest domyślne kółko w kolorze `color`
  (jak dotąd) - obie ścieżki współistnieją, nic nie trzeba było przepisywać.
  `PLAYER_SETUP` w `game_map_controller.gd` przyjmuje też opcjonalny klucz
  `"sprite"` (ścieżka `res://...`), więc można od razu przypisać różne
  obrazki wszystkim 6 dynamicznie tworzonym graczom przez same dane, bez
  dotykania kodu - działa tylko dla plików, które faktycznie istnieją
  (`ResourceLoader.exists()`), więc nie psuje niczego, dopóki nie dodasz
  własnej grafiki do projektu.
- **Budynki na mapie czytane z KML, nie zgadywane z typu zasobu** (update).
  `tools/convert_kml_to_json.py` ma teraz `classify_building()`, które
  rozpoznaje w etykiecie realny obiekt gospodarczy (gazoport, huta, fabryka,
  kopalnia, elektrownia, rafineria, stocznia, złoża) niezależnie od tego,
  czy trafił już w `RESOURCE_KEYWORDS`. `map_data.gd` (`_attach_building`)
  czyta gotowe pole `"building"` z JSON zamiast (jak wcześniej) doklejać
  identyczny placeholder do każdego heksa z jakimkolwiek zasobem - budynek
  ma teraz swoją prawdziwą nazwę z KML. Zregenerowano też istniejący
  `data/map_data.json` tą samą logiką (bez KML - prosto z już zapisanych
  etykiet `label_raw`), więc efekt jest widoczny od razu, bez ponownego
  eksportu z Google Earth: 440 z 496 heksów ma teraz budynek.
- **Wydobycie lasu NAPRAWIONE - drewno faktycznie się wyczerpywało w
  nieskończoność** (bug, nie feature). `harvest_forest()` liczyło
  `wood_gained` na podstawie `hex.resource_level`, ale nigdy go nie
  pomniejszało o wydobytą ilość - pole zawsze zostawało na ~100% (albo
  regenerowało się z powrotem do 100%, zanim ktokolwiek zdążył to zauważyć),
  więc dało się zbierać to samo drewno co turę bez ograniczeń. Brakującą
  linię (`hex.resource_level -= wood_gained`) dodano w `game_manager.gd` -
  teraz pole faktycznie się wyczerpuje i regeneruje wg wzoru z sekcji 6.1
  GDD, zgodnie z zamierzonym mechanizmem zrównoważonego wydobycia.

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
  `Building` tworzonym automatycznie przez `map_data.gd` z pola "building" w
  JSON). To celowe uproszczenie, dopóki nie ustalimy kosztów naprawy per typ
  budynku — repair działa więc już teraz "za darmo", tylko żeby przetestować
  przepływ aneksacja → naprawa → dochód. Budynki Karty Miasta (Faza 8) MAJĄ
  już zdefiniowane, niezerowe koszty (`city_buildings_data.gd`).
- **Budynki przemysłowe bez dopasowanego surowca nic nie produkują** (np.
  "Elektrownia Opole", "Rafineria Orlen Płock" - konwerter je rozpoznaje i
  tworzy im budynek do znalezienia/naprawienia, ale `produces_resource` zostaje
  "none", więc dochód po naprawie wynosi zero). To świadomie zostawione otwarte
  - GDD (sekcja 6/11) nie rozstrzygnął, czy/jak surowce mają być przetwarzane
  w budynkach przemysłowych na "zaawansowane produkty"; zgadywanie konkretnego
  surowca z samej nazwy (np. "elektrownia" -> węgiel? gaz? atom?) byłoby
  zgadywaniem, nie danymi z KML.
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
- **Ludzik przeciwnika widoczny tylko na odkrytym polu** (update - wcześniej
  widoczny zawsze, niezależnie od mgły). `game_map_controller._update_ludzik_visibility()`
  ustawia `Node2D.visible` każdego CUDZEGO ludzika wg fog_state aktywnego
  (oglądającego) gracza na heksie, na którym ludzik akurat stoi - widoczny,
  jeśli ten heks jest choćby "seen" (kiedyś znalazł się w promieniu widzenia
  jednego z Twoich ludzików, `VISION_RADIUS`), nie dopiero po pełnym
  zbadaniu/zaanektowaniu. Własne ludziki są widoczne zawsze. Wołane przez
  nową `_refresh_map_view()` (zastąpiła bezpośrednie
  `hex_map_view.queue_redraw()` wszędzie, gdzie mgła/widok/pozycja ludzika
  mogły się zmienić), więc widoczność jest zawsze spójna z tym, co akurat
  pokazuje mgła wojny na mapie. Nadal działa niezależnie od "funkcji
  obronnej" (blokada ruchu, sekcja 3 GDD) - ta zostaje oparta o faktyczną
  pozycję, nie o to, czy akurat ją widzisz, bo GDD nie warunkuje obrony
  terytorium widocznością.
- **Otwarte pytania z sekcji 11 GDD** wciąż nierozstrzygnięte (nie blokują
  Faz 0-9, ale wpłyną na balans): czy typ strefy chronionej (UNESCO vs zwykły
  PN) różnicuje karę prestiżową; czy surowce wymagają przetworzenia w
  budynkach przemysłowych zanim zasilą Kartę Miasta; dokładne wartości stałych
  wzoru regeneracji lasu; ostateczny warunek zwycięstwa (Faza 11).
- **Jeszcze nie zaimplementowane**: multiplayer sieciowy (Faza 10 — ENet,
  klient-serwer, lobby 6 graczy), warunek zwycięstwa i polish końcowy
  (Faza 11).
