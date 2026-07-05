extends Control
## Campaign map: chapter list with locked / done / current states.

@onready var background: TextureRect = %Background
@onready var chapter_list: VBoxContainer = %ChapterList
@onready var back_btn: Button = %BackBtn


func _ready() -> void:
	# Dynamic assets - override texture if path differs from scene default
	var bg_tex := UiTheme.tex(Db.background_path("main_menu"))
	if bg_tex != null:
		background.texture = bg_tex
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 20)
	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))

	# Populate chapter rows (dynamic content from data)
	var chapters := Db.chapters()
	for i in chapters.size():
		chapter_list.add_child(_chapter_row(i, chapters[i]))

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
