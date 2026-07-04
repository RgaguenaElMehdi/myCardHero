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
	var lv1: Dictionary = def.levels[0]
	var text := "%s — %d/%d" % [ATTACK_TYPE_NAMES[def.attack_type],
			int(lv1.atk), int(lv1.hp)]
	var kw := keywords_line(def.keywords)
	if kw != "":
		text += "\n" + kw
	if def.evolves_to != &"":
		text += "\nÉvolue (%d pierres)" % def.evolve_cost
	return text
