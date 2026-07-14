extends Control
## Passe de saison : piste horizontale de niveaux (récompense par niveau,
## réclamable une fois le niveau atteint), XP gagnée en jouant. Saison = mois
## calendaire. Config déclarative dans resources/data/season_pass.json,
## règles pures dans scripts/core/season.gd.

const CURRENCY_ICONS := {
	"gold": "res://assets/sprites/ui/menu/icon_gold.png",
	"shards": "res://assets/sprites/ui/menu/icon_shard.png",
	"gems": "res://assets/sprites/ui/menu/icon_gem.png",
}
const MONTHS := ["", "JANVIER", "FÉVRIER", "MARS", "AVRIL", "MAI", "JUIN",
		"JUILLET", "AOÛT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DÉCEMBRE"]
const GOLD := Color(0.902, 0.765, 0.353)
const DIM := Color(0.55, 0.53, 0.48)

var _chips := {}   ## niveau -> Button


func _ready() -> void:
	if get_viewport_rect().size.x > 2000:
		%BG.texture = UiTheme.tex("res://assets/backgrounds/freeplay_2400.png")
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%BackBtn as Button).pressed.connect(UiTheme._click_sfx)
	(%ClaimAllBtn as Button).pressed.connect(_claim_all)
	(%ClaimAllBtn as Button).pressed.connect(UiTheme._click_sfx)

	%Title.text = "—  PASSE DE %s  —" % MONTHS[Time.get_datetime_dict_from_system().month]
	_tick_season()
	var t := Timer.new()
	t.wait_time = 60.0
	t.timeout.connect(_tick_season)
	add_child(t)
	t.start()

	var cfg := Game.season_config()
	for level in range(1, int(cfg.get("levels", 100)) + 1):
		var chip := _make_chip(level, Season.reward_for(level, cfg))
		_chips[level] = chip
		%Track.add_child(chip)
	_refresh()
	_scroll_to_current.call_deferred()
	Audio.play_music("menu")


## Une pastille de niveau : numéro, récompense, état (réclamée / prête / à venir).
func _make_chip(level: int, reward: Dictionary) -> Button:
	var chip := Button.new()
	chip.custom_minimum_size = Vector2(150, 0)
	chip.theme_type_variation = &"MenuTabButton"
	chip.pressed.connect(_claim.bind(level))
	var v := VBoxContainer.new()
	v.name = "V"
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lvl := UiTheme.label("NIV. %d" % level, 17, GOLD)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := UiTheme.title_font()
	if f != null:
		lvl.add_theme_font_override("font", f)
	v.add_child(lvl)
	for kind in reward:
		var icon := TextureRect.new()
		icon.texture = UiTheme.tex(CURRENCY_ICONS.get(String(kind), CURRENCY_ICONS.gold))
		icon.custom_minimum_size = Vector2(0, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(icon)
		var amount := UiTheme.label("+%d" % int(reward[kind]), 18, Color(0.96, 0.93, 0.85))
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if f != null:
			amount.add_theme_font_override("font", f)
		v.add_child(amount)
	var state := UiTheme.label("", 14, DIM)
	state.name = "State"
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(state)
	chip.add_child(v)
	return chip


func _refresh() -> void:
	var cfg := Game.season_config()
	var xp := int(Game.season_state().get("xp", 0))
	var level := Game.season_level()
	var per := maxi(1, int(cfg.get("xp_per_level", 100)))
	var claimed: Array = Game.season_state().get("claimed", [])
	%PassLevel.text = "NIV. %d" % level
	(%PassXpBar as ProgressBar).max_value = per
	(%PassXpBar as ProgressBar).value = xp % per if level < int(cfg.get("levels", 100)) else per
	%PassXpLabel.text = "%d XP — encore %d XP avant le niveau %d" \
			% [xp, per - (xp % per), level + 1] if level < int(cfg.get("levels", 100)) \
			else "%d XP — passe terminé, bravo !" % xp
	var claimable := 0
	for l: int in _chips:
		var chip: Button = _chips[l]
		var state := chip.get_node("V/State") as Label
		if claimed.has(l):
			chip.modulate = Color(0.55, 0.55, 0.6)
			chip.disabled = true
			state.text = "✔ Réclamée"
		elif l <= level:
			chip.modulate = Color(1.15, 1.1, 0.95)
			state.text = "RÉCLAMER !"
			state.add_theme_color_override("font_color", GOLD)
			claimable += 1
		else:
			chip.modulate = Color(0.72, 0.72, 0.76)
			state.text = "À venir"
	(%ClaimAllBtn as Button).disabled = claimable == 0
	(%ClaimAllBtn as Button).text = "TOUT RÉCLAMER (%d)" % claimable if claimable > 0 \
			else "TOUT RÉCLAMER"


func _claim(level: int) -> void:
	if not Game.claim_season_level(level).is_empty():
		Audio.play_sfx("levelup")
	_refresh()


func _claim_all() -> void:
	var got := false
	for l in range(1, Game.season_level() + 1):
		if not Game.claim_season_level(l).is_empty():
			got = true
	if got:
		Audio.play_sfx("levelup")
	_refresh()


## Centre la piste sur le niveau courant.
func _scroll_to_current() -> void:
	await get_tree().process_frame
	var level := maxi(Game.season_level(), 1)
	if _chips.has(level):
		var chip: Control = _chips[level]
		(%TrackScroll as ScrollContainer).scroll_horizontal = \
				maxi(0, int(chip.position.x - %TrackScroll.size.x / 2.0 + chip.size.x / 2.0))


## Compte à rebours réel jusqu'à la fin du mois (fin de saison).
func _tick_season() -> void:
	var now := Time.get_datetime_dict_from_system()
	var end := { "year": now.year, "month": now.month + 1, "day": 1,
			"hour": 0, "minute": 0, "second": 0 }
	if end.month > 12:
		end.month = 1
		end.year += 1
	var secs := Time.get_unix_time_from_datetime_dict(end) \
			- Time.get_unix_time_from_datetime_dict(now)
	%SeasonEnds.text = "Fin de saison dans %dj %dh" % [int(secs) / 86400, (int(secs) % 86400) / 3600]
