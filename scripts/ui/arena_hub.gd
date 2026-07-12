extends Control
## Hub Arène (mockup utilisateur) : rang actuel (Glicko-2 local), bilan
## victoires/défaites, récompenses de rang, saison en cours, quêtes
## quotidiennes et bouton COMBATTRE (popup de modes).
## Structure dans arena_hub[_mobile].tscn — logique seulement ici.

const FREE_SETUP := preload("res://scenes/widgets/free_setup.tscn")
const MODE_SELECT := preload("res://scenes/widgets/mode_select.tscn")

## Quêtes du jour : [compteur profil, objectif, libellé]
const QUESTS := [
	["wins", 3, "Gagner 3 combats"],
	["powers", 10, "Utiliser 10 pouvoirs"],
	["wins", 1, "Remporter 1 victoire"],
]

@onready var rank_label: Label = %RankLabel
@onready var wins_label: Label = %WinsLabel
@onready var losses_label: Label = %LossesLabel
@onready var season_label: Label = %SeasonLabel
@onready var fight_btn: Button = %FightBtn
@onready var back_btn: Button = %BackBtn
@onready var ladder_btn: Button = %LadderBtn
@onready var history_btn: Button = %HistoryBtn
@onready var rewards_btn: Button = %RewardsBtn
@onready var all_quests_btn: Button = %AllQuestsBtn
@onready var info_popup: PanelContainer = %InfoPopup
@onready var info_label: Label = %InfoLabel


func _ready() -> void:
	var r := LocalBackend.new().rating()
	rank_label.text = LocalBackend.rank_name(float(r.rating))
	wins_label.text = str(int(r.get("wins", 0)))
	losses_label.text = str(int(r.get("losses", 0)))

	var q := Game.quest_state()
	for i in QUESTS.size():
		var done: int = mini(int(q.get(QUESTS[i][0], 0)), int(QUESTS[i][1]))
		var goal: int = QUESTS[i][1]
		(get_node("%%Quest%dLabel" % i) as Label).text = QUESTS[i][2]
		(get_node("%%Quest%dCount" % i) as Label).text = "%d/%d" % [done, goal]
		var bar := get_node("%%Quest%dBar" % i) as ProgressBar
		bar.max_value = goal
		bar.value = done

	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))
	fight_btn.pressed.connect(_show_mode_select)
	ladder_btn.pressed.connect(func() -> void:
		_show_info("CLASSEMENT", "Votre cote : %d\nRang : %s" % [
				int(round(float(r.rating))), LocalBackend.rank_name(float(r.rating))]))
	history_btn.pressed.connect(func() -> void:
		_show_info("HISTORIQUE", "Bilan de saison :\n%d victoires — %d défaites" % [
				int(r.get("wins", 0)), int(r.get("losses", 0))]))
	rewards_btn.pressed.connect(func() -> void:
		_show_info("RÉCOMPENSES", "Les récompenses de rang seront\ndistribuées en fin de saison."))
	all_quests_btn.pressed.connect(func() -> void:
		_show_info("QUÊTES", "De nouvelles quêtes chaque jour !\nRevenez demain pour la suite."))
	%InfoCloseBtn.pressed.connect(func() -> void: info_popup.visible = false)
	for b: Button in [fight_btn, back_btn, ladder_btn, history_btn,
			rewards_btn, all_quests_btn]:
		b.pressed.connect(UiTheme._click_sfx)

	_tick_season()
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_tick_season)
	add_child(t)
	t.start()

	_animate_fight_btn.call_deferred()


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
	season_label.text = "Fin dans : %dj %dh %dm" % [d, h, m]


## Bouton COMBATTRE : halo doré pulsé derrière + léger battement d'échelle.
func _animate_fight_btn() -> void:
	await get_tree().process_frame
	# Halo lumineux placé DERRIÈRE le bouton (glow "flamme dorée").
	var glow := TextureRect.new()
	var orb := UiTheme.tex("res://assets/sprites/ui/gold/orb_endturn.png")
	glow.texture = orb
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.modulate = Color(1.0, 0.85, 0.45, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = fight_btn.position - Vector2(60, 40)
	glow.size = fight_btn.size + Vector2(120, 80)
	fight_btn.get_parent().add_child(glow)
	fight_btn.get_parent().move_child(glow, fight_btn.get_index())

	fight_btn.pivot_offset = fight_btn.size / 2.0
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "modulate:a", 0.55, 1.0)
	tw.parallel().tween_property(fight_btn, "scale", Vector2(1.03, 1.03), 1.0)
	tw.parallel().tween_property(fight_btn, "modulate", Color(1.25, 1.15, 0.9), 1.0)
	tw.tween_property(glow, "modulate:a", 0.1, 1.0)
	tw.parallel().tween_property(fight_btn, "scale", Vector2.ONE, 1.0)
	tw.parallel().tween_property(fight_btn, "modulate", Color.WHITE, 1.0)


func _show_info(title: String, text: String) -> void:
	%InfoTitle.text = title
	info_label.text = text
	info_popup.visible = true


func _show_mode_select() -> void:
	var popup: Control = MODE_SELECT.instantiate()
	popup.chose_free.connect(_show_free_setup)
	popup.chose_normal.connect(func() -> void:
		Game.matchmaking_ranked = false
		Game.goto("matchmaking"))
	popup.chose_ranked.connect(func() -> void:
		Game.matchmaking_ranked = true
		Game.goto("matchmaking"))
	add_child(popup)


func _show_free_setup() -> void:
	var setup: Control = FREE_SETUP.instantiate()
	setup.launched.connect(func(_master_id: String, level: int) -> void:
		var chapters := Db.chapters()
		var ch: Dictionary = chapters[randi() % chapters.size()]
		Game.start_free_battle(level, String(ch.opponent.master), ch.opponent.deck))
	add_child(setup)
