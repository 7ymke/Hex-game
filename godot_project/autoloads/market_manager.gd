extends Node
## Autoload: MarketManager
## Resource market simulation ("Model Ekonomii Rynku") - a mean-reverting
## price per resource, driven by player buy/sell pressure plus a simulated
## "other cities" background demand/supply, short-term momentum, and a
## little random noise. Parameters live in scripts/market_balance.gd; the
## formula itself is `_update_price()` below, a direct implementation of
## the uploaded design doc's section 7 pseudocode.
##
## Prices only move ONCE PER ROUND (`process_round_end()`, called from
## TurnManager.end_round()) - trades made during the round
## (`attempt_trade()`) only ACCUMULATE pressure, exactly like the doc's own
## pseudocode ("update_price wywoływane raz na surowiec, przy przeliczeniu
## rundy").

const DIRECTION_BUY = "buy"
const DIRECTION_SELL = "sell"

## resource(int) -> Array[float], the FULL price history (P_mid), oldest
## first - kept in full (not just the doc's 3-round momentum window) so the
## market page's chart can show more than a handful of rounds; the actual
## pricing math below only ever reads the last few entries.
var price_history: Dictionary = {}

## resource(int) -> float - background "other cities" AR(1) state
## (eta_s/eta_d in the doc).
var _eta_s: Dictionary = {}
var _eta_d: Dictionary = {}

## resource(int) -> float - this round's accumulated player buy/sell
## pressure (q_buy/q_sell in the doc), reset every round in
## process_round_end().
var _q_buy_this_round: Dictionary = {}
var _q_sell_this_round: Dictionary = {}

## player_id(int) -> resource(int) -> {"buy": float, "sell": float} - this
## round's per-player trade volume, reset every round - the per-round
## per-direction trade limit (doc section 5.1) is checked against this.
var _player_trade_log: Dictionary = {}


func _ready() -> void:
	for resource in MarketBalance.RESOURCE_PARAMS:
		price_history[resource] = [MarketBalance.RESOURCE_PARAMS[resource]["p_eq"]]
		_eta_s[resource] = 0.0
		_eta_d[resource] = 0.0
		_q_buy_this_round[resource] = 0.0
		_q_sell_this_round[resource] = 0.0


## Zapis stanu (autoloads/save_manager.gd) - tylko to, co faktycznie
## definiuje rynek między rundami (historia cen + tło AR(1)). Presja z
## BIEŻĄCEJ rundy (_q_buy_this_round/_q_sell_this_round) i dzienny limit
## handlu per gracz (_player_trade_log) celowo NIE są zapisywane - to stan
## czysto rundowy, zerowany i tak co rundę w process_round_end(), więc po
## wczytaniu poprawnie zaczyna się od zera, tak jak na początku każdej rundy.
## Klucze (HexData.ResourceType, int) zamienione na String - JSON nie ma
## kluczy innych niż String.
func get_save_state() -> Dictionary:
	var history_out = {}
	for resource in price_history:
		history_out[str(resource)] = price_history[resource]
	var eta_s_out = {}
	for resource in _eta_s:
		eta_s_out[str(resource)] = _eta_s[resource]
	var eta_d_out = {}
	for resource in _eta_d:
		eta_d_out[str(resource)] = _eta_d[resource]
	return {"price_history": history_out, "eta_s": eta_s_out, "eta_d": eta_d_out}


## Wczytanie stanu (autoloads/save_manager.gd) - odwrotność get_save_state().
## Klucze wracają z JSON jako String (patrz wyżej) - z powrotem na int
## (HexData.ResourceType). Liczby w price_history wracają z JSON jako float
## (JSON zna tylko typ "number") - to i tak dokładnie to, czym są w pamięci
## (Array[float]), więc bez dodatkowego rzutowania.
func load_save_state(data: Dictionary) -> void:
	price_history.clear()
	for resource_str in data.get("price_history", {}):
		price_history[int(resource_str)] = data["price_history"][resource_str]
	_eta_s.clear()
	for resource_str in data.get("eta_s", {}):
		_eta_s[int(resource_str)] = data["eta_s"][resource_str]
	_eta_d.clear()
	for resource_str in data.get("eta_d", {}):
		_eta_d[int(resource_str)] = data["eta_d"][resource_str]


## The current mid price (P_mid) - the "fair value" the formula computes.
## Players never trade AT this price directly - see get_trade_prices().
func get_current_price(resource: HexData.ResourceType) -> float:
	var history: Array = price_history.get(resource, [])
	if history.is_empty():
		return 0.0
	return history[-1]


## The two prices actually offered to a player right now - always straddle
## get_current_price() by the resource's spread (MarketBalance.spread()),
## so buying always costs more than selling nets back. This (plus the
## per-round trade limit) is the model's defense against trading back and
## forth for free profit as the price mean-reverts - see doc section 5.2.
func get_trade_prices(resource: HexData.ResourceType) -> Dictionary:
	var mid = get_current_price(resource)
	var s = MarketBalance.spread(resource)
	return {
		"buy_price": mid * (1.0 + s / 2.0),
		"sell_price": mid * (1.0 - s / 2.0),
	}


## `last_n` most recent prices (oldest first), or the full history if
## `last_n` is omitted/non-positive - for the market page's chart.
func get_price_history(resource: HexData.ResourceType, last_n: int = -1) -> Array:
	var history: Array = price_history.get(resource, [])
	if last_n <= 0 or last_n >= history.size():
		return history.duplicate()
	return history.slice(history.size() - last_n)


func get_trade_limit(resource: HexData.ResourceType) -> int:
	return MarketBalance.trade_limit(resource)


## How much of `resource` `player_id` has already bought/sold THIS round -
## for the market page's "limit used" readout and for attempt_trade()'s own
## limit check, so both always agree.
func get_traded_this_round(player_id: int, resource: HexData.ResourceType, direction: String) -> float:
	var per_player: Dictionary = _player_trade_log.get(player_id, {})
	var per_resource: Dictionary = per_player.get(resource, {})
	return per_resource.get(direction, 0.0)


## Attempts a trade - the only place a player actually buys/sells on the
## market. Checks the per-round volume limit (doc section 5.1), then
## whether the player can actually afford it (buy) or has the stock
## (sell), then applies it: money and the resource move between the
## player and the market IMMEDIATELY, but the PRICE itself only moves at
## the next round boundary (process_round_end()) - this round's
## accumulated volume just biases where it moves to.
## Returns {"success": bool, "reason": String} on failure (matching
## GameManager's action functions), or {"success": true, "amount",
## "total", "unit_price"} on success.
func attempt_trade(player_id: int, resource: HexData.ResourceType, direction: String, amount: float) -> Dictionary:
	if amount <= 0.0:
		return {"success": false, "reason": "invalid_amount"}
	if not MarketBalance.RESOURCE_PARAMS.has(resource):
		return {"success": false, "reason": "resource_not_tradeable"}
	if direction != DIRECTION_BUY and direction != DIRECTION_SELL:
		return {"success": false, "reason": "invalid_direction"}

	var player = GameManager.get_player(player_id)
	if player == null:
		return {"success": false, "reason": "invalid_player"}

	var limit = get_trade_limit(resource)
	var already = get_traded_this_round(player_id, resource, direction)
	if already + amount > limit:
		return {"success": false, "reason": "limit_exceeded", "limit": limit, "already_traded": already}

	var prices = get_trade_prices(resource)

	if direction == DIRECTION_BUY:
		var cost = prices["buy_price"] * amount
		if player.money < cost:
			return {"success": false, "reason": "cannot_afford", "cost": cost}
		player.add_money(-cost)
		player.add_resource(resource, amount)
		_q_buy_this_round[resource] = _q_buy_this_round.get(resource, 0.0) + amount
		_record_trade(player_id, resource, direction, amount)
		return {"success": true, "amount": amount, "total": cost, "unit_price": prices["buy_price"]}

	# direction == DIRECTION_SELL
	if player.get_resource_amount(resource) < amount:
		return {"success": false, "reason": "insufficient_stock"}
	var proceeds = prices["sell_price"] * amount
	player.add_resource(resource, -amount)
	player.add_money(proceeds)
	_q_sell_this_round[resource] = _q_sell_this_round.get(resource, 0.0) + amount
	_record_trade(player_id, resource, direction, amount)
	return {"success": true, "amount": amount, "total": proceeds, "unit_price": prices["sell_price"]}


func _record_trade(player_id: int, resource: HexData.ResourceType, direction: String, amount: float) -> void:
	if not _player_trade_log.has(player_id):
		_player_trade_log[player_id] = {}
	if not _player_trade_log[player_id].has(resource):
		_player_trade_log[player_id][resource] = {}
	var per_resource: Dictionary = _player_trade_log[player_id][resource]
	per_resource[direction] = per_resource.get(direction, 0.0) + amount


## Resolves one round for every resource - called from TurnManager.end_round(),
## after all of this round's trades have already happened via
## attempt_trade() above. Resets the accumulated volume/per-player limits
## for the next round.
func process_round_end() -> void:
	for resource in MarketBalance.RESOURCE_PARAMS:
		_update_price(resource, _q_buy_this_round.get(resource, 0.0), _q_sell_this_round.get(resource, 0.0))
		_q_buy_this_round[resource] = 0.0
		_q_sell_this_round[resource] = 0.0
	_player_trade_log.clear()


## The core formula (doc sections 3.1-3.4) - one resource, one round.
func _update_price(resource: HexData.ResourceType, q_buy: float, q_sell: float) -> void:
	var params: Dictionary = MarketBalance.RESOURCE_PARAMS[resource]
	var p_eq: float = params["p_eq"]
	var v_r: float = params["v_r"]

	# Step 1: "other cities" background - an AR(1) random walk with memory,
	# so market mood persists across rounds instead of resetting every time.
	var eta_s = MarketBalance.PHI * float(_eta_s.get(resource, 0.0)) + randfn(0.0, MarketBalance.SIGMA_B)
	var eta_d = MarketBalance.PHI * float(_eta_d.get(resource, 0.0)) + randfn(0.0, MarketBalance.SIGMA_B)
	_eta_s[resource] = eta_s
	_eta_d[resource] = eta_d
	var b_supply = v_r * maxf(0.1, 1.0 + eta_s)
	var b_demand = v_r * maxf(0.1, 1.0 + eta_d)

	# Step 2: total pressure (players + background), normalized to [-1, 1]
	# so the same formula works whether the market is tiny or huge.
	var demand = q_buy + b_demand
	var supply = q_sell + b_supply
	var rho = (demand - supply) / (demand + supply)

	# Step 3: momentum - average log-return over the last 3 rounds.
	var trend = _recent_trend(resource)

	# Step 4: new price - mean-reversion speed weakens the further the
	# price has already drifted from equilibrium, so large moves take
	# longer to fully unwind than small, everyday wobbles (doc sections
	# 3.4 and 6.6).
	var history: Array = price_history[resource]
	var p_t: float = history[-1]
	var deviation = absf(log(p_t / p_eq))
	var lambda_eff = MarketBalance.LAMBDA / (1.0 + MarketBalance.GAMMA * deviation)

	var log_next = (
		log(p_t)
		+ lambda_eff * (log(p_eq) - log(p_t))
		+ params["k"] * rho
		+ MarketBalance.MU * trend
		+ randfn(0.0, MarketBalance.SIGMA)
	)

	# Logarithmic math throughout means the price can never go negative,
	# and every term above is a PERCENTAGE change, not a flat amount - a 5%
	# move means the same thing for a resource priced at 5 as at 500.
	var p_next = clampf(exp(log_next), 0.2 * p_eq, 5.0 * p_eq)
	history.append(p_next)


## Average log-return over the last 3 rounds (or fewer, right at the start
## of the game, per doc section 3.3) - the "trend" term in _update_price().
func _recent_trend(resource: HexData.ResourceType) -> float:
	var history: Array = price_history[resource]
	var window = mini(3, history.size() - 1)
	if window <= 0:
		return 0.0
	var total = 0.0
	for i in range(window):
		var newer: float = history[history.size() - 1 - i]
		var older: float = history[history.size() - 2 - i]
		total += log(newer) - log(older)
	return total / window


## Forces an immediate, large price jump for `resource` - the "Market Crash"
## random event (autoloads/random_event_manager.gd), the only caller.
## Appends a NEW price point (rather than mutating the last one), so it
## shows as a visible jump on the market page's chart, exactly like a
## normal round-end price move - clamped to the same [0.2, 5.0] x p_eq
## bounds _update_price() itself uses, so a crash can never send a price to
## an absurd or non-positive value.
func trigger_price_shock(resource: HexData.ResourceType, multiplier: float) -> void:
	if not MarketBalance.RESOURCE_PARAMS.has(resource):
		return
	var p_eq: float = MarketBalance.RESOURCE_PARAMS[resource]["p_eq"]
	var history: Array = price_history[resource]
	var new_price = clampf(history[-1] * multiplier, 0.2 * p_eq, 5.0 * p_eq)
	history.append(new_price)
