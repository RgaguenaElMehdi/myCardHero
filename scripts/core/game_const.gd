class_name GameConst
## Global game constants and enums. Pure data, no state.

enum Guild { FLAME, SYLVAN, SHADOW, LIGHT }
enum CardKind { MONSTER, SPELL }
enum AttackType { MELEE, RANGED, MAGIC }

const BOARD_COLS := 3
const BOARD_ROWS := 4

const START_STONES := 3
const STONES_PER_TURN := 2
const MAX_STONES := 12

const DECK_SIZE := 25
const MAX_COPIES := 2
const START_HAND := 5
const HAND_LIMIT := 7

const MASTER_HP := 20

## Safety cap: game ends after this many half-turns (winner = highest master HP).
const TURN_LIMIT := 300

## Keyword keys (values: int for X keywords, true for flags).
const KW_HASTE := &"haste"
const KW_FLYING := &"flying"
const KW_ARMOR := &"armor"
const KW_RIPOSTE := &"riposte"
const KW_REGEN := &"regen"
const KW_SHIELD := &"shield"

## Passive identifiers for master abilities (single source of truth).
const PASSIVE_SPELL_DAMAGE_PLUS := &"spell_damage_plus"
const PASSIVE_SUMMON_HP_PLUS    := &"summon_hp_plus"
const PASSIVE_KILL_BONUS_STONE  := &"kill_bonus_stone"
const PASSIVE_RANGED_RESIST     := &"ranged_resist"
const PASSIVE_MELEE_DAMAGE_PLUS   := &"melee_damage_plus"
const PASSIVE_TURN_START_REGEN    := &"turn_start_regen"
const PASSIVE_ALLY_DEATH_DRAW      := &"ally_death_draw"
const PASSIVE_FIRST_SUMMON_SHIELD := &"first_summon_shield"

const GUILD_NAMES := {
	Guild.FLAME: "Flamme",
	Guild.SYLVAN: "Sylve",
	Guild.SHADOW: "Ombre",
	Guild.LIGHT: "Lumière",
}

## Couleurs de faction — source unique de vérité (l'UI délègue ici).
const GUILD_COLORS := {
	Guild.FLAME: Color("e2603c"),
	Guild.SYLVAN: Color("5aa864"),
	Guild.SHADOW: Color("8b6bc7"),
	Guild.LIGHT: Color("e6c35a"),
}

## Couleurs de rareté (halo des cartes / unités). "commune" ne brille pas :
## c'est la valeur par défaut, on met en avant tout ce qui est au-dessus.
const RARITY_COLORS := {
	&"commune": Color("8b96a8"),
	&"rare": Color("4a90e2"),
	&"epique": Color("b45ee8"),
	&"legendaire": Color("f0b429"),
	&"ascendant": Color("46e0c0"),
}


## Halo color for a rarity, or null when it should not glow (commune).
static func rarity_glow(rarity: StringName):
	if rarity == &"commune" or not RARITY_COLORS.has(rarity):
		return null
	return RARITY_COLORS[rarity]
