class_name MasterDef
extends Resource
## Static definition of a Master (the player piece on the board).
## Loaded from resources/masters/*.tres.

@export var id: StringName
@export var display_name: String
@export var guild: GameConst.Guild
@export var hp: int = GameConst.MASTER_HP
@export_multiline var lore: String

@export_group("Passive")
## One of: &"spell_damage_plus" (Kiran), &"summon_hp_plus" (Willow),
## &"kill_bonus_stone" (Grim), &"ranged_resist" (Aria).
@export var passive_id: StringName
@export_multiline var passive_desc: String

@export_group("Active power")
@export var power_name: String
@export var power_cost: int = 2
## Same op vocabulary as CardDef.effect (see Effects.gd).
@export var power_effect: Array[Dictionary] = []
@export_multiline var power_desc: String

@export_group("Art")
@export var portrait: String


## Target requirement of the active power (same convention as CardDef.target_kind).
func power_target_kind() -> String:
	for op in power_effect:
		var t: String = op.get("target", "")
		if t != "":
			return t
	return ""
