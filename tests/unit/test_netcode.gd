extends TestCase
## Netcode foundations: full-state serialization round-trip + per-player redaction.
## Pure (no transport) — validates the hardest, most security-critical pieces.

const DbScript := preload("res://scripts/autoload/db.gd")


func _setup_ctx() -> Dictionary:
	var result := DbScript.load_all()
	var m0: MasterDef = result.masters[StringName("kiran")]
	var m1: MasterDef = result.masters[StringName("willow")]
	var state := Rules.setup(result.cards, [m0, m1],
			[result.campaign.starter.deck, result.campaign.chapters[0].opponent.deck], 777)
	Rules.apply(state, { "type": "mulligan", "redraw": false })
	Rules.apply(state, { "type": "mulligan", "redraw": true })
	# summon one monster if legal, to exercise board serialization
	for a in Rules.legal_actions(state):
		if String(a.get("type", "")) == "summon":
			Rules.apply(state, a)
			break
	return { "state": state, "cards": result.cards, "masters": result.masters }


func test_state_roundtrip() -> void:
	var ctx := _setup_ctx()
	var state: GameState = ctx.state
	var back := GameState.from_dict(state.to_dict(), ctx.cards, ctx.masters)
	eq(back.turn, state.turn, "turn préservé")
	eq(back.current, state.current, "current préservé")
	eq(int(back.phase), int(state.phase), "phase préservée")
	eq(back.players.size(), 2, "2 joueurs")
	for i in 2:
		eq(back.players[i].master_hp, state.players[i].master_hp, "hp maître j%d" % i)
		eq(back.players[i].stones, state.players[i].stones, "pierres j%d" % i)
		eq(back.players[i].hand.size(), state.players[i].hand.size(), "taille main j%d" % i)
		eq(back.players[i].deck.size(), state.players[i].deck.size(), "taille deck j%d" % i)
		eq(String(back.players[i].master.id), String(state.players[i].master.id), "maître j%d" % i)
	eq(back.board.cells.size(), state.board.cells.size(), "monstres sur le plateau")
	for cell in state.board.cells:
		var a: MonsterInst = state.board.cells[cell]
		var b: MonsterInst = back.board.at(cell)
		ok(b != null, "monstre présent après round-trip")
		if b != null:
			eq(b.hp, a.hp, "hp monstre")
			eq(b.level, a.level, "niveau monstre")
			eq(String(b.def.id), String(a.def.id), "def monstre")


func test_redaction_hides_secrets() -> void:
	var ctx := _setup_ctx()
	var state: GameState = ctx.state
	var snap := NetRedact.snapshot_for(state, 0)
	ok(not snap.has("rng_seed") and not snap.has("rng_state"), "RNG jamais envoyé au client")
	var p0: Dictionary = snap.players[0]
	var p1: Dictionary = snap.players[1]
	for id in p0.hand:
		ok(not NetRedact.is_hidden(id), "ma main est visible")
	eq(p1.hand.size(), state.players[1].hand.size(), "taille main adverse préservée")
	for id in p1.hand:
		ok(NetRedact.is_hidden(id), "carte de la main adverse masquée")
	for i in 2:
		eq(snap.players[i].deck.size(), state.players[i].deck.size(),
				"taille deck j%d préservée" % i)
		for id in snap.players[i].deck:
			ok(NetRedact.is_hidden(id), "ordre du deck j%d masqué" % i)
	eq(snap.board.size(), state.board.cells.size(), "plateau public")


func test_redacted_snapshot_rebuilds_without_crash() -> void:
	# The client rebuilds a GameState from a redacted snapshot; hidden cards become
	# null defs (rendered face-down by the UI) — reconstruction must not crash.
	var ctx := _setup_ctx()
	var client_state := GameState.from_dict(
			NetRedact.snapshot_for(ctx.state, 1), ctx.cards, ctx.masters)
	eq(client_state.players.size(), 2, "état client reconstruit")
	eq(client_state.turn, ctx.state.turn, "tour cohérent côté client")
	eq(client_state.board.cells.size(), ctx.state.board.cells.size(), "plateau côté client")


func test_server_authoritative_flow() -> void:
	var result := DbScript.load_all()
	var srv := NetServerLogic.new()
	srv.setup(result.cards, [result.masters[&"kiran"], result.masters[&"willow"]],
			[result.campaign.starter.deck, result.campaign.chapters[0].opponent.deck], 42)
	# sequential mulligans (active player first)
	ok(srv.handle_action(srv.state().current, { "type": "mulligan", "redraw": false }).ok,
			"mulligan du joueur actif accepté")
	ok(srv.handle_action(srv.state().current, { "type": "mulligan", "redraw": true }).ok,
			"mulligan de l'autre joueur accepté")
	eq(int(srv.state().phase), int(GameState.Phase.MAIN), "phase principale atteinte")
	# out-of-turn action is rejected (anti-cheat)
	var cur := srv.state().current
	ok(not srv.handle_action(1 - cur, { "type": "end_turn" }).ok,
			"action hors-tour rejetée")
	# current player acts and everyone gets a redacted snapshot
	var res := srv.handle_action(cur, { "type": "end_turn" })
	ok(res.ok, "action du joueur courant acceptée")
	eq(res.snapshots.size(), 2, "un snapshot par joueur")
	for viewer in 2:
		for id in (res.snapshots[viewer].players[1 - viewer] as Dictionary).hand:
			ok(NetRedact.is_hidden(id), "snapshot j%d masque la main adverse" % viewer)
