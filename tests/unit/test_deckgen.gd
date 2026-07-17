extends TestCase
## Générateur de deck IA (Db.build_guild_deck) : decks valides, dominés par la
## guilde, avec une vraie courbe de mana et des sorts — pas un remplissage naïf.

const DbScript := preload("res://scripts/autoload/db.gd")


func test_guild_deck_valid_curved_and_themed() -> void:
	var data: Dictionary = DbScript.load_all()
	var cards: Dictionary = data.cards
	for guild in [GameConst.Guild.FLAME, GameConst.Guild.SYLVAN,
			GameConst.Guild.SHADOW, GameConst.Guild.LIGHT]:
		var deck: Array = DbScript.build_guild_deck(cards, guild)
		eq(Rules.validate_deck(cards, deck), "", "deck valide (guilde %d)" % guild)

		var own := 0
		var monsters := 0
		var spells := 0
		var cheap := 0   # coût <= 2
		var big := 0     # coût >= 5
		for id in deck:
			var c: CardDef = cards[StringName(id)]
			if c.guild == guild:
				own += 1
			if c.is_monster():
				monsters += 1
				if c.cost <= 2:
					cheap += 1
				elif c.cost >= 5:
					big += 1
			else:
				spells += 1
		ok(own >= 15, "deck dominé par la guilde %d (%d/%d)" % [guild, own, deck.size()])
		ok(monsters >= 15, "assez de monstres (guilde %d : %d)" % [guild, monsters])
		ok(spells >= 3, "au moins quelques sorts (guilde %d : %d)" % [guild, spells])
		ok(cheap >= 4, "courbe : cartes bon marché (guilde %d : %d)" % [guild, cheap])
		ok(big >= 1, "courbe : au moins une grosse carte (guilde %d : %d)" % [guild, big])
