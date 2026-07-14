extends TestCase
## Intégrité de resources/data/challenges.json : ids uniques, modificateurs
## connus, maîtres adverses existants, récompenses valides.

const PATH := "res://resources/data/challenges.json"
const MOD_KEYS := ["player_hp", "opponent_hp", "deck_guild"]
const GUILDS := ["flame", "sylvan", "shadow", "light"]
const CURRENCIES := ["gold", "shards", "gems"]
const DbScript := preload("res://scripts/autoload/db.gd")


func _challenges() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	ok(data is Array, "challenges.json doit être un tableau")
	return data if data is Array else []


func test_challenges_shape() -> void:
	var masters: Dictionary = DbScript.load_all().masters
	var seen := {}
	var list := _challenges()
	ok(list.size() >= 3, "au moins 3 défis")
	for ch in list:
		var id := String(ch.get("id", ""))
		ok(id != "" and not seen.has(id), "id de défi vide ou en double : %s" % id)
		seen[id] = true
		ok(String(ch.get("name", "")) != "", "%s : nom manquant" % id)
		ok(not (ch.get("mod", {}) as Dictionary).is_empty(), "%s : aucun modificateur" % id)
		for key in ch.get("mod", {}):
			ok(MOD_KEYS.has(String(key)), "%s : modificateur inconnu %s" % [id, key])
			if String(key) == "deck_guild":
				ok(GUILDS.has(String(ch.mod[key])), "%s : guilde inconnue" % id)
			else:
				ok(int(ch.mod[key]) > 0, "%s : PV invalides" % id)
		ok(masters.has(StringName(String(ch.get("opponent", {}).get("master", "")))),
				"%s : maître adverse inconnu" % id)
		var reward: Dictionary = ch.get("reward", {})
		ok(reward.size() == 1, "%s : une seule monnaie par récompense" % id)
		for kind in reward:
			ok(CURRENCIES.has(String(kind)) and int(reward[kind]) > 0,
					"%s : récompense invalide" % id)
