class_name GameState
extends RefCounted
## Complete, serializable match state. Mutated only by Rules.apply().

enum Phase { MULLIGAN, MAIN, OVER }

var players: Array[PlayerState] = []
var board: Board = Board.new()
var phase: Phase = Phase.MULLIGAN
var current: int = 0
## Half-turn counter, starts at 1 on player 0's first turn.
var turn: int = 1
var rng := RandomNumberGenerator.new()
var winner: int = -1
## Lookup card definitions by id (injected at setup, typically from Db).
var card_index: Dictionary = {}


## --- Serialization (authoritative snapshots / reconnection) ----------------
## `card_index` and `master_index` are injected on rebuild (never serialized —
## they are static definition tables both sides already own). Redaction of hidden
## zones is applied on the dict BEFORE sending (see NetRedact), not here.

func to_dict(include_rng := true) -> Dictionary:
	var pl: Array = []
	for p in players:
		pl.append(p.to_dict())
	var d := {
		"phase": phase, "current": current, "turn": turn, "winner": winner,
		"players": pl, "board": board.to_dict(),
	}
	if include_rng:
		d["rng_seed"] = rng.seed
		d["rng_state"] = rng.state
	return d


static func from_dict(d: Dictionary, card_index: Dictionary, master_index: Dictionary) -> GameState:
	var s := GameState.new()
	s.card_index = card_index
	s.phase = int(d.get("phase", Phase.MULLIGAN))
	s.current = int(d.get("current", 0))
	s.turn = int(d.get("turn", 1))
	s.winner = int(d.get("winner", -1))
	if d.has("rng_seed"):
		s.rng.seed = int(d["rng_seed"])
	if d.has("rng_state"):
		s.rng.state = int(d["rng_state"])
	var pl: Array[PlayerState] = []
	for pd in d.get("players", []):
		pl.append(PlayerState.from_dict(pd, master_index))
	s.players = pl
	s.board = Board.from_dict(d.get("board", []), card_index)
	return s


func opponent() -> int:
	return 1 - current


func me() -> PlayerState:
	return players[current]


func enemy() -> PlayerState:
	return players[1 - current]


func is_over() -> bool:
	return phase == Phase.OVER


func card(id: StringName) -> CardDef:
	return card_index.get(id)


## Turn number as seen by one player (1, 2, 3...).
func player_turn_count() -> int:
	return (turn + 1) / 2
