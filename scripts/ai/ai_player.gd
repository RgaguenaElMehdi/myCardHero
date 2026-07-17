class_name AiPlayer
extends RefCounted
## Heuristic opponent. Scores every legal action and picks one according to
## its level; the battle loop calls choose_action() repeatedly and applies the
## result until it returns end_turn. Turn termination is guaranteed because
## every non-end action consumes a finite resource (monster action, card,
## stones, once-per-turn flags).
##
## Les trois niveaux sont trois personnalités (spec
## docs/superpowers/specs/2026-07-17-ai-levels-redesign-design.md) :
## - NOVICE : valeur immédiate seule, ignore la défense du maître et les
##   menaces adverses, gros bruit, oublie souvent évolution / pouvoir. Fonce.
## - ADEPT  : heuristiques complètes (couverture, riposte, tempo), bruit modéré.
## - MASTER : anticipation réelle à 1 coup — chaque action légale est jouée via
##   Rules.apply sur un clone de l'état, la position résultante est notée par
##   _evaluate (PV maîtres, matériel ajusté au danger, menaces, position, tempo).
##   Mesuré (tools/ai_arena.gd, 40 duels miroirs) : ~78 % vs Novice et Adepte.

enum Level { NOVICE, ADEPT, MASTER }

const NOISE := { Level.NOVICE: 3.0, Level.ADEPT: 1.0, Level.MASTER: 0.1 }

var level: int = Level.ADEPT
var rng := RandomNumberGenerator.new()


func _init(p_level: int = Level.ADEPT, seed_value: int = 0) -> void:
	level = p_level
	rng.seed = seed_value if seed_value != 0 else randi()


func choose_action(state: GameState) -> Dictionary:
	if state.phase == GameState.Phase.MULLIGAN:
		# Le novice garde n'importe quelle main ; les autres réfléchissent.
		var redraw := false if level == Level.NOVICE else _wants_mulligan(state)
		return { "type": "mulligan", "redraw": redraw }
	if level == Level.MASTER:
		return _choose_master(state)
	var actions := Rules.legal_actions(state)
	var best := { "type": "end_turn" }
	var best_score := 0.0
	for a in actions:
		if a.type == "end_turn":
			continue
		if level == Level.NOVICE:
			# Oublie ses options avancées la moitié du temps, et ne pense
			# jamais à déplacer son maître.
			if a.type == "master_move":
				continue
			if (a.type == "evolve" or a.type == "master_power") and rng.randf() < 0.5:
				continue
		var score := _score(state, a)
		score += rng.randf_range(-NOISE[level], NOISE[level])
		if score > best_score:
			best_score = score
			best = a
	return best


## Niveau Maître : anticipation réelle à 1 coup. Chaque action légale est jouée
## avec les VRAIES règles sur un clone de l'état (kills, XP, récompenses, morts,
## effets — rien d'estimé), puis la position résultante est notée par
## _evaluate(). On garde la meilleure ; end_turn sert de référence.
func _choose_master(state: GameState) -> Dictionary:
	var master_index := {}
	for p in state.players:
		master_index[p.master.id] = p.master
	var snapshot := state.to_dict()
	var best := { "type": "end_turn" }
	var best_eval := -INF
	for a in Rules.legal_actions(state):
		var sim := GameState.from_dict(snapshot, state.card_index, master_index)
		var res: Dictionary = Rules.apply(sim, a)
		if not res.ok:
			continue
		var e := _evaluate(sim, state.current)
		if a.type == "end_turn":
			e -= 0.01  # à valeur égale, préférer agir
		e += rng.randf_range(-NOISE[level], NOISE[level])
		if e > best_eval:
			best_eval = e
			best = a
	return best


## Note une position pour le joueur `me` : différentiel de PV des maîtres,
## matériel, menaces réciproques sur les maîtres, position et tempo.
func _evaluate(state: GameState, me: int) -> float:
	if state.phase == GameState.Phase.OVER:
		return 10000.0 if state.winner == me else -10000.0
	var foe := 1 - me
	var e := (state.players[me].master_hp - state.players[foe].master_hp) * 3.0
	for cell in state.board.monster_cells_of(me):
		var m := state.board.at(cell)
		# Matériel ajusté au danger : un monstre tuable au prochain tour adverse
		# ne vaut que la moitié — le glouton apprend ainsi à ne pas nourrir
		# l'ennemi et à préférer les échanges où les siens survivent.
		var w := 1.0 if _doomed(state, cell, foe) else 2.0
		e += _monster_value(m) * w + m.xp * 0.3
		# Position : une mêlée ne menace que SA colonne ; un tireur veut l'arrière.
		if m.def.attack_type == GameConst.AttackType.MELEE:
			var lane_live := cell.x == state.players[foe].master_col
			for c in state.board.defender_column_cells(foe, cell.x):
				if state.board.at(c) != null:
					lane_live = true
			if lane_live:
				e += 1.2
			if cell.y == Board.front_row(me):
				e += 0.6
		elif cell.y == Board.back_row(me):
			e += 0.6
	for cell in state.board.monster_cells_of(foe):
		var m := state.board.at(cell)
		var w := 1.0 if _doomed(state, cell, me) else 2.0
		e -= _monster_value(m) * w
	var threat := _incoming_master_damage(state, me)
	e -= threat * 1.2
	if threat >= state.players[me].master_hp:
		e -= 300.0  # exposé à un létal : à éviter à tout prix (sauf victoire)
	e += _incoming_master_damage(state, foe) * 0.8
	e += state.players[me].stones * 0.3 + state.players[me].hand.size() * 0.5
	return e


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
		if foe.has_passive(GameConst.PASSIVE_RANGED_RESIST) \
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
	if level >= Level.ADEPT and attacker.def.attack_type == GameConst.AttackType.MELEE:
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
	if level >= Level.ADEPT:
		# Cover the master's column when it is exposed (le novice n'y pense pas).
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
			state.me().has_passive(GameConst.PASSIVE_SPELL_DAMAGE_PLUS))


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
	var from: Vector2i = a.from
	var to: Vector2i = a.to
	var m := state.board.at(from)
	var score := 0.0
	var had_targets := not Rules.legal_attack_targets(state, from).is_empty()
	# Cheap lookahead: snapshot board, mutate, score, restore immediately.
	# No await between save and restore — safe against state corruption.
	var saved_cells := state.board.cells.duplicate()
	state.board.move(from, to)
	var gains_targets := not Rules.legal_attack_targets(state, to).is_empty()
	var covers_master: bool = to.x == state.me().master_col \
			and state.board.column_cover(state.current, state.me().master_col, false) == 1
	state.board.cells = saved_cells
	if not had_targets and gains_targets:
		score += 4.0
	if level >= Level.ADEPT:
		if covers_master and from.x != state.me().master_col:
			score += 5.0
		# Pull a wounded blocker back home.
		if m.hp <= 2 and to.y == Board.back_row(state.current):
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


## Le monstre en `cell` peut-il être tué par UN coup de `hunter` (un des
## monstres du joueur adverse) à son prochain tour ? Portée approximée :
## distance/magie touchent tout ; une mêlée touche le premier non-volant de
## SA colonne.
func _doomed(state: GameState, cell: Vector2i, hunter: int) -> bool:
	var prey := state.board.at(cell)
	if prey == null:
		return false
	for hcell in state.board.monster_cells_of(hunter):
		var h := state.board.at(hcell)
		if h.def.attack_type == GameConst.AttackType.MELEE:
			if hcell.x != cell.x or prey.has_keyword(GameConst.KW_FLYING):
				continue
			# La mêlée frappe le premier non-volant de la colonne : notre proie
			# doit être ce premier (rangée de front, ou arrière sans écran).
			var front := Vector2i(cell.x, Board.front_row(prey.owner_idx))
			if cell != front:
				var screen := state.board.at(front)
				if screen != null and not screen.has_keyword(GameConst.KW_FLYING):
					continue
		if _expected_damage(h, prey) >= prey.hp:
			return true
	return false


# --- Anticipation défensive (niveau Maître) ------------------------------

## Dégâts que le joueur `1 - me` peut infliger au maître de `me` dès son
## prochain tour, sur l'état courant du plateau.
func _incoming_master_damage(state: GameState, me: int) -> int:
	var my := state.players[me]
	var col := my.master_col
	var foe := 1 - me
	var dmg := 0
	var cover_ranged := state.board.column_cover(me, col, false)
	var cover_melee := state.board.column_cover(me, col, true)
	for cell in state.board.monster_cells_of(foe):
		var m := state.board.at(cell)
		match m.def.attack_type:
			GameConst.AttackType.RANGED:
				if cover_ranged == 0:
					var hit := m.atk()
					if my.has_passive(GameConst.PASSIVE_RANGED_RESIST):
						hit = maxi(0, hit - 1)
					dmg += hit
			GameConst.AttackType.MAGIC:
				if cover_ranged == 0:
					dmg += m.atk()
			GameConst.AttackType.MELEE:
				# Un corps-à-corps ne frappe le maître que depuis sa ligne de
				# front, dans la colonne du maître, colonne non couverte.
				if cell.x == col and cell.y == Board.front_row(foe) \
						and cover_melee == 0:
					dmg += m.atk()
	return dmg


