class_name MonsterInst
extends RefCounted
## A monster on the board: live state wrapping a CardDef.
## Position is owned by Board, not stored here.

var def: CardDef
var owner_idx: int
var level: int = 1
var xp: int = 0
var hp: int
## Permanent modifiers granted by spells / master passives.
var atk_bonus: int = 0
var max_hp_bonus: int = 0
## True while an unbroken Shield protects this monster (keyword or granted).
var shield: bool = false
## A monster gets one action per turn: move OR attack.
var acted: bool = false
## Half-turn index of summoning, for summoning sickness.
var summoned_on_turn: int = -1


static func create(p_def: CardDef, p_owner: int, p_turn: int) -> MonsterInst:
	var m := MonsterInst.new()
	m.def = p_def
	m.owner_idx = p_owner
	m.summoned_on_turn = p_turn
	m.shield = p_def.has_keyword(GameConst.KW_SHIELD)
	m.hp = m.max_hp()
	return m


func stats() -> Dictionary:
	return def.levels[level - 1]


func max_hp() -> int:
	return int(stats().hp) + max_hp_bonus


func atk() -> int:
	return maxi(0, int(stats().atk) + atk_bonus)


func has_keyword(kw: StringName) -> bool:
	return def.has_keyword(kw)


func keyword_value(kw: StringName) -> int:
	return def.keyword_value(kw)


func at_max_level() -> bool:
	return level >= def.max_level()


func can_evolve() -> bool:
	return at_max_level() and def.evolves_to != &""


## XP needed to reach the next level, or -1 at max level.
func next_level_xp() -> int:
	if at_max_level():
		return -1
	return int(def.levels[level].xp)


## Grants XP and applies any level-ups (level-up fully heals). Returns the
## number of levels gained.
func gain_xp(amount: int) -> int:
	if amount <= 0 or at_max_level():
		xp += maxi(amount, 0)
		return 0
	xp += amount
	var gained := 0
	while not at_max_level() and xp >= next_level_xp():
		level += 1
		gained += 1
	if gained > 0:
		hp = max_hp()
	return gained
