extends Node
## Autoload: DiplomacyManager
## Pakt o nieagresji - DWUETAPOWY (update na wyraźne życzenie: "pakt o
## nieagresji powinien polegać na tym że - 1 gracz wysyła prośbę a drugi
## akceptuje, dopiero wtedy można stracić [prestiż]"): jeden gracz WYSYŁA
## PROŚBĘ (`send_proposal()`), a pakt faktycznie zaczyna obowiązywać (i
## dopiero wtedy może zostać złamany za karę prestiżową) TYLKO gdy druga
## strona ją ZAAKCEPTUJE (`accept_proposal()`). Poprzednia wersja zawierała
## pakt natychmiast, bez zgody drugiej strony - to była świadoma decyzja
## uzasadniona hotseatem ("obaj gracze siedzą przy tym samym ekranie"), ale
## użytkownik chce jednak prawdziwej zgody obu stron, więc ta wersja ją
## wymaga.
##
## Trzy stany między parą graczy, sprawdzane w tej kolejności:
## 1. AKTYWNY PAKT (`_pacts`) - zaakceptowany, blokuje
##    `GameManager.attempt_takeover()` między stronami, ma datę wygaśnięcia.
## 2. OCZEKUJĄCA PROŚBA (`_pending_proposals`) - wysłana, ale jeszcze nie
##    rozpatrzona - NIE blokuje niczego, to jeszcze nie jest pakt.
## 3. Brak żadnego z powyższych.
##
## Stała długość (`GameBalance.NON_AGGRESSION_PACT_DURATION_ROUNDS`) zamiast
## suwaka w UI - życzenie mówi "Bez kosztu", więc prostota wygrywa z dalszą
## konfigurowalnością, której nikt nie prosił. Liczona OD MOMENTU AKCEPTACJI,
## nie od wysłania prośby - prośba może czekać dowolnie długo (gracz, do
## którego jest skierowana, może akurat nie być aktywny), a długość paktu ma
## sens dopiero, gdy realnie zaczyna obowiązywać.
##
## Pakt blokuje WYŁĄCZNIE `GameManager.attempt_takeover()` między jego
## dwoma stronami ("blokującą przejęcie heksów między sobą") - aneksacja
## nie jest tym dotknięta, bo działa tylko na heksach NICZYJICH, więc nigdy
## nie dotyczy "heksów między graczami" w pierwszej kolejności.
##
## Zerwanie AKTYWNEGO paktu to JEDYNA droga do kary prestiżowej
## (`break_pact()`) - zgodnie z życzeniem, prośba/propozycja sama w sobie
## nigdy nikogo nic nie kosztuje, dopiero złamanie już zaakceptowanej umowy.
## Pakt inaczej wygasa sam, bez kary, gdy `TurnManager.round_number`
## przekroczy `expires_round` (leniwe sprawdzenie w `has_pact()`, ten sam
## wzorzec co `RandomEventManager.is_pest_plague_active()` i inne efekty
## "aktywne do rundy X" - bez osobnego przetwarzania przy końcu rundy).
##
## Powiadomienia idą do WSPÓLNEGO dziennika `RandomEventManager.log_notification()`
## (patrz komentarz tam) zamiast własnego - panel powiadomień i licznik
## nieprzeczytanych działają więc identycznie dla dyplomacji i dla losowych
## wydarzeń. Dotyczą DOKŁADNIE dwóch konkretnych graczy (nie jednego, nie
## wszystkich) - logowane osobno dla każdego z nich (albo tylko dla adresata,
## przy samej prośbie - patrz `send_proposal()`).

## player_a:player_b (posortowane rosnąco - patrz `_pact_key()`) ->
## {"proposer_id": int, "target_id": int} - prośba jeszcze nierozpatrzona.
var _pending_proposals: Dictionary = {}

## player_a:player_b (posortowane rosnąco) -> {"player_a": int, "player_b": int,
## "expires_round": int} - AKTYWNY, zaakceptowany pakt.
var _pacts: Dictionary = {}


func _pact_key(player_a: int, player_b: int) -> String:
	return "%d:%d" % [mini(player_a, player_b), maxi(player_a, player_b)]


## Czy MIĘDZY tymi dwoma graczami aktualnie obowiązuje AKTYWNY (zaakceptowany)
## pakt - leniwe sprawdzenie daty wygaśnięcia, patrz komentarz u góry pliku.
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


## Kto (jeśli ktokolwiek) wysłał jeszcze nierozpatrzoną prośbę o pakt między
## tymi dwoma graczami - -1, jeśli nie ma żadnej otwartej prośby.
func pending_proposer(player_a: int, player_b: int) -> int:
	var entry: Dictionary = _pending_proposals.get(_pact_key(player_a, player_b), {})
	return entry.get("proposer_id", -1)


## Relacja między `viewer_id` a `other_id` z punktu widzenia `viewer_id` - do
## zbudowania odpowiedniego wiersza/przycisków w scenes/diplomacy_panel.gd
## bez powtarzania tej samej logiki w dwóch miejscach. `state` to jedno z:
## "active" (+ "expires_round"), "sent" (viewer wysłał, czeka), "received"
## (viewer dostał, może zaakceptować/odrzucić), "none".
func get_relationship(viewer_id: int, other_id: int) -> Dictionary:
	if has_pact(viewer_id, other_id):
		return {"state": "active", "expires_round": pact_expires_at(viewer_id, other_id)}
	var proposer = pending_proposer(viewer_id, other_id)
	if proposer == viewer_id:
		return {"state": "sent"}
	if proposer == other_id:
		return {"state": "received"}
	return {"state": "none"}


## Wysyła prośbę o pakt - NIE zawiera go jeszcze (patrz accept_proposal()).
## Powiadomienie idzie TYLKO do adresata (`target_id`) - to jego decyzja,
## proponujący już wie, że właśnie to zrobił.
func send_proposal(proposer_id: int, target_id: int) -> Dictionary:
	if proposer_id == target_id:
		return {"success": false, "reason": "same_player"}
	var proposer = GameManager.get_player(proposer_id)
	var target = GameManager.get_player(target_id)
	if proposer == null or target == null:
		return {"success": false, "reason": "invalid_players"}
	if has_pact(proposer_id, target_id):
		return {"success": false, "reason": "already_active"}
	if pending_proposer(proposer_id, target_id) != -1:
		return {"success": false, "reason": "already_pending"}

	_pending_proposals[_pact_key(proposer_id, target_id)] = {
		"proposer_id": proposer_id, "target_id": target_id,
	}
	RandomEventManager.log_notification(
		"🤝 %s proponuje Ci pakt o nieagresji - zaakceptuj albo odrzuć w panelu Dyplomacji." % proposer.player_name,
		target_id
	)
	return {"success": true}


## Akceptacja - DOPIERO TERAZ pakt faktycznie zaczyna obowiązywać (i dopiero
## od teraz jego zerwanie może kosztować prestiż). `accepter_id` musi być
## faktycznym ADRESATEM zapamiętanej prośby (nie może "zaakceptować" prośby,
## której sam nie dostał, np. własnej) - stąd sprawdzenie przez
## `pending_proposer()` poniżej, nie tylko istnienia wpisu.
func accept_proposal(accepter_id: int, proposer_id: int) -> Dictionary:
	if pending_proposer(accepter_id, proposer_id) != proposer_id:
		return {"success": false, "reason": "no_pending_proposal"}

	_pending_proposals.erase(_pact_key(accepter_id, proposer_id))

	var expires_round = TurnManager.round_number + GameBalance.NON_AGGRESSION_PACT_DURATION_ROUNDS - 1
	_pacts[_pact_key(accepter_id, proposer_id)] = {
		"player_a": accepter_id, "player_b": proposer_id, "expires_round": expires_round,
	}

	var accepter = GameManager.get_player(accepter_id)
	var proposer = GameManager.get_player(proposer_id)
	var message = "🤝 Pakt o nieagresji między %s a %s - obowiązuje do rundy %d." % [
		accepter.player_name, proposer.player_name, expires_round,
	]
	RandomEventManager.log_notification(message, accepter_id)
	RandomEventManager.log_notification(message, proposer_id)

	return {"success": true, "expires_round": expires_round}


## Usuwa jeszcze nierozpatrzoną prośbę BEZ żadnych konsekwencji dla nikogo -
## może to zrobić zarówno adresat (odmowa), jak i sam proponujący
## (anulowanie własnej, jeszcze nierozpatrzonej prośby); `_pact_key()` jest
## symetryczny względem kolejności argumentów, więc obie strony wołają to
## samo tą samą parą id.
func cancel_proposal(canceller_id: int, other_id: int) -> Dictionary:
	var key = _pact_key(canceller_id, other_id)
	if not _pending_proposals.has(key):
		return {"success": false, "reason": "no_pending_proposal"}
	_pending_proposals.erase(key)
	return {"success": true}


## Zrywa AKTYWNY pakt PRZED czasem - `breaker_player_id` (ten, kto klika
## "Zerwij pakt") płaci `GameBalance.NON_AGGRESSION_PACT_BREAK_PENALTY`
## prestiżu ("zerwanie przed czasem to duża kara prestiżu"); `other_player_id`
## nie traci nic. Naturalne wygaśnięcie o czasie (has_pact() zwraca false
## samo, gdy minie `expires_round`) NIE przechodzi przez tę funkcję i nie
## karze nikogo - razem z samą PROŚBĄ (nigdy nie kosztuje nic - patrz
## send_proposal()/cancel_proposal()) to jedyna droga do kary.
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


## Zapis stanu (autoloads/save_manager.gd) - oba słowniki są już w pełni
## JSON-bezpiecznym kształcie (klucze i wartości String/int), więc kopiowane
## wprost, bez dodatkowej konwersji.
func get_save_state() -> Dictionary:
	return {
		"pacts": _pacts.duplicate(true),
		"pending_proposals": _pending_proposals.duplicate(true),
	}


## Wczytanie stanu (autoloads/save_manager.gd) - odwrotność get_save_state().
## Liczby wracają z JSON jako float (JSON zna tylko typ "number") - jawnie
## rzutowane z powrotem na int.
func load_save_state(data: Dictionary) -> void:
	_pacts.clear()
	for key in data.get("pacts", {}):
		var entry: Dictionary = data["pacts"][key]
		_pacts[key] = {
			"player_a": int(entry["player_a"]),
			"player_b": int(entry["player_b"]),
			"expires_round": int(entry["expires_round"]),
		}
	_pending_proposals.clear()
	for key in data.get("pending_proposals", {}):
		var entry: Dictionary = data["pending_proposals"][key]
		_pending_proposals[key] = {
			"proposer_id": int(entry["proposer_id"]),
			"target_id": int(entry["target_id"]),
		}
