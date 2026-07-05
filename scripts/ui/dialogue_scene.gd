extends Control
## Story dialogue scene. Plays the pre- or post-battle dialogue of the current
## chapter (Game.dialogue_phase), with a typewriter effect. After "pre" it
## launches the battle; after "post" it grants rewards and returns to the map.

const CHARS_PER_SEC := 40.0

@onready var background: TextureRect = %Background
@onready var portrait: TextureRect = %Portrait
@onready var portrait_frame: Panel = %PortraitFrame
@onready var name_label: Label = %NameLabel
@onready var text_label: Label = %TextLabel
@onready var hint_label: Label = %HintLabel
@onready var skip_btn: Button = %SkipBtn

var lines: Array = []
var line_index := 0
var revealed := 0.0
var typing := false


func _ready() -> void:
	if Game.battle_config.is_empty():
		# Direct launch (debug): play chapter 1's intro.
		Game.start_chapter(0)
		return
	var chapter := Db.chapter(int(Game.battle_config.chapter))
	var phase := Game.dialogue_phase
	lines = chapter.get("pre_dialogue" if phase == "pre" else "post_dialogue", [])

	# Dynamic assets
	background.texture = UiTheme.tex(Db.background_path(String(Game.battle_config.background)))
	UiTheme.style_button(skip_btn, UiTheme.PANEL_LIGHT, 16)
	skip_btn.pressed.connect(_finish)

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
			var w := CardWidget.spawn(def, 160)
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
