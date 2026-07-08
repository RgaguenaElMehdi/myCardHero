class_name Combat
extends RefCounted
## Shared damage / death resolution, used by Rules (attacks) and Effects (spells).
## All functions append UI events to `events` and enforce win conditions.


## Applies damage to the monster in `cell`.
## pierce=true (magic / spell damage) ignores Armor and Shield.
## source_owner: player index credited for a kill (-1 = nobody, e.g. sacrifice).
## Returns { "dealt": int, "died": bool }.
static func apply_damage(state: GameState, cell: Vector2i, raw: int, pierce: bool,
		source_owner: int, events: Array) -> Dictionary:
	var m := state.board.at(cell)
	assert(m != null)
	if not pierce and m.shield:
		m.shield = false
		events.append({ "e": "shield_break", "cell": cell })
		return { "dealt": 0, "died": false }
	var dealt := raw
	if not pierce:
		dealt = maxi(0, dealt - m.keyword_value(GameConst.KW_ARMOR))
	dealt = maxi(0, dealt)
	m.hp -= dealt
	events.append({ "e": "damage", "cell": cell, "amount": dealt, "hp": maxi(m.hp, 0) })
	if m.hp <= 0:
		destroy(state, cell, source_owner, true, events)
		return { "dealt": dealt, "died": true }
	return { "dealt": dealt, "died": false }


## Removes the monster in `cell` from the board (into its owner's discard).
## If grant_reward and killer is its enemy, the killer earns stones = victim level
## (+1 with the Grim passive).
static func destroy(state: GameState, cell: Vector2i, killer: int, grant_reward: bool,
		events: Array) -> void:
	var m := state.board.remove(cell)
	if m == null:
		return
	state.players[m.owner_idx].discard.append(m.def.id)
	events.append({ "e": "death", "cell": cell, "card_id": m.def.id, "owner": m.owner_idx })
	if not m.def.on_death.is_empty():
		Effects.apply_ops(state, m.owner_idx, m.def.on_death, null, false, events)
	if grant_reward and killer >= 0 and killer != m.owner_idx:
		var reward := m.level
		if state.players[killer].has_passive(GameConst.PASSIVE_KILL_BONUS_STONE):
			reward += 1
		events.append({ "e": "kill_reward", "player": killer, "amount": reward })
		gain_stones(state, killer, reward, events)


## Damages a master. attack_type matters for the Aria passive (-1 from ranged).
static func damage_master(state: GameState, player_idx: int, raw: int,
		attack_type: int, events: Array) -> void:
	var p := state.players[player_idx]
	var dealt := raw
	if attack_type == GameConst.AttackType.RANGED and p.has_passive(GameConst.PASSIVE_RANGED_RESIST):
		dealt -= 1
	dealt = maxi(0, dealt)
	p.master_hp -= dealt
	events.append({ "e": "master_damage", "player": player_idx, "amount": dealt,
			"hp": maxi(p.master_hp, 0) })
	if p.master_hp <= 0:
		end_game(state, 1 - player_idx, "master_down", events)


static func gain_stones(state: GameState, player_idx: int, amount: int, events: Array) -> void:
	var p := state.players[player_idx]
	var before := p.stones
	p.stones = clampi(p.stones + amount, 0, GameConst.MAX_STONES)
	if p.stones != before:
		events.append({ "e": "stones", "player": player_idx,
				"amount": p.stones - before, "total": p.stones })


static func end_game(state: GameState, winner_idx: int, reason: String, events: Array) -> void:
	if state.phase == GameState.Phase.OVER:
		return
	state.phase = GameState.Phase.OVER
	state.winner = winner_idx
	events.append({ "e": "win", "player": winner_idx, "reason": reason })
