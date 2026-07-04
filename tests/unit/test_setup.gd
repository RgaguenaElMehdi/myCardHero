extends TestCase
## Deck validation, match setup, mulligan flow, determinism.


func _valid_deck() -> Array:
	var ids := ["grunt", "archer", "mage", "tank", "shieldy", "flyer", "spiky", "healer",
			"hasty", "bolt"]
	var deck := []
	for id in ids:
		deck.append(id)
		deck.append(id)
	return deck


func test_deck_validation() -> void:
	var index := TestUtil.std_index()
	eq(Rules.validate_deck(index, _valid_deck()), "", "deck valide")
	ne(Rules.validate_deck(index, []), "", "deck vide refusé")
	var too_many := _valid_deck()
	too_many[2] = "grunt"  # 3rd copy
	ne(Rules.validate_deck(index, too_many), "", "3 exemplaires refusés")
	var unknown := _valid_deck()
	unknown[0] = "nope"
	ne(Rules.validate_deck(index, unknown), "", "carte inconnue refusée")
	var token := _valid_deck()
	token[0] = "grunt_evo"
	ne(Rules.validate_deck(index, token), "", "token refusé")


func test_initial_state() -> void:
	var index := TestUtil.std_index()
	var deck: Array[StringName] = []
	for i in GameConst.DECK_SIZE:
		deck.append(&"grunt")
	var state := Rules.setup(index, [TestUtil.master("a"), TestUtil.master("b")], [deck, deck], 7)
	eq(state.phase, GameState.Phase.MULLIGAN, "phase initiale")
	for i in 2:
		eq(state.players[i].hand.size(), GameConst.START_HAND, "main de départ j%d" % i)
		eq(state.players[i].deck.size(), GameConst.DECK_SIZE - GameConst.START_HAND,
				"deck restant j%d" % i)
		eq(state.players[i].stones, GameConst.START_STONES, "pierres de départ j%d" % i)
		eq(state.players[i].master_hp, GameConst.MASTER_HP, "PV maître j%d" % i)


func test_mulligan_keep_flow() -> void:
	var state := TestUtil.fresh_game()
	eq(state.phase, GameState.Phase.MAIN, "phase MAIN après mulligans")
	eq(state.current, 0, "joueur 0 commence")
	eq(state.turn, 1, "tour 1")
	# start 3 + 2 turn gain
	eq(state.me().stones, GameConst.START_STONES + GameConst.STONES_PER_TURN, "pierres t1")
	# first player skips the first draw
	eq(state.me().hand.size(), GameConst.START_HAND, "pas de pioche j0 t1")


func test_mulligan_redraw() -> void:
	var index := TestUtil.std_index()
	var deck: Array[StringName] = []
	for i in GameConst.DECK_SIZE:
		deck.append(&"grunt")
	var state := Rules.setup(index, [TestUtil.master("a"), TestUtil.master("b")], [deck, deck], 7)
	var res := Rules.apply(state, { "type": "mulligan", "redraw": true })
	applied(res, "mulligan redraw")
	eq(state.players[0].hand.size(), GameConst.START_HAND, "main après redraw")
	eq(state.players[0].deck.size(), GameConst.DECK_SIZE - GameConst.START_HAND,
			"deck après redraw")
	# actions other than mulligan are rejected during the mulligan phase
	rejected(Rules.apply(state, { "type": "end_turn" }), "end_turn pendant mulligan")


func test_determinism() -> void:
	var a := TestUtil.fresh_game(42)
	var b := TestUtil.fresh_game(42)
	eq(a.players[0].deck, b.players[0].deck, "même seed, même deck j0")
	eq(a.players[1].deck, b.players[1].deck, "même seed, même deck j1")
