extends Control
## Main menu hub: campaign, free play (widget free_setup.tscn), deck builder,
## guide, settings, quit. Structure in main_menu.tscn — logic only here.

const FREE_SETUP := preload("res://scenes/widgets/free_setup.tscn")

@onready var background: TextureRect = %Background
@onready var logo: TextureRect = %Logo
@onready var title_fallback: Label = %TitleFallback
@onready var campaign_btn: Button = %CampaignBtn
@onready var free_play_btn: Button = %FreePlayBtn
@onready var deck_builder_btn: Button = %DeckBuilderBtn
@onready var guide_btn: Button = %GuideBtn
@onready var options_btn: Button = %OptionsBtn
@onready var quit_btn: Button = %QuitBtn
@onready var fight_btn: Button = %FightBtn
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	# Background texture: override with runtime path if different from scene default
	var bg_tex := UiTheme.tex(Db.background_path("main_menu"))
	if bg_tex != null:
		background.texture = bg_tex

	# Logo: show texture if available, otherwise fallback title
	var logo_tex := UiTheme.tex(UiTheme.TEX_LOGO)
	if logo_tex != null:
		logo.texture = logo_tex
		title_fallback.visible = false
	else:
		logo.visible = false
		title_fallback.visible = true

	# Style all buttons; the hub CTA gets the red/secondary plate.
	for btn in [free_play_btn, deck_builder_btn, guide_btn, options_btn, quit_btn]:
		UiTheme.style_button(btn, UiTheme.PANEL_LIGHT, 24)
	UiTheme.style_button(campaign_btn, UiTheme.DANGER, 24)
	UiTheme.style_button(fight_btn, UiTheme.DANGER, 26)

	# Connect button signals
	campaign_btn.pressed.connect(func() -> void: Game.goto("campaign"))
	fight_btn.pressed.connect(func() -> void: Game.goto("campaign"))
	free_play_btn.pressed.connect(_show_free_setup)
	var multi_btn := get_node_or_null("%MultiBtn")
	if multi_btn != null:
		multi_btn.pressed.connect(func() -> void: Game.goto("online_lobby"))
	deck_builder_btn.pressed.connect(func() -> void: Game.goto("deck_builder"))
	guide_btn.pressed.connect(func() -> void: Game.goto("guide"))
	options_btn.pressed.connect(func() -> void: Game.goto("settings"))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())

	# Campaign progress status
	var progress := int(Game.profile.campaign_progress)
	var status := "Progression : chapitre %d / %d" % [mini(progress + 1, 10), Db.chapters().size()] \
			if progress < Db.chapters().size() else "Campagne terminée — Champion de Petraheim !"
	status_label.text = status

	Audio.play_music("menu")


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
