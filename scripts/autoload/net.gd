extends Node
## ENet transport for online 1v1. Thin wrapper around the authoritative match
## logic (NetServerLogic) — the HOST runs the authority (peer 1, player 0); the
## joiner is a pure client (player 1). Both sides play through a
## NetworkMatchController that only ever sees its own redacted view.
##
## Flow: host() / join() → deck exchange → server builds the match → each side
## gets a player index + initial snapshot → `match_ready` → battle scene.
## See docs/multiplayer-plan.md (Phase 1).

signal match_ready(my_player: int)     ## go to the battle scene in online mode
signal opponent_joined
signal connection_failed(reason: String)
signal opponent_left

const DEFAULT_PORT := 8790

enum Role { NONE, HOST, CLIENT }
var role := Role.NONE
var controller: NetworkMatchController         ## this client's view (set at start)

var _server: NetServerLogic                    ## host only
var _peer_player := {}                          ## host only: peer_id -> player index
var _my_deck: Dictionary                        ## { name, master, cards }
var _client_deck: Dictionary                    ## host only: joiner's deck


# --- Public API ------------------------------------------------------------

func host(deck: Dictionary, port := DEFAULT_PORT) -> String:
	reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)
	if err != OK:
		return "Impossible d'héberger sur le port %d (%s)." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	_my_deck = deck
	_server = NetServerLogic.new()
	_peer_player = { 1: 0 }
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return ""


func join(ip: String, deck: Dictionary, port := DEFAULT_PORT) -> String:
	reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return "Connexion impossible à %s:%d (%s)." % [ip, port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_my_deck = deck
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void:
		connection_failed.emit("Le serveur n'a pas répondu."))
	multiplayer.server_disconnected.connect(_on_server_left)
	return ""


## Submit the local player's action to the authority.
func submit_action(action: Dictionary) -> void:
	if role == Role.HOST:
		_apply_authoritative(0, action)
	elif role == Role.CLIENT:
		_srv_action.rpc_id(1, action)


func reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	controller = null
	_server = null
	_peer_player = {}
	_client_deck = {}


# --- Connection lifecycle --------------------------------------------------

func _on_peer_connected(id: int) -> void:            # host side
	_peer_player[id] = 1
	opponent_joined.emit()
	# the joiner sends its deck on connect (see _on_connected) — nothing to ask


func _on_peer_disconnected(_id: int) -> void:
	opponent_left.emit()


func _on_connected() -> void:                        # client side
	_send_deck.rpc_id(1, _my_deck)


func _on_server_left() -> void:
	opponent_left.emit()
	reset()


# --- Deck exchange & match start (RPC) -------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _send_deck(deck: Dictionary) -> void:           # joiner → server
	if not _client_deck.is_empty():
		return                                       # deck already received
	_client_deck = deck
	_begin_match()


func _begin_match() -> void:                         # host: both decks known
	var d0 := _my_deck
	var d1 := _client_deck
	var m0: MasterDef = Db.master(StringName(String(d0.get("master", "kiran"))))
	var m1: MasterDef = Db.master(StringName(String(d1.get("master", "kiran"))))
	_server.setup(Db.cards, [m0, m1], [d0.get("cards", []), d1.get("cards", [])], randi())
	# start both sides with their initial redacted snapshot
	_start_match(0, NetRedact.snapshot_for(_server.state(), 0))
	for id in _peer_player:
		if id != 1:
			_start_match.rpc_id(id, _peer_player[id],
					NetRedact.snapshot_for(_server.state(), _peer_player[id]))


@rpc("authority", "call_local", "reliable")
func _start_match(player_idx: int, snapshot: Dictionary) -> void:
	controller = NetworkMatchController.new()
	controller.configure(player_idx, Db.cards, Db.masters)
	controller.ingest([], snapshot, false, -1)
	# deferred so both sides finish setup before any handler acts (avoids the host
	# mutating the match before the joiner's initial snapshot is taken).
	match_ready.emit.call_deferred(player_idx)


# --- Action routing (RPC) --------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _srv_action(action: Dictionary) -> void:        # client → server
	var sender := multiplayer.get_remote_sender_id()
	_apply_authoritative(int(_peer_player.get(sender, -1)), action)


## Host-only: run the action through the authority and push results per player.
func _apply_authoritative(player_idx: int, action: Dictionary) -> void:
	var res := _server.handle_action(player_idx, action)
	if not res.get("ok", false):
		_error_to(player_idx, String(res.get("error", "Action refusée.")))
		return
	for p in _peer_player.values():
		_deliver(p, res.events, res.snapshots[p], res.over, res.winner)


func _deliver(player_idx: int, events: Array, snapshot: Dictionary, over: bool, winner: int) -> void:
	if player_idx == 0:                              # the host itself
		if controller != null:
			controller.ingest(events, snapshot, over, winner)
	else:
		var peer := _peer_of(player_idx)
		if peer != -1:
			_cli_update.rpc_id(peer, events, snapshot, over, winner)


func _error_to(player_idx: int, msg: String) -> void:
	if player_idx == 0:
		connection_failed.emit(msg)                 # reused as a generic toast on host
	else:
		var peer := _peer_of(player_idx)
		if peer != -1:
			_cli_error.rpc_id(peer, msg)


@rpc("authority", "call_remote", "reliable")
func _cli_update(events: Array, snapshot: Dictionary, over: bool, winner: int) -> void:
	if controller != null:
		controller.ingest(events, snapshot, over, winner)


@rpc("authority", "call_remote", "reliable")
func _cli_error(msg: String) -> void:
	connection_failed.emit(msg)


func _peer_of(player_idx: int) -> int:
	for peer in _peer_player:
		if _peer_player[peer] == player_idx:
			return peer
	return -1
