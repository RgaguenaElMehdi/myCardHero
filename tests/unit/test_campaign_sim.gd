extends TestCase
## Campaign completability: simulates the whole campaign — for each chapter,
## a MASTER-level "player" AI (with the collection available at that point)
## must be able to beat the chapter opponent within a bundle of seeded games.
## Also prints per-chapter win rates as a balance report.

const GAMES_PER_CHAPTER := 10
const DbScript := preload("res://scripts/autoload/db.gd")


func test_campaign_is_winnable() -> void:
	var data: Dictionary = DbScript.load_all()
	var cards: Dictionary = data.cards
	var collection: Dictionary = {}
	for id in data.campaign.starter.collection:
		collection[id] = int(data.campaign.starter.collection[id])
	var deck: Array = data.campaign.starter.deck.duplicate()
	var chapters: Array = data.campaign.chapters

	var real_i := 0                     # index parmi les vraies batailles :
	for i in chapters.size():           # les seeds restent stables quand on
		var ch: Dictionary = chapters[i]  # insère des leçons scriptées.
		if ch.has("mission"):
			continue      # leçon scriptée : gagnée par objectif, pas simulable ici
		var opp: Dictionary = ch.opponent
		var wins := 0
		var turns_total := 0
		for g in GAMES_PER_CHAPTER:
			var state := Rules.setup(cards,
					[data.masters[StringName("kiran")], data.masters[StringName(String(opp.master))]],
					[deck, opp.deck], 1000 * real_i + g)
			var player_ai := AiPlayer.new(AiPlayer.Level.MASTER, 100 + g)
			var enemy_ai := AiPlayer.new(int(opp.ai_level), 200 + g)
			var steps := 0
			while not state.is_over() and steps < 4000:
				steps += 1
				var actor := player_ai if state.current == 0 else enemy_ai
				var res := Rules.apply(state, actor.choose_action(state))
				if not res.ok:
					failures.append("%s : action illégale en simulation (%s)" % [ch.id, res.error])
					return
			if state.winner == 0:
				wins += 1
			turns_total += state.turn
		print("      [campagne] %s vs %s (IA niv %d) : %d/%d victoires, ~%d demi-tours"
				% [ch.id, opp.name, int(opp.ai_level), wins, GAMES_PER_CHAPTER,
				turns_total / GAMES_PER_CHAPTER])
		ok(wins >= 1, "%s doit être gagnable (%d/%d)" % [ch.id, wins, GAMES_PER_CHAPTER])
		# Grant rewards, then rebuild the proxy player deck from the collection.
		for id in ch.get("rewards", {}).get("cards", {}):
			collection[id] = int(collection.get(id, 0)) + int(ch.rewards.cards[id])
		deck = _build_deck(cards, collection)
		var err := Rules.validate_deck(cards, deck)
		eq(err, "", "deck simulé valide après %s" % ch.id)
		real_i += 1


## Curve-aware deck: ~13 monsters split cheap/mid/big, damage spells first,
## then utility, respecting owned copies.
func _build_deck(cards: Dictionary, collection: Dictionary) -> Array:
	var buckets := { "cheap": [], "mid": [], "big": [] }
	var dmg_spells: Array = []
	var other_spells: Array = []
	for id in collection:
		var def: CardDef = cards.get(StringName(String(id)))
		if def == null or def.token or int(collection[String(id)]) <= 0:
			continue
		if def.is_monster():
			if def.cost <= 1:
				buckets.cheap.append(def)
			elif def.cost <= 3:
				buckets.mid.append(def)
			else:
				buckets.big.append(def)
		else:
			var has_dmg := false
			for op in def.effect:
				if String(op.get("op", "")).begins_with("damage"):
					has_dmg = true
			(dmg_spells if has_dmg else other_spells).append(def)
	for key in buckets:
		buckets[key].sort_custom(func(a: CardDef, b: CardDef) -> bool:
			return _monster_score(a) > _monster_score(b))
	var deck: Array = []
	_take(deck, collection, buckets.cheap, 5)
	_take(deck, collection, buckets.mid, 16 - mini(deck.size(), 5) - 4)
	_take(deck, collection, buckets.big, 16 - deck.size())
	_take(deck, collection, buckets.mid, 16 - deck.size())
	_take(deck, collection, buckets.cheap, 16 - deck.size())
	dmg_spells.sort_custom(func(a: CardDef, b: CardDef) -> bool: return a.cost < b.cost)
	_take(deck, collection, dmg_spells, GameConst.DECK_SIZE - deck.size())
	_take(deck, collection, other_spells, GameConst.DECK_SIZE - deck.size())
	for bucket in [buckets.mid, buckets.big, buckets.cheap]:
		_take(deck, collection, bucket, GameConst.DECK_SIZE - deck.size())
	return deck


func _take(deck: Array, collection: Dictionary, defs: Array, slots: int) -> void:
	if slots <= 0:
		return
	var added := 0
	for def in defs:
		var id := String(def.id)
		var copies := mini(int(collection[id]), GameConst.MAX_COPIES)
		while deck.count(id) < copies and added < slots:
			deck.append(id)
			added += 1
		if added >= slots:
			return


func _monster_score(def: CardDef) -> float:
	var lv1: Dictionary = def.levels[0]
	var score := (int(lv1.atk) + int(lv1.hp) * 0.6) / maxf(def.cost, 1.0)
	if def.evolves_to != &"":
		score += 0.5
	if def.has_keyword(GameConst.KW_HASTE) or def.has_keyword(GameConst.KW_FLYING):
		score += 0.3
	return score