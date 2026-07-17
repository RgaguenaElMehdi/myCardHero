extends TestCase
## AI sanity: always legal, always terminates, takes obvious wins.


func test_ai_full_game_terminates_with_only_legal_actions() -> void:
	var state := TestUtil.fresh_game(2024)
	# fresh_game already resolved mulligans; play from MAIN phase.
	var ais := [AiPlayer.new(AiPlayer.Level.MASTER, 11), AiPlayer.new(AiPlayer.Level.ADEPT, 22)]
	var steps := 0
	while not state.is_over() and steps < 5000:
		var action: Dictionary = ais[state.current].choose_action(state)
		var res := Rules.apply(state, action)
		if not res.ok:
			failures.append("Action IA illégale au pas %d : %s (%s)" % [steps, action, res.error])
			return
		steps += 1
	ok(state.is_over(), "la partie se termine (pas %d)" % steps)
	ok(steps < 5000, "pas de boucle infinie")


func test_ai_full_game_with_real_data() -> void:
	var DbScript := load("res://scripts/autoload/db.gd")
	var data: Dictionary = DbScript.load_all()
	var deck0: Array = data.campaign.starter.deck
	var deck1: Array = data.campaign.chapters[3].opponent.deck
	var state := Rules.setup(data.cards,
			[data.masters[StringName("kiran")], data.masters[StringName("willow")]],
			[deck0, deck1], 777)
	var ais := [AiPlayer.new(AiPlayer.Level.ADEPT, 1), AiPlayer.new(AiPlayer.Level.MASTER, 2)]
	var steps := 0
	while not state.is_over() and steps < 5000:
		var action: Dictionary = ais[state.current].choose_action(state)
		var res := Rules.apply(state, action)
		if not res.ok:
			failures.append("Action IA illégale : %s (%s)" % [action, res.error])
			return
		steps += 1
	ok(state.is_over(), "partie réelle terminée en %d pas" % steps)


func test_ai_takes_lethal() -> void:
	var state := TestUtil.fresh_game()
	state.players[1].master_hp = 2
	TestUtil.put(state, Vector2i(1, 1), "grunt", 0)  # atk 2, enemy master col 1 exposed
	var ai := AiPlayer.new(AiPlayer.Level.MASTER, 5)
	var action := ai.choose_action(state)
	eq(action.get("type"), "attack", "l'IA attaque")
	eq(action.get("to"), Vector2i(1, 3), "l'IA prend le létal sur le maître")


func test_ai_mulligan_logic() -> void:
	var index := TestUtil.std_index()
	var expensive: Array[StringName] = []
	for i in GameConst.DECK_SIZE:
		expensive.append(&"mage")  # cost 2 — playable, no redraw expected
	var state := Rules.setup(index, [TestUtil.master("a"), TestUtil.master("b")],
			[expensive, expensive], 3)
	var ai := AiPlayer.new(AiPlayer.Level.MASTER, 5)
	var action := ai.choose_action(state)
	eq(action.get("type"), "mulligan", "phase mulligan respectée")
	eq(action.get("redraw"), false, "main jouable conservée")


## Miroir parfait (mêmes maîtres, mêmes decks, sièges alternés) : le niveau
## haut doit dominer le niveau bas. Retourne les victoires du niveau `level_hi`.
func _mirror_wins(level_hi: int, level_lo: int, games: int) -> int:
	var DbScript := load("res://scripts/autoload/db.gd")
	var data: Dictionary = DbScript.load_all()
	var deck: Array = data.campaign.chapters[3].opponent.deck
	var wins := 0
	for g in games:
		var hi_seat := g % 2  # alterner qui commence
		var state := Rules.setup(data.cards,
				[data.masters[&"kiran"], data.masters[&"kiran"]], [deck, deck], 9000 + g)
		var ais := [null, null]
		ais[hi_seat] = AiPlayer.new(level_hi, 300 + g)
		ais[1 - hi_seat] = AiPlayer.new(level_lo, 600 + g)
		var steps := 0
		while not state.is_over() and steps < 4000:
			steps += 1
			var res := Rules.apply(state, ais[state.current].choose_action(state))
			if not res.ok:
				failures.append("action illégale en duel miroir (partie %d) : %s" % [g, res.error])
				return -1
		if state.winner == hi_seat:
			wins += 1
	return wins


func test_ai_master_beats_novice() -> void:
	var games := 20
	var wins := _mirror_wins(AiPlayer.Level.MASTER, AiPlayer.Level.NOVICE, games)
	if wins < 0:
		return
	print("      [ia] Maître vs Novice : %d/%d" % [wins, games])
	ok(wins >= int(games * 0.7), "le Maître domine le Novice (%d/%d)" % [wins, games])


func test_ai_master_beats_adept() -> void:
	var games := 20
	var wins := _mirror_wins(AiPlayer.Level.MASTER, AiPlayer.Level.ADEPT, games)
	if wins < 0:
		return
	print("      [ia] Maître vs Adepte : %d/%d" % [wins, games])
	ok(wins >= int(ceil(games * 0.55)), "le Maître bat l'Adepte (%d/%d)" % [wins, games])


func test_ai_master_covers_exposed_master() -> void:
	# Maître à 3 PV, colonne du maître sans couverture, deux archers ennemis en
	# vue (2+2 = létal au prochain tour). Le Maître doit invoquer DANS la colonne
	# du maître pour faire écran, pas ailleurs.
	var state := TestUtil.fresh_game(7)
	state.players[0].master_hp = 3
	TestUtil.put(state, Vector2i(0, 2), "archer", 1)
	TestUtil.put(state, Vector2i(2, 2), "archer", 1)
	state.me().stones = 3
	var ai := AiPlayer.new(AiPlayer.Level.MASTER, 5)
	var action := ai.choose_action(state)
	eq(action.get("type"), "summon", "le Maître invoque pour se protéger")
	eq(action.get("cell"), Vector2i(1, 1), "l'invocation couvre la colonne du maître")
