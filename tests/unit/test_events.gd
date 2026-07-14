extends TestCase
## Intégrité de resources/data/events.json : planification, bonus et modes
## spéciaux valides.

const PATH := "res://resources/data/events.json"
const SCHEDULES := ["week", "weekend"]
const BONUS_KEYS := ["gold", "xp"]
const MOD_KEYS := ["player_hp", "opponent_hp", "deck_guild"]
const CURRENCIES := ["gold", "shards", "gems"]
const DbScript := preload("res://scripts/autoload/db.gd")


func test_events_shape() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	ok(data is Array, "events.json doit être un tableau")
	var masters: Dictionary = DbScript.load_all().masters
	var seen := {}
	var week_count := 0
	for ev in (data if data is Array else []):
		var id := String(ev.get("id", ""))
		ok(id != "" and not seen.has(id), "id vide ou en double : %s" % id)
		seen[id] = true
		ok(SCHEDULES.has(String(ev.get("schedule", ""))), "%s : planification inconnue" % id)
		if String(ev.get("schedule", "")) == "week":
			week_count += 1
		match String(ev.get("kind", "")):
			"bonus":
				var bonus: Dictionary = ev.get("bonus", {})
				ok(not bonus.is_empty(), "%s : bonus vide" % id)
				for k in bonus:
					ok(BONUS_KEYS.has(String(k)), "%s : bonus inconnu %s" % [id, k])
					ok(float(bonus[k]) > 1.0, "%s : multiplicateur <= 1" % id)
			"battle":
				for k in ev.get("mod", {}):
					ok(MOD_KEYS.has(String(k)), "%s : modificateur inconnu %s" % [id, k])
				ok(masters.has(StringName(String(ev.get("opponent", {}).get("master", "")))),
						"%s : maître inconnu" % id)
				var reward: Dictionary = ev.get("win_reward", {})
				ok(reward.size() == 1, "%s : une monnaie par victoire" % id)
				for k in reward:
					ok(CURRENCIES.has(String(k)) and int(reward[k]) > 0,
							"%s : récompense invalide" % id)
			_:
				ok(false, "%s : kind inconnu" % id)
	ok(week_count >= 1, "au moins un événement hebdomadaire en rotation")
