class_name CardPopup
extends Control
## Full-screen card inspector (right-click anywhere a card appears):
## dimmed backdrop, the composed card in large, and a rules panel beside it.
## Any click or Échap closes it.


static func open(host: Control, def: CardDef, live: MonsterInst = null) -> void:
	var p := CardPopup.new()
	host.add_child(p)
	p._build_card(def, live)


static func open_master(host: Control, master: MasterDef) -> void:
	var p := CardPopup.new()
	host.add_child(p)
	p._build_master(master)


func _base() -> HBoxContainer:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	return row


var _armed := false


func _finish(row: HBoxContainer) -> void:
	UiTheme.pass_through(self)
	pivot_offset = get_viewport_rect().size / 2.0
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	var hint := UiTheme.label("Cliquez n'importe où pour fermer  ·  Échap", 15, UiTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -44
	add_child(hint)
	var close := Button.new()
	close.text = "✕  Fermer"
	close.custom_minimum_size = Vector2(150, 48)
	UiTheme.style_button(close, UiTheme.DANGER.darkened(0.35), 18)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -190
	close.offset_top = 30
	close.offset_right = -40
	close.pressed.connect(queue_free)
	add_child(close)
	# Ignore the very click that opened the popup, then close on any press.
	get_tree().create_timer(0.2).timeout.connect(func() -> void: _armed = true)


## Global catch: any mouse press anywhere closes the popup, even if another
## control would normally swallow the click.
func _input(event: InputEvent) -> void:
	if _armed and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		queue_free()


func _card_image(path: String, fallback_def: CardDef) -> Control:
	var tex := UiTheme.tex(path)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(560, 780)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return img
	return CardWidget.create(fallback_def, 480) if fallback_def != null else Control.new()


func _side_panel(title: String, body: String, width: float = 470.0) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_ornate())
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var t := UiTheme.title_label(title, 26)
	vbox.add_child(t)
	var l := UiTheme.label(body, 17, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(l)
	return panel


func _build_card(def: CardDef, live: MonsterInst) -> void:
	var row := _base()
	row.add_child(_card_image(CardWidget.full_card_path(def.id), def))
	var evo_name := ""
	if def.evolves_to != &"":
		var tree := Engine.get_main_loop() as SceneTree
		var db = tree.root.get_node_or_null("Db") if tree != null else null
		if db != null and db.card(def.evolves_to) != null:
			evo_name = db.card(def.evolves_to).display_name
	var body := GameText.card_tooltip(def, evo_name)
	if def.is_monster():
		body += "\n\n" + GameText.ATTACK_TYPE_NAMES[def.attack_type] + " : " \
				+ GameText.ATTACK_TYPE_DEFS[def.attack_type] + "."
		for kw in def.keywords:
			body += "\n%s : %s." % [GameText.KEYWORD_NAMES.get(String(kw), String(kw)),
					GameText.KEYWORD_DEFS.get(String(kw), "")]
	if live != null:
		body += "\n\n— En jeu —\nNiveau %d · ATQ %d · PV %d/%d" \
				% [live.level, live.atk(), live.hp, live.max_hp()]
		if not live.at_max_level():
			body += "\nXP %d / %d" % [live.xp, live.next_level_xp()]
		if live.shield:
			body += "\nBouclier actif"
		if live.acted:
			body += "\nA déjà agi ce tour"
	row.add_child(_side_panel(def.display_name, body))
	_finish(row)


func _build_master(master: MasterDef) -> void:
	var row := _base()
	var path := "res://assets/sprites/cards_full/master_%s.png" % master.id
	row.add_child(_card_image(path, null))
	var body := "PV : %d\n\nPassif : %s\n\nPouvoir — %s (%d pierres, 1×/tour) :\n%s" \
			% [master.hp, master.passive_desc, master.power_name, master.power_cost,
			master.power_desc]
	if master.lore != "":
		body += "\n\n« %s »" % master.lore
	row.add_child(_side_panel(master.display_name, body))
	_finish(row)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
