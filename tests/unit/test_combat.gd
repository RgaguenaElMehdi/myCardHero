extends TestCase
## Attack targeting, keywords, XP/level-up, kill rewards, master damage & win.
## Board reminder: p0 rows 0 (back) / 1 (front); p1 rows 2 (front) / 3 (back).
## Masters start on column 1 of their back row.


func test_melee_targets_frontmost() -> void:
	var state := TestUtil.fresh_game()
	TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	TestUtil.put(state, Vector2i(0, 2), "grunt", 1)
	TestUtil.put(state, Vector2i(0, 3), "archer", 1)
	var targets := Rules.legal_attack_targets(state, Vector2i(0, 1))
	eq(targets, [Vector2i(0, 2)], "mêlée : le plus proche de la colonne uniquement")


func test_melee_blocked_from_back_row() -> void:
	var state := TestUtil.fresh_game()
	TestUtil.put(state, Vector2i(0, 0), "grunt", 0)
	TestUtil.put(state, Vector2i(0, 2), "grunt", 1)
	eq(Rules.legal_attack_targets(state, Vector2i(0, 0)), [Vector2i(0, 2)],
			"rangée arrière non bloquée : attaque OK")
	TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	eq(Rules.legal_attack_targets(state, Vector2i(0, 0)).size(), 0,
			"rangée arrière bloquée par un allié devant")


func test_melee_master_requires_open_column_and_front_row() -> void:
	var state := TestUtil.fresh_game()
	# enemy master on column 1, no defenders
	TestUtil.put(state, Vector2i(1, 1), "grunt", 0)
	eq(Rules.legal_attack_targets(state, Vector2i(1, 1)), [Vector2i(1, 3)],
			"maître exposé en mêlée depuis la rangée avant")
	# wrong column: no targets
	TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	eq(Rules.legal_attack_targets(state, Vector2i(0, 1)).size(), 0,
			"pas de cible hors de la colonne du maître")
	# defender in master column blocks it
	TestUtil.put(state, Vector2i(1, 2), "grunt", 1)
	eq(Rules.legal_attack_targets(state, Vector2i(1, 1)), [Vector2i(1, 2)],
			"défenseur dans la colonne : maître protégé")


func test_flying_cover_and_targeting() -> void:
	var state := TestUtil.fresh_game()
	TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	TestUtil.put(state, Vector2i(0, 2), "flyer", 1)
	TestUtil.put(state, Vector2i(0, 3), "grunt", 1)
	eq(Rules.legal_attack_targets(state, Vector2i(0, 1)), [Vector2i(0, 3)],
			"la mêlée ignore les volants (pas de couverture, pas ciblables)")
	# flying attacker ignores its own column block
	TestUtil.put(state, Vector2i(2, 0), "flyer", 0)
	TestUtil.put(state, Vector2i(2, 1), "grunt", 0)
	TestUtil.put(state, Vector2i(2, 2), "grunt", 1)
	eq(Rules.legal_attack_targets(state, Vector2i(2, 0)), [Vector2i(2, 2)],
			"attaquant volant : ignore le blocage de colonne")


func test_ranged_targets_and_master_exposure() -> void:
	var state := TestUtil.fresh_game()
	TestUtil.put(state, Vector2i(2, 1), "archer", 0)
	TestUtil.put(state, Vector2i(0, 2), "grunt", 1)
	TestUtil.put(state, Vector2i(1, 2), "flyer", 1)
	var targets := Rules.legal_attack_targets(state, Vector2i(2, 1))
	ok(targets.has(Vector2i(0, 2)), "distance : cible n'importe quel monstre")
	ok(targets.has(Vector2i(1, 2)), "distance : peut cibler un volant")
	ok(not targets.has(Vector2i(1, 3)), "maître couvert (volant compte comme couverture)")
	state.board.remove(Vector2i(1, 2))
	targets = Rules.legal_attack_targets(state, Vector2i(2, 1))
	ok(targets.has(Vector2i(1, 3)), "maître exposé pour la distance")


func test_armor_shield_and_magic_pierce() -> void:
	var state := TestUtil.fresh_game()
	var grunt := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)   # atk 2 melee
	var tank := TestUtil.put(state, Vector2i(0, 2), "tank", 1)     # armor 1, hp 5
	applied(Rules.apply(state, { "type": "attack", "from": Vector2i(0, 1), "to": Vector2i(0, 2) }),
			"attaque sur tank")
	eq(tank.hp, 4, "armure réduit les dégâts (2-1)")
	eq(grunt.xp, 1, "XP +1 pour avoir blessé")
	# shield blocks the first non-magic hit entirely
	var shieldy := TestUtil.put(state, Vector2i(1, 2), "shieldy", 1)
	var g2 := TestUtil.put(state, Vector2i(1, 1), "grunt", 0)
	var res := Rules.apply(state, { "type": "attack", "from": Vector2i(1, 1), "to": Vector2i(1, 2) })
	ok(has_event(res.events, "shield_break"), "bouclier brisé")
	eq(shieldy.hp, 2, "aucun dégât à travers le bouclier")
	eq(g2.xp, 0, "pas d'XP si les dégâts sont bloqués")
	eq(shieldy.shield, false, "bouclier consommé")
	# magic pierces armor and shield
	var mage := TestUtil.put(state, Vector2i(2, 1), "mage", 0)     # atk 2 magic
	var shieldy2 := TestUtil.put(state, Vector2i(2, 2), "shieldy", 1)
	applied(Rules.apply(state, { "type": "attack", "from": Vector2i(2, 1), "to": Vector2i(2, 2) }),
			"attaque magique")
	ok(state.board.at(Vector2i(2, 2)) == null, "magie ignore le bouclier (2 dégâts, mort)")
	eq(mage.xp, 2, "XP +2 pour un kill")


func test_riposte() -> void:
	var state := TestUtil.fresh_game()
	var grunt := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)   # 2/3
	var spiky := TestUtil.put(state, Vector2i(0, 2), "spiky", 1)   # 1/4, riposte 1
	applied(Rules.apply(state, { "type": "attack", "from": Vector2i(0, 1), "to": Vector2i(0, 2) }),
			"attaque sur spiky")
	eq(spiky.hp, 2, "spiky blessé")
	eq(grunt.hp, 2, "riposte 1 subie")
	# no riposte against ranged
	var archer := TestUtil.put(state, Vector2i(1, 1), "archer", 0)
	applied(Rules.apply(state, { "type": "attack", "from": Vector2i(1, 1), "to": Vector2i(0, 2) }),
			"tir sur spiky")
	eq(archer.hp, 2, "pas de riposte contre la distance")


func test_xp_level_up_and_kill_reward() -> void:
	var state := TestUtil.fresh_game()
	var grunt := TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	TestUtil.put(state, Vector2i(0, 2), "hasty", 1)  # 1/1
	var stones_before: int = state.players[0].stones
	var res := Rules.apply(state, { "type": "attack", "from": Vector2i(0, 1), "to": Vector2i(0, 2) })
	applied(res, "kill")
	eq(grunt.xp, 2, "XP de kill")
	eq(grunt.level, 2, "niveau 2 atteint (seuil 2)")
	eq(grunt.hp, grunt.max_hp(), "montée de niveau soigne complètement")
	eq(grunt.atk(), 3, "stats de niveau 2")
	eq(state.players[0].stones, stones_before + 1, "récompense de kill = niveau victime")
	ok(has_event(res.events, "kill_reward"), "événement kill_reward")


func test_kill_reward_grim_passive() -> void:
	var grim := TestUtil.master("grim", &"kill_bonus_stone")
	var state := TestUtil.fresh_game(1, grim, null)
	TestUtil.put(state, Vector2i(0, 1), "grunt", 0)
	TestUtil.put(state, Vector2i(0, 2), "hasty", 1)
	var before: int = state.players[0].stones
	Rules.apply(state, { "type": "attack", "from": Vector2i(0, 1), "to": Vector2i(0, 2) })
	eq(state.players[0].stones, before + 2, "passif Grim : +1 pierre de kill")


func test_master_damage_and_win() -> void:
	var state := TestUtil.fresh_game()
	state.players[1].master_hp = 2
	TestUtil.put(state, Vector2i(1, 1), "grunt", 0)
	var res := Rules.apply(state, { "type": "attack", "from": Vector2i(1, 1), "to": Vector2i(1, 3) })
	applied(res, "attaque du maître")
	eq(state.players[1].master_hp, 0, "maître à 0")
	eq(state.winner, 0, "joueur 0 gagne")
	eq(state.phase, GameState.Phase.OVER, "partie terminée")
	ok(has_event(res.events, "win"), "événement win")
	rejected(Rules.apply(state, { "type": "end_turn" }), "aucune action après la fin")


func test_aria_ranged_resist() -> void:
	var aria := TestUtil.master("aria", &"ranged_resist")
	var state := TestUtil.fresh_game(1, null, aria)
	TestUtil.put(state, Vector2i(2, 1), "archer", 0)  # atk 2 ranged, master exposed
	Rules.apply(state, { "type": "attack", "from": Vector2i(2, 1), "to": Vector2i(1, 3) })
	eq(state.players[1].master_hp, GameConst.MASTER_HP - 1, "passif Aria : -1 dégât distance")
