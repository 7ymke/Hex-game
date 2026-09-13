extends Node
## Autoload: GameSetup
## Przekazuje wybór miast/graczy dokonany na ekranie startowym
## (scenes/start_screen.gd) do scenes/game_map_controller.gd, który go
## odczytuje w _setup_players(). Jedyny stan, jaki tu trzymamy - żyje między
## zmianą sceny (start_screen.tscn -> main.tscn), więc autoload, nie zwykły
## węzeł sceny.

## ID graczy (z scripts/player_setup.gd -> PlayerSetup.LIST) wybranych do
## udziału w rozgrywce. Pusta lista = wszyscy (np. przy uruchomieniu
## main.tscn wprost w edytorze, z pominięciem ekranu startowego - tak samo
## działało to przed dodaniem ekranu startowego).
var selected_player_ids: Array[int] = []
