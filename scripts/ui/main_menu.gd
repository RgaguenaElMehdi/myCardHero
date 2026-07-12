extends Control
## Accueil (design "or baroque sur noir", mockup utilisateur) : quatre tuiles —
## Sélection (campagne), Deck builder, Arène (modes de combat), Paramètres.
## Structure et style dans main_menu[_mobile].tscn — logique seulement ici.

@onready var selection_btn: Button = %SelectionBtn
@onready var deck_btn: Button = %DeckBtn
@onready var arena_btn: Button = %ArenaBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var quit_btn: Button = %QuitBtn


func _ready() -> void:
	# The boot scene is the desktop menu; hop to the mobile variant on a phone.
	# (Every other screen is reached through Game.goto, which resolves this.)
	if OS.has_feature("mobile") and not scene_file_path.ends_with("_mobile.tscn") \
			and ResourceLoader.exists("res://scenes/main_menu_mobile.tscn"):
		Game.goto("main_menu")
		return

	selection_btn.pressed.connect(func() -> void: Game.goto("selection"))
	deck_btn.pressed.connect(func() -> void: Game.goto("deck_builder"))
	arena_btn.pressed.connect(func() -> void: Game.goto("arena_hub"))
	settings_btn.pressed.connect(func() -> void: Game.goto("settings"))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	for btn: Button in [selection_btn, deck_btn, arena_btn, settings_btn, quit_btn]:
		btn.pressed.connect(UiTheme._click_sfx)

	Audio.play_music("menu")
