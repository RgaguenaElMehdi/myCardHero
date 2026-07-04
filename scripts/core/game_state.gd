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
