class_name TestUtil
extends RefCounted
## Factories building in-memory card/master defs and ready-to-play states,
## so unit tests do not depend on the real card data in resources/.


static func monster(id: String, cost: int, levels: Array, opts: Dictionary = {}) -> CardDef:
	var c := CardDef.new()
	c.id = StringName(id)
	c.display_name = id
	c.kind = GameConst.CardKind.MONSTER
	c.cost = cost
	c.attack_type = opts.get("attack_type", GameConst.AttackType.MELEE)
	var typed: Array[Dictionary] = []
	for lv in levels:
		typed.append(lv)
	c.levels = typed
	c.keywords = opts.get("keywords", {})
	c.evolves_to = StringName(opts.get("evolves_to", ""))
	c.evolve_cost = opts.get("evolve_cost", 0)
	c.token = opts.get("token", false)
	return c


static func spell(id: String, cost: int, effect: Array) -> CardDef:
	var c := CardDef.new()
	c.id = StringName(id)
	c.display_name = id
	c.kind = GameConst.CardKind.SPELL
	c.cost = cost
	var typed: Array[Dictionary] = []
	for op in effect:
		typed.append(op)
	c.effect = typed
	return c


static func master(id: String, passive: StringName = &"", power_cost: int = 2,
		power_effect: Array = []) -> MasterDef:
	var m := MasterDef.new()
	m.id = StringName(id)
	m.display_name = id
	m.passive_id = passive
	m.power_cost = power_cost
	var typed: Array[Dictionary] = []
	for op in power_effect:
		typed.append(op)
	m.power_effect = typed
	return m


## Standard test card set.
static func std_index() -> Dictionary:
	var cards := [
		monster("grunt", 1, [
			{ "xp": 0, "atk": 2, "hp": 3 },
			{ "xp": 2, "atk": 3, "hp": 4 },
			{ "xp": 5, "atk": 4, "hp": 6 },
		], { "evolves_to": "grunt_evo", "evolve_cost": 2 }),
		monster("grunt_evo", 0, [{ "xp": 0, "atk": 5, "hp": 8 }], { "token": true }),
		monster("archer", 2, [{ "xp": 0, "atk": 2, "hp": 2 }],
				{ "attack_type": GameConst.AttackType.RANGED }),
		monster("mage", 2, [{ "xp": 0, "atk": 2, "hp": 2 }],
				{ "attack_type": GameConst.AttackType.MAGIC }),
		monster("tank", 2, [{ "xp": 0, "atk": 1, "hp": 5 }], { "keywords": { "armor": 1 } }),
		monster("shieldy", 1, [{ "xp": 0, "atk": 1, "hp": 2 }], { "keywords": { "shield": true } }),
		monster("flyer", 2, [{ "xp": 0, "atk": 2, "hp": 2 }], { "keywords": { "flying": true } }),
		monster("spiky", 1, [{ "xp": 0, "atk": 1, "hp": 4 }], { "keywords": { "riposte": 1 } }),
		monster("healer", 1, [{ "xp": 0, "atk": 1, "hp": 4 }], { "keywords": { "regen": 1 } }),
		monster("hasty", 1, [{ "xp": 0, "atk": 1, "hp": 1 }], { "keywords": { "haste": true } }),
		spell("bolt", 1, [{ "op": "damage", "amount": 2, "target": "enemy_monster" }]),
		spell("nova", 3, [{ "op": "damage_all_enemies", "amount": 1 }]),
		spell("mend", 1, [{ "op": "heal", "amount": 3, "target": "ally_monster" }]),
		spell("grow", 2, [{ "op": "buff", "atk": 1, "hp": 2, "target": "ally_monster" }]),
		spell("gem", 1, [{ "op": "stones", "amount": 2 }]),
		spell("tap", 1, [{ "op": "draw", "count": 1 }]),
	]
	var index := {}
	for c in cards:
		index[c.id] = c
	return index


## A started game (mulligans kept) with 20x `deck_card` decks and plain masters.
static func fresh_game(seed_value: int = 1, master0: MasterDef = null,
		master1: MasterDef = null, deck_card: String = "grunt") -> GameState:
	var index := std_index()
	var m0 := master0 if master0 != null else master("m0")
	var m1 := master1 if master1 != null else master("m1")
	var deck: Array[StringName] = []
	for i in GameConst.DECK_SIZE:
		deck.append(StringName(deck_card))
	var state := Rules.setup(index, [m0, m1], [deck, deck], seed_value)
	Rules.apply(state, { "type": "mulligan", "redraw": false })
	Rules.apply(state, { "type": "mulligan", "redraw": false })
	return state


## Force-places a monster on the board (bypasses summoning rules and sickness).
static func put(state: GameState, cell: Vector2i, card_id: String, owner_idx: int) -> MonsterInst:
	var def: CardDef = state.card_index[StringName(card_id)]
	var m := MonsterInst.create(def, owner_idx, -99)
	state.board.place(cell, m)
	return m


## Gives the current player enough stones for expensive test actions.
static func fill_stones(state: GameState, amount: int = GameConst.MAX_STONES) -> void:
	state.me().stones = amount
