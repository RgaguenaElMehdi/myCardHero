extends Control
## Écran Événements : bonus actifs (appliqués automatiquement aux gains) et
## modes spéciaux jouables, planifiés localement (semaine / week-end).
## Définitions dans resources/data/events.json — structure dans events.tscn.

const ROW_SCENE: PackedScene = preload("res://scenes/widgets/quest_row.tscn")
const CURRENCY_ICONS := {
	"gold": "res://assets/sprites/ui/menu/icon_gold.png",
	"shards": "res://assets/sprites/ui/menu/icon_shard.png",
	"gems": "res://assets/sprites/ui/menu/icon_gem.png",
}


func _ready() -> void:
	if get_viewport_rect().size.x > 2000:
		%BG.texture = UiTheme.tex("res://assets/backgrounds/freeplay_2400.png")
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%BackBtn as Button).pressed.connect(UiTheme._click_sfx)

	for ev in Game.active_events():
		%ActiveList.add_child(_row(ev, true))
	var upcoming := Game.upcoming_events()
	%UpcomingPanel.visible = not upcoming.is_empty()
	for ev in upcoming:
		var row := _row(ev, false)
		row.modulate = Color(0.6, 0.6, 0.65)
		%UpcomingList.add_child(row)
	Audio.play_music("menu")


func _row(ev: Dictionary, active: bool) -> Control:
	var row := ROW_SCENE.instantiate()
	(row.get_node("%Icon") as TextureRect).texture = UiTheme.tex(String(ev.get("icon", "")))
	(row.get_node("%QLabel") as Label).text = String(ev.name)
	var desc := row.get_node("%QDesc") as Label
	desc.text = String(ev.desc)
	desc.visible = true
	(row.get_node("%QBar").get_parent() as Control).visible = false
	var reward: Dictionary = ev.get("win_reward", {})
	for kind in reward:
		(row.get_node("%RewardIcon") as TextureRect).texture = \
				UiTheme.tex(CURRENCY_ICONS.get(String(kind), CURRENCY_ICONS.gold))
		(row.get_node("%RewardLabel") as Label).text = "+%d / victoire" % int(reward[kind])
	if reward.is_empty():
		(row.get_node("%RewardIcon") as TextureRect).visible = false
	var btn := row.get_node("%ClaimBtn") as Button
	if not active:
		btn.text = "CE WEEK-END"
		btn.disabled = true
	elif String(ev.get("kind", "")) == "battle":
		btn.text = "JOUER  ❯"
		btn.pressed.connect(func() -> void: Game.start_event_battle(ev))
		btn.pressed.connect(UiTheme._click_sfx)
	else:
		btn.text = "✔  BONUS ACTIF"
		btn.disabled = true
	return row
