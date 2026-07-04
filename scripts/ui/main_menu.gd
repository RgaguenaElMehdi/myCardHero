extends Control
## Main menu: campaign, free play (master + difficulty picker), deck builder,
## settings, quit.

var free_overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = UiTheme.tex(Db.background_path("main_menu"))
	add_child(bg)

	var logo_tex := UiTheme.tex(UiTheme.TEX_LOGO)
	if logo_tex != null:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
		logo.offset_top = 24
		logo.custom_minimum_size = Vector2(0, 330)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(logo)
	else:
		var title := UiTheme.title_label("STONEBOUND", 84)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title.offset_top = 90
		add_child(title)

	var subtitle := UiTheme.title_label("Le Circuit de Petraheim", 26, UiTheme.TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 352
	add_child(subtitle)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0.55), 16))
	panel.position = Vector2(760, 425)
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_menu_btn(vbox, "Campagne", func() -> void: Game.goto("campaign"))
	_menu_btn(vbox, "Partie libre", _show_free_setup)
	_menu_btn(vbox, "Deck builder", func() -> void: Game.goto("deck_builder"))
	_menu_btn(vbox, "Guide du jeu", func() -> void: Game.goto("guide"))
	_menu_btn(vbox, "Options", func() -> void: Game.goto("settings"))
	_menu_btn(vbox, "Quitter", func() -> void: get_tree().quit())

	var progress := int(Game.profile.campaign_progress)
	var status := "Progression : chapitre %d / %d" % [mini(progress + 1, 10), Db.chapters().size()] \
			if progress < Db.chapters().size() else "Campagne terminée — Champion de Petraheim !"
	var status_l := UiTheme.label(status, 17, UiTheme.TEXT_DIM)
	status_l.add_theme_color_override("font_outline_color", Color.BLACK)
	status_l.add_theme_constant_override("outline_size", 6)
	status_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_l.offset_top = 880
	add_child(status_l)
	Audio.play_music("menu")


func _menu_btn(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 62)
	UiTheme.style_button(b, UiTheme.PANEL_LIGHT, 24)
	b.pressed.connect(action)
	parent.add_child(b)


func _show_free_setup() -> void:
	free_overlay = Control.new()
	free_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	free_overlay.add_child(dim)
	add_child(free_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	free_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 14))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	vbox.add_child(UiTheme.label("Partie libre", 30, UiTheme.GOLD))

	vbox.add_child(UiTheme.label("Votre Maître :", 18, UiTheme.TEXT_DIM))
	var masters_row := HBoxContainer.new()
	masters_row.add_theme_constant_override("separation", 10)
	vbox.add_child(masters_row)
	var selected_master: Array = [String(Game.profile.active_master)]
	var master_buttons: Array[Button] = []
	for mid in Game.profile.masters:
		var m := Db.master(StringName(String(mid)))
		var b := Button.new()
		b.text = m.display_name
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 52)
		b.button_pressed = String(mid) == selected_master[0]
		b.tooltip_text = "%s\nPouvoir : %s" % [m.passive_desc, m.power_desc]
		UiTheme.style_toggle(b, UiTheme.guild_color(m.guild).darkened(0.5), 18)
		masters_row.add_child(b)
		master_buttons.append(b)
		b.pressed.connect(func() -> void:
			selected_master[0] = String(mid)
			for other in master_buttons:
				other.set_pressed_no_signal(other == b))

	vbox.add_child(UiTheme.label("Difficulté :", 18, UiTheme.TEXT_DIM))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	vbox.add_child(diff_row)
	var selected_diff: Array = [int(AiPlayer.Level.ADEPT)]
	var diff_buttons: Array[Button] = []
	var diffs := [["Novice", AiPlayer.Level.NOVICE], ["Adepte", AiPlayer.Level.ADEPT],
			["Maître", AiPlayer.Level.MASTER]]
	for d in diffs:
		var b := Button.new()
		b.text = d[0]
		b.toggle_mode = true
		b.button_pressed = int(d[1]) == selected_diff[0]
		b.custom_minimum_size = Vector2(140, 50)
		UiTheme.style_toggle(b, UiTheme.PANEL_LIGHT, 20)
		diff_row.add_child(b)
		diff_buttons.append(b)
		b.pressed.connect(func() -> void:
			selected_diff[0] = int(d[1])
			for other in diff_buttons:
				other.set_pressed_no_signal(other == b))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	vbox.add_child(actions)
	var launch := Button.new()
	launch.text = "⚔  Lancer la partie"
	launch.custom_minimum_size = Vector2(280, 60)
	UiTheme.style_button(launch, UiTheme.OK.darkened(0.2), 22)
	launch.pressed.connect(func() -> void:
		Game.profile.active_master = selected_master[0]
		Game.save_profile()
		_launch_free(selected_diff[0]))
	actions.add_child(launch)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.custom_minimum_size = Vector2(140, 60)
	UiTheme.style_button(cancel, UiTheme.PANEL_LIGHT, 18)
	cancel.pressed.connect(func() -> void: free_overlay.queue_free())
	actions.add_child(cancel)


func _launch_free(level: int) -> void:
	# Random opponent borrowed from the campaign roster.
	var chapters := Db.chapters()
	var ch: Dictionary = chapters[randi() % chapters.size()]
	Game.start_free_battle(level, String(ch.opponent.master), ch.opponent.deck)
