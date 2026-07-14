extends Control
## Hub Arène (mockup utilisateur, style bleu nuit/doré) : modes à gauche
## (Classé / Non classé / Amical + Historique / Récompenses), rang actuel au
## centre (blason teinté, progression vers la division suivante), rangée des
## paliers, puis quêtes du jour, stats et COMBATTRE en bas.
## Structure dans arena_hub[_mobile].tscn — logique seulement ici.

## Quêtes du jour : [compteur profil, objectif, libellé]
const QUESTS := [
	["wins", 3, "Gagner 3 combats"],
	["powers", 10, "Utiliser 10 pouvoirs"],
	["wins", 1, "Remporter 1 victoire"],
]

const GOLD := Color(0.902, 0.765, 0.353)
const DIM := Color(0.55, 0.52, 0.46)

var _mode := "ranked"                       # ranked | casual | friendly


func _ready() -> void:
	var r := LocalBackend.new().rating()
	_fill_rank(r)
	_fill_stats(r)
	_build_tiers(float(r.rating))
	_fill_quests()

	var cur: Dictionary = Game.profile.get("currency", {})
	%GoldLabel.text = UiTheme.fmt_thousands(int(cur.get("gold", 0)))
	%ShardLabel.text = UiTheme.fmt_thousands(int(cur.get("shards", 0)))

	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%NavRanked as Button).pressed.connect(_pick_mode.bind("ranked"))
	(%NavCasual as Button).pressed.connect(_pick_mode.bind("casual"))
	(%NavFriendly as Button).pressed.connect(_pick_mode.bind("friendly"))
	(%HistoryBtn as Button).pressed.connect(func() -> void:
		_show_info("HISTORIQUE", "Bilan de saison :\n%d victoires — %d défaites" % [
				int(r.get("wins", 0)), int(r.get("losses", 0))]))
	(%RewardsBtn as Button).pressed.connect(func() -> void:
		_show_info("RÉCOMPENSES", "Les récompenses de rang seront\ndistribuées en fin de saison."))
	(%LadderBtn as Button).pressed.connect(func() -> void:
		var lines: PackedStringArray = []
		for e in LocalBackend.new().leaderboard():
			lines.append("%s — %d" % [e.name, int(e.rating)])
		_show_info("CLASSEMENT", "\n".join(lines)))
	(%FightBtn as Button).pressed.connect(_fight)
	(%InfoCloseBtn as Button).pressed.connect(func() -> void: %InfoPopup.visible = false)
	for b: Button in [%BackBtn, %NavRanked, %NavCasual, %NavFriendly, %HistoryBtn,
			%RewardsBtn, %LadderBtn, %FightBtn, %InfoCloseBtn]:
		b.pressed.connect(UiTheme._click_sfx)

	_pick_mode("ranked")
	_tick_season()
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_tick_season)
	add_child(t)
	t.start()
	_animate_fight_btn.call_deferred()
	Audio.play_music("menu")


# ---- rang / paliers ---------------------------------------------------------

func _tier_of(rating: float) -> Array:
	for t in LocalBackend.TIERS:
		if rating < float(t[2]):
			return t
	return LocalBackend.TIERS[-1]


func _fill_rank(r: Dictionary) -> void:
	var rating := float(r.rating)
	var tier := _tier_of(rating)
	%RankLabel.text = LocalBackend.rank_name(rating)
	(%RankCrest as TextureRect).modulate = LocalBackend.TIER_COLORS.get(String(tier[0]), Color.WHITE)
	if String(tier[0]) == "MAÎTRE":
		(%RankBar as ProgressBar).max_value = 1
		(%RankBar as ProgressBar).value = 1
		%RankPoints.text = str(int(round(rating)))
		%RankHint.text = "Vous êtes au sommet — défendez votre titre !"
		return
	var lo := maxf(float(tier[1]), 0.0)
	var hi := float(tier[2])
	(%RankBar as ProgressBar).max_value = hi - lo
	(%RankBar as ProgressBar).value = clampf(rating - lo, 0.0, hi - lo)
	%RankPoints.text = "%d / %d" % [int(round(rating)), int(hi)]
	var next_i := LocalBackend.TIERS.find(tier) + 1
	%RankHint.text = "Remportez encore %d points pour atteindre %s." \
			% [int(ceil(hi - rating)), String(LocalBackend.TIERS[next_i][0]).capitalize()]


## Rangée des paliers : une carte par palier, celui du joueur mis en avant.
func _build_tiers(rating: float) -> void:
	var current := _tier_of(rating)
	for t in LocalBackend.TIERS:
		var is_current: bool = t == current
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.12, 0.95)
		sb.set_border_width_all(2 if not is_current else 3)
		sb.border_color = GOLD if is_current else Color(0.35, 0.3, 0.18)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(150, 0)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 6)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.texture = UiTheme.tex("res://assets/sprites/ui/battle/rank_crest.png")
		ic.custom_minimum_size = Vector2(0, 84)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = LocalBackend.TIER_COLORS.get(String(t[0]), Color.WHITE)
		if not is_current:
			ic.modulate = ic.modulate.darkened(0.25)
		vb.add_child(ic)
		var name := UiTheme.label(String(t[0]), 18, GOLD if is_current else DIM)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var f := UiTheme.title_font()
		if f != null:
			name.add_theme_font_override("font", f)
		vb.add_child(name)
		var range_txt := "%d+" % int(t[1]) if String(t[0]) == "MAÎTRE" \
				else "%d – %d" % [int(t[1]), int(t[2]) - 1]
		var rl := UiTheme.label(range_txt, 14, Color(0.72, 0.68, 0.6))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(rl)
		card.add_child(vb)
		%TiersRow.add_child(card)


# ---- stats / quêtes ---------------------------------------------------------

func _fill_stats(r: Dictionary) -> void:
	var wins := int(r.get("wins", 0))
	var losses := int(r.get("losses", 0))
	%WinsLabel.text = str(wins)
	%LossesLabel.text = str(losses)
	%RatioLabel.text = "%d%%" % roundi(100.0 * wins / maxi(wins + losses, 1))
	var streak := int(r.get("streak", 0))
	%StreakLabel.text = ("🔥 %d" % streak) if streak > 0 else "—"


func _fill_quests() -> void:
	var q := Game.quest_state()
	for i in QUESTS.size():
		var done: int = mini(int(q.get(QUESTS[i][0], 0)), int(QUESTS[i][1]))
		var goal: int = QUESTS[i][1]
		(get_node("%%Quest%dLabel" % i) as Label).text = QUESTS[i][2]
		(get_node("%%Quest%dCount" % i) as Label).text = "%d/%d" % [done, goal]
		var bar := get_node("%%Quest%dBar" % i) as ProgressBar
		bar.max_value = goal
		bar.value = done


# ---- modes / combat ---------------------------------------------------------

func _pick_mode(mode: String) -> void:
	_mode = mode
	var navs := { "ranked": %NavRanked, "casual": %NavCasual, "friendly": %NavFriendly }
	for key in navs:
		(navs[key] as Button).set_pressed_no_signal(key == mode)
		(navs[key] as Button).modulate = Color(1.25, 1.2, 1.05) if key == mode \
				else Color(0.72, 0.7, 0.66)
	%ModeHint.text = "Mode : " + { "ranked": "Classé", "casual": "Non classé",
			"friendly": "Amical" }[mode]


func _fight() -> void:
	match _mode:
		"friendly":
			Game.goto("online_lobby")
		"casual":
			Game.matchmaking_ranked = false
			Game.goto("matchmaking")
		_:
			Game.matchmaking_ranked = true
			Game.goto("matchmaking")


# ---- divers -----------------------------------------------------------------

## Compte à rebours jusqu'à la fin du mois courant (saison locale).
func _tick_season() -> void:
	var now := Time.get_datetime_dict_from_system()
	var end := { "year": now.year, "month": now.month + 1, "day": 1,
			"hour": 0, "minute": 0, "second": 0 }
	if end.month > 12:
		end.month = 1
		end.year += 1
	var secs := Time.get_unix_time_from_datetime_dict(end) \
			- Time.get_unix_time_from_datetime_dict(now)
	var d := int(secs) / 86400
	var h := (int(secs) % 86400) / 3600
	var m := (int(secs) % 3600) / 60
	%SeasonLabel.text = "✦ Saison — Fin dans %dj %dh %dm" % [d, h, m]


## Bouton COMBATTRE : léger battement d'échelle + éclat doré.
func _animate_fight_btn() -> void:
	await get_tree().process_frame
	var btn := %FightBtn as Button
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 1.0)
	tw.parallel().tween_property(btn, "modulate", Color(1.2, 1.12, 0.92), 1.0)
	tw.tween_property(btn, "scale", Vector2.ONE, 1.0)
	tw.parallel().tween_property(btn, "modulate", Color.WHITE, 1.0)


func _show_info(title: String, text: String) -> void:
	%InfoTitle.text = title
	%InfoLabel.text = text
	%InfoPopup.visible = true
