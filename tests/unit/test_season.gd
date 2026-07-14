extends TestCase
## Passe de saison : règles pures (scripts/core/season.gd) + intégrité de
## resources/data/season_pass.json.

const PATH := "res://resources/data/season_pass.json"
const CURRENCIES := ["gold", "shards", "gems"]


func _cfg() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	ok(data is Dictionary, "season_pass.json doit être un objet")
	return data if data is Dictionary else {}


func test_level_of() -> void:
	var cfg := { "xp_per_level": 100, "levels": 10 }
	eq(Season.level_of(0, cfg), 0, "0 XP = niveau 0")
	eq(Season.level_of(99, cfg), 0, "99 XP = niveau 0")
	eq(Season.level_of(100, cfg), 1, "100 XP = niveau 1")
	eq(Season.level_of(999999, cfg), 10, "plafonné au dernier niveau")


func test_reward_priority() -> void:
	var cfg := { "rewards": {
		"default": { "gold": 10 }, "every_5": { "shards": 5 },
		"every_10": { "gems": 1 }, "milestones": { "10": { "gems": 99 } } } }
	eq(int(Season.reward_for(3, cfg).get("gold", 0)), 10, "niveau simple = base")
	eq(int(Season.reward_for(5, cfg).get("shards", 0)), 5, "palier de 5")
	eq(int(Season.reward_for(20, cfg).get("gems", 0)), 1, "palier de 10")
	eq(int(Season.reward_for(10, cfg).get("gems", 0)), 99, "jalon prioritaire")


func test_config_integrity() -> void:
	var cfg := _cfg()
	ok(int(cfg.get("levels", 0)) >= 50, "au moins 50 niveaux")
	ok(int(cfg.get("xp_per_level", 0)) > 0, "xp_per_level > 0")
	for level in range(1, int(cfg.get("levels", 0)) + 1):
		var reward := Season.reward_for(level, cfg)
		ok(reward.size() == 1, "niveau %d : une seule monnaie" % level)
		for kind in reward:
			ok(CURRENCIES.has(String(kind)), "niveau %d : monnaie inconnue %s" % [level, kind])
			ok(int(reward[kind]) > 0, "niveau %d : récompense nulle" % level)
	var bxp: Dictionary = cfg.get("battle_xp", {})
	ok(int(bxp.get("win", 0)) > int(bxp.get("loss", 0)),
			"la victoire doit rapporter plus que la défaite")
