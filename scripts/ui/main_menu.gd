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
	panel.add_theme_stylebox_override("panel", UiTheme.panel_ornate())
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var title := UiTheme.title_label("Partie libre", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var pick_hint := UiTheme.label(
			"Choisissez votre Maître — clic droit pour voir sa carte en grand :",
			17, UiTheme.TEXT_DIM)
	pick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pick_hint)

	# The masters ARE the selector: click a card to pick it.
	var masters_row := HBoxContainer.new()
	masters_row.alignment = BoxContainer.ALIGNMENT_CENTER
	masters_row.add_theme_constant_override("separation", 16)
	vbox.add_child(masters_row)
	var selected_master: Array = [String(Game.profile.active_master)]
	var card_frames: Array = []
	var restyle := func() -> void:
		for entry in card_frames:
			var frame: PanelContainer = entry[0]
			var is_sel: bool = entry[1] == selected_master[0]
			var sb := UiTheme.panel(Color(0, 0, 0, 0.25), 12,
					UiTheme.GOLD if is_sel else Color(1, 1, 1, 0.12), 4 if is_sel else 1)
			sb.content_margin_left = 6
			sb.content_margin_right = 6
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
			frame.add_theme_stylebox_override("panel", sb)
			frame.modulate = Color.WHITE if is_sel else Color(0.72, 0.72, 0.78)
	for mid in Game.profile.masters:
		var m := Db.master(StringName(String(mid)))
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		var img := TextureRect.new()
		img.texture = UiTheme.tex("res://assets/sprites/cards_full/master_%s.png" % mid)
		img.custom_minimum_size = Vector2(222, 310)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(img)
		masters_row.add_child(frame)
		card_frames.append([frame, String(mid)])
		frame.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				frame.accept_event()
				if ev.button_index == MOUSE_BUTTON_LEFT:
					Audio.play_sfx("click")
					selected_master[0] = String(mid)
					restyle.call()
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					CardPopup.open_master(self, m))
		frame.mouse_entered.connect(func() -> void:
			if String(mid) != selected_master[0]:
				frame.modulate = Color(0.9, 0.9, 0.95))
		frame.mouse_exited.connect(func() -> void: restyle.call())
	restyle.call()

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
