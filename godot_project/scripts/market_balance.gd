class_name MarketBalance
extends RefCounted
## Market economy constants ("Model Ekonomii Rynku" - see the uploaded
## design doc for the full derivation/rationale). Tunable parameters for the
## per-resource price simulation in autoloads/market_manager.gd, kept here
## rather than in scripts/game_balance.gd since this is a large, self
## -contained block of numbers specific to one subsystem.

## Global model parameters - deliberately shared across all resources for
## now (the doc's own section 4: resource-to-resource variety is already
## achieved through P_EQ/K/V_R below, without needing separate values here
## too; easy to split later if playtesting shows otherwise).
const LAMBDA = 0.04  ## base mean-reversion speed (how fast price drifts back toward p_eq)
const GAMMA = 3.0  ## how much a large deviation slows that return - lambda_eff = LAMBDA / (1 + GAMMA * deviation)
const MU = 0.15  ## momentum/trend weight (a rising price is a bit more likely to keep rising)
const SIGMA = 0.02  ## pure random noise, std dev in log-price space
const SIGMA_B = 0.15  ## background "other cities" volatility
const PHI = 0.85  ## background "other cities" persistence (AR(1) - closer to 1 = longer mood swings)

## Per-round trade limit = round(V_R * CAP_FRACTION) - ties the limit to the
## same "market depth" figure the rest of the model already uses, instead of
## a second set of numbers that could drift out of sync with it.
const CAP_FRACTION = 0.25

## P_EQ (long-run equilibrium price), K (volatility - how much player
## buy/sell pressure moves the price), V_R (background "other cities"
## market size - bigger means harder for one player to move alone) - one
## entry per tradeable resource, straight from the doc's section 5 table.
## HexData.ResourceType.NONE is deliberately absent (not a real commodity).
const RESOURCE_PARAMS = {
	HexData.ResourceType.FOOD: {"p_eq": 5.0, "k": 0.05, "v_r": 150.0},
	HexData.ResourceType.WOOD: {"p_eq": 8.0, "k": 0.06, "v_r": 100.0},
	HexData.ResourceType.COAL: {"p_eq": 15.0, "k": 0.08, "v_r": 80.0},
	HexData.ResourceType.COPPER: {"p_eq": 40.0, "k": 0.10, "v_r": 50.0},
	HexData.ResourceType.GAS: {"p_eq": 35.0, "k": 0.10, "v_r": 50.0},
	HexData.ResourceType.NICKEL: {"p_eq": 60.0, "k": 0.15, "v_r": 25.0},
	## Ropa zastąpiła Uran (życzenie: "zamień Uran na ropę (zmień statystki
	## na rynku)") - inny profil niż uranu (rzadki, cienki, bardzo zmienny
	## rynek): ropa to głęboki, płynny rynek globalny, więc wyższe V_R (trudniej
	## jednemu graczowi ruszyć cenę) i niższe K (mniejsza wrażliwość na
	## pojedynczą transakcję) niż miał uran, ale wciąż drożej niż metale
	## przemysłowe (miedź/nikiel) - P_EQ w okolicach realnej ceny baryłki ropy.
	HexData.ResourceType.OIL: {"p_eq": 75.0, "k": 0.12, "v_r": 70.0},
}


## Max units of `resource` a single player may buy - and, separately, sell -
## in one round (doc section 5.1: the main defense against a patient player
## mean-reversion-arbitraging the market for guaranteed profit at unlimited
## scale).
static func trade_limit(resource: HexData.ResourceType) -> int:
	var params: Dictionary = RESOURCE_PARAMS.get(resource, {})
	if params.is_empty():
		return 0
	return roundi(params["v_r"] * CAP_FRACTION)


## Buy/sell spread as a fraction of the mid price (doc section 5.2) - wider
## for more volatile resources, exactly like real commodity markets (deep,
## liquid goods trade tight; thin, volatile ones trade wide).
static func spread(resource: HexData.ResourceType) -> float:
	var params: Dictionary = RESOURCE_PARAMS.get(resource, {})
	if params.is_empty():
		return 0.0
	return 0.02 + 0.7 * params["k"]
