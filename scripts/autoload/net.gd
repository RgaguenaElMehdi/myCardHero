extends Node
## ENet transport + matchmaking for online 1v1.
##
## The server side (HOST or dedicated SERVER) keeps a QUEUE of players and runs
## any number of concurrent matches, pairing waiting players two at a time. Each
## match has its own authoritative NetServerLogic; the event stream carries no
## hidden info, only per-player state snapshots are redacted.
##   • HOST (listen-server): the host is also a player and is paired with the one
##     joining client.
##   • SERVER (dedicated, headless): pure matchmaker/arbiter — clients click
##     "Trouver une partie", queue up, and get paired automatically.
## See docs/multiplayer-plan.md.

signal match_ready(my_player: int)
signal searching                                ## client: connected, waiting for a pair
signal opponent_joined
signal connection_failed(reason: String)
signal opponent_left

const DEFAULT_PORT := 8790
const MAX_CLIENTS := 32
## Default matchmaking server ("Trouver une partie" connects here without typing).
const MATCH_SERVER := "37.60.232.49"

enum Role { NONE, HOST, CLIENT, SERVER }
var role := Role.NONE
var controller: NetworkMatchController         ## client side (incl. HOST's own view)

const SELF_ID := 1                              ## our peer id while we are the server
var _my_deck: Dictionary                        ## HOST / CLIENT
var _host_plays := false                         ## HOST: our own id 1 is a player
# server-side matchmaking state
var _queue: Array = []                           ## peer ids waiting (deck received)
var _peer_deck := {}                             ## pid -> deck
var _matches: Array = []                         ## [{ logic, peers:[pid0, pid1] }]
var _peer_match := {}                            ## pid -> match dict
var _peer_pidx := {}                             ## pid -> 0 | 1


# --- Public API ------------------------------------------------------------

## Listen-server: I host AND play. Paired with the single joining client.
func host(deck: Dictionary, port := DEFAULT_PORT) -> String:
	var err := _create_server(port, 1)
	if err != "":
		return err
	role = Role.HOST
	_my_deck = deck
	_host_plays = true
	_peer_deck[SELF_ID] = deck
	_queue = [SELF_ID]
	return ""


## Dedicated server: pure matchmaker, not a player. Runs many concurrent matches.
func serve(port := DEFAULT_PORT) -> String:
	var err := _create_server(port, MAX_CLIENTS)
	if err != "":
		return err
	role = Role.SERVER
	_host_plays = false
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
		var m = _peer_match.get(SELF_ID)
		if m != null:
			_apply_in_match(m, int(_peer_pidx.get(SELF_ID, 0)), action)
	elif role == Role.CLIENT:
		_srv_action.rpc_id(1, action)


func reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	role = Role.NONE
	controller = null
	_host_plays = false
	_queue = []
	_peer_deck = {}
	_matches = []
	_peer_match = {}
	_peer_pidx = {}


# --- Server bring-up -------------------------------------------------------

func _create_server(port: int, max_clients: int) -> String:
	reset()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		return "Impossible d'héberger sur le port %d (%s)." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return ""


func _on_peer_connected(_id: int) -> void:           # server: wait for its deck
	opponent_joined.emit()


func _on_peer_disconnected(id: int) -> void:
	_queue.erase(id)
	_peer_deck.erase(id)
	opponent_left.emit()
	var m = _peer_match.get(id)
	if m != null:
		for pid in m.peers:
			_peer_match.erase(pid)
			_peer_pidx.erase(pid)
			if pid != id and pid != SELF_ID:
				_opp_left.rpc_id(pid)                # tell the survivor the match is off
		_matches.erase(m)
	_try_matchmake()


func _on_connected() -> void:                        # client
	_send_deck.rpc_id(1, _my_deck)
	searching.emit()


func _on_server_left() -> void:
	opponent_left.emit()
	reset()


# --- Matchmaking -----------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _send_deck(deck: Dictionary) -> void:           # client → server: enter queue
	var pid := multiplayer.get_remote_sender_id()
	if _peer_deck.has(pid) or _peer_match.has(pid):
		return
	_peer_deck[pid] = deck
	_queue.append(pid)
	_try_matchmake()


func _try_matchmake() -> void:
	while _queue.size() >= 2:
		_start_match_between(_queue.pop_front(), _queue.pop_front())


func _start_match_between(pid_a: int, pid_b: int) -> void:
	var da: Dictionary = _peer_deck[pid_a]
	var db: Dictionary = _peer_deck[pid_b]
	var ma: MasterDef = Db.master(StringName(String(da.get("master", "kiran"))))
	var mb: MasterDef = Db.master(StringName(String(db.get("master", "kiran"))))
	var logic := NetServerLogic.new()
	logic.setup(Db.cards, [ma, mb], [da.get("cards", []), db.get("cards", [])], randi())
	var m := { "logic": logic, "peers": [pid_a, pid_b] }
	_matches.append(m)
	_peer_match[pid_a] = m
	_peer_pidx[pid_a] = 0
	_peer_match[pid_b] = m
	_peer_pidx[pid_b] = 1
	_send_start(m, 0)
	_send_start(m, 1)


func _send_start(m: Dictionary, pidx: int) -> void:
	var pid: int = m.peers[pidx]
	var snap := NetRedact.snapshot_for(m.logic.state(), pidx)
	if pid == SELF_ID and _host_plays:
		_start_match(pidx, snap)                     # HOST's own player (local)
	else:
		_start_match.rpc_id(pid, pidx, snap)


@rpc("authority", "call_local", "reliable")
func _start_match(player_idx: int, snapshot: Dictionary) -> void:
	controller = NetworkMatchController.new()
	controller.configure(player_idx, Db.cards, Db.masters)
	controller.ingest([], snapshot, false, -1)
	match_ready.emit.call_deferred(player_idx)


# --- Action routing --------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _srv_action(action: Dictionary) -> void:        # client → server
	var pid := multiplayer.get_remote_sender_id()
	var m = _peer_match.get(pid)
	if m != null:
		_apply_in_match(m, int(_peer_pidx.get(pid, 0)), action)


func _apply_in_match(m: Dictionary, pidx: int, action: Dictionary) -> void:
	var res: Dictionary = m.logic.handle_action(pidx, action)
	if not res.get("ok", false):
		_send_error(m, pidx, String(res.get("error", "Action refusée.")))
		return
	for p in 2:
		_send_update(m, p, res.events, res.snapshots[p], res.over, res.winner)


func _send_update(m: Dictionary, pidx: int, events: Array, snapshot: Dictionary,
		over: bool, winner: int) -> void:
	var pid: int = m.peers[pidx]
	if pid == SELF_ID and _host_plays:
		if controller != null:
			controller.ingest(events, snapshot, over, winner)
	else:
		_cli_update.rpc_id(pid, events, snapshot, over, winner)


func _send_error(m: Dictionary, pidx: int, msg: String) -> void:
	var pid: int = m.peers[pidx]
	if pid == SELF_ID and _host_plays:
		connection_failed.emit(msg)
	else:
		_cli_error.rpc_id(pid, msg)


@rpc("authority", "call_remote", "reliable")
func _cli_update(events: Array, snapshot: Dictionary, over: bool, winner: int) -> void:
	if controller != null:
		controller.ingest(events, snapshot, over, winner)


@rpc("authority", "call_remote", "reliable")
func _cli_error(msg: String) -> void:
	connection_failed.emit(msg)


@rpc("authority", "call_remote", "reliable")
func _opp_left() -> void:
	opponent_left.emit()
