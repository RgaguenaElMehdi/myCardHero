class_name NetworkMatchController
extends MatchController
## Client-side match controller for online play. It is NOT the authority: apply()
## forwards the action to the server and returns immediately (no events yet). The
## authoritative result — the public event stream + THIS player's redacted state
## snapshot — arrives asynchronously and is delivered by ingest(), which rebuilds
## `state` and emits remote_events for the battle scene to animate.
##
## Used in place of the local MatchController when battle_config.mode == "online".
## See docs/multiplayer-plan.md.

signal remote_events(events: Array, over: bool, winner: int)

var my_player := 0
var _cards: Dictionary
var _masters: Dictionary
var _ready := false            ## true once the first server snapshot has arrived


func configure(player_idx: int, cards: Dictionary, masters: Dictionary) -> void:
	my_player = player_idx
	_cards = cards
	_masters = masters


## Online setup is server-driven: the client's state is built from the first
## server snapshot, not from Rules. Returns null until ingest() fires.
func setup(_cards2: Dictionary, _masters2: Array, _decks: Array, _seed: int,
		_first_player: int = 0) -> GameState:
	return state


## Send the local player's action to the authority. The action is expressed in
## MY view (player 0 = me); flip it back to server coordinates first. The result
## comes back via the server push (ingest), so no events to return synchronously.
func apply(action: Dictionary) -> Dictionary:
	Net.submit_action(NetView.flip_action(action, my_player))
	return { "ok": true, "events": [] }


## Called by Net with an authoritative (server-coords) update for this client.
## Normalize snapshot + events into my view so the battle scene always renders me
## at the bottom as player 0.
func ingest(events: Array, snapshot: Dictionary, over: bool, winner: int) -> void:
	if not snapshot.is_empty():
		state = GameState.from_dict(
				NetView.normalize_snapshot(snapshot, my_player), _cards, _masters)
	_ready = state != null
	remote_events.emit(NetView.flip_events(events, my_player),
			over, NetView.flip_pidx(winner, my_player))
