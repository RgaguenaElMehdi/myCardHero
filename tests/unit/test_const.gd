extends TestCase
## Palette de guilde : source unique dans GameConst.

func test_guild_colors_present_for_every_guild() -> void:
	for g in [GameConst.Guild.FLAME, GameConst.Guild.SYLVAN,
			GameConst.Guild.SHADOW, GameConst.Guild.LIGHT]:
		ok(GameConst.GUILD_COLORS.has(g), "couleur manquante pour guilde %d" % g)

func test_uitheme_delegates_to_gameconst() -> void:
	eq(UiTheme.guild_color(GameConst.Guild.FLAME),
			GameConst.GUILD_COLORS[GameConst.Guild.FLAME],
			"UiTheme.guild_color doit refleter GameConst")
