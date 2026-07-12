extends Control
## Accueil (design "or baroque sur noir", mockup utilisateur) : quatre tuiles —
## Sélection (campagne), Deck builder, Arène (modes de combat), Paramètres.
## Structure et style dans main_menu[_mobile].tscn — logique seulement ici.

const FREE_SETUP := preload("res://scenes/widgets/free_setup.tscn")
const MODE_SELECT := preload("res://scenes/widgets/mode_select.tscn")

@onready var selection_btn: Button = %SelectionBtn
@onready var deck_btn: Button = %DeckBtn
@onready var arena_btn: Button = %ArenaBtn
@onready var settings_btn: Button = %SettingsBtn


func _ready() -> void:
	# The boot scene is the desktop menu; hop to the mobile variant on a phone.
	# (Every other screen is reached through Game.goto, which resolves this.)
	if OS.has_feature("mobile") and not scene_file_path.ends_with("_mobile.tscn") \
			and ResourceLoader.exists("res://scenes/main_menu_mobile.tscn"):
		Game.goto("main_menu")
		return

	selection_btn.pressed.connect(func() -> void: Game.goto("campaign"))
	deck_btn.pressed.connect(func() -> void: Game.goto("deck_builder"))
	arena_btn.pressed.connect(_show_mode_select)
	settings_btn.pressed.connect(func() -> void: Game.goto("settings"))
	for btn: Button in [selection_btn, deck_btn, arena_btn, settings_btn]:
		btn.pressed.connect(UiTheme._click_sfx)

	Audio.play_music("menu")


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
		_launch_free(level))
	add_child(setup)


func _launch_free(level: int) -> void:
	# Random opponent borrowed from the campaign roster.
	var chapters := Db.chapters()
	var ch: Dictionary = chapters[randi() % chapters.size()]
	Game.start_free_battle(level, String(ch.opponent.master), ch.opponent.deck)
