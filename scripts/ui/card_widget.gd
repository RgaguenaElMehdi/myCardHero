class_name CardWidget
extends PanelContainer
## Visual card (hand, deck builder, rewards, detail preview).
## Built entirely in code; art comes from assets/sprites/cards/<id>.png.

signal pressed(widget: CardWidget)

var def: CardDef
var selected := false
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
	tooltip_text = def.description

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)

	var cost := UiTheme.label(str(def.cost), 20, Color.WHITE)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.custom_minimum_size = Vector2(30, 30)
	var gem := StyleBoxFlat.new()
	gem.bg_color = UiTheme.ACCENT.darkened(0.3)
	gem.set_corner_radius_all(15)
	gem.border_color = UiTheme.ACCENT
	gem.set_border_width_all(2)
	var cost_panel := PanelContainer.new()
	cost_panel.add_theme_stylebox_override("panel", gem)
	cost_panel.add_child(cost)
	top.add_child(cost_panel)

	var name_l := UiTheme.label(def.display_name, 16)
	name_l.clip_text = true
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, custom_minimum_size.x * 0.62)
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
	var info := UiTheme.label(info_text, 13, UiTheme.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(info)

	_count_label = UiTheme.label("", 15, UiTheme.GOLD)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.visible = false
	vbox.add_child(_count_label)


func _apply_style() -> void:
	var border := Color.WHITE if selected else UiTheme.guild_color(def.guild)
	var sb := UiTheme.panel(UiTheme.PANEL.darkened(0.2), 10, border, 4 if selected else 2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
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
