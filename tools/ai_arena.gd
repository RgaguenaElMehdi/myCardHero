extends SceneTree
## Arène IA headless pour régler les niveaux :
##   godot --headless --path . -s res://tools/ai_arena.gd
## Duels miroirs seedés (mêmes maîtres, mêmes decks, sièges alternés) entre
## tous les couples de niveaux + un aperçu campagne (joueur Maître).

const GAMES := 40


func _initialize() -> void:
	var DbScript := load("res://scripts/autoload/db.gd")
	var data: Dictionary = DbScript.load_all()
	var deck: Array = data.campaign.chapters[3].opponent.deck
	for pair in [[AiPlayer.Level.MASTER, AiPlayer.Level.NOVICE, "Maître", "Novice"],
			[AiPlayer.Level.MASTER, AiPlayer.Level.ADEPT, "Maître", "Adepte"],
			[AiPlayer.Level.ADEPT, AiPlayer.Level.NOVICE, "Adepte", "Novice"]]:
		var wins := 0
		var draws := 0
		var wins_p0 := 0   # victoires du niveau haut quand il joue en premier
		var games_p0 := 0
		for g in GAMES:
			var hi_seat := g % 2
			var state := Rules.setup(data.cards,
					[data.masters[&"kiran"], data.masters[&"kiran"]], [deck, deck], 9000 + g)
			var ais := [null, null]
			ais[hi_seat] = AiPlayer.new(int(pair[0]), 300 + g)
			ais[1 - hi_seat] = AiPlayer.new(int(pair[1]), 600 + g)
			var steps := 0
			while not state.is_over() and steps < 4000:
				steps += 1
				var res := Rules.apply(state, ais[state.current].choose_action(state))
				if not res.ok:
					print("ILLEGAL %s" % res.error)
					quit(1)
					return
			if hi_seat == 0:
				games_p0 += 1
			if state.winner == hi_seat:
				wins += 1
				if hi_seat == 0:
					wins_p0 += 1
			elif state.winner == -1:
				draws += 1
		print("%s vs %s : %d/%d (%d nulles) — en 1er : %d/%d, en 2e : %d/%d"
				% [pair[2], pair[3], wins, GAMES, draws,
				wins_p0, games_p0, wins - wins_p0, GAMES - games_p0])
	quit(0)
