class_name BoardCell
extends Panel
## One board square. Renders its occupant (monster or master) from GameState
## and shows action highlights. Emits clicked(cell) for the battle controller.

signal clicked(cell: Vector2i)
signal inspect_requested(cell: Vector2i)

const SIZE := 148.0

var cell: Vector2i
var side: int  ## player index owning this row
var highlight := ""  ## "", "summon", "move", "attack", "selected", "target"

var _content: Control
var _ring: Panel


static func create(p_cell: Vector2i) -> BoardCell:
	var c := BoardCell.new()
	c.cell = p_cell
	c.side = Board.row_owner(p_cell.y)
	c.custom_minimum_size = Vector2(SIZE, SIZE)
	c.size = c.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c._ring = Panel.new()
	c._ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	c._ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(c._ring)
	c._apply_style()
	return c


func set_highlight(mode: String) -> void:
	highlight = mode
	_apply_style()


func _apply_style() -> void:
	# Base: generated stone tile, warm-tinted for the player side, cool for the enemy.
	var tile := UiTheme.tex(UiTheme.TEX_CELL_TILE)
	if tile != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tile
		var tint := Color(1.0, 0.96, 0.9) if side == 0 else Color(0.72, 0.78, 0.92)
		if highlight != "":
			tint = tint.lightened(0.15)
		sb.modulate_color = tint
		add_theme_stylebox_override("panel", sb)
	else:
		var base := UiTheme.PANEL if side == 0 else UiTheme.PANEL.darkened(0.25)
		var sb := StyleBoxFlat.new()
		sb.bg_color = base.lightened(0.06) if highlight != "" else base
		sb.set_corner_radius_all(8)
		add_theme_stylebox_override("panel", sb)
	# Highlight ring above the content.
	var border := Color(0, 0, 0, 0.35)
	var width := 2
	match highlight:
		"summon":
			border = UiTheme.GOLD
			width = 4
		"move":
			border = UiTheme.ACCENT
			width = 4
		"attack", "target":
			border = UiTheme.DANGER
			width = 5
		"selected":
			border = Color.WHITE
			width = 4
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color.TRANSPARENT
	ring_sb.set_corner_radius_all(8)
	ring_sb.border_color = border
	ring_sb.set_border_width_all(width)
	_ring.add_theme_stylebox_override("panel", ring_sb)


## Rebuilds the cell content from state.
func render(state: GameState) -> void:
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var p := state.players[side]
	if Board.master_cell(side, p.master_col) == cell:
		_render_master(state, p)
	else:
		var m := state.board.at(cell)
		if m != null:
			_render_monster(m)
	# Highlight ring stays above the occupant art.
	move_child(_ring, get_child_count() - 1)
	# Clicks must reach the cell itself in one click, never its decorations.
	UiTheme.pass_through(self)


func _render_master(_state: GameState, p: PlayerState) -> void:
	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 8
	portrait.offset_top = 8
	portrait.offset_right = -8
	portrait.offset_bottom = -8
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = UiTheme.tex(p.master.portrait)
	_content.add_child(portrait)

	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.set_corner_radius_all(8)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(3)
	ring.add_theme_stylebox_override("panel", sb)
	_content.add_child(ring)

	_content.add_child(_badge("%d" % p.master_hp, UiTheme.DANGER, Vector2(4, 4)))
	var name_l := UiTheme.label(p.master.display_name, 13, UiTheme.GOLD)
	name_l.position = Vector2(6, SIZE - 24)
	name_l.add_theme_color_override("font_outline_color", Color.BLACK)
	name_l.add_theme_constant_override("outline_size", 6)
	_content.add_child(name_l)


func _render_monster(m: MonsterInst) -> void:
	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 4
	art.offset_top = 4
	art.offset_right = -4
	art.offset_bottom = -4
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = UiTheme.tex(Db.card_art_path(m.def.id))
	if art.texture == null:
		var ph := ColorRect.new()
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		ph.color = UiTheme.guild_color(m.def.guild).darkened(0.5)
		_content.add_child(ph)
	else:
		_content.add_child(art)

	# stat bar
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -26
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.65)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	bar.add_theme_stylebox_override("panel", sb)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bar)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	bar.add_child(stats)
	stats.add_child(UiTheme.icon_label(UiTheme.ICON_ATK, str(m.atk()), 15, Color("ffb27d")))
	stats.add_child(UiTheme.icon_label(UiTheme.ICON_HP, str(m.hp), 15,
			Color("8fe08f") if m.hp >= m.max_hp() else Color("ff9d9d")))

	# level badge
	if m.def.max_level() > 1 or m.level > 1:
		_content.add_child(_badge("★%d" % m.level, Color(0.25, 0.2, 0.05, 0.9), Vector2(4, 4),
				UiTheme.GOLD))
	# shield ring
	if m.shield:
		var ring := Panel.new()
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color.TRANSPARENT
		rsb.set_corner_radius_all(8)
		rsb.border_color = Color("7dd8ff")
		rsb.set_border_width_all(3)
		ring.add_theme_stylebox_override("panel", rsb)
		_content.add_child(ring)
	# acted = dimmed
	if m.acted:
		_content.modulate = Color(0.6, 0.6, 0.65)


func _badge(text: String, bg: Color, pos: Vector2, fg: Color = Color.WHITE) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(UiTheme.label(text, 14, fg))
	return panel


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT and (state_has_content()):
			accept_event()
			inspect_requested.emit(cell)


## True when the cell currently shows a monster or a master (worth inspecting);
## empty cells let right-click fall through to "cancel selection".
func state_has_content() -> bool:
	return _content != null and _content.get_child_count() > 0
