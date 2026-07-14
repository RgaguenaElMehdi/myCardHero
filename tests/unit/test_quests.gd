extends TestCase
## Intégrité de resources/data/quests.json : structure, clés de compteurs
## connues, récompenses en monnaies valides, ids de succès uniques.

const PATH := "res://resources/data/quests.json"
const COUNTER_KEYS := ["games", "wins", "cards", "summons", "kills", "powers"]
const STAT_KEYS := ["games", "wins", "cards", "summons", "kills", "powers",
		"level", "collection", "campaign", "rating"]
const CURRENCIES := ["gold", "shards", "gems"]


func _data() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	ok(data is Dictionary, "quests.json doit être un objet JSON")
	return data if data is Dictionary else {}


func test_quests_shape() -> void:
	var data := _data()
	for scope in ["daily", "weekly"]:
		var quests: Array = data.get(scope, [])
		ok(quests.size() >= 3, "%s : au moins 3 quêtes" % scope)
		for q in quests:
			ok(COUNTER_KEYS.has(String(q.get("key", ""))),
					"clé de compteur inconnue : %s" % q.get("key"))
			ok(int(q.get("goal", 0)) > 0, "objectif nul pour %s" % q.get("label"))
			ok(String(q.get("label", "")) != "", "quête sans libellé")


func test_achievements_shape() -> void:
	var seen := {}
	for a in _data().get("achievements", []):
		var id := String(a.get("id", ""))
		ok(id != "" and not seen.has(id), "id de succès vide ou en double : %s" % id)
		seen[id] = true
		ok(STAT_KEYS.has(String(a.get("stat", ""))),
				"stat de succès inconnue : %s" % a.get("stat"))
		ok(int(a.get("goal", 0)) > 0, "objectif nul pour %s" % id)


func test_rewards_use_known_currencies() -> void:
	var data := _data()
	for group in [data.get("daily", []), data.get("weekly", []), data.get("achievements", [])]:
		for q in group:
			var reward: Dictionary = q.get("reward", {})
			ok(reward.size() == 1, "une seule monnaie par récompense (%s)" % q.get("label", q.get("id")))
			for kind in reward:
				ok(CURRENCIES.has(String(kind)), "monnaie inconnue : %s" % kind)
				ok(int(reward[kind]) > 0, "récompense nulle")
