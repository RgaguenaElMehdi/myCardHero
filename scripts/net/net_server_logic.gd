class_name NetServerLogic
extends RefCounted
## Authoritative match logic, transport-free (the ENet server is a thin wrapper).
## Holds the one true state, validates every action, and produces the per-player
## payloads to broadcast. The event stream carries no hidden info (draws are
## count-only; summon/cast/death are public), so only the STATE snapshot is
## redacted, once per player. See docs/multiplayer-plan.md.

var _match := MatchController.new()


func setup(cards: Dictionary, masters: Array, decks: Array, seed_value: int) -> void:
	_match.setup(cards, masters, decks, seed_value)


func state() -> GameState:
	return _match.state


## Apply `player_idx`'s action authoritatively.
## Returns { ok, error?, events?, snapshots?: [snap_p0, snap_p1], over?, winner? }.
## Anti-cheat: outside the mulligan phase a player may only act on its own turn.
func handle_action(player_idx: int, action: Dictionary) -> Dictionary:
	var st := _match.state
	if st == null:
		return { "ok": false, "error": "Aucune partie en cours." }
	# Anti-cheat: a player may only submit actions on its own turn (mulligan is
	# sequential — the active player first).
	if not st.is_over() and player_idx != st.current:
		return { "ok": false, "error": "Ce n'est pas votre tour." }
	var res := _match.apply(action)
	if not res.ok:
		return { "ok": false, "error": res.error }
	return {
		"ok": true,
		"events": res.events,
		"snapshots": [
			NetRedact.snapshot_for(_match.state, 0),
			NetRedact.snapshot_for(_match.state, 1),
		],
		"over": _match.state.is_over(),
		"winner": _match.state.winner,
	}
