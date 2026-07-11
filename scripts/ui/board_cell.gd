class_name BoardCell
extends Panel
## One board square, laid over the painted arena texture (the tiles are part
## of the arena art, so the cell itself is transparent). Renders its occupant
## (monster or master) from GameState and shows action highlights.
## Instanced from scenes/widgets/board_cell.tscn; sized by the battle scene.

signal clicked(cell: Vector2i)
signal inspect_requested(cell: Vector2i)

var cell: Vector2i
var side: int  ## player index owning this row
var highlight := ""  ## "", "summon", "move", "attack", "selected", "target"

var _content: Control
var _pulse: Tween

@onready var _ring: Panel = $Ring


## Called by the battle scene right after instantiating the widget.
func setup(p_cell: Vector2i) -> void:
	cell = p_cell
	side = Board.row_owner(p_cell.y)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_apply_style()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


## Survol : la case s'éclaire doucement (feedback même sans highlight).
func _on_hover(on: bool) -> void:
	var target := Color(1.18, 1.18, 1.12) if on else Color.WHITE
	create_tween().tween_property(self, "modulate", target, 0.12)


func set_highlight(mode: String) -> void:
	highlight = mode
	_apply_style()
	if _pulse != null:
		_pulse.kill()
		_pulse = null
		_ring.modulate.a = 1.0
	# Cases jouables : pulsation douce qui attire l'œil ; sélection plus vive.
	if mode in ["summon", "move", "attack", "target"]:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_ring, "modulate:a", 0.45, 0.65)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse.tween_property(_ring, "modulate:a", 1.0, 0.65)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif mode == "selected":
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_ring, "modulate:a", 0.7, 0.4)
		_pulse.tween_property(_ring, "modulate:a", 1.0, 0.4)


func _apply_style() -> void:
	# Clean flat tile (anime navy+gold look) drawn by the cell itself,
	# teintée par camp : rangées hautes (adversaire) chaudes, basses (joueur) froides.
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.24, 0.16, 0.22, 0.55) if cell.y >= 2 else Color(0.14, 0.19, 0.33, 0.55)
	base.set_corner_radius_all(12)
	base.border_color = Color(0.79, 0.65, 0.31, 0.30)
	base.set_border_width_all(2)
	base.shadow_color = Color(0, 0, 0, 0.35)
	base.shadow_size = 6
	base.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", base)

	var fill := Color.TRANSPARENT
	var border := Color.TRANSPARENT
	var width := 0
	match highlight:
		"summon":
			border = UiTheme.GOLD
			fill = Color(UiTheme.GOLD, 0.14)
			width = 4
		"move":
			border = UiTheme.ACCENT
			fill = Color(UiTheme.ACCENT, 0.14)
			width = 4
		"attack", "target":
			border = UiTheme.DANGER
			fill = Color(UiTheme.DANGER, 0.16)
			width = 5
		"selected":
			border = Color.WHITE
			width = 4
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = fill
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


## Detoured battle sprite for a unit, or null when not generated yet.
static func unit_tex(id: String) -> Texture2D:
	return UiTheme.tex("res://assets/sprites/units/%s.png" % id)


func _render_master(_state: GameState, p: PlayerState) -> void:
	# Camp-tinted halo under the master — red enemy, blue player (mockup style).
	var tile := ColorRect.new()
	tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.offset_left = 4
	tile.offset_top = 4
	tile.offset_right = -4
	tile.offset_bottom = -4
	tile.color = Color("2f4a86", 0.4) if side == 0 else Color("8c2f26", 0.4)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(tile)
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.set_corner_radius_all(8)
	sb.border_color = Color("6e93e8") if side == 0 else Color("d95f4b")
	sb.set_border_width_all(3)
	ring.add_theme_stylebox_override("panel", sb)
	_content.add_child(ring)

	var sprite := unit_tex("master_%s" % p.master.id)
	if sprite != null:
		var unit := TextureRect.new()
		unit.set_anchors_preset(Control.PRESET_FULL_RECT)
		unit.offset_left = 8
		unit.offset_top = 4
		unit.offset_right = -8
		unit.offset_bottom = -12
		unit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		unit.texture = sprite
		_content.add_child(unit)
	else:
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

	var hp := _badge("%d" % p.master_hp, UiTheme.DANGER, Vector2.ZERO)
	_content.add_child(hp)
	hp.position = Vector2(size.x - hp.get_minimum_size().x - 4, size.y - 30)
	var name_l := UiTheme.label(p.master.display_name, 13, UiTheme.GOLD)
	name_l.position = Vector2(6, size.y - 24)
	name_l.add_theme_color_override("font_outline_color", Color.BLACK)
	name_l.add_theme_constant_override("outline_size", 6)
	_content.add_child(name_l)


func _render_monster(m: MonsterInst) -> void:
	# Preferred: detoured sprite standing on the tile (mockup style).
	var sprite := unit_tex(String(m.def.id))
	if sprite != null:
		var unit := TextureRect.new()
		unit.set_anchors_preset(Control.PRESET_FULL_RECT)
		unit.offset_left = 6
		unit.offset_top = 2
		unit.offset_right = -6
		unit.offset_bottom = -10
		unit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		unit.texture = sprite
		_content.add_child(unit)
	else:
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

	# Stat plates flanking the unit's feet, mockup style: green ATQ / red PV.
	var atk_badge := _stat_badge(str(m.atk()), Color("2f5a1e"), Color("7fae4a"))
	atk_badge.position = Vector2(size.x * 0.16, size.y - 38)
	_content.add_child(atk_badge)
	var hp_border := Color("c04b3a") if m.hp >= m.max_hp() else Color("e88a3a")
	var hp_badge := _stat_badge(str(m.hp), Color("5a1f1a"), hp_border)
	_content.add_child(hp_badge)
	hp_badge.position = Vector2(size.x * 0.84 - hp_badge.get_minimum_size().x,
			size.y - 38)

	# level badge
	if m.def.max_level() > 1 or m.level > 1:
		_content.add_child(_badge("★%d" % m.level, Color(0.25, 0.2, 0.05, 0.9), Vector2(4, 4),
				UiTheme.GOLD))
	# ability indicators (top-right): attack type + keywords
	var abil := _ability_icons(m)
	if abil != null:
		_content.add_child(abil)
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


const _PX := "res://assets/sprites/ui/pixel/"

## Vertical strip of small keyword icons (attack type + abilities) at the
## unit's top-right, so its capabilities read at a glance. Null when empty.
func _ability_icons(m: MonsterInst) -> Control:
	var paths: Array[String] = []
	match m.def.attack_type:
		GameConst.AttackType.RANGED:
			paths.append(_PX + "kw_ranged.png")
		GameConst.AttackType.MAGIC:
			paths.append(_PX + "kw_magic.png")
		_:
			paths.append(_PX + "icon_stat_attack.png")
	if m.has_keyword(GameConst.KW_FLYING):
		paths.append(_PX + "kw_flying.png")
	if m.keyword_value(GameConst.KW_ARMOR) > 0:
		paths.append(_PX + "kw_armor.png")
	if m.keyword_value(GameConst.KW_RIPOSTE) > 0:
		paths.append(_PX + "kw_riposte.png")
	if m.keyword_value(GameConst.KW_REGEN) > 0:
		paths.append(_PX + "kw_regen.png")
	if m.has_keyword(GameConst.KW_HASTE):
		paths.append(_PX + "kw_haste.png")
	if m.has_keyword(GameConst.KW_SHIELD):
		paths.append(_PX + "icon_stat_shield.png")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in paths:
		var tex := UiTheme.tex(p)
		if tex == null:
			continue
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(24, 24)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.62)
		sb.set_corner_radius_all(5)
		sb.border_color = Color(0.85, 0.72, 0.4, 0.6)
		sb.set_border_width_all(1)
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := TextureRect.new()
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 2
		ic.offset_top = 2
		ic.offset_right = -2
		ic.offset_bottom = -2
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(ic)
		col.add_child(chip)
	if col.get_child_count() == 0:
		col.queue_free()
		return null
	col.position = Vector2(size.x - 28, 4)
	return col


## Small colored stat plate (mockup style: green ATQ shield / red PV shield).
func _stat_badge(value: String, bg: Color, border: Color) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg, 0.92)
	sb.set_corner_radius_all(6)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(value, 17, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	chip.add_child(l)
	return chip


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
