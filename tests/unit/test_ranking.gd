extends TestCase
## Glicko-2 ranking maths, checked against Glickman's worked example and sanity.


func test_glickman_reference_example() -> void:
	# Player (1500, 200, 0.06), tau=0.5, vs three opponents → published results.
	var player := { "rating": 1500.0, "rd": 200.0, "vol": 0.06 }
	var results := [
		{ "rating": 1400.0, "rd": 30.0, "score": 1.0 },
		{ "rating": 1550.0, "rd": 100.0, "score": 0.0 },
		{ "rating": 1700.0, "rd": 300.0, "score": 0.0 },
	]
	var out := Ranking.update(player, results)
	ok(absf(float(out.rating) - 1464.06) < 0.2, "rating ~1464.06 (obtenu %.2f)" % out.rating)
	ok(absf(float(out.rd) - 151.52) < 0.2, "RD ~151.52 (obtenu %.2f)" % out.rd)
	ok(absf(float(out.vol) - 0.05999) < 0.0005, "vol ~0.05999 (obtenu %.5f)" % out.vol)


func test_win_raises_loss_lowers() -> void:
	var base := Ranking.new_rating()
	var won := Ranking.update(base, [{ "rating": 1500.0, "rd": 350.0, "score": 1.0 }])
	var lost := Ranking.update(base, [{ "rating": 1500.0, "rd": 350.0, "score": 0.0 }])
	ok(float(won.rating) > 1500.0, "gagner monte le rating")
	ok(float(lost.rating) < 1500.0, "perdre baisse le rating")


func test_playing_shrinks_rd() -> void:
	var base := Ranking.new_rating()
	var after := Ranking.update(base, [{ "rating": 1500.0, "rd": 60.0, "score": 1.0 }])
	ok(float(after.rd) < float(base.rd), "jouer réduit l'incertitude (RD)")


func test_backend_report_result() -> void:
	var b := MetaBackend.new()
	ok(float(b.report_result(1.0, { "rating": 1500.0, "rd": 350.0 }).rating) > 1500.0,
			"une victoire ranked fait monter le rating")
	ok(float(b.report_result(0.0, { "rating": 1500.0, "rd": 350.0 }).rating) < 1500.0,
			"une défaite ranked fait baisser le rating")


func test_idle_period_grows_rd() -> void:
	var base := { "rating": 1600.0, "rd": 80.0, "vol": 0.06 }
	var after := Ranking.update(base, [])
	ok(float(after.rd) > float(base.rd), "l'inactivité augmente le RD")
	eq(int(round(float(after.rating))), 1600, "sans partie, le rating ne bouge pas")
