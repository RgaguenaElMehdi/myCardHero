extends Control
## Settings: volumes, fullscreen, profile reset.

var reset_armed := false
var reset_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 16))
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	vbox.add_child(UiTheme.title_label("Options", 36))

	var settings: Dictionary = Game.profile.settings
	vbox.add_child(UiTheme.label("Volume de la musique", 18))
	vbox.add_child(_slider(float(settings.get("music_volume", 0.8)), func(v: float) -> void:
		Game.profile.settings.music_volume = v
		_apply()))
	vbox.add_child(UiTheme.label("Volume des effets", 18))
	vbox.add_child(_slider(float(settings.get("sfx_volume", 0.9)), func(v: float) -> void:
		Game.profile.settings.sfx_volume = v
		_apply()
		Audio.play_sfx("hit")))

	var fs := CheckButton.new()
	fs.text = "Plein écran"
	fs.button_pressed = bool(settings.get("fullscreen", false))
	fs.add_theme_font_size_override("font_size", 18)
	fs.toggled.connect(func(on: bool) -> void:
		Game.profile.settings.fullscreen = on
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if on
				else DisplayServer.WINDOW_MODE_WINDOWED)
		Game.save_profile())
	vbox.add_child(fs)

	reset_btn = Button.new()
	reset_btn.text = "Réinitialiser la progression"
	UiTheme.style_button(reset_btn, UiTheme.DANGER.darkened(0.4), 18)
	reset_btn.pressed.connect(_on_reset)
	vbox.add_child(reset_btn)

	var back := Button.new()
	back.text = "← Retour au menu"
	back.custom_minimum_size = Vector2(0, 54)
	UiTheme.style_button(back, UiTheme.PANEL_LIGHT, 20)
	back.pressed.connect(func() -> void: Game.goto("main_menu"))
	vbox.add_child(back)


func _slider(value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 30)
	s.value_changed.connect(on_change)
	return s


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
