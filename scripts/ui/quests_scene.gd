extends Control
## Écran Quêtes & Succès : quotidiennes / hebdomadaires (remise à zéro
## automatique) et succès à vie, avec réclamation des récompenses.
## Définitions dans resources/data/quests.json — structure dans quests.tscn.

const ROW_SCENE: PackedScene = preload("res://scenes/widgets/quest_row.tscn")
const QUEST_ICON := "res://assets/sprites/ui/menu/icon_quests.png"
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
	for tab: Button in [%TabDaily, %TabWeekly, %TabAch]:
		tab.pressed.connect(_rebuild)
		tab.pressed.connect(UiTheme._click_sfx)
	_rebuild()
	Audio.play_music("menu")


func _rebuild() -> void:
	for child in %QuestList.get_children():
		child.queue_free()
	if (%TabAch as Button).button_pressed:
		%ResetLabel.text = "Progression à vie"
		for a in Game.achievements():
			%QuestList.add_child(_ach_row(a))
	else:
		var weekly: bool = (%TabWeekly as Button).button_pressed
		%ResetLabel.text = "Remise à zéro chaque %s" % ("semaine" if weekly else "jour")
		var scope := "w" if weekly else "d"
		var defs := Game.weekly_quests() if weekly else Game.daily_quests()
		for i in defs.size():
			%QuestList.add_child(_quest_row(scope, i, defs[i]))


func _quest_row(scope: String, idx: int, quest: Dictionary) -> Control:
	var goal := int(quest.goal)
	var done := mini(Game.quest_progress(scope, String(quest.key)), goal)
	var claimed: bool = Game.quest_state().get(scope + "claimed", []).has(idx)
	var row := _base_row(String(quest.label), "", QUEST_ICON, done, goal,
			quest.get("reward", {}), claimed)
	(row.get_node("%ClaimBtn") as Button).pressed.connect(func() -> void:
		if not Game.claim_quest(scope, idx).is_empty():
			Audio.play_sfx("levelup")
			_rebuild())
	return row


func _ach_row(a: Dictionary) -> Control:
	var goal := int(a.goal)
	var done := mini(Game.achievement_stat(String(a.stat)), goal)
	var claimed: bool = Game.profile.get("ach_claimed", []).has(String(a.id))
	var row := _base_row(String(a.label), String(a.desc),
			String(a.get("icon", QUEST_ICON)), done, goal, a.get("reward", {}), claimed)
	(row.get_node("%ClaimBtn") as Button).pressed.connect(func() -> void:
		if not Game.claim_achievement(a).is_empty():
			Audio.play_sfx("levelup")
			_rebuild())
	return row


func _base_row(label: String, desc: String, icon: String, done: int, goal: int,
		reward: Dictionary, claimed: bool) -> Control:
	var row := ROW_SCENE.instantiate()
	(row.get_node("%Icon") as TextureRect).texture = UiTheme.tex(icon)
	(row.get_node("%QLabel") as Label).text = label
	if desc != "":
		(row.get_node("%QDesc") as Label).text = desc
		(row.get_node("%QDesc") as Label).visible = true
	var bar := row.get_node("%QBar") as ProgressBar
	bar.max_value = goal
	bar.value = done
	(row.get_node("%QCount") as Label).text = "%d / %d" % [done, goal]
	# Récompense (une seule monnaie par quête dans quests.json).
	for kind in reward:
		(row.get_node("%RewardIcon") as TextureRect).texture = \
				UiTheme.tex(CURRENCY_ICONS.get(String(kind), CURRENCY_ICONS.gold))
		(row.get_node("%RewardLabel") as Label).text = "+%d" % int(reward[kind])
	var btn := row.get_node("%ClaimBtn") as Button
	if claimed:
		btn.text = "✔  RÉCLAMÉE"
		btn.disabled = true
		row.modulate = Color(0.62, 0.62, 0.66)
	elif done < goal:
		btn.text = "EN COURS…"
		btn.disabled = true
	else:
		btn.pressed.connect(UiTheme._click_sfx)
	return row
