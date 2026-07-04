extends Control
## Story dialogue scene. Plays the pre- or post-battle dialogue of the current
## chapter (Game.dialogue_phase), with a typewriter effect. After "pre" it
## launches the battle; after "post" it grants rewards and returns to the map.

const CHARS_PER_SEC := 40.0

var lines: Array = []
var line_index := 0
var revealed := 0.0
var typing := false

var portrait: TextureRect
var portrait_frame: Panel
var name_label: Label
var text_label: Label
var hint_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Game.battle_config.is_empty():
		# Direct launch (debug): play chapter 1's intro.
		Game.start_chapter(0)
		return
	var chapter := Db.chapter(int(Game.battle_config.chapter))
	var phase := Game.dialogue_phase
	lines = chapter.get("pre_dialogue" if phase == "pre" else "post_dialogue", [])

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = UiTheme.tex(Db.background_path(String(Game.battle_config.background)))
	add_child(bg)

	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(280, 280)
	portrait.position = Vector2(120, 520)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(portrait)
	var frame := Panel.new()
	frame.position = portrait.position
	frame.custom_minimum_size = portrait.custom_minimum_size
	frame.size = portrait.custom_minimum_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color.TRANSPARENT
	fsb.border_color = UiTheme.GOLD
	fsb.set_border_width_all(3)
	fsb.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", fsb)
	add_child(frame)
	portrait_frame = frame

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0.75), 14))
	box.position = Vector2(440, 700)
	box.custom_minimum_size = Vector2(1360, 300)
	add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	box.add_child(vbox)
	name_label = UiTheme.title_label("", 26)
	vbox.add_child(name_label)
	text_label = UiTheme.label("", 22)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_label)
	hint_label = UiTheme.label("Cliquez pour continuer…", 15, UiTheme.TEXT_DIM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint_label)

	var skip := Button.new()
	skip.text = "Passer ⏭"
	skip.position = Vector2(1740, 30)
	UiTheme.style_button(skip, UiTheme.PANEL_LIGHT, 16)
	skip.pressed.connect(_finish)
	add_child(skip)

	Audio.play_music("story")
	_show_line()


func _process(delta: float) -> void:
	if typing:
		revealed += delta * CHARS_PER_SEC
		var full: String = lines[line_index].text
		text_label.text = full.substr(0, int(revealed))
		if int(revealed) >= full.length():
			typing = false
			hint_label.visible = true


func _show_line() -> void:
	if line_index >= lines.size():
		_finish()
		return
	var line: Dictionary = lines[line_index]
	var speaker := String(line.get("speaker", "narrator"))
	revealed = 0.0
	typing = true
	hint_label.visible = false
	text_label.text = ""
	if speaker == "narrator":
		name_label.text = ""
		portrait.texture = null
		text_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	else:
		name_label.text = _speaker_name(speaker)
		portrait.texture = UiTheme.tex(Db.portrait_path(speaker))
		text_label.add_theme_color_override("font_color", UiTheme.TEXT)
	portrait.visible = portrait.texture != null
	portrait_frame.visible = portrait.texture != null


func _speaker_name(speaker: String) -> String:
	if speaker == "milo":
		return String(Db.campaign.get("hero_name", "Milo"))
	var m := Db.master(StringName(speaker))
	if m != null:
		return m.display_name
	return speaker.capitalize()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	if typing:
		revealed = 99999.0
		return
	line_index += 1
	_show_line()


func _finish() -> void:
	if Game.dialogue_phase == "pre":
		Game.goto("battle")
	else:
		var granted := Game.complete_chapter(int(Game.battle_config.chapter))
		_show_rewards(granted)


func _show_rewards(granted: Dictionary) -> void:
	set_process(false)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 16, UiTheme.GOLD, 3))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var title := UiTheme.label("Récompenses", 32, UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var cards: Dictionary = granted.get("cards", {})
	var masters: Array = granted.get("masters", [])
	if cards.is_empty() and masters.is_empty():
		vbox.add_child(UiTheme.label("Aucune nouvelle récompense (chapitre déjà terminé).",
				18, UiTheme.TEXT_DIM))
	if not cards.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)
		for id in cards:
			var def := Db.card(StringName(String(id)))
			if def == null:
				continue
			var w := CardWidget.create(def, 160)
			w.set_count(int(cards[id]))
			row.add_child(w)
	for mid in masters:
		var m := Db.master(StringName(String(mid)))
		vbox.add_child(UiTheme.label("Nouveau Maître débloqué : %s !" % m.display_name,
				22, UiTheme.ACCENT))

	var next := Button.new()
	next.text = "Continuer"
	next.custom_minimum_size = Vector2(220, 56)
	UiTheme.style_button(next, UiTheme.OK.darkened(0.25), 20)
	next.pressed.connect(func() -> void: Game.goto("campaign"))
	var btn_center := CenterContainer.new()
	btn_center.add_child(next)
	vbox.add_child(btn_center)
