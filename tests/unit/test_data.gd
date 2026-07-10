extends TestCase
## Integrity of the real game data (resources/data/*.json), loaded through Db.

const DbScript := preload("res://scripts/autoload/db.gd")


func test_data_loads_without_errors() -> void:
	var result := DbScript.load_all()
	for err in result.errors:
		failures.append(err)


func test_content_counts() -> void:
	var result := DbScript.load_all()
	var constructible := 0
	var tokens := 0
	var spells := 0
	for id in result.cards:
		var c: CardDef = result.cards[id]
		if c.token:
			tokens += 1
		elif c.is_spell():
			spells += 1
			constructible += 1
		else:
			constructible += 1
	eq(constructible, 46, "46 cartes constructibles")
	eq(tokens, 8, "8 formes évoluées")
	eq(spells, 12, "12 sorts")
	eq(result.masters.size(), 8, "8 maîtres")
	eq(result.campaign.get("chapters", []).size(), 10, "10 chapitres")


func test_full_collection_reachable() -> void:
	## Starter + all chapter rewards must reach 2 copies of every constructible card.
	var result := DbScript.load_all()
	var owned := {}
	for id in result.campaign.starter.collection:
		owned[id] = owned.get(id, 0) + int(result.campaign.starter.collection[id])
	for ch in result.campaign.chapters:
		for id in ch.get("rewards", {}).get("cards", {}):
			owned[id] = owned.get(id, 0) + int(ch.rewards.cards[id])
	for id in result.cards:
		var c: CardDef = result.cards[id]
		if c.token:
			continue
		var copies := int(owned.get(String(id), 0))
		ok(copies == GameConst.MAX_COPIES,
				"collection complète : %s (%d/%d exemplaires)" % [id, copies, GameConst.MAX_COPIES])
	# all masters unlockable (starter grant + campaign rewards)
	var unlocked := {}
	for mid in result.campaign.starter.masters:
		unlocked[mid] = true
	for ch in result.campaign.chapters:
		for mid in ch.get("rewards", {}).get("masters", []):
			unlocked[mid] = true
	eq(unlocked.size(), 8, "8 maîtres déblocables")


func test_playable_matchup_from_data() -> void:
	## A real match can be set up from data decks and played (a few actions).
	var result := DbScript.load_all()
	var starter_deck: Array = result.campaign.starter.deck
	var ch1_deck: Array = result.campaign.chapters[0].opponent.deck
	var m0: MasterDef = result.masters[StringName("kiran")]
	var m1: MasterDef = result.masters[StringName("willow")]
	var state := Rules.setup(result.cards, [m0, m1], [starter_deck, ch1_deck], 123)
	applied(Rules.apply(state, { "type": "mulligan", "redraw": false }), "mulligan j0")
	applied(Rules.apply(state, { "type": "mulligan", "redraw": true }), "mulligan j1")
	eq(state.phase, GameState.Phase.MAIN, "partie démarrée avec les données réelles")
	var acts := Rules.legal_actions(state)
	ok(acts.size() > 1, "des actions disponibles")
	applied(Rules.apply(state, { "type": "end_turn" }), "fin de tour")
