class_name MatchController
extends RefCounted
## The single seam between the battle UI and the pure rules (scripts/core).
##
## The UI submits actions and replays the returned events — it never calls Rules
## directly. In LOCAL play this class forwards straight to Rules and IS the
## authority. For ONLINE play a NetworkMatchController will subclass this to
## round-trip the authoritative server (validate + apply there) and receive the
## opponent's moves as server-pushed, per-player REDACTED events.
##
## See docs/multiplayer-plan.md (Phase 0).

var state: GameState


## Build the match. Local: the seed lives here; online, the server owns it and
## the client rebuilds `state` from the events it is sent.
func setup(cards: Dictionary, masters: Array, decks: Array, seed_value: int,
		first_player: int = 0) -> GameState:
	state = Rules.setup(cards, masters, decks, seed_value, first_player)
	return state


## Apply an action and return { ok, error, events }. Local = authoritative, so we
## forward to Rules. NetworkMatchController overrides this to send the action to
## the server and await the redacted event stream instead.
func apply(action: Dictionary) -> Dictionary:
	return Rules.apply(state, action)
