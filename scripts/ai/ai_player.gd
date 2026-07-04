class_name AiPlayer
extends RefCounted
## Heuristic opponent. Scores every legal action and picks one according to
## its level; the battle loop calls choose_action() repeatedly and applies the
## result until it returns end_turn. Turn termination is guaranteed because
## every non-end action consumes a finite resource (monster action, card,
## stones, once-per-turn flags).

enum Level { NOVICE, ADEPT, MASTER }

var level: int = Level.ADEPT
var rng := RandomNumberGenerator.new()


func _init(p_level: int = Level.ADEPT, seed_value: int = 0) -> void:
	level = p_level
	rng.seed = seed_value if seed_value != 0 else randi()


func choose_action(state: GameState) -> Dictionary:
	if state.phase == GameState.Phase.MULLIGAN:
		return { "type": "mulligan", "redraw": _wants_mulligan(state) }
	var actions := Rules.legal_actions(state)
	var best := { "type": "end_turn" }
	var best_score := 0.0
	for a in actions:
		if a.type == "end_turn":
			continue
		var score := _score(state, a)
		# Novices misjudge a lot, adepts a little, masters barely.
		match level:
			Level.NOVICE:
				score += rng.randf_range(-3.0, 3.0)
				if a.type == "evolve" or a.type == "master_power":
					if rng.randf() < 0.5:
						continue  # forgets its advanced options half the time
			Level.ADEPT:
				score += rng.randf_range(-1.0, 1.0)
			Level.MASTER:
				score += rng.randf_range(-0.2, 0.2)
		if score > best_score:
			best_score = score
			best = a
	return best


## Redraw when the hand has fewer than two playable early monsters.
func _wants_mulligan(state: GameState) -> bool:
	var early := 0
	for id in state.me().hand:
		var def := state.card(id)
		if def != null and def.is_monster() and def.cost <= 2:
			early += 1
	return early < 2


# --- Scoring ------------------------------------------------------------

func _score(state: GameState, a: Dictionary) -> float:
	match String(a.type):
		"attack":
			return _score_attack(state, a)
		"summon":
			return _score_summon(state, a)
		"cast":
			return _score_cast(state, a)
		"evolve":
			return 8.0 + 2.0 * _monster_value(state.board.at(a.cell))
		"move":
			return _score_move(state, a)
		"master_move":
			return _score_master_move(state, a)
		"master_power":
			return _score_power(state, a)
	return 0.0


func _monster_value(m: MonsterInst) -> float:
	if m == null:
		return 0.0
	return m.def.cost * 0.8 + m.atk() + m.hp * 0.5 + m.level * 1.5


func _expected_damage(attacker: MonsterInst, defender: MonsterInst) -> int:
	if attacker.def.attack_type == GameConst.AttackType.MAGIC:
		return attacker.atk()
	if defender.shield:
		return 0
	return maxi(0, attacker.atk() - defender.keyword_value(GameConst.KW_ARMOR))


func _score_attack(state: GameState, a: Dictionary) -> float:
	var attacker := state.board.at(a.from)
	var defender := state.board.at(a.to)
	if defender == null:
		# Master hit: huge if lethal, always strong tempo otherwise.
		var dmg := attacker.atk()
		var foe := state.players[1 - attacker.owner_idx]
		if foe.has_passive(&"ranged_resist") \
				and attacker.def.attack_type == GameConst.AttackType.RANGED:
			dmg = maxi(0, dmg - 1)
		if dmg >= foe.master_hp:
			return 1000.0
		return 12.0 + dmg * 3.0
	var dmg := _expected_damage(attacker, defender)
	if dmg <= 0:
		return 1.0  # still breaks a shield
	var score := dmg * 1.5
	if dmg >= defender.hp:
		score += 6.0 + _monster_value(defender) + defender.level  # kill + stone reward
	if attacker.def.attack_type == GameConst.AttackType.MELEE:
		var rip := defender.keyword_value(GameConst.KW_RIPOSTE)
		if rip >= attacker.hp and dmg < defender.hp:
			score -= 8.0  # suicide into riposte
		else:
			score -= rip * 0.8
	if not attacker.at_max_level() and attacker.xp + (2 if dmg >= defender.hp else 1) \
			>= attacker.next_level_xp():
		score += 3.0  # level-up (full heal) incoming
	return score


func _score_summon(state: GameState, a: Dictionary) -> float:
	var def := state.card(state.me().hand[a.hand_index])
	var cell: Vector2i = a.cell
	var me := state.current
	var front := cell.y == Board.front_row(me)
	var score := 4.0 + def.cost * 0.8
	# Melee wants the front line, shooters want the back line.
	if def.attack_type == GameConst.AttackType.MELEE:
		score += 1.5 if front else -1.0
	else:
		score += 1.5 if not front else -1.0
	# Cover the master's column when it is exposed.
	var p := state.me()
	if cell.x == p.master_col and state.board.column_cover(me, p.master_col, false) == 0:
		score += 5.0
	# Threaten the enemy master's column.
	if cell.x == state.players[1 - me].master_col:
		score += 1.0
	# Don't dump the whole hand when the board is already strong.
	if state.board.monsters_of(me).size() >= 4:
		score -= 3.0
	return score


func _score_cast(state: GameState, a: Dictionary) -> float:
	var def := state.card(state.me().hand[a.hand_index])
	return _score_ops(state, def.effect, a.get("target"),
			state.me().has_passive(&"spell_damage_plus"))


func _score_power(state: GameState, a: Dictionary) -> float:
	# Hold the power early, use it when it matters (stones less scarce).
	var base := _score_ops(state, state.me().master.power_effect, a.get("target"), false)
	return base - 2.0 if state.me().stones < 5 else base


func _score_ops(state: GameState, ops: Array, target, spell_bonus: bool) -> float:
	var score := 0.0
	var tm: MonsterInst = state.board.at(target) if target is Vector2i else null
	for op in ops:
		match String(op.get("op", "")):
			"damage":
				if tm != null:
					var amount := int(op.get("amount", 0)) + (1 if spell_bonus else 0)
					score += mini(amount, tm.hp) * 1.2
					if amount >= tm.hp:
						score += 5.0 + _monster_value(tm)
			"damage_all_enemies":
				var amount := int(op.get("amount", 0)) + (1 if spell_bonus else 0)
				for c in state.board.monster_cells_of(1 - state.current):
					var m := state.board.at(c)
					score += mini(amount, m.hp) * 1.2
					if amount >= m.hp and not m.shield:
						score += 3.0 + _monster_value(m) * 0.5
			"heal":
				if tm != null:
					score += mini(int(op.get("amount", 0)), tm.max_hp() - tm.hp) * 1.2
			"heal_master":
				score += mini(int(op.get("amount", 0)),
						state.me().master.hp - state.me().master_hp) * 1.0
			"buff":
				if tm != null and not tm.acted:
					score += 3.0 + tm.level
			"shield":
				if tm != null and not tm.shield:
					score += 2.0 + _monster_value(tm) * 0.4
			"draw":
				score += (3.0 if state.me().hand.size() <= 3 else 1.0) * int(op.get("count", 0))
			"stones":
				score += 1.5 * int(op.get("amount", 0))
			"sacrifice":
				if tm != null:
					score -= _monster_value(tm) * 0.8
					if tm.hp <= 2:
						score += 3.0  # it was going to die anyway
	return score


func _score_move(state: GameState, a: Dictionary) -> float:
	var m := state.board.at(a.from)
	var score := 0.0
	var had_targets := not Rules.legal_attack_targets(state, a.from).is_empty()
	# Cheap lookahead: would this cell open up targets next turn?
	state.board.move(a.from, a.to)
	var gains_targets := not Rules.legal_attack_targets(state, a.to).is_empty()
	var covers_master := a.to.x == state.me().master_col \
			and state.board.column_cover(state.current, state.me().master_col, false) == 1
	state.board.move(a.to, a.from)
	if not had_targets and gains_targets:
		score += 4.0
	if covers_master and a.from.x != state.me().master_col:
		score += 5.0
	# Pull a wounded blocker back home.
	if m.hp <= 2 and a.to.y == Board.back_row(state.current):
		score += 1.5
	return score


func _score_master_move(state: GameState, a: Dictionary) -> float:
	var p := state.me()
	var danger_now := _master_column_danger(state, p.master_col)
	var danger_then := _master_column_danger(state, int(a.col))
	return (danger_now - danger_then) * 6.0


## Rough threat level of having the master in `col`: exposed + enemies able to hit it.
func _master_column_danger(state: GameState, col: int) -> float:
	var me := state.current
	var foe := 1 - me
	var danger := 0.0
	if state.board.column_cover(me, col, false) == 0:
		danger += 0.5
		for c in state.board.monster_cells_of(foe):
			var m := state.board.at(c)
			if m.def.attack_type != GameConst.AttackType.MELEE:
				danger += m.atk() * 0.5
	if state.board.column_cover(me, col, true) == 0:
		for c in state.board.monster_cells_of(foe):
			var m := state.board.at(c)
			if m.def.attack_type == GameConst.AttackType.MELEE and c.x == col:
				danger += m.atk() * 0.7
	return danger
