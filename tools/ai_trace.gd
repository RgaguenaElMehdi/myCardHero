extends SceneTree
## Trace une partie Maître(p0) vs Novice(p1) : actions + résumé par tour.
##   godot --headless --path . -s res://tools/ai_trace.gd

func _initialize() -> void:
	var DbScript := load("res://scripts/autoload/db.gd")
	var data: Dictionary = DbScript.load_all()
	var deck: Array = data.campaign.chapters[3].opponent.deck
	var state := Rules.setup(data.cards,
			[data.masters[&"kiran"], data.masters[&"kiran"]], [deck, deck], 9001)
	var ais := [AiPlayer.new(AiPlayer.Level.MASTER, 301), AiPlayer.new(AiPlayer.Level.NOVICE, 601)]
	var steps := 0
	var last_turn := -1
	while not state.is_over() and steps < 600:
		steps += 1
		if state.turn != last_turn:
			last_turn = state.turn
			var b0 := state.board.monsters_of(0).size()
			var b1 := state.board.monsters_of(1).size()
			print("--- demi-tour %d (j%d) | PV %d/%d | plateau %d vs %d | pierres %d/%d | main %d/%d"
					% [state.turn, state.current, state.players[0].master_hp,
					state.players[1].master_hp, b0, b1,
					state.players[0].stones, state.players[1].stones,
					state.players[0].hand.size(), state.players[1].hand.size()])
		var a: Dictionary = ais[state.current].choose_action(state)
		if a.type != "end_turn":
			print("  j%d %s" % [state.current, a])
		Rules.apply(state, a)
	print("VAINQUEUR : j%d (tour %d)" % [state.winner, state.turn])
	quit(0)
