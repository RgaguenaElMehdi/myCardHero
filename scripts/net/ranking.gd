class_name Ranking
## Glicko-2 rating system (Glickman 2013). Pure math — used by the ranked backend
## to update MMR after a match. A rating is { rating, rd, vol }.
##
## Reference worked example from the paper is covered by test_ranking.gd.

const SCALE := 173.7178      # maps Glicko ratings to the internal Glicko-2 scale
const TAU := 0.5             # volatility constant (smaller = less swingy)
const EPSILON := 0.000001


static func new_rating() -> Dictionary:
	return { "rating": 1500.0, "rd": 350.0, "vol": 0.06 }


## Update `player` ({rating,rd,vol}) against a batch of results.
## results: Array of { rating, rd, score } where score is 1 (win) / 0.5 / 0 (loss).
static func update(player: Dictionary, results: Array) -> Dictionary:
	var mu := (float(player.rating) - 1500.0) / SCALE
	var phi := float(player.rd) / SCALE
	var sigma := float(player.vol)

	if results.is_empty():
		# No games this period: only the deviation grows toward the baseline.
		return _external(mu, sqrt(phi * phi + sigma * sigma), sigma)

	var v_inv := 0.0
	var delta_sum := 0.0
	for r in results:
		var mj := (float(r.rating) - 1500.0) / SCALE
		var phij := float(r.rd) / SCALE
		var g := _g(phij)
		var e := _e(mu, mj, phij)
		v_inv += g * g * e * (1.0 - e)
		delta_sum += g * (float(r.score) - e)
	var v := 1.0 / v_inv
	var delta := v * delta_sum

	var sigma_new := _new_volatility(sigma, phi, v, delta)
	var phi_star := sqrt(phi * phi + sigma_new * sigma_new)
	var phi_new := 1.0 / sqrt(1.0 / (phi_star * phi_star) + v_inv)
	var mu_new := mu + phi_new * phi_new * delta_sum
	return _external(mu_new, phi_new, sigma_new)


## Illinois-algorithm root find for the new volatility (Glicko-2 step 5).
static func _new_volatility(sigma: float, phi: float, v: float, delta: float) -> float:
	var a := log(sigma * sigma)
	var d2 := delta * delta
	var p2 := phi * phi

	var f := func(x: float) -> float:
		var ex := exp(x)
		var num := ex * (d2 - p2 - v - ex)
		var den := 2.0 * pow(p2 + v + ex, 2.0)
		return (num / den) - ((x - a) / (TAU * TAU))

	var big_a := a
	var big_b := 0.0
	if d2 > p2 + v:
		big_b = log(d2 - p2 - v)
	else:
		var k := 1
		while f.call(a - k * TAU) < 0.0:
			k += 1
		big_b = a - k * TAU

	var f_a: float = f.call(big_a)
	var f_b: float = f.call(big_b)
	var guard := 0
	while absf(big_b - big_a) > EPSILON and guard < 100:
		guard += 1
		var c := big_a + (big_a - big_b) * f_a / (f_b - f_a)
		var f_c: float = f.call(c)
		if f_c * f_b <= 0.0:
			big_a = big_b
			f_a = f_b
		else:
			f_a = f_a / 2.0
		big_b = c
		f_b = f_c
	return exp(big_a / 2.0)


static func _external(mu: float, phi: float, sigma: float) -> Dictionary:
	return { "rating": mu * SCALE + 1500.0, "rd": phi * SCALE, "vol": sigma }


static func _g(phi: float) -> float:
	return 1.0 / sqrt(1.0 + 3.0 * phi * phi / (PI * PI))


static func _e(mu: float, mj: float, phij: float) -> float:
	return 1.0 / (1.0 + exp(-_g(phij) * (mu - mj)))
