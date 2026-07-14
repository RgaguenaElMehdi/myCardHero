extends Control
## Écran Défis PvE : modificateurs de règles (PV de départ, boss, deck imposé)
## définis dans resources/data/challenges.json. Le défi de la semaine (rotation)
## double sa récompense. Structure dans challenges.tscn — logique ici.

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
	(%FreeBtn as Button).pressed.connect(func() -> void: Game.goto("free_setup"))
	for b: Button in [%BackBtn, %FreeBtn]:
		b.pressed.connect(UiTheme._click_sfx)

	var weekly := Game.weekly_challenge()
	if not weekly.is_empty():
		%WeeklySlot.add_child(_row(weekly, true))
	for ch in Game.challenges():
		if String(ch.get("id", "")) != String(weekly.get("id", "")):
			%ChallengeList.add_child(_row(ch, false))
	Audio.play_music("menu")


func _row(ch: Dictionary, weekly: bool) -> Control:
	var row := ROW_SCENE.instantiate()
	(row.get_node("%Icon") as TextureRect).texture = \
			UiTheme.tex(Db.portrait_path(String(ch.opponent.master)))
	(row.get_node("%QLabel") as Label).text = String(ch.name)
	var desc := row.get_node("%QDesc") as Label
	desc.text = String(ch.desc)
	desc.visible = true
	(row.get_node("%QBar").get_parent() as Control).visible = false
	var mult := 2 if weekly else 1
	for kind in ch.get("reward", {}):
		(row.get_node("%RewardIcon") as TextureRect).texture = \
				UiTheme.tex(CURRENCY_ICONS.get(String(kind), CURRENCY_ICONS.gold))
		(row.get_node("%RewardLabel") as Label).text = "+%d" % (int(ch.reward[kind]) * mult)
	var btn := row.get_node("%ClaimBtn") as Button
	btn.text = "✓  REJOUER" if Game.challenge_done(String(ch.id)) else "JOUER  ❯"
	btn.pressed.connect(func() -> void: Game.start_challenge(ch))
	btn.pressed.connect(UiTheme._click_sfx)
	return row
