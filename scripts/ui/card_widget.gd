class_name CardWidget
extends PanelContainer
## Visual card (hand, deck builder, rewards, detail preview).
## HQ look: art under an ornate generated golden frame, cost gem, Cinzel name.
## Falls back to the flat style when the frame texture is missing.

signal pressed(widget: CardWidget)

var def: CardDef
var selected := false
var hovering := false
var _count_label: Label


static func create(p_def: CardDef, width: float = 190.0) -> CardWidget:
	var w := CardWidget.new()
	w.def = p_def
	w.custom_minimum_size = Vector2(width, width * 1.42)
	w._build()
	return w


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	var evo_name := ""
	if def.evolves_to != &"":
		var tree := Engine.get_main_loop() as SceneTree
		var db = tree.root.get_node_or_null("Db") if tree != null else null
		if db != null and db.card(def.evolves_to) != null:
			evo_name = db.card(def.evolves_to).display_name
	tooltip_text = GameText.card_tooltip(def, evo_name)
	mouse_entered.connect(func() -> void:
		hovering = true
		_apply_style())
	mouse_exited.connect(func() -> void:
		hovering = false
		_apply_style())

	var w := custom_minimum_size.x
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

	# Name strip on a dark backing so it reads over the frame and art.
	var strip := PanelContainer.new()
	var strip_sb := StyleBoxFlat.new()
	strip_sb.bg_color = Color(0, 0, 0, 0.55)
	strip_sb.set_corner_radius_all(6)
	strip_sb.content_margin_left = 4
	strip_sb.content_margin_right = 4
	strip.add_theme_stylebox_override("panel", strip_sb)
	vbox.add_child(strip)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	strip.add_child(top)
	top.add_child(_cost_chip(w))

	var name_size := int(w * 0.085)
	if def.display_name.length() > 13:
		name_size = int(w * 0.068)
	var name_l := UiTheme.title_label(def.display_name, name_size, Color.WHITE)
	name_l.clip_text = true
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)

	# guild pip
	var pip := Panel.new()
	var pip_sb := StyleBoxFlat.new()
	pip_sb.bg_color = UiTheme.guild_color(def.guild)
	pip_sb.set_corner_radius_all(99)
	pip_sb.border_color = Color(0, 0, 0, 0.5)
	pip_sb.set_border_width_all(1)
	pip.add_theme_stylebox_override("panel", pip_sb)
	pip.custom_minimum_size = Vector2(w * 0.07, w * 0.07)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pip)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, w * 0.72)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = UiTheme.tex(def.art)
	if art.texture == null:
		var ph := ColorRect.new()
		ph.color = UiTheme.guild_color(def.guild).darkened(0.6)
		ph.custom_minimum_size = art.custom_minimum_size
		vbox.add_child(ph)
	else:
		vbox.add_child(art)

	var info_text := ""
	if def.is_monster():
		info_text = GameText.monster_summary(def)
	else:
		info_text = GameText.describe_effect(def.effect)
	var info := UiTheme.label(info_text, int(w * 0.068), UiTheme.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(info)

	_count_label = UiTheme.label("", int(w * 0.08), UiTheme.GOLD)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.visible = false
	vbox.add_child(_count_label)

	# ornate frame on top of everything
	var frame_tex := UiTheme.tex(UiTheme.TEX_CARD_FRAME)
	if frame_tex != null:
		var frame := TextureRect.new()
		frame.texture = frame_tex
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(frame)

	# Decorative children must never eat the click.
	UiTheme.pass_through(self)


func _cost_chip(w: float) -> Control:
	var chip := Control.new()
	var d := w * 0.19
	chip.custom_minimum_size = Vector2(d, d)
	var icon_tex := UiTheme.tex(UiTheme.ICON_STONE)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		chip.add_child(icon)
	else:
		var gem := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.ACCENT.darkened(0.3)
		sb.set_corner_radius_all(99)
		sb.border_color = UiTheme.ACCENT
		sb.set_border_width_all(2)
		gem.add_theme_stylebox_override("panel", sb)
		gem.set_anchors_preset(Control.PRESET_FULL_RECT)
		chip.add_child(gem)
	var num := UiTheme.title_label(str(def.cost), int(d * 0.62), Color.WHITE)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(num)
	return chip


func _apply_style() -> void:
	var has_frame := UiTheme.tex(UiTheme.TEX_CARD_FRAME) != null
	var w := custom_minimum_size.x
	var border := Color.TRANSPARENT
	var border_w := 0
	if selected:
		border = Color.WHITE
		border_w = 4
	elif hovering:
		border = UiTheme.GOLD if has_frame else UiTheme.guild_color(def.guild).lightened(0.35)
		border_w = 3
	elif not has_frame:
		border = UiTheme.guild_color(def.guild)
		border_w = 2
	var bg := Color("141824") if has_frame else UiTheme.PANEL.darkened(0.2)
	if hovering:
		bg = bg.lightened(0.07)
	var sb := UiTheme.panel(bg, 12, border, border_w)
	var mx := w * 0.085 if has_frame else 8.0
	var my := w * 0.08 if has_frame else 6.0
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	add_theme_stylebox_override("panel", sb)


func set_selected(on: bool) -> void:
	selected = on
	_apply_style()


## Shows "×n" (deck builder / rewards).
func set_count(n: int) -> void:
	_count_label.text = "×%d" % n
	_count_label.visible = n > 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(self)
