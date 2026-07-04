class_name CardDef
extends Resource
## Static definition of a card (monster or spell). Pure data loaded from
## resources/cards/*.tres — no gameplay values are hardcoded in scripts.

@export var id: StringName
@export var display_name: String
@export var guild: GameConst.Guild
@export var kind: GameConst.CardKind
@export var cost: int = 1
@export_multiline var description: String
## res:// path of the card illustration (assets/, never embedded in code).
@export var art: String

@export_group("Monster")
@export var attack_type: GameConst.AttackType
## One entry per level, index 0 = level 1.
## Each entry: { "xp": cumulative XP needed to reach this level, "atk": int, "hp": int }
@export var levels: Array[Dictionary] = []
## e.g. { "armor": 1, "haste": true, "riposte": 2 }
@export var keywords: Dictionary = {}
## Card id of the evolved form ("" = no evolution). Evolution is available at max level.
@export var evolves_to: StringName = &""
@export var evolve_cost: int = 0
## Tokens (evolved forms) cannot be put in decks.
@export var token: bool = false

@export_group("Spell")
## Ordered effect ops, e.g. [{ "op": "damage", "amount": 2, "target": "enemy_monster" }].
## See Effects.gd for the op vocabulary.
@export var effect: Array[Dictionary] = []


func is_monster() -> bool:
	return kind == GameConst.CardKind.MONSTER


func is_spell() -> bool:
	return kind == GameConst.CardKind.SPELL


func max_level() -> int:
	return levels.size()


func has_keyword(kw: StringName) -> bool:
	return keywords.has(kw)


func keyword_value(kw: StringName) -> int:
	return int(keywords.get(kw, 0))


## Returns the target requirement of a spell: "", "ally_monster", "enemy_monster", "any_monster".
func target_kind() -> String:
	for op in effect:
		var t: String = op.get("target", "")
		if t != "":
			return t
	return ""
