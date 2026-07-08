extends TestCase
## Tests mécaniques des triggers on_summon / on_death / on_attack.


## Injecte une CardDef personnalisée dans le card_index et dans la main du joueur actif.
func _inject(state: GameState, def: CardDef) -> void:
	state.card_index[def.id] = def
	state.me().hand.push_front(def.id)


func test_on_summon_gains_stones() -> void:
	var state := TestUtil.fresh_game()
	var def := TestUtil.monster("s_test", 1, [{ "xp": 0, "atk": 1, "hp": 2 }])
	def.on_summon = [{ "op": "stones", "amount": 2 }]
	_inject(state, def)
	state.me().stones = 3
	var before := state.me().stones
	var res := Rules.apply(state,
			{ "type": "summon", "hand_index": 0, "cell": Vector2i(0, 1) })
	applied(res, "invocation")
	# Coût = 1 pierre dépensée, on_summon = +2 pierres.
	eq(state.players[0].stones, before - 1 + 2, "on_summon : bilan pierres correct")


func test_on_summon_draws() -> void:
	var state := TestUtil.fresh_game()
	var def := TestUtil.monster("sd_test", 1, [{ "xp": 0, "atk": 1, "hp": 2 }])
	def.on_summon = [{ "op": "draw", "count": 1 }]
	_inject(state, def)
	state.me().stones = 3
	var hand_before := state.me().hand.size()
	var res := Rules.apply(state,
			{ "type": "summon", "hand_index": 0, "cell": Vector2i(0, 1) })
	applied(res, "invocation")
	# La carte invoquée quitte la main (-1) et on_summon pioche 1 (+1) → net 0.
	eq(state.me().hand.size(), hand_before - 1 + 1, "on_summon draw : taille de main correcte")


func test_on_death_owner_draws() -> void:
	var state := TestUtil.fresh_game()
	var def := TestUtil.monster("d_test", 1, [{ "xp": 0, "atk": 1, "hp": 1 }])
	def.on_death = [{ "op": "draw", "count": 1 }]
	state.card_index[def.id] = def
	# Pose le monstre sur le plateau comme monstre du joueur 1.
	var m := MonsterInst.create(def, 1, -99)
	state.board.place(Vector2i(1, 2), m)
	# Le joueur 0 attaque avec un grunt (ATQ 2 > PV 1 → mort).
	TestUtil.put(state, Vector2i(1, 1), "grunt", 0)
	var hand_before: int = state.players[1].hand.size()
	Rules.apply(state,
			{ "type": "attack", "from": Vector2i(1, 1), "to": Vector2i(1, 2) })
	eq(state.players[1].hand.size(), hand_before + 1,
			"on_death : le propriétaire pioche 1 carte")


func test_on_death_stones_to_owner() -> void:
	var state := TestUtil.fresh_game()
	var def := TestUtil.monster("ds_test", 1, [{ "xp": 0, "atk": 1, "hp": 1 }])
	def.on_death = [{ "op": "stones", "amount": 1 }]
	state.card_index[def.id] = def
	var m := MonsterInst.create(def, 1, -99)
	state.board.place(Vector2i(0, 2), m)
	TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	var before: int = state.players[1].stones
	Rules.apply(state,
			{ "type": "attack", "from": Vector2i(0, 1), "to": Vector2i(0, 2) })
	eq(state.players[1].stones, before + 1,
			"on_death : +1 pierre au propriétaire")


func test_on_attack_gains_stones() -> void:
	var state := TestUtil.fresh_game()
	var def := TestUtil.monster("a_test", 1, [{ "xp": 0, "atk": 1, "hp": 3 }])
	def.on_attack = [{ "op": "stones", "amount": 1 }]
	state.card_index[def.id] = def
	TestUtil.put(state, Vector2i(0, 1), "a_test", 0)
	TestUtil.put(state, Vector2i(0, 2), "grunt", 1)
	var before := state.me().stones
	var res := Rules.apply(state,
			{ "type": "attack", "from": Vector2i(0, 1), "to": Vector2i(0, 2) })
	applied(res, "attaque")
	eq(state.me().stones, before + 1, "on_attack : +1 pierre à l'attaquant")


func test_on_attack_not_fired_if_attacker_dies() -> void:
	## Un attaquant tué par riposte ne déclenche pas son on_attack.
	var state := TestUtil.fresh_game()
	var def := TestUtil.monster("ar_test", 1, [{ "xp": 0, "atk": 1, "hp": 1 }])
	def.on_attack = [{ "op": "stones", "amount": 3 }]
	state.card_index[def.id] = def
	# Ennemi avec riposte 5 (tue l'attaquant)
	var rip_def := TestUtil.monster("riposte5", 3,
			[{ "xp": 0, "atk": 1, "hp": 5 }], { "keywords": { "riposte": 5 } })
	state.card_index[rip_def.id] = rip_def
	TestUtil.put(state, Vector2i(2, 1), "ar_test", 0)
	TestUtil.put(state, Vector2i(2, 2), "riposte5", 1)
	var before := state.me().stones
	Rules.apply(state, { "type": "attack", "from": Vector2i(2, 1), "to": Vector2i(2, 2) })
	eq(state.me().stones, before, "on_attack non déclenché si l'attaquant meurt en riposte")
