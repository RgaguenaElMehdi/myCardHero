class_name NetRedact
## Per-player redaction of an authoritative GameState snapshot.
##
## Hidden information — every deck's ORDER, and each opponent's HAND — is replaced
## by a sentinel while the COUNT is preserved, so a client can render pile sizes
## and face-down cards without learning the secret. Board, discards, resources,
## masters, hp and turn are public. The RNG is never sent to a client.
##
## The server calls snapshot_for(state, p) once per player and sends each the
## result. See docs/multiplayer-plan.md.

const HIDDEN := &"__hidden__"


## Redacted, JSON-ready snapshot of `state` as seen by player `viewer`.
static func snapshot_for(state: GameState, viewer: int) -> Dictionary:
	var d := state.to_dict(false)          # false: never leak the RNG to a client
	var players: Array = d["players"]
	for i in players.size():
		var p: Dictionary = players[i]
		p["deck"] = _hide(p["deck"])       # deck order is secret to everyone
		if i != viewer:
			p["hand"] = _hide(p["hand"])   # opponents' hands are secret
	return d


## True if a card id is a redacted placeholder (client renders it face-down).
static func is_hidden(id) -> bool:
	return StringName(id) == HIDDEN


static func _hide(zone: Array) -> Array:
	var out: Array = []
	for _c in zone:
		out.append(String(HIDDEN))
	return out
