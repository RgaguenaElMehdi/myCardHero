extends SceneTree
## Équilibre des maîtres : round-robin des 8 maîtres, chacun avec le deck généré
## de sa guilde, IA Maître des deux côtés, premier joueur alterné (neutralise
## l'avantage d'ouverture). Tally du winrate par maître.
##   godot --headless --path . -s res://tools/master_arena.gd

const GAMES := 12  # parties par paire (sièges alternés)


func _initialize() -> void:
	var Db := load("res://scripts/autoload/db.gd")
	var data: Dictionary = Db.load_all()
	var ids := ["kiran", "brand", "willow", "rowan", "grim", "vane", "aria", "sol"]
	var decks := {}
	for id in ids:
		var m: MasterDef = data.masters[StringName(id)]
		decks[id] = Db.build_guild_deck(data.cards, m.guild)

	var wins := {}
	var played := {}
	for id in ids:
		wins[id] = 0
		played[id] = 0

	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			for g in GAMES:
				var first := g % 2  # alterner qui ouvre
				var state := Rules.setup(data.cards,
						[data.masters[StringName(a)], data.masters[StringName(b)]],
						[decks[a], decks[b]], 4000 + i * 100 + j * 10 + g, first)
				var ais := [AiPlayer.new(AiPlayer.Level.MASTER, 11 + g),
						AiPlayer.new(AiPlayer.Level.MASTER, 77 + g)]
				var steps := 0
				while not state.is_over() and steps < 4000:
					steps += 1
					Rules.apply(state, ais[state.current].choose_action(state))
				played[a] += 1
				played[b] += 1
				if state.winner == 0:
					wins[a] += 1
				elif state.winner == 1:
					wins[b] += 1

	# Tri par winrate décroissant.
	var rows := []
	for id in ids:
		var wr: float = 100.0 * int(wins[id]) / maxf(played[id], 1)
		rows.append([id, wr, wins[id], played[id]])
	rows.sort_custom(func(x, y): return x[1] > y[1])
	print("=== Winrate des maîtres (round-robin, IA Maître, %d parties/paire) ===" % GAMES)
	for r in rows:
		var m: MasterDef = data.masters[StringName(r[0])]
		var guild_names := ["Flamme", "Sylve", "Ombre", "Lumière"]
		print("  %-8s %-8s %5.1f%%  (%d/%d)"
				% [r[0], guild_names[int(m.guild)], r[1], r[2], r[3]])
	quit(0)
