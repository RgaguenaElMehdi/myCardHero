class_name CardWidget
extends PanelContainer
## Visual card (hand, deck builder, rewards, detail preview).
## Preferred path: displays the fully-composed card image built offline by
## tools/build_cards.py (frame + art + texts in one picture — nothing can
## overlap). Falls back to an in-engine composite when the image is missing.

signal pressed(widget: CardWidget)
signal inspect_requested(widget: CardWidget)

var def: CardDef
var selected := false
var hovering := false
var _full := false
var _count_label: Label


static func full_card_path(id: StringName) -> String:
	return "res://assets/sprites/cards_full/%s.png" % id


static func create(p_def: CardDef, width: float = 190.0) -> CardWidget:
	var w := CardWidget.new()
	w.def = p_def
	w.custom_minimum_size = Vector2(width, width * 1.385)
	w._build()
	return w


## Compact hand format: cost gem, name, big art, ATQ/PV badges, keyword line.
## The full composed card stays one right-click away.
static func create_mini(p_def: CardDef, width: float = 156.0) -> CardWidget:
	var w := CardWidget.new()
	w.def = p_def
	w.custom_minimum_size = Vector2(width, width * 1.34)
	w._build_mini()
	return w


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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

	var full_tex := UiTheme.tex(CardWidget.full_card_path(def.id))
	_full = full_tex != null
	_apply_style()
	if _full:
		_build_full(full_tex)
	else:
		_build_composite()
	# Decorative children must never eat the click.
	UiTheme.pass_through(self)


# --- Preferred: one pre-composed image ----------------------------------

func _build_full(tex: Texture2D) -> void:
	var art := TextureRect.new()
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(art)
	var overlay := Control.new()
	add_child(overlay)
	_count_label = UiTheme.label("", int(custom_minimum_size.x * 0.11), UiTheme.GOLD)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 8)
	_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.offset_left = -70
	_count_label.offset_top = -46
	_count_label.offset_right = -10
	_count_label.offset_bottom = -10
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.visible = false
	overlay.add_child(_count_label)


# --- Mini hand format ------------------------------------------------------

func _build_mini() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_full = false
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
	_apply_style()

	var w := custom_minimum_size.x
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	vbox.add_child(top)
	top.add_child(_cost_disc(str(def.cost), w * 0.155))
	var name_size := int(w * 0.092)
	if def.display_name.length() > 12:
		name_size = int(w * 0.072)
	var name_l := UiTheme.title_label(def.display_name, name_size, Color.WHITE)
	name_l.clip_text = true
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, w * 0.68)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = UiTheme.tex(def.art)
	vbox.add_child(art)

	if def.is_monster():
		var badges := HBoxContainer.new()
		badges.add_theme_constant_override("separation", 6)
		vbox.add_child(badges)
		badges.add_child(_stat_chip(str(def.levels[0].atk), UiTheme.ICON_ATK,
				Color("e2884c"), w * 0.17))
		badges.add_child(_stat_chip(str(def.levels[0].hp), UiTheme.ICON_HP,
				Color("cf5757"), w * 0.17))
		var type_l := UiTheme.label(GameText.ATTACK_TYPE_NAMES[def.attack_type],
				int(w * 0.070), UiTheme.TEXT_DIM)
		type_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		type_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		type_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badges.add_child(type_l)
		var kw := GameText.keywords_line(def.keywords)
		if def.evolves_to != &"":
			kw = ("%s · Évolue" % kw) if kw != "" else "Évolue"
		if kw != "":
			var kw_l := UiTheme.label(kw, int(w * 0.066), UiTheme.GOLD.lightened(0.2))
			kw_l.clip_text = true
			vbox.add_child(kw_l)
	else:
		var eff := UiTheme.label(GameText.describe_effect(def.effect), int(w * 0.070),
				UiTheme.TEXT)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(eff)

	_count_label = UiTheme.label("", int(w * 0.08), UiTheme.GOLD)
	_count_label.visible = false
	vbox.add_child(_count_label)
	UiTheme.pass_through(self)


## Cost gem sliced from the mockup sheet (digit baked in), golden disc fallback.
func _cost_disc(value: String, size: float) -> Control:
	var gem := UiTheme.tex("res://assets/sprites/ui/pixel/gem_cost_%d.png"
			% mini(int(value), 7))
	if gem != null:
		var rect := TextureRect.new()
		rect.texture = gem
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return rect
	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.GOLD
	sb.set_corner_radius_all(int(size / 2.0))
	sb.border_color = Color("6b5320")
	sb.set_border_width_all(2)
	disc.add_theme_stylebox_override("panel", sb)
	var l := UiTheme.title_label(value, int(size * 0.62), Color("241c08"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(l)
	return disc


func _stat_chip(value: String, icon_path: String, color: Color, size: float) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(int(size * 0.3))
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.content_margin_left = 5
	sb.content_margin_right = 6
	chip.add_theme_stylebox_override("panel", sb)
	chip.add_child(UiTheme.icon_label(icon_path, value, int(size * 0.62),
			Color.WHITE.lerp(color, 0.25)))
	return chip


# --- Fallback: in-engine composite ---------------------------------------

func _build_composite() -> void:
	var w := custom_minimum_size.x
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

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
	var cost := UiTheme.title_label(str(def.cost), int(w * 0.1), Color.WHITE)
	top.add_child(cost)
	var name_size := int(w * 0.085)
	if def.display_name.length() > 13:
		name_size = int(w * 0.068)
	var name_l := UiTheme.title_label(def.display_name, name_size, Color.WHITE)
	name_l.clip_text = true
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(name_l)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, w * 0.72)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = UiTheme.tex(def.art)
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


func _apply_style() -> void:
	var border := Color.TRANSPARENT
	var border_w := 0
	if selected:
		border = Color.WHITE
		border_w = 4
	elif hovering:
		border = UiTheme.GOLD
		border_w = 3
	elif not _full:
		# Dark bronze frame (mockup style) — the guild shows through the art.
		border = Color("554830")
		border_w = 2
	var bg := Color(0, 0, 0, 0.0) if _full else Color(0.09, 0.1, 0.12, 0.94)
	if hovering and not _full:
		bg = bg.lightened(0.07)
	var sb := UiTheme.panel(bg, 12, border, border_w)
	var m := 2.0 if _full else 8.0
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m
	sb.content_margin_bottom = m
	add_theme_stylebox_override("panel", sb)


func set_selected(on: bool) -> void:
	selected = on
	_apply_style()


## Shows "×n" (deck builder / rewards).
func set_count(n: int) -> void:
	_count_label.text = "×%d" % n
	_count_label.visible = n > 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			inspect_requested.emit(self)
