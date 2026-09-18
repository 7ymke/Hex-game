extends Node
## Autoload: DiplomacyManager
## Pakt o nieagresji (nowość, na życzenie: "Pakt o nieagresji — dwóch graczy
## zawiera czasową umowę blokującą przejęcie heksów między sobą. Bez kosztu;
## zerwanie przed czasem to duża kara prestiżu.").
##
## Hotseat: obaj gracze siedzą przy tym samym ekranie, więc "zawarcie paktu"
## nie potrzebuje osobnego etapu propozycja/akceptacja (jak np. przez sieć) -
## gracz aktywny wybiera drugiego gracza z listy w scenes/diplomacy_panel.gd
## i pakt zostaje zawarty NATYCHMIAST, dokładnie tak samo jak "Zmiana gracza"
## już zakłada lokalne zaufanie między graczami przy tym samym ekranie.
##
## Stała długość (`GameBalance.NON_AGGRESSION_PACT_DURATION_ROUNDS`) zamiast
## suwaka w UI - życzenie mówi "Bez kosztu", więc prostota wygrywa z dalszą
## konfigurowalnością, której nikt nie prosił.
##
## Pakt blokuje WYŁĄCZNIE `GameManager.attempt_takeover()` między jego
## dwoma stronami ("blokującą przejęcie heksów między sobą") - aneksacja
## nie jest tym dotknięta, bo działa tylko na heksach NICZYJICH, więc nigdy
## nie dotyczy "heksów między graczami" w pierwszej kolejności.
##
## Zerwanie paktu to JEDYNY sposób, żeby przestał obowiązywać przed czasem
## (`break_pact()`) - inaczej wygasa sam, bez kary, gdy `TurnManager.round_number`
## przekroczy `expires_round` (leniwe sprawdzenie w `has_pact()`, ten sam
## wzorzec co `RandomEventManager.is_pest_plague_active()` i inne efekty
## "aktywne do rundy X" - bez osobnego przetwarzania przy końcu rundy).
##
## Powiadomienia o zawarciu/zerwaniu/wygaśnięciu idą do WSPÓLNEGO dziennika
## `RandomEventManager.log_notification()` (patrz komentarz tam) zamiast
## własnego - panel powiadomień i licznik nieprzeczytanych działają więc
## identycznie dla dyplomacji i dla losowych wydarzeń, bez duplikowania
## infrastruktury. Ponieważ pakt dotyczy DOKŁADNIE dwóch konkretnych graczy
## (nie jednego i nie wszystkich, jedyne dwa kształty, jakie zna istniejący
## system powiadomień), ta sama wiadomość jest logowana DWA razy, raz na
## gracza.

## player_a(int):player_b(int) (posortowane rosnąco - patrz `_pact_key()`) ->
## {"player_a": int, "player_b": int, "expires_round": int}.
var _pacts: Dictionary = {}


func _pact_key(player_a: int, player_b: int) -> String:
	return "%d:%d" % [mini(player_a, player_b), maxi(player_a, player_b)]


## Czy MIĘDZY tymi dwoma graczami aktualnie obowiązuje pakt - leniwe
## sprawdzenie daty wygaśnięcia, patrz komentarz na górze pliku.
func has_pact(player_a: int, player_b: int) -> bool:
	var entry: Dictionary = _pacts.get(_pact_key(player_a, player_b), {})
	return not entry.is_empty() and TurnManager.round_number <= entry["expires_round"]


## Runda, do której (włącznie) trwa pakt między tymi dwoma graczami, albo -1,
## jeśli nie ma między nimi aktywnego paktu - do wyświetlenia w
## scenes/diplomacy_panel.gd ("pakt do rundy X").
func pact_expires_at(player_a: int, player_b: int) -> int:
	if not has_pact(player_a, player_b):
		return -1
	return _pacts[_pact_key(player_a, player_b)]["expires_round"]


func propose_pact(player_a_id: int, player_b_id: int) -> Dictionary:
	if player_a_id == player_b_id:
		return {"success": false, "reason": "same_player"}
	if GameManager.get_player(player_a_id) == null or GameManager.get_player(player_b_id) == null:
		return {"success": false, "reason": "invalid_players"}
	if has_pact(player_a_id, player_b_id):
		return {"success": false, "reason": "already_active"}

	var expires_round = TurnManager.round_number + GameBalance.NON_AGGRESSION_PACT_DURATION_ROUNDS - 1
	_pacts[_pact_key(player_a_id, player_b_id)] = {
		"player_a": player_a_id, "player_b": player_b_id, "expires_round": expires_round,
	}

	var player_a = GameManager.get_player(player_a_id)
	var player_b = GameManager.get_player(player_b_id)
	var message = "🤝 Pakt o nieagresji między %s a %s - obowiązuje do rundy %d." % [
		player_a.player_name, player_b.player_name, expires_round,
	]
	RandomEventManager.log_notification(message, player_a_id)
	RandomEventManager.log_notification(message, player_b_id)

	return {"success": true, "expires_round": expires_round}


## Zrywa pakt PRZED czasem - `breaker_player_id` (ten, kto klika "Zerwij
## pakt") płaci `GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY` prestiżu
## ("zerwanie przed czasem to duża kara prestiżu"); `other_player_id` nie
## traci nic. Naturalne wygaśnięcie o czasie (has_pact() zwraca false samo,
## gdy minie `expires_round`) NIE przechodzi przez tę funkcję i nie karze
## nikogo - to jedyna droga do kary.
func break_pact(breaker_player_id: int, other_player_id: int) -> Dictionary:
	if not has_pact(breaker_player_id, other_player_id):
		return {"success": false, "reason": "no_active_pact"}

	_pacts.erase(_pact_key(breaker_player_id, other_player_id))
	GameManager.change_prestige(breaker_player_id, -GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY)

	var breaker = GameManager.get_player(breaker_player_id)
	var other = GameManager.get_player(other_player_id)
	var message = "💔 %s zerwał pakt o nieagresji z %s przed czasem (-%d prestiżu)." % [
		breaker.player_name, other.player_name, GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY,
	]
	RandomEventManager.log_notification(message, breaker_player_id)
	RandomEventManager.log_notification(message, other_player_id)

	return {"success": true, "penalty": GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY}


## Zapis stanu (autoloads/save_manager.gd) - `_pacts` jest już w pełni
## JSON-bezpiecznym kształcie (klucze i wartości String/int), więc kopiowane
## wprost, bez dodatkowej konwersji.
func get_save_state() -> Dictionary:
	return _pacts.duplicate(true)


## Wczytanie stanu (autoloads/save_manager.gd) - odwrotność get_save_state().
## Liczby wracają z JSON jako float (JSON zna tylko typ "number") - jawnie
## rzutowane z powrotem na int.
func load_save_state(data: Dictionary) -> void:
	_pacts.clear()
	for key in data:
		var entry: Dictionary = data[key]
		_pacts[key] = {
			"player_a": int(entry["player_a"]),
			"player_b": int(entry["player_b"]),
			"expires_round": int(entry["expires_round"]),
		}
