class_name PlayerState
extends RefCounted
## Live state of one player: master, resources, zones.

var master: MasterDef
var master_hp: int
var stones: int = GameConst.START_STONES
## Column of the master within this player's back row.
var master_col: int = 1
## Card ids, top of deck = end of array.
var deck: Array[StringName] = []
var hand: Array[StringName] = []
var discard: Array[StringName] = []
var power_used: bool = false
var master_moved: bool = false
var mulligan_done: bool = false


static func create(p_master: MasterDef, p_deck: Array[StringName]) -> PlayerState:
	var p := PlayerState.new()
	p.master = p_master
	p.master_hp = p_master.hp
	p.deck = p_deck.duplicate()
	return p


func has_passive(id: StringName) -> bool:
	return master.passive_id == id
