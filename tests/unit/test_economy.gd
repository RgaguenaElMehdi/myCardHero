extends TestCase
## Économie pure (scripts/core/economy.gd) : tirage de boosters (taille,
## garantie de rareté, contenu valide) et cohérence recyclage / fabrication.


func _pools() -> Dictionary:
	var defs: Array = []
	for data in [["c1", &"commune"], ["c2", &"commune"], ["c3", &"commune"],
			["r1", &"rare"], ["r2", &"rare"], ["e1", &"epique"], ["l1", &"legendaire"]]:
		var def := CardDef.new()
		def.id = StringName(data[0])
		def.rarity = data[1]
		defs.append(def)
	return Economy.pools_of(defs)


func test_roll_size_and_known_ids() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pools := _pools()
	var all_ids := []
	for r in pools:
		all_ids.append_array(pools[r])
	var ids := Economy.roll_booster(pools, 5, &"commune", rng)
	eq(ids.size(), 5, "un booster de 5 donne 5 cartes")
	for id in ids:
		ok(all_ids.has(id), "carte inconnue tirée : %s" % id)


func test_guarantee_min_rarity() -> void:
	var pools := _pools()
	var rare_plus := []
	for r in [&"rare", &"epique", &"legendaire"]:
		rare_plus.append_array(pools.get(r, []))
	for i in 60:  # 60 tirages : la garantie doit tenir à chaque fois
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var ids := Economy.roll_booster(pools, 5, &"rare", rng)
		var found := false
		for id in ids:
			if rare_plus.has(id):
				found = true
		ok(found, "tirage %d sans carte Rare ou mieux" % i)


func test_craft_costs_more_than_recycle() -> void:
	for r in Economy.RARITY_ORDER:
		ok(int(Economy.CRAFT_COST[r]) > int(Economy.RECYCLE_VALUE[r]),
				"fabriquer %s doit coûter plus que son recyclage" % r)


func test_pools_group_by_rarity() -> void:
	var pools := _pools()
	eq((pools[&"commune"] as Array).size(), 3, "3 communes")
	eq((pools[&"legendaire"] as Array).size(), 1, "1 légendaire")
