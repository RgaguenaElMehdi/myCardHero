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
