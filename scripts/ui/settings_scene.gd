extends Control
## Settings: volumes, fullscreen, profile reset.

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var reset_btn: Button = %ResetBtn
@onready var back_btn: Button = %BackBtn

var reset_armed := false


func _ready() -> void:
	# Apply dynamic styling
	UiTheme.style_button(reset_btn, UiTheme.DANGER.darkened(0.4), 18)
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 20)

	# Load current settings
	var settings: Dictionary = Game.profile.settings
	music_slider.value = float(settings.get("music_volume", 0.8))
	sfx_slider.value = float(settings.get("sfx_volume", 0.9))
	fullscreen_check.button_pressed = bool(settings.get("fullscreen", false))

	# Connect signals
	music_slider.value_changed.connect(func(v: float) -> void:
		Game.profile.settings.music_volume = v
		_apply())
	sfx_slider.value_changed.connect(func(v: float) -> void:
		Game.profile.settings.sfx_volume = v
		_apply()
		Audio.play_sfx("hit"))
	fullscreen_check.toggled.connect(func(on: bool) -> void: Game.set_fullscreen(on))
	Game.profile_changed.connect(func() -> void:
		if is_instance_valid(fullscreen_check):
			fullscreen_check.set_pressed_no_signal(bool(Game.profile.settings.get("fullscreen", false))))
	reset_btn.pressed.connect(_on_reset)
	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))


func _apply() -> void:
	Game.save_profile()
	Audio.apply_settings()


func _on_reset() -> void:
	if not reset_armed:
		reset_armed = true
		reset_btn.text = "Confirmer ? Toute la progression sera perdue !"
		return
	Game.reset_profile()
	reset_armed = false
	reset_btn.text = "Progression réinitialisée."
	reset_btn.disabled = true
