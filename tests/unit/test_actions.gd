extends TestCase
## Summon, move, master move, evolve, end turn, spells, master powers.


func test_summon_rules() -> void:
	var state := TestUtil.fresh_game()  # 5 stones, hand = 5 grunts (cost 1)
	var stones: int = state.me().stones
	applied(Rules.apply(state, { "type": "summon", "hand_index": 0, "cell": Vector2i(0, 0) }),
			"invocation valide")
	eq(state.me().stones, stones - 1, "coût payé")
	eq(state.me().hand.size(), 4, "carte retirée de la main")
	ne(state.board.at(Vector2i(0, 0)), null, "monstre posé")
	# summoning sickness: cannot move nor attack this turn
	rejected(Rules.apply(state, { "type": "move", "from": Vector2i(0, 0), "to": Vector2i(0, 1) }),
			"mal d'invocation : déplacement")
	# illegal cells
	rejected(Rules.apply(state, { "type": "summon", "hand_index": 0, "cell": Vector2i(1, 0) }),
			"case du maître")
	rejected(Rules.apply(state, { "type": "summon", "hand_index": 0, "cell": Vector2i(0, 0) }),
			"case occupée")
	rejected(Rules.apply(state, { "type": "summon", "hand_index": 0, "cell": Vector2i(0, 2) }),
			"côté ennemi")
	state.me().stones = 0
	rejected(Rules.apply(state, { "type": "summon", "hand_index": 0, "cell": Vector2i(2, 0) }),
			"pas assez de pierres")


func test_haste_acts_on_summon_turn() -> void:
	var state := TestUtil.fresh_game(1, null, null, "hasty")
	applied(Rules.apply(state, { "type": "summon", "hand_index": 0, "cell": Vector2i(0, 0) }),
			"invocation hasty")
	applied(Rules.apply(state, { "type": "move", "from": Vector2i(0, 0), "to": Vector2i(0, 1) }),
			"célérité : agit immédiatement")


func test_move_rules() -> void:
	var state := TestUtil.fresh_game()
	var m := TestUtil.put(state, Vector2i(2, 0), "grunt", 0)
	rejected(Rules.apply(state, { "type": "move", "from": Vector2i(2, 0), "to": Vector2i(1, 0) }),
			"case du maître interdite")
	rejected(Rules.apply(state, { "type": "move", "from": Vector2i(2, 0), "to": Vector2i(1, 1) }),
			"diagonale interdite")
	applied(Rules.apply(state, { "type": "move", "from": Vector2i(2, 0), "to": Vector2i(2, 1) }),
			"déplacement orthogonal")
	eq(m.acted, true, "action consommée")
	rejected(Rules.apply(state, { "type": "move", "from": Vector2i(2, 1), "to": Vector2i(2, 0) }),
			"une action par tour")
	# own side only
	var m2 := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	rejected(Rules.apply(state, { "type": "move", "from": Vector2i(0, 1), "to": Vector2i(0, 2) }),
			"pas de déplacement côté ennemi")
	ok(m2.acted == false, "action non consommée sur refus")


func test_master_move() -> void:
	var state := TestUtil.fresh_game()
	eq(Rules.legal_master_cols(state), [0, 2], "colonnes adjacentes libres")
	TestUtil.put(state, Vector2i(0, 0), "grunt", 0)
	eq(Rules.legal_master_cols(state), [2], "colonne occupée exclue")
	applied(Rules.apply(state, { "type": "master_move", "col": 2 }), "déplacement maître")
	eq(state.me().master_col, 2, "colonne mise à jour")
	rejected(Rules.apply(state, { "type": "master_move", "col": 1 }),
			"un déplacement de maître par tour")


func test_evolve() -> void:
	var state := TestUtil.fresh_game()
	var m := TestUtil.put(state, Vector2i(0, 0), "grunt", 0)
	rejected(Rules.apply(state, { "type": "evolve", "cell": Vector2i(0, 0) }),
			"pas au niveau max")
	m.gain_xp(5)
	eq(m.level, 3, "niveau max atteint")
	state.me().stones = 1
	rejected(Rules.apply(state, { "type": "evolve", "cell": Vector2i(0, 0) }),
			"coût d'évolution non payé")
	state.me().stones = 5
	var res := Rules.apply(state, { "type": "evolve", "cell": Vector2i(0, 0) })
	applied(res, "évolution")
	eq(m.def.id, &"grunt_evo", "forme évoluée")
	eq(m.level, 1, "niveau 1 de la nouvelle forme")
	eq(m.hp, 8, "PV max de la nouvelle forme")
	eq(state.me().stones, 3, "coût d'évolution payé")
	ok(has_event(res.events, "evolve"), "événement evolve")


func test_end_turn_flow() -> void:
	var state := TestUtil.fresh_game()
	var healer := TestUtil.put(state, Vector2i(0, 2), "healer", 1)  # regen 1, hp 4
	healer.hp = 2
	var mine := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	Rules.apply(state, { "type": "move", "from": Vector2i(0, 1), "to": Vector2i(1, 1) })
	eq(mine.acted, true, "a agi")
	applied(Rules.apply(state, { "type": "end_turn" }), "fin de tour")
	eq(state.current, 1, "au joueur 1")
	eq(state.turn, 2, "tour 2")
	eq(state.me().stones, GameConst.START_STONES + GameConst.STONES_PER_TURN, "pierres j1")
	eq(state.me().hand.size(), GameConst.START_HAND + 1, "j1 pioche à son 1er tour")
	eq(healer.hp, 3, "régénération au début du tour")
	applied(Rules.apply(state, { "type": "end_turn" }), "fin de tour j1")
	eq(mine.acted, false, "action réinitialisée")


func test_deck_out_loss() -> void:
	var state := TestUtil.fresh_game()
	state.players[1].deck.clear()
	var res := Rules.apply(state, { "type": "end_turn" })
	ok(has_event(res.events, "deck_out"), "événement deck_out")
	eq(state.winner, 0, "j1 perd par deck vide")


func test_hand_limit_skips_draw() -> void:
	var state := TestUtil.fresh_game()
	var p1 := state.players[1]
	while p1.hand.size() < GameConst.HAND_LIMIT:
		p1.hand.append(&"grunt")
	var deck_size := p1.deck.size()
	Rules.apply(state, { "type": "end_turn" })
	eq(p1.hand.size(), GameConst.HAND_LIMIT, "main pleine : pas de pioche")
	eq(p1.deck.size(), deck_size, "deck intact")


func test_stone_cap() -> void:
	var state := TestUtil.fresh_game()
	state.players[1].stones = GameConst.MAX_STONES - 1
	Rules.apply(state, { "type": "end_turn" })
	eq(state.players[1].stones, GameConst.MAX_STONES, "plafond de pierres")


func _hand(state: GameState, cards: Array) -> void:
	state.me().hand.clear()
	for id in cards:
		state.me().hand.append(StringName(id))


func test_spell_bolt_targeting() -> void:
	var state := TestUtil.fresh_game()
	_hand(state, ["bolt"])
	var foe := TestUtil.put(state, Vector2i(0, 2), "grunt", 1)
	var mine := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	rejected(Rules.apply(state, { "type": "cast", "hand_index": 0 }), "cible requise")
	rejected(Rules.apply(state, { "type": "cast", "hand_index": 0, "target": Vector2i(0, 1) }),
			"cible alliée refusée pour enemy_monster")
	applied(Rules.apply(state, { "type": "cast", "hand_index": 0, "target": Vector2i(0, 2) }),
			"bolt sur ennemi")
	eq(foe.hp, 1, "2 dégâts de sort")
	eq(mine.hp, 3, "allié intact")
	eq(state.me().discard, [&"bolt"] as Array[StringName], "sort défaussé")


func test_kiran_spell_damage_passive() -> void:
	var kiran := TestUtil.master("kiran", &"spell_damage_plus")
	var state := TestUtil.fresh_game(1, kiran, null)
	_hand(state, ["bolt"])
	TestUtil.put(state, Vector2i(0, 2), "grunt", 1)  # 3 hp
	var before: int = state.me().stones
	var res := Rules.apply(state, { "type": "cast", "hand_index": 0, "target": Vector2i(0, 2) })
	applied(res, "bolt kiran")
	ok(state.board.at(Vector2i(0, 2)) == null, "3 dégâts avec le passif : kill")
	eq(state.me().stones, before - 1 + 1, "récompense de kill par sort")


func test_spell_heal_buff_gem_tap_nova() -> void:
	var state := TestUtil.fresh_game()
	_hand(state, ["mend", "grow", "gem", "tap", "nova"])
	TestUtil.fill_stones(state, 10)
	var mine := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	mine.hp = 1
	applied(Rules.apply(state, { "type": "cast", "hand_index": 0, "target": Vector2i(0, 1) }),
			"mend")
	eq(mine.hp, 3, "soin plafonné aux PV max")
	applied(Rules.apply(state, { "type": "cast", "hand_index": 0, "target": Vector2i(0, 1) }),
			"grow")
	eq(mine.atk(), 3, "buff ATK")
	eq(mine.max_hp(), 5, "buff PV max")
	eq(mine.hp, 5, "buff soigne du montant de PV ajouté")
	var stones: int = state.me().stones
	applied(Rules.apply(state, { "type": "cast", "hand_index": 0 }), "gem")
	eq(state.me().stones, stones - 1 + 2, "gem : +2 pierres net -1 coût")
	var hand_size: int = state.me().hand.size()
	applied(Rules.apply(state, { "type": "cast", "hand_index": 0 }), "tap")
	eq(state.me().hand.size(), hand_size - 1 + 1, "tap : défausse le sort, pioche 1")
	TestUtil.put(state, Vector2i(1, 2), "hasty", 1)
	TestUtil.put(state, Vector2i(2, 2), "hasty", 1)
	var res := Rules.apply(state, { "type": "cast", "hand_index": 0 })
	applied(res, "nova")
	ok(state.board.at(Vector2i(1, 2)) == null and state.board.at(Vector2i(2, 2)) == null,
			"nova tue les deux 1/1")
	eq(mine.hp, 5, "nova épargne les alliés")


func test_master_power_sacrifice_draw() -> void:
	var grim := TestUtil.master("grim", &"", 1,
			[{ "op": "sacrifice", "target": "ally_monster" }, { "op": "draw", "count": 2 }])
	var state := TestUtil.fresh_game(1, grim, null)
	TestUtil.put(state, Vector2i(0, 0), "grunt", 0)
	var hand_size: int = state.me().hand.size()
	var foe_stones: int = state.players[1].stones
	var res := Rules.apply(state, { "type": "master_power", "target": Vector2i(0, 0) })
	applied(res, "pacte")
	ok(state.board.at(Vector2i(0, 0)) == null, "allié sacrifié")
	eq(state.me().hand.size(), hand_size + 2, "pioche 2")
	eq(state.players[1].stones, foe_stones, "sacrifice : aucune récompense adverse")
	rejected(Rules.apply(state, { "type": "master_power", "target": Vector2i(0, 0) }),
			"pouvoir une fois par tour")


func test_master_power_shield_and_cost() -> void:
	var aria := TestUtil.master("aria", &"", 2, [{ "op": "shield", "target": "ally_monster" }])
	var state := TestUtil.fresh_game(1, aria, null)
	var m := TestUtil.put(state, Vector2i(0, 0), "grunt", 0)
	state.me().stones = 1
	rejected(Rules.apply(state, { "type": "master_power", "target": Vector2i(0, 0) }),
			"coût du pouvoir")
	state.me().stones = 2
	applied(Rules.apply(state, { "type": "master_power", "target": Vector2i(0, 0) }), "égide")
	eq(m.shield, true, "bouclier accordé")
	eq(state.me().stones, 0, "coût payé")


func test_legal_actions_sanity() -> void:
	var state := TestUtil.fresh_game()
	var acts := Rules.legal_actions(state)
	var has_end := false
	var summons_idx0 := 0
	for a in acts:
		if a.type == "end_turn":
			has_end = true
		if a.type == "summon" and a.hand_index == 0:
			summons_idx0 += 1
	ok(has_end, "end_turn toujours présent")
	eq(summons_idx0, 5, "5 cases d'invocation (6 moins la case du maître)")
	# every enumerated action must apply cleanly on a copy of the state
	var state2 := TestUtil.fresh_game(99)
	for a in Rules.legal_actions(state2):
		if a.type == "end_turn":
			continue
		var probe := TestUtil.fresh_game(99)
		var res := Rules.apply(probe, a)
		ok(res.ok, "action énumérée applicable : %s (%s)" % [a, res.error])
