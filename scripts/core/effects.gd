class_name Effects
extends RefCounted
## Data-driven effect ops shared by spell cards (CardDef.effect) and master
## powers (MasterDef.power_effect).
##
## Op vocabulary (all fields int unless noted):
##   { "op": "damage", "amount", "target": "enemy_monster"|"any_monster" }
##   { "op": "damage_all_enemies", "amount" }
##   { "op": "heal", "amount", "target": "ally_monster" }
##   { "op": "heal_master", "amount" }
##   { "op": "buff", "atk", "hp", "target": "ally_monster"|"enemy_monster"|"any_monster" }
##   { "op": "shield", "target": "ally_monster" }
##   { "op": "draw", "count" }
##   { "op": "stones", "amount" }
##   { "op": "sacrifice", "target": "ally_monster" }
## Effect damage is magic-like: it ignores Armor and Shield.
## Targeted ops all resolve on the single `target` cell of the action.


## Applies an op list. `target` is a Vector2i cell or null for untargeted effects.
## is_spell_card enables the Kiran passive (+1 to spell card damage).
static func apply_ops(state: GameState, caster: int, ops: Array, target,
		is_spell_card: bool, events: Array) -> void:
	for op in ops:
		if state.phase == GameState.Phase.OVER:
			return
		match String(op.get("op", "")):
			"damage":
				var amount: int = op.get("amount", 0)
				if is_spell_card and state.players[caster].has_passive(&"spell_damage_plus"):
					amount += 1
				if target != null and state.board.at(target) != null:
					Combat.apply_damage(state, target, amount, true, caster, events)
			"damage_all_enemies":
				var amount: int = op.get("amount", 0)
				if is_spell_card and state.players[caster].has_passive(&"spell_damage_plus"):
					amount += 1
				for cell in state.board.monster_cells_of(1 - caster):
					if state.board.at(cell) != null:
						Combat.apply_damage(state, cell, amount, true, caster, events)
			"heal":
				if target != null:
					var m := state.board.at(target)
					if m != null:
						var healed: int = mini(m.hp + int(op.get("amount", 0)), m.max_hp()) - m.hp
						m.hp += healed
						events.append({ "e": "heal", "cell": target, "amount": healed, "hp": m.hp })
			"heal_master":
				var p := state.players[caster]
				var healed: int = mini(p.master_hp + int(op.get("amount", 0)), p.master.hp) - p.master_hp
				p.master_hp += healed
				events.append({ "e": "master_heal", "player": caster, "amount": healed,
						"hp": p.master_hp })
			"buff":
				if target != null:
					var m := state.board.at(target)
					if m != null:
						var d_atk: int = op.get("atk", 0)
						var d_hp: int = op.get("hp", 0)
						m.atk_bonus += d_atk
						m.max_hp_bonus += d_hp
						if d_hp > 0:
							m.hp += d_hp
						m.hp = clampi(m.hp, 1, m.max_hp())
						events.append({ "e": "buff", "cell": target, "atk": d_atk, "hp": d_hp })
			"shield":
				if target != null:
					var m := state.board.at(target)
					if m != null:
						m.shield = true
						events.append({ "e": "shield", "cell": target })
			"draw":
				draw_cards(state, caster, int(op.get("count", 0)), false, events)
			"stones":
				Combat.gain_stones(state, caster, int(op.get("amount", 0)), events)
			"sacrifice":
				if target != null and state.board.at(target) != null:
					Combat.destroy(state, target, -1, false, events)
			_:
				push_error("Unknown effect op: %s" % [op])


## Draws up to `count` cards. On the turn-start draw (turn_draw), an empty deck
## inflicts ramping FATIGUE damage to the player's master (1, then 2, then 3…)
## instead of a card; effect draws simply fizzle. A full hand skips the draw.
static func draw_cards(state: GameState, player_idx: int, count: int,
		turn_draw: bool, events: Array) -> void:
	var p := state.players[player_idx]
	for i in count:
		if p.deck.is_empty():
			if turn_draw:
				p.fatigue += 1
				events.append({ "e": "fatigue", "player": player_idx, "amount": p.fatigue })
				Combat.damage_master(state, player_idx, p.fatigue, -1, events)
			return
		if p.hand.size() >= GameConst.HAND_LIMIT:
			return
		p.hand.append(p.deck.pop_back())
		events.append({ "e": "draw", "player": player_idx, "count": 1 })
