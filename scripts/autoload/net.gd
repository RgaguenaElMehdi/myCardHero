extends Node
## ENet transport for online 1v1. Two server topologies share the same
## authoritative logic (NetServerLogic):
##   • HOST (listen-server): one player also arbitrates — is player 0, waits for 1
##     client (player 1).
##   • SERVER (dedicated, headless): pure arbiter, not a player — waits for 2
##     clients and assigns them player 0 / 1 by connection order.
## A CLIENT just connects and plays. See docs/multiplayer-plan.md (Phase 1).

signal match_ready(my_player: int)
signal opponent_joined
signal connection_failed(reason: String)
signal opponent_left

const DEFAULT_PORT := 8790

enum Role { NONE, HOST, CLIENT, SERVER }
var role := Role.NONE
var controller: NetworkMatchController         ## client side (incl. HOST's own view)

var _server: NetServerLogic                    ## HOST / SERVER
var _peer_player := {}                          ## peer_id -> player index
var _local_player := -1                         ## HOST = 0, SERVER/CLIENT = -1
var _my_deck: Dictionary                        ## HOST / CLIENT
var _decks := [null, null]                      ## server side: deck per player index
var _started := false


# --- Public API ------------------------------------------------------------

## Listen-server: I host AND play (player 0).
func host(deck: Dictionary, port := DEFAULT_PORT) -> String:
	var err := _create_server(port, 1)
	if err != "":
		return err
	role = Role.HOST
	_local_player = 0
	_my_deck = deck
	_decks = [deck, null]
	_peer_player = { 1: 0 }
	return ""


## Dedicated server: pure arbiter, not a player. Waits for two clients.
func serve(port := DEFAULT_PORT) -> String:
	var err := _create_server(port, 2)
	if err != "":
		return err
	role = Role.SERVER
	_local_player = -1
	_decks = [null, null]
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


func submit_action(action: Dictionary) -> void:
	if role == Role.HOST:
		_apply_authoritative(_local_player, action)   # my own (player 0)
	elif role == Role.CLIENT:
		_srv_action.rpc_id(1, action)


func reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	controller = null
	_server = null
	_peer_player = {}
	_local_player = -1
	_decks = [null, null]
	_started = false


# --- Server bring-up -------------------------------------------------------

func _create_server(port: int, max_clients: int) -> String:
	reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return "Impossible d'héberger sur le port %d (%s)." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	_server = NetServerLogic.new()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return ""


func _next_player_slot() -> int:
	var taken := {}
	if _local_player >= 0:
		taken[_local_player] = true
	for p in _peer_player.values():
		taken[p] = true
	for i in 2:
		if not taken.has(i):
			return i
	return -1


func _on_peer_connected(id: int) -> void:            # server (HOST or SERVER)
	var slot := _next_player_slot()
	if slot == -1:
		multiplayer.multiplayer_peer.disconnect_peer(id)   # match already full
		return
	_peer_player[id] = slot
	opponent_joined.emit()


func _on_peer_disconnected(_id: int) -> void:
	opponent_left.emit()


func _on_connected() -> void:                        # client
	_send_deck.rpc_id(1, _my_deck)


func _on_server_left() -> void:
	opponent_left.emit()
	reset()


# --- Deck exchange & match start -------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _send_deck(deck: Dictionary) -> void:           # client → server
	var idx := int(_peer_player.get(multiplayer.get_remote_sender_id(), -1))
	if idx < 0 or _decks[idx] != null:
		return
	_decks[idx] = deck
	if _decks[0] != null and _decks[1] != null and not _started:
		_begin_match()


func _begin_match() -> void:
	_started = true
	var d0: Dictionary = _decks[0]
	var d1: Dictionary = _decks[1]
	var m0: MasterDef = Db.master(StringName(String(d0.get("master", "kiran"))))
	var m1: MasterDef = Db.master(StringName(String(d1.get("master", "kiran"))))
	_server.setup(Db.cards, [m0, m1], [d0.get("cards", []), d1.get("cards", [])], randi())
	for p in 2:
		var snap := NetRedact.snapshot_for(_server.state(), p)
		if p == _local_player:
			_start_match(p, snap)                    # HOST's own player, local
		else:
			var peer := _peer_of(p)
			if peer != -1:
				_start_match.rpc_id(peer, p, snap)


@rpc("authority", "call_local", "reliable")
func _start_match(player_idx: int, snapshot: Dictionary) -> void:
	controller = NetworkMatchController.new()
	controller.configure(player_idx, Db.cards, Db.masters)
	controller.ingest([], snapshot, false, -1)
	match_ready.emit.call_deferred(player_idx)


# --- Action routing --------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _srv_action(action: Dictionary) -> void:        # client → server
	_apply_authoritative(int(_peer_player.get(multiplayer.get_remote_sender_id(), -1)), action)


func _apply_authoritative(player_idx: int, action: Dictionary) -> void:
	var res := _server.handle_action(player_idx, action)
	if not res.get("ok", false):
		_error_to(player_idx, String(res.get("error", "Action refusée.")))
		return
	for p in 2:
		_deliver(p, res.events, res.snapshots[p], res.over, res.winner)


func _deliver(player_idx: int, events: Array, snapshot: Dictionary, over: bool, winner: int) -> void:
	if player_idx == _local_player:
		if controller != null:
			controller.ingest(events, snapshot, over, winner)
	else:
		var peer := _peer_of(player_idx)
		if peer != -1:
			_cli_update.rpc_id(peer, events, snapshot, over, winner)


func _error_to(player_idx: int, msg: String) -> void:
	if player_idx == _local_player:
		connection_failed.emit(msg)
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
