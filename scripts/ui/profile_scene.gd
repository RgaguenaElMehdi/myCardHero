extends Control
## Écran Profil : identité (avatar, nom éditable, titre auto, niveau/XP, rang,
## ancienneté), statistiques réelles (bilan classé, collection, campagne),
## maître favori (le plus joué dans les decks) et badges calculés.
## Structure dans profile[_mobile].tscn — logique seulement ici (règle n°1).

const BADGE_CHIP: PackedScene = preload("res://scenes/widgets/badge_chip.tscn")

## Titre affiché sous le nom : automatique selon le niveau.
const TITLES := [
	[30, "Légende de Stonebound"],
	[20, "Champion de Petraheim"],
	[10, "Adepte des Pierres"],
	[0, "Apprenti Maître"],
]


func _ready() -> void:
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%BackBtn as Button).pressed.connect(UiTheme._click_sfx)
	var name_edit := %NameEdit as LineEdit
	name_edit.text_submitted.connect(func(_t: String) -> void: _save_name())
	name_edit.focus_exited.connect(_save_name)
	_fill()
	Audio.play_music("menu")


func _fill() -> void:
	var p: Dictionary = Game.profile.get("player", {})
	(%NameEdit as LineEdit).text = str(p.get("name", "Joueur"))
	var level := int(p.get("level", 1))
	for t in TITLES:
		if level >= int(t[0]):
			%TitleLabel.text = str(t[1])
			break
	%LevelLabel.text = "NIVEAU %d" % level
	(%XpBar as ProgressBar).max_value = maxi(1, int(p.get("xp_next", 100)))
	(%XpBar as ProgressBar).value = int(p.get("xp", 0))
	%XpPts.text = "%s / %s XP" % [UiTheme.fmt_thousands(int(p.get("xp", 0))),
			UiTheme.fmt_thousands(int(p.get("xp_next", 100)))]
	%CreatedLabel.text = "Maître depuis le %s" % _fr_date(str(p.get("created", "")))

	# Rang classé (local).
	var r := LocalBackend.new().rating()
	var rating := float(r.rating)
	var tier := LocalBackend.tier_of(rating)
	(%RankCrest as TextureRect).modulate = \
			LocalBackend.TIER_COLORS.get(String(tier[0]), Color.WHITE)
	%RankName.text = LocalBackend.rank_name(rating)
	%RankPts.text = "%d points de ligue" % int(round(rating))

	# Statistiques réelles.
	var wins := int(r.get("wins", 0))
	var losses := int(r.get("losses", 0))
	var games := wins + losses
	%StatWins.text = str(wins)
	%StatLosses.text = str(losses)
	%StatRatio.text = "%d%%" % roundi(100.0 * wins / maxi(games, 1))
	var streak := int(r.get("streak", 0))
	%StatStreak.text = ("🔥 %d" % streak) if streak > 0 else "—"
	%StatGames.text = str(games)
	var distinct := 0
	for id in Game.profile.get("collection", {}):
		if Game.owned_count(String(id)) > 0:
			distinct += 1
	%StatCards.text = "%d / %d" % [distinct, Db.cards.size()]
	%StatMasters.text = "%d / %d" % [Game.profile.get("masters", []).size(), Db.masters.size()]
	%StatChapters.text = "%d / %d" % [int(Game.profile.get("campaign_progress", 0)),
			Db.chapters().size()]

	_fill_fav_master()
	_fill_badges(wins, losses, streak, level, distinct)


## Maître favori = le plus présent dans les decks sauvegardés.
func _fill_fav_master() -> void:
	var counts := {}
	for deck in Game.profile.get("decks", []):
		var m := String(deck.get("master", ""))
		counts[m] = int(counts.get(m, 0)) + 1
	var best := ""
	for m in counts:
		if best == "" or int(counts[m]) > int(counts[best]):
			best = m
	var def: MasterDef = Db.master(StringName(best)) if best != "" else null
	if def == null:
		%FavPanel.visible = false
		return
	(%FavPortrait as TextureRect).texture = UiTheme.tex(def.portrait)
	%FavName.text = def.display_name
	%FavTitle.text = def.title


## Badges = les succès (quests.json), débloqués d'abord, 8 affichés au plus
## (la liste complète vit sur l'écran Quêtes & Succès).
func _fill_badges(_wins: int, _losses: int, _streak: int, _level: int, _distinct: int) -> void:
	var achs := Game.achievements().duplicate()
	achs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(Game.achievement_unlocked(a)) > int(Game.achievement_unlocked(b)))
	for a: Dictionary in achs.slice(0, 8):
		var chip: Control = BADGE_CHIP.instantiate()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(chip.get_node("%Icon") as TextureRect).texture = UiTheme.tex(String(a.get("icon", "")))
		(chip.get_node("%Name") as Label).text = String(a.label)
		(chip.get_node("%Desc") as Label).text = String(a.desc)
		if not Game.achievement_unlocked(a):
			chip.modulate = Color(0.5, 0.5, 0.55)
			(chip.get_node("%Desc") as Label).text += "  🔒"
		%BadgeGrid.add_child(chip)


func _save_name() -> void:
	var name := (%NameEdit as LineEdit).text.strip_edges()
	if name.is_empty():
		(%NameEdit as LineEdit).text = str(Game.profile.player.get("name", "Joueur"))
		return
	if name != str(Game.profile.player.get("name", "")):
		Game.profile.player["name"] = name
		Game.save_profile()
		Game.profile_changed.emit()


func _fr_date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3:
		return "aujourd'hui"
	return "%s/%s/%s" % [parts[2], parts[1], parts[0]]
