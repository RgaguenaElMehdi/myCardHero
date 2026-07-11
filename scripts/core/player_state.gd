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
## Reset each turn: true once the first monster of the turn has been summoned
## (drives the first_summon_shield passive).
var first_summon_done: bool = false
## Consecutive turn-start draws missed on an empty deck (fatigue damage ramps).
var fatigue: int = 0


static func create(p_master: MasterDef, p_deck: Array[StringName]) -> PlayerState:
	var p := PlayerState.new()
	p.master = p_master
	p.master_hp = p_master.hp
	p.deck = p_deck.duplicate()
	return p


func has_passive(id: StringName) -> bool:
	return master.passive_id == id


## --- Serialization ---------------------------------------------------------

static func _ids(a: Array) -> Array:
	var out: Array = []
	for id in a:
		out.append(String(id))
	return out


static func _snames(a: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in a:
		out.append(StringName(id))
	return out


func to_dict() -> Dictionary:
	return {
		"master": String(master.id), "master_hp": master_hp, "stones": stones,
		"master_col": master_col, "deck": _ids(deck), "hand": _ids(hand),
		"discard": _ids(discard), "power_used": power_used,
		"master_moved": master_moved, "mulligan_done": mulligan_done,
		"first_summon_done": first_summon_done, "fatigue": fatigue,
	}


static func from_dict(d: Dictionary, master_index: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.master = master_index.get(StringName(d.get("master", "")))
	p.master_hp = int(d.get("master_hp", 0))
	p.stones = int(d.get("stones", 0))
	p.master_col = int(d.get("master_col", 1))
	p.deck = _snames(d.get("deck", []))
	p.hand = _snames(d.get("hand", []))
	p.discard = _snames(d.get("discard", []))
	p.power_used = bool(d.get("power_used", false))
	p.master_moved = bool(d.get("master_moved", false))
	p.mulligan_done = bool(d.get("mulligan_done", false))
	p.first_summon_done = bool(d.get("first_summon_done", false))
	p.fatigue = int(d.get("fatigue", 0))
	return p
