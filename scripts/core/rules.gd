class_name Rules
extends RefCounted
## The rules engine. UI and AI both talk to the game exclusively through:
##   - Rules.setup()          create a match
##   - Rules.legal_actions()  enumerate what the current player may do
##   - Rules.apply()          validate + execute one action, returning UI events
##
## Actions are Dictionaries:
##   { "type": "mulligan", "redraw": bool }
##   { "type": "summon", "hand_index": int, "cell": Vector2i }
##   { "type": "move", "from": Vector2i, "to": Vector2i }
##   { "type": "attack", "from": Vector2i, "to": Vector2i }   (to = monster or master cell)
##   { "type": "cast", "hand_index": int, "target": Vector2i? }
##   { "type": "evolve", "cell": Vector2i }
##   { "type": "master_move", "col": int }
##   { "type": "master_power", "target": Vector2i? }
##   { "type": "end_turn" }


# --- Setup -------------------------------------------------------------

static func validate_deck(card_index: Dictionary, deck: Array) -> String:
	if deck.size() != GameConst.DECK_SIZE:
		return "Le deck doit contenir %d cartes (actuel : %d)." % [GameConst.DECK_SIZE, deck.size()]
	var counts := {}
	for id in deck:
		var def: CardDef = card_index.get(StringName(id))
		if def == null:
			return "Carte inconnue : %s" % id
		if def.token:
			return "Les formes évoluées ne sont pas constructibles : %s" % id
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > GameConst.MAX_COPIES:
			return "Maximum %d exemplaires de %s" % [GameConst.MAX_COPIES, def.display_name]
	return ""


## masters: [MasterDef, MasterDef] — decks: [Array of card ids, Array of card ids]
static func setup(card_index: Dictionary, masters: Array, decks: Array, seed_value: int) -> GameState:
	var state := GameState.new()
	state.card_index = card_index
	state.rng.seed = seed_value
	for i in 2:
		var typed: Array[StringName] = []
		for id in decks[i]:
			typed.append(StringName(id))
		var p := PlayerState.create(masters[i], typed)
		state.players.append(p)
		shuffle(state, p.deck)
	var events: Array = []
	for i in 2:
		Effects.draw_cards(state, i, GameConst.START_HAND, false, events)
	state.phase = GameState.Phase.MULLIGAN
	state.current = 0
	return state


## Deterministic Fisher-Yates using the match RNG.
static func shuffle(state: GameState, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := state.rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- Action application ------------------------------------------------

static func apply(state: GameState, action: Dictionary) -> Dictionary:
	var events: Array = []
	var error := _apply(state, action, events)
	return { "ok": error == "", "error": error, "events": events }


static func _apply(state: GameState, action: Dictionary, events: Array) -> String:
	if state.phase == GameState.Phase.OVER:
		return "La partie est terminée."
	var type := String(action.get("type", ""))
	if state.phase == GameState.Phase.MULLIGAN:
		if type != "mulligan":
			return "Phase de mulligan : action '%s' impossible." % type
		return _apply_mulligan(state, action, events)
	match type:
		"summon":
			return _apply_summon(state, action, events)
		"move":
			return _apply_move(state, action, events)
		"attack":
			return _apply_attack(state, action, events)
		"cast":
			return _apply_cast(state, action, events)
		"evolve":
			return _apply_evolve(state, action, events)
		"master_move":
			return _apply_master_move(state, action, events)
		"master_power":
			return _apply_master_power(state, action, events)
		"end_turn":
			return _apply_end_turn(state, events)
		_:
			return "Action inconnue : '%s'" % type


static func _apply_mulligan(state: GameState, action: Dictionary, events: Array) -> String:
	var p := state.me()
	if p.mulligan_done:
		return "Mulligan déjà effectué."
	var redraw := bool(action.get("redraw", false))
	if redraw:
		for id in p.hand:
			p.deck.append(id)
		p.hand.clear()
		shuffle(state, p.deck)
		Effects.draw_cards(state, state.current, GameConst.START_HAND, false, events)
	p.mulligan_done = true
	events.append({ "e": "mulligan", "player": state.current, "redraw": redraw })
	if not state.players[1].mulligan_done:
		state.current = 1
	else:
		state.current = 0
		state.phase = GameState.Phase.MAIN
		_start_turn(state, events)
	return ""


static func _start_turn(state: GameState, events: Array) -> void:
	var p := state.me()
	events.append({ "e": "turn_start", "player": state.current, "turn": state.turn })
	Combat.gain_stones(state, state.current, GameConst.STONES_PER_TURN, events)
	p.power_used = false
	p.master_moved = false
	for cell in state.board.monster_cells_of(state.current):
		var m := state.board.at(cell)
		m.acted = false
		var regen := m.keyword_value(GameConst.KW_REGEN)
		if regen > 0 and m.hp < m.max_hp():
			var healed: int = mini(m.hp + regen, m.max_hp()) - m.hp
			m.hp += healed
			events.append({ "e": "heal", "cell": cell, "amount": healed, "hp": m.hp })
	# The very first player skips their first draw.
	if state.turn > 1:
		Effects.draw_cards(state, state.current, 1, true, events)


static func _apply_summon(state: GameState, action: Dictionary, events: Array) -> String:
	var p := state.me()
	var idx := int(action.get("hand_index", -1))
	if idx < 0 or idx >= p.hand.size():
		return "Index de main invalide."
	var def := state.card(p.hand[idx])
	if def == null or not def.is_monster():
		return "Cette carte n'est pas un monstre."
	if def.cost > p.stones:
		return "Pas assez de pierres (%d requis)." % def.cost
	var cell: Vector2i = action.get("cell", Vector2i(-1, -1))
	if not state.board.summon_cells(state.current, p.master_col).has(cell):
		return "Case d'invocation invalide."
	_spend(state, state.current, def.cost, events)
	p.hand.remove_at(idx)
	var m := MonsterInst.create(def, state.current, state.turn)
	if p.has_passive(GameConst.PASSIVE_SUMMON_HP_PLUS):
		m.max_hp_bonus += 1
		m.hp = m.max_hp()
	state.board.place(cell, m)
	events.append({ "e": "summon", "player": state.current, "cell": cell, "card_id": def.id })
	if not def.on_summon.is_empty():
		Effects.apply_ops(state, state.current, def.on_summon, cell, false, events)
	return ""


static func _apply_move(state: GameState, action: Dictionary, events: Array) -> String:
	var from: Vector2i = action.get("from", Vector2i(-1, -1))
	var to: Vector2i = action.get("to", Vector2i(-1, -1))
	var m := state.board.at(from)
	var err := _check_can_act(state, m)
	if err != "":
		return err
	if not legal_move_cells(state, from).has(to):
		return "Déplacement invalide."
	state.board.move(from, to)
	m.acted = true
	events.append({ "e": "move", "from": from, "to": to })
	return ""


static func _apply_attack(state: GameState, action: Dictionary, events: Array) -> String:
	var from: Vector2i = action.get("from", Vector2i(-1, -1))
	var to: Vector2i = action.get("to", Vector2i(-1, -1))
	var attacker := state.board.at(from)
	var err := _check_can_act(state, attacker)
	if err != "":
		return err
	if not legal_attack_targets(state, from).has(to):
		return "Cible d'attaque invalide."
	attacker.acted = true
	var foe := 1 - state.current
	var is_master_target := state.board.at(to) == null
	events.append({ "e": "attack", "from": from, "to": to, "master": is_master_target })
	if is_master_target:
		Combat.damage_master(state, foe, attacker.atk(), attacker.def.attack_type, events)
		return ""
	var defender := state.board.at(to)
	var pierce := attacker.def.attack_type == GameConst.AttackType.MAGIC
	var res := Combat.apply_damage(state, to, attacker.atk(), pierce, state.current, events)
	if int(res.dealt) > 0:
		_grant_xp(attacker, from, 2 if bool(res.died) else 1, events)
	if not bool(res.died) and attacker.def.attack_type == GameConst.AttackType.MELEE:
		var rip := defender.keyword_value(GameConst.KW_RIPOSTE)
		if rip > 0:
			events.append({ "e": "riposte", "from": to, "to": from, "amount": rip })
			Combat.apply_damage(state, from, rip, true, defender.owner_idx, events)
	# on_attack hook: fire if attacker survived the riposte.
	if state.board.at(from) != null and not attacker.def.on_attack.is_empty():
		Effects.apply_ops(state, state.current, attacker.def.on_attack, null, false, events)
	return ""


static func _apply_cast(state: GameState, action: Dictionary, events: Array) -> String:
	var p := state.me()
	var idx := int(action.get("hand_index", -1))
	if idx < 0 or idx >= p.hand.size():
		return "Index de main invalide."
	var def := state.card(p.hand[idx])
	if def == null or not def.is_spell():
		return "Cette carte n'est pas un sort."
	if def.cost > p.stones:
		return "Pas assez de pierres (%d requis)." % def.cost
	var target = action.get("target")
	var err := _check_target(state, def.target_kind(), target)
	if err != "":
		return err
	_spend(state, state.current, def.cost, events)
	p.hand.remove_at(idx)
	p.discard.append(def.id)
	events.append({ "e": "cast", "player": state.current, "card_id": def.id, "target": target })
	Effects.apply_ops(state, state.current, def.effect, target, true, events)
	return ""


static func _apply_evolve(state: GameState, action: Dictionary, events: Array) -> String:
	var cell: Vector2i = action.get("cell", Vector2i(-1, -1))
	var m := state.board.at(cell)
	if m == null or m.owner_idx != state.current:
		return "Aucun monstre allié sur cette case."
	if not m.can_evolve():
		return "Ce monstre ne peut pas évoluer."
	var evo := state.card(m.def.evolves_to)
	if evo == null:
		return "Forme évoluée introuvable : %s" % m.def.evolves_to
	if m.def.evolve_cost > state.me().stones:
		return "Pas assez de pierres (%d requis)." % m.def.evolve_cost
	_spend(state, state.current, m.def.evolve_cost, events)
	var from_id := m.def.id
	m.def = evo
	m.level = 1
	m.xp = 0
	m.atk_bonus = 0
	m.max_hp_bonus = 0
	m.shield = evo.has_keyword(GameConst.KW_SHIELD)
	m.hp = m.max_hp()
	events.append({ "e": "evolve", "cell": cell, "from_id": from_id, "to_id": evo.id })
	return ""


static func _apply_master_move(state: GameState, action: Dictionary, events: Array) -> String:
	var p := state.me()
	if p.master_moved:
		return "Le Maître s'est déjà déplacé ce tour."
	var col := int(action.get("col", -1))
	if not legal_master_cols(state).has(col):
		return "Déplacement de Maître invalide."
	p.master_col = col
	p.master_moved = true
	events.append({ "e": "master_move", "player": state.current, "col": col })
	return ""


static func _apply_master_power(state: GameState, action: Dictionary, events: Array) -> String:
	var p := state.me()
	if p.power_used:
		return "Pouvoir déjà utilisé ce tour."
	if p.master.power_cost > p.stones:
		return "Pas assez de pierres (%d requis)." % p.master.power_cost
	var target = action.get("target")
	var err := _check_target(state, p.master.power_target_kind(), target)
	if err != "":
		return err
	_spend(state, state.current, p.master.power_cost, events)
	p.power_used = true
	events.append({ "e": "power", "player": state.current, "target": target })
	Effects.apply_ops(state, state.current, p.master.power_effect, target, false, events)
	return ""


static func _apply_end_turn(state: GameState, events: Array) -> String:
	events.append({ "e": "end_turn", "player": state.current })
	state.current = 1 - state.current
	state.turn += 1
	if state.turn > GameConst.TURN_LIMIT:
		var hp0 := state.players[0].master_hp
		var hp1 := state.players[1].master_hp
		if hp0 == hp1:
			state.phase = GameState.Phase.OVER
			state.winner = -2
			events.append({ "e": "win", "player": -2, "reason": "turn_limit_draw" })
		else:
			Combat.end_game(state, 0 if hp0 > hp1 else 1, "turn_limit", events)
		return ""
	_start_turn(state, events)
	return ""


# --- Shared validation helpers -----------------------------------------

static func _spend(state: GameState, player_idx: int, amount: int, events: Array) -> void:
	var p := state.players[player_idx]
	p.stones -= amount
	events.append({ "e": "spend", "player": player_idx, "amount": amount, "total": p.stones })


static func _grant_xp(m: MonsterInst, cell: Vector2i, amount: int, events: Array) -> void:
	var gained := m.gain_xp(amount)
	events.append({ "e": "xp", "cell": cell, "amount": amount, "level": m.level,
			"leveled": gained > 0 })


static func _check_can_act(state: GameState, m: MonsterInst) -> String:
	if m == null or m.owner_idx != state.current:
		return "Aucun monstre allié sur cette case."
	if m.acted:
		return "Ce monstre a déjà agi ce tour."
	if m.summoned_on_turn == state.turn and not m.has_keyword(GameConst.KW_HASTE):
		return "Mal d'invocation : ce monstre agira au prochain tour."
	return ""


static func _check_target(state: GameState, kind: String, target) -> String:
	if kind == "":
		return ""
	if not (target is Vector2i):
		return "Cette action requiert une cible."
	var m := state.board.at(target)
	if m == null:
		return "Aucun monstre sur la case ciblée."
	match kind:
		"ally_monster":
			if m.owner_idx != state.current:
				return "La cible doit être un monstre allié."
		"enemy_monster":
			if m.owner_idx == state.current:
				return "La cible doit être un monstre ennemi."
		"any_monster":
			pass
	return ""


# --- Legality queries (shared by UI highlighting and AI enumeration) ----

static func legal_move_cells(state: GameState, from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var m := state.board.at(from)
	if m == null:
		return result
	var p := state.players[m.owner_idx]
	var master := Board.master_cell(m.owner_idx, p.master_col)
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var to := from + delta
		if not Board.in_bounds(to):
			continue
		if Board.row_owner(to.y) != m.owner_idx:
			continue
		if to == master or state.board.at(to) != null:
			continue
		result.append(to)
	return result


static func legal_attack_targets(state: GameState, from: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attacker := state.board.at(from)
	if attacker == null:
		return result
	var me_idx := attacker.owner_idx
	var foe := 1 - me_idx
	var foe_p := state.players[foe]
	match attacker.def.attack_type:
		GameConst.AttackType.MELEE:
			if state.board.melee_blocked(me_idx, from) \
					and not attacker.has_keyword(GameConst.KW_FLYING):
				return result
			var found := false
			for cell in state.board.defender_column_cells(foe, from.x):
				var d := state.board.at(cell)
				if d != null and not d.has_keyword(GameConst.KW_FLYING):
					result.append(cell)
					found = true
					break
			if not found and foe_p.master_col == from.x \
					and from.y == Board.front_row(me_idx):
				result.append(Board.master_cell(foe, foe_p.master_col))
		GameConst.AttackType.RANGED, GameConst.AttackType.MAGIC:
			result.append_array(state.board.monster_cells_of(foe))
			if state.board.column_cover(foe, foe_p.master_col, false) == 0:
				result.append(Board.master_cell(foe, foe_p.master_col))
	return result


static func legal_master_cols(state: GameState) -> Array[int]:
	var result: Array[int] = []
	var p := state.me()
	for dc: int in [-1, 1]:
		var col := p.master_col + dc
		if col < 0 or col >= GameConst.BOARD_COLS:
			continue
		if state.board.at(Vector2i(col, Board.back_row(state.current))) != null:
			continue
		result.append(col)
	return result


## All legal actions for the current player (used by the AI, and by tests).
static func legal_actions(state: GameState) -> Array[Dictionary]:
	var acts: Array[Dictionary] = []
	if state.phase == GameState.Phase.OVER:
		return acts
	if state.phase == GameState.Phase.MULLIGAN:
		acts.append({ "type": "mulligan", "redraw": false })
		acts.append({ "type": "mulligan", "redraw": true })
		return acts
	var p := state.me()
	acts.append({ "type": "end_turn" })
	for i in p.hand.size():
		var def := state.card(p.hand[i])
		if def == null or def.cost > p.stones:
			continue
		if def.is_monster():
			for cell in state.board.summon_cells(state.current, p.master_col):
				acts.append({ "type": "summon", "hand_index": i, "cell": cell })
		else:
			var tk := def.target_kind()
			if tk == "":
				acts.append({ "type": "cast", "hand_index": i })
			else:
				for cell in _target_cells(state, tk):
					acts.append({ "type": "cast", "hand_index": i, "target": cell })
	for cell in state.board.monster_cells_of(state.current):
		var m := state.board.at(cell)
		if _check_can_act(state, m) == "":
			for to in legal_move_cells(state, cell):
				acts.append({ "type": "move", "from": cell, "to": to })
			for to in legal_attack_targets(state, cell):
				acts.append({ "type": "attack", "from": cell, "to": to })
		if m.can_evolve() and p.stones >= m.def.evolve_cost \
				and state.card(m.def.evolves_to) != null:
			acts.append({ "type": "evolve", "cell": cell })
	if not p.master_moved:
		for col in legal_master_cols(state):
			acts.append({ "type": "master_move", "col": col })
	if not p.power_used and p.stones >= p.master.power_cost:
		var tk := p.master.power_target_kind()
		if tk == "":
			acts.append({ "type": "master_power" })
		else:
			for cell in _target_cells(state, tk):
				acts.append({ "type": "master_power", "target": cell })
	return acts


static func _target_cells(state: GameState, kind: String) -> Array[Vector2i]:
	match kind:
		"ally_monster":
			return state.board.monster_cells_of(state.current)
		"enemy_monster":
			return state.board.monster_cells_of(1 - state.current)
		"any_monster":
			var all := state.board.monster_cells_of(state.current)
			all.append_array(state.board.monster_cells_of(1 - state.current))
			return all
	var empty: Array[Vector2i] = []
	return empty
