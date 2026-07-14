class_name Economy
## Règles d'économie pures : tirage de boosters, valeurs de recyclage et de
## fabrication. Zéro dépendance UI/scène (testable headless) — Game applique
## les résultats au profil.

## Essence rendue en recyclant une carte, par rareté.
const RECYCLE_VALUE := {
	&"commune": 5, &"rare": 20, &"epique": 60, &"legendaire": 200,
}

## Essence demandée pour fabriquer une carte, par rareté.
const CRAFT_COST := {
	&"commune": 25, &"rare": 100, &"epique": 300, &"legendaire": 1000,
}

## Poids de tirage d'un booster, par rareté.
const DROP_WEIGHTS := {
	&"commune": 70.0, &"rare": 22.0, &"epique": 6.5, &"legendaire": 1.5,
}

const RARITY_ORDER: Array[StringName] = [&"commune", &"rare", &"epique", &"legendaire"]


## Regroupe des CardDef constructibles par rareté : { rareté: [ids] }.
static func pools_of(defs: Array) -> Dictionary:
	var pools := {}
	for def in defs:
		var r: StringName = def.rarity if RARITY_ORDER.has(def.rarity) else &"commune"
		if not pools.has(r):
			pools[r] = []
		pools[r].append(String(def.id))
	return pools


## Tire les cartes d'un booster : `count` cartes pondérées par rareté, avec au
## moins une carte de rareté >= `min_rarity` (remplace le dernier tirage sinon).
static func roll_booster(pools: Dictionary, count: int, min_rarity: StringName,
		rng: RandomNumberGenerator) -> Array:
	var ids: Array = []
	var got_guarantee := false
	for i in count:
		var r := _roll_rarity(pools, rng)
		if _at_least(r, min_rarity):
			got_guarantee = true
		ids.append(_pick(pools[r], rng))
	if not got_guarantee:
		var eligible: Array[StringName] = []
		for r in RARITY_ORDER:
			if _at_least(r, min_rarity) and pools.has(r):
				eligible.append(r)
		if not eligible.is_empty():
			ids[ids.size() - 1] = _pick(pools[eligible[rng.randi() % eligible.size()]], rng)
	return ids


static func _roll_rarity(pools: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total := 0.0
	for r in RARITY_ORDER:
		if pools.has(r):
			total += float(DROP_WEIGHTS[r])
	var roll := rng.randf() * total
	for r in RARITY_ORDER:
		if not pools.has(r):
			continue
		roll -= float(DROP_WEIGHTS[r])
		if roll <= 0.0:
			return r
	return &"commune"


static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	return String(pool[rng.randi() % pool.size()])


static func _at_least(r: StringName, min_r: StringName) -> bool:
	return RARITY_ORDER.find(r) >= RARITY_ORDER.find(min_r)
