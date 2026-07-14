extends Control
## Écran SÉLECTION (mockup utilisateur) : quatre modes de jeu illustrés —
## Solo (partie libre vs IA), Histoire (campagne), Défi (IA maximale),
## Arène (classé, hub). Structure dans selection[_mobile].tscn — logique ici.

const FREE_SETUP := preload("res://scenes/widgets/free_setup.tscn")

@onready var solo_btn: Button = %SoloBtn
@onready var histoire_btn: Button = %HistoireBtn
@onready var defi_btn: Button = %DefiBtn
@onready var arene_btn: Button = %AreneBtn
@onready var back_btn: Button = %BackBtn


func _ready() -> void:
	solo_btn.pressed.connect(_show_free_setup)
	histoire_btn.pressed.connect(func() -> void: Game.goto("campaign"))
	defi_btn.pressed.connect(_launch_challenge)
	arene_btn.pressed.connect(func() -> void: Game.goto("arena_hub"))
	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 26)
	back_btn.add_theme_color_override("font_color", UiTheme.GOLD)
	back_btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6))
	for b: Button in [solo_btn, histoire_btn, defi_btn, arene_btn, back_btn]:
		b.pressed.connect(UiTheme._click_sfx)


## Solo : choisir le maître adversaire et la difficulté, puis affronter l'IA.
func _show_free_setup() -> void:
	var setup: Control = FREE_SETUP.instantiate()
	setup.launched.connect(func(master: String, deck: Array, level: int) -> void:
		Game.start_free_battle(level, master, deck))
	add_child(setup)


## Défi : combat immédiat contre l'IA au niveau maximal.
func _launch_challenge() -> void:
	var ch := _random_chapter()
	Game.start_free_battle(AiPlayer.Level.MASTER,
			String(ch.opponent.master), ch.opponent.deck)


func _random_chapter() -> Dictionary:
	var chapters := Db.chapters()
	return chapters[randi() % chapters.size()]
