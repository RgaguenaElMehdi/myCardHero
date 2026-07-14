class_name Season
## Règles pures du passe de saison : niveaux depuis l'XP et récompense d'un
## niveau depuis la config déclarative (resources/data/season_pass.json).
## Zéro dépendance scène — Game applique au profil.


## Niveau atteint (0 = rien, plafonné au nombre de niveaux du passe).
static func level_of(xp: int, cfg: Dictionary) -> int:
	var per := maxi(1, int(cfg.get("xp_per_level", 100)))
	return clampi(xp / per, 0, int(cfg.get("levels", 50)))


## Récompense d'un niveau : jalon explicite > palier de 10 > palier de 5 > base.
static func reward_for(level: int, cfg: Dictionary) -> Dictionary:
	var rewards: Dictionary = cfg.get("rewards", {})
	var milestones: Dictionary = rewards.get("milestones", {})
	if milestones.has(str(level)):
		return milestones[str(level)]
	if level % 10 == 0 and rewards.has("every_10"):
		return rewards.every_10
	if level % 5 == 0 and rewards.has("every_5"):
		return rewards.every_5
	return rewards.get("default", {})
