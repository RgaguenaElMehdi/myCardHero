extends Node
## Db autoload: loads all declarative game data (resources/data/*.json) into
## typed defs, validates integrity, and exposes lookups + asset path conventions.
## Static loaders are unit-testable without the scene tree.

const CARDS_PATH := "res://resources/data/cards.json"
const MASTERS_PATH := "res://resources/data/masters.json"
const CAMPAIGN_PATH := "res://resources/data/campaign.json"

const GUILDS := {
	"flame": GameConst.Guild.FLAME,
	"sylvan": GameConst.Guild.SYLVAN,
	"shadow": GameConst.Guild.SHADOW,
	"light": GameConst.Guild.LIGHT,
}
const ATTACK_TYPES := {
	"melee": GameConst.AttackType.MELEE,
	"ranged": GameConst.AttackType.RANGED,
	"magic": GameConst.AttackType.MAGIC,
}

## StringName -> CardDef
var cards: Dictionary = {}
## StringName -> MasterDef
var masters: Dictionary = {}
## Parsed campaign data (chapters, starter, hero_name).
var campaign: Dictionary = {}


func _ready() -> void:
	var result := load_all()
	cards = result.cards
	masters = result.masters
	campaign = result.campaign
	for err in result.errors:
		push_error("[Db] %s" % err)
	assert(result.errors.is_empty(), "Game data failed validation — see errors above.")


func card(id: StringName) -> CardDef:
	return cards.get(id)


func master(id: StringName) -> MasterDef:
	return masters.get(id)


func chapters() -> Array:
	return campaign.get("chapters", [])


func chapter(index: int) -> Dictionary:
	var list := chapters()
	return list[index] if index >= 0 and index < list.size() else {}


## Cards allowed in player decks (excludes evolved tokens).
func constructible_cards() -> Array[CardDef]:
	var result: Array[CardDef] = []
	for id in cards:
		if not (cards[id] as CardDef).token:
			result.append(cards[id])
	result.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		if a.guild != b.guild:
			return a.guild < b.guild
		if a.cost != b.cost:
			return a.cost < b.cost
		return String(a.id) < String(b.id))
	return result


# --- Asset path conventions (all visuals live under assets/) -----------

static func card_art_path(id: StringName) -> String:
	return "res://assets/sprites/cards/%s.png" % id


static func portrait_path(name: String) -> String:
	return "res://assets/portraits/%s.png" % name


static func background_path(id: String) -> String:
	return "res://assets/backgrounds/%s.png" % id


# --- Static loading / validation (testable headless) --------------------

static func load_all() -> Dictionary:
	var errors: Array[String] = []
	var card_index := _load_cards(CARDS_PATH, errors)
	var master_index := _load_masters(MASTERS_PATH, errors)
	var campaign_data := _load_json(CAMPAIGN_PATH, errors)
	_validate(card_index, master_index, campaign_data, errors)
	return {
		"cards": card_index, "masters": master_index, "campaign": campaign_data,
		"errors": errors,
	}


static func _load_json(path: String, errors: Array[String]) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("Fichier introuvable ou vide : %s" % path)
		return {}
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		errors.append("JSON invalide : %s" % path)
		return {}
	return data


## JSON numbers arrive as floats; the engine expects ints everywhere.
static func _intify(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		var v = d[key]
		out[key] = int(v) if v is float else v
	return out


static func _load_cards(path: String, errors: Array[String]) -> Dictionary:
	var data := _load_json(path, errors)
	var index := {}
	for entry in data.get("cards", []):
		var c := CardDef.new()
		c.id = StringName(entry.get("id", ""))
		c.display_name = entry.get("name", "")
		c.guild = GUILDS.get(entry.get("guild", ""), GameConst.Guild.FLAME)
		c.kind = GameConst.CardKind.MONSTER if entry.get("kind") == "monster" \
				else GameConst.CardKind.SPELL
		c.cost = int(entry.get("cost", 0))
		c.description = entry.get("flavor", "")
		c.token = bool(entry.get("token", false))
		c.rarity = StringName(entry.get("rarity", "ascendant" if c.token else "commune"))
		c.art = card_art_path(c.id)
		if not GUILDS.has(entry.get("guild", "")):
			errors.append("Carte %s : guilde inconnue '%s'" % [c.id, entry.get("guild")])
		if c.kind == GameConst.CardKind.MONSTER:
			if not ATTACK_TYPES.has(entry.get("attack_type", "")):
				errors.append("Carte %s : type d'attaque inconnu '%s'"
						% [c.id, entry.get("attack_type")])
			c.attack_type = ATTACK_TYPES.get(entry.get("attack_type", ""),
					GameConst.AttackType.MELEE)
			var levels: Array[Dictionary] = []
			for lv in entry.get("levels", []):
				levels.append(_intify(lv))
			c.levels = levels
			c.keywords = _intify(entry.get("keywords", {}))
			c.evolves_to = StringName(entry.get("evolves_to", ""))
			c.evolve_cost = int(entry.get("evolve_cost", 0))
		else:
			var ops: Array[Dictionary] = []
			for op in entry.get("effect", []):
				ops.append(_intify(op))
			c.effect = ops
		# Trigger hooks — parsed for all card kinds.
		var summon_ops: Array[Dictionary] = []
		for op in entry.get("on_summon", []):
			summon_ops.append(_intify(op))
		c.on_summon = summon_ops
		var death_ops: Array[Dictionary] = []
		for op in entry.get("on_death", []):
			death_ops.append(_intify(op))
		c.on_death = death_ops
		var attack_ops: Array[Dictionary] = []
		for op in entry.get("on_attack", []):
			attack_ops.append(_intify(op))
		c.on_attack = attack_ops
		if index.has(c.id):
			errors.append("Carte en double : %s" % c.id)
		index[c.id] = c
	return index


static func _load_masters(path: String, errors: Array[String]) -> Dictionary:
	var data := _load_json(path, errors)
	var index := {}
	for entry in data.get("masters", []):
		var m := MasterDef.new()
		m.id = StringName(entry.get("id", ""))
		m.display_name = entry.get("name", "")
		m.guild = GUILDS.get(entry.get("guild", ""), GameConst.Guild.FLAME)
		m.hp = int(entry.get("hp", GameConst.MASTER_HP))
		m.lore = entry.get("lore", "")
		m.passive_id = StringName(entry.get("passive_id", ""))
		m.passive_desc = entry.get("passive_desc", "")
		m.power_name = entry.get("power_name", "")
		m.power_cost = int(entry.get("power_cost", 0))
		m.power_desc = entry.get("power_desc", "")
		m.portrait = portrait_path(String(m.id))
		var ops: Array[Dictionary] = []
		for op in entry.get("power_effect", []):
			ops.append(_intify(op))
		m.power_effect = ops
		if index.has(m.id):
			errors.append("Maître en double : %s" % m.id)
		index[m.id] = m
	return index


static func _validate(card_index: Dictionary, master_index: Dictionary,
		campaign_data: Dictionary, errors: Array[String]) -> void:
	for id in card_index:
		var c: CardDef = card_index[id]
		if c.is_monster():
			if c.levels.is_empty():
				errors.append("Carte %s : aucun niveau défini" % id)
			else:
				if int(c.levels[0].get("xp", -1)) != 0:
					errors.append("Carte %s : le niveau 1 doit avoir xp=0" % id)
				for i in range(1, c.levels.size()):
					if int(c.levels[i].xp) <= int(c.levels[i - 1].xp):
						errors.append("Carte %s : seuils d'XP non croissants" % id)
			if c.evolves_to != &"":
				var evo: CardDef = card_index.get(c.evolves_to)
				if evo == null:
					errors.append("Carte %s : évolution inconnue '%s'" % [id, c.evolves_to])
				elif not evo.token:
					errors.append("Carte %s : l'évolution %s devrait être un token"
							% [id, c.evolves_to])
				if c.evolve_cost <= 0:
					errors.append("Carte %s : coût d'évolution manquant" % id)
		elif c.effect.is_empty():
			errors.append("Sort %s : aucun effet" % id)
	# Campaign integrity
	var starter: Dictionary = campaign_data.get("starter", {})
	if not master_index.has(StringName(starter.get("master", ""))):
		errors.append("Starter : maître inconnu '%s'" % starter.get("master"))
	var deck_err := Rules.validate_deck(card_index, starter.get("deck", []))
	if deck_err != "":
		errors.append("Starter deck : %s" % deck_err)
	for id in starter.get("collection", {}):
		if not card_index.has(StringName(id)):
			errors.append("Starter collection : carte inconnue '%s'" % id)
	var chapter_list: Array = campaign_data.get("chapters", [])
	if chapter_list.is_empty():
		errors.append("Campagne : aucun chapitre")
	for ch in chapter_list:
		var cid: String = ch.get("id", "?")
		var opp: Dictionary = ch.get("opponent", {})
		if not master_index.has(StringName(opp.get("master", ""))):
			errors.append("%s : maître adverse inconnu '%s'" % [cid, opp.get("master")])
		var opp_err := Rules.validate_deck(card_index, opp.get("deck", []))
		if opp_err != "":
			errors.append("%s : deck adverse — %s" % [cid, opp_err])
		var lvl := int(ch.get("opponent", {}).get("ai_level", -1))
		if lvl < 0 or lvl > 2:
			errors.append("%s : ai_level invalide (%d)" % [cid, lvl])
		var rewards: Dictionary = ch.get("rewards", {})
		for id in rewards.get("cards", {}):
			var def: CardDef = card_index.get(StringName(id))
			if def == null:
				errors.append("%s : récompense inconnue '%s'" % [cid, id])
			elif def.token:
				errors.append("%s : une récompense ne peut pas être un token (%s)" % [cid, id])
		for mid in rewards.get("masters", []):
			if not master_index.has(StringName(mid)):
				errors.append("%s : maître récompense inconnu '%s'" % [cid, mid])
		for line in (ch.get("pre_dialogue", []) + ch.get("post_dialogue", [])):
			if String(line.get("text", "")).is_empty():
				errors.append("%s : ligne de dialogue vide" % cid)
