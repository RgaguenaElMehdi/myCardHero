extends Control
## Campaign map: chapter list with locked / done / current states.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = UiTheme.tex(Db.background_path("main_menu"))
	bg.modulate = Color(0.55, 0.55, 0.6)
	add_child(bg)

	var title := UiTheme.label("Le Circuit de Petraheim", 44, UiTheme.GOLD)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(700, 40)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(560, 130)
	scroll.custom_minimum_size = Vector2(800, 840)
	add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var chapters := Db.chapters()
	for i in chapters.size():
		vbox.add_child(_chapter_row(i, chapters[i]))

	var back := Button.new()
	back.text = "← Menu"
	back.position = Vector2(40, 40)
	back.custom_minimum_size = Vector2(160, 52)
	UiTheme.style_button(back, UiTheme.PANEL_LIGHT, 20)
	back.pressed.connect(func() -> void: Game.goto("main_menu"))
	add_child(back)
	Audio.play_music("menu")


func _chapter_row(index: int, ch: Dictionary) -> Control:
	var unlocked := Game.is_chapter_unlocked(index)
	var done := Game.is_chapter_done(index)
	var row := PanelContainer.new()
	var border := UiTheme.GOLD if (unlocked and not done) else Color.TRANSPARENT
	row.add_theme_stylebox_override("panel",
			UiTheme.panel(UiTheme.PANEL if unlocked else UiTheme.PANEL.darkened(0.4), 12,
					border, 2 if border.a > 0 else 0))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	row.add_child(hbox)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(84, 84)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = UiTheme.tex(Db.portrait_path(String(ch.opponent.portrait)))
	if not unlocked:
		portrait.modulate = Color(0.2, 0.2, 0.25)
	hbox.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(text_box)
	var status := "✔ " if done else ("" if unlocked else "Verrouillé — ")
	text_box.add_child(UiTheme.label("Chapitre %d — %s" % [index + 1, ch.title], 24,
			UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM))
	text_box.add_child(UiTheme.label("%sAdversaire : %s" % [status, ch.opponent.name], 16,
			UiTheme.OK if done else UiTheme.TEXT_DIM))

	var play := Button.new()
	play.text = "Rejouer" if done else "Jouer"
	play.disabled = not unlocked
	play.custom_minimum_size = Vector2(150, 54)
	UiTheme.style_button(play, UiTheme.OK.darkened(0.25) if not done else UiTheme.PANEL_LIGHT, 20)
	play.pressed.connect(func() -> void: Game.start_chapter(index))
	hbox.add_child(play)
	return row
