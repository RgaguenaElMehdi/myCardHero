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

const GUILD_NAMES := {
	Guild.FLAME: "Flamme",
	Guild.SYLVAN: "Sylve",
	Guild.SHADOW: "Ombre",
	Guild.LIGHT: "Lumière",
}
