class_name GameText
## French display strings derived from data (keywords, effects, attack types).
## Keeps all rules text generated from the actual data — no drift.

const KEYWORD_NAMES := {
	"haste": "Célérité",
	"flying": "Vol",
	"armor": "Armure",
	"riposte": "Riposte",
	"regen": "Régénération",
	"shield": "Bouclier",
}

const ATTACK_TYPE_NAMES := {
	GameConst.AttackType.MELEE: "Mêlée",
	GameConst.AttackType.RANGED: "Distance",
	GameConst.AttackType.MAGIC: "Magie",
}

const TARGET_NAMES := {
	"ally_monster": "un monstre allié",
	"enemy_monster": "un monstre ennemi",
	"any_monster": "un monstre",
}

const KEYWORD_DEFS := {
	"haste": "peut agir dès le tour où il est invoqué",
	"flying": "ciblable uniquement à Distance/Magie ; sa mêlée ignore les blocages",
	"armor": "réduit chaque dégât subi (sauf Magie)",
	"riposte": "renvoie des dégâts à l'attaquant en mêlée",
	"regen": "se soigne au début du tour de son propriétaire",
	"shield": "annule la première source de dégâts subie (sauf Magie)",
}

const ATTACK_TYPE_DEFS := {
	GameConst.AttackType.MELEE: "frappe le premier monstre non-volant de sa colonne",
	GameConst.AttackType.RANGED: "peut viser n'importe quel monstre ennemi",
	GameConst.AttackType.MAGIC: "vise n'importe quelle cible et ignore Armure et Bouclier",
}


static func keywords_line(keywords: Dictionary) -> String:
	var parts: PackedStringArray = []
	for kw in keywords:
		var name: String = KEYWORD_NAMES.get(String(kw), String(kw))
		var value = keywords[kw]
		parts.append(name if value is bool else "%s %d" % [name, int(value)])
	return ", ".join(parts)


static func describe_effect(ops: Array) -> String:
	var parts: PackedStringArray = []
	for op in ops:
		match String(op.get("op", "")):
			"damage":
				parts.append("Inflige %d dégâts à %s." % [int(op.get("amount", 0)),
						TARGET_NAMES.get(op.get("target", ""), "une cible")])
			"damage_all_enemies":
				parts.append("Inflige %d dégâts à tous les monstres ennemis."
						% int(op.get("amount", 0)))
			"heal":
				parts.append("Soigne %d PV à %s." % [int(op.get("amount", 0)),
						TARGET_NAMES.get(op.get("target", ""), "une cible")])
			"heal_master":
				parts.append("Soigne %d PV à votre Maître." % int(op.get("amount", 0)))
			"buff":
				var atk := int(op.get("atk", 0))
				var hp := int(op.get("hp", 0))
				var bits: PackedStringArray = []
				if atk != 0:
					bits.append("%+d ATQ" % atk)
				if hp != 0:
					bits.append("%+d PV" % hp)
				parts.append("Donne %s à %s." % [" et ".join(bits),
						TARGET_NAMES.get(op.get("target", ""), "une cible")])
			"shield":
				parts.append("Donne un Bouclier à %s."
						% TARGET_NAMES.get(op.get("target", ""), "une cible"))
			"draw":
				parts.append("Piochez %d carte(s)." % int(op.get("count", 0)))
			"stones":
				parts.append("Gagnez %d pierre(s)." % int(op.get("amount", 0)))
			"sacrifice":
				parts.append("Sacrifiez %s." % TARGET_NAMES.get(op.get("target", ""), "un allié"))
	return " ".join(parts)


static func monster_summary(def: CardDef) -> String:
	var text := "%s — %s" % [ATTACK_TYPE_NAMES[def.attack_type], level_progression(def)]
	var kw := keywords_line(def.keywords)
	if kw != "":
		text += "\n" + kw
	if def.evolves_to != &"":
		text += "\nÉvolue (%d pierres)" % def.evolve_cost
	return text


## "2/2 › 3/3 › 4/4" (ATK/PV per level).
static func level_progression(def: CardDef) -> String:
	var parts: PackedStringArray = []
	for lv in def.levels:
		parts.append("%d/%d" % [int(lv.atk), int(lv.hp)])
	return " › ".join(parts)


## Full rules text of a card, for tooltips and detail panels.
## evo_name: display name of the evolved form ("" if none/unknown).
static func card_tooltip(def: CardDef, evo_name: String = "") -> String:
	var lines: PackedStringArray = []
	lines.append("%s — %d pierre(s)" % [def.display_name, def.cost])
	if def.is_monster():
		lines.append("%s : %s." % [ATTACK_TYPE_NAMES[def.attack_type],
				ATTACK_TYPE_DEFS[def.attack_type]])
		for i in def.levels.size():
			var lv: Dictionary = def.levels[i]
			var seuil := "" if i == 0 else " (%d XP)" % int(lv.xp)
			lines.append("Niveau %d%s : %d ATQ / %d PV" % [i + 1, seuil,
					int(lv.atk), int(lv.hp)])
		lines.append("Gagne 1 XP en blessant, 2 XP en tuant. Monter de niveau soigne entièrement.")
		for kw in def.keywords:
			var kw_name: String = KEYWORD_NAMES.get(String(kw), String(kw))
			var value = def.keywords[kw]
			var shown := kw_name if value is bool else "%s %d" % [kw_name, int(value)]
			lines.append("%s : %s." % [shown, KEYWORD_DEFS.get(String(kw), "")])
		if def.evolves_to != &"":
			var target := evo_name if evo_name != "" else "sa forme évoluée"
			lines.append("Au niveau max, peut évoluer en %s pour %d pierres (PV restaurés)."
					% [target, def.evolve_cost])
	else:
		lines.append("Sort : " + describe_effect(def.effect))
	if def.description != "":
		lines.append("« %s »" % def.description)
	return "\n".join(lines)
