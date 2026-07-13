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
var _unit: TextureRect      ## sprite de l'occupant (pour le halo de sélection)
var _halo: TextureRect      ## silhouette lumineuse derrière le sprite

@onready var _ring: TextureRect = $Ring


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
		_pulse.tween_property(_ring, "modulate:a", 0.62, 0.65)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse.tween_property(_ring, "modulate:a", 1.0, 0.65)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif mode == "selected":
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_ring, "modulate:a", 0.7, 0.4)
		_pulse.tween_property(_ring, "modulate:a", 1.0, 0.4)


func _apply_style() -> void:
	# Les logements sont GRAVÉS dans le décor : pas de cadre dessiné. La
	# surbrillance est une lueur douce au sol qui emplit le logement (pas de
	# rectangle), teintée selon l'action.
	var fill := Color.TRANSPARENT
	var halo := Color.TRANSPARENT
	match highlight:
		"summon":
			fill = Color(UiTheme.GOLD, 0.9)
		"move":
			fill = Color(0.35, 0.72, 1.0, 0.95)
		"attack", "target":
			fill = Color(UiTheme.DANGER, 0.9)
			halo = Color(1.6, 0.55, 0.45, 0.85)
		"selected":
			fill = Color(1, 1, 1, 0.8)
			halo = Color(1.7, 1.6, 1.1, 0.9)
	_ring.self_modulate = fill
	if is_instance_valid(_halo):
		_halo.self_modulate = halo


## Rebuilds the cell content from state.
func render(state: GameState) -> void:
	if _content != null:
		_content.queue_free()
	_unit = null
	_halo = null
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


## Sprite détouré debout dans le logement : à l'échelle (marge visible tout
## autour), pieds posés un peu au-dessus du bord bas. Un halo-silhouette est
## préparé derrière lui pour la sélection.
func _standing_sprite(tex: Texture2D, breathe: bool) -> void:
	var ts := tex.get_size()
	var k := minf(size.x * 0.62 / ts.x, size.y * 0.80 / ts.y)
	var ssz := ts * k
	var feet_y := size.y - maxf(19.0, size.y * 0.20)
	var pos := Vector2((size.x - ssz.x) / 2.0, feet_y - ssz.y)
	# Halo de sélection : même sprite légèrement agrandi, teinté, derrière.
	_halo = TextureRect.new()
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.texture = tex
	_halo.size = ssz * 1.14
	_halo.position = pos - (ssz * 0.07)
	_halo.self_modulate = Color(1, 1, 1, 0)
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_halo)
	var unit := TextureRect.new()
	unit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit.stretch_mode = TextureRect.STRETCH_SCALE
	unit.texture = tex
	unit.size = ssz
	unit.position = pos
	unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(unit)
	_unit = unit
	_apply_style()  # réapplique le halo si la case est déjà sélectionnée
	if breathe:
		# Respiration subtile : l'unité vit sur sa case.
		var period := 1.1 + randf() * 0.5
		var tw := unit.create_tween().set_loops()
		tw.tween_property(unit, "position:y", -2.0, period).as_relative()\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(unit, "position:y", 2.0, period).as_relative()\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _render_master(_state: GameState, p: PlayerState) -> void:
	# Halo de camp au sol (bleu joueur / rouge adverse) : on comprend
	# immédiatement « c'est le Maître », sans piédestal.
	var col := Color(0.45, 0.72, 1.0) if side == 0 else Color(1.0, 0.42, 0.36)
	for i in 2:  # deux nappes superposées = halo net et bien visible
		var glow := TextureRect.new()
		var gw := size.x * (1.02 if i == 0 else 0.68)
		var gh := size.y * (0.58 if i == 0 else 0.4)
		glow.position = Vector2((size.x - gw) / 2.0, size.y - gh - 4)
		glow.size = Vector2(gw, gh)
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.texture = UiTheme.tex("res://assets/sprites/ui/battle/glow_master.png")
		glow.modulate = Color(col, 1.0)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(glow)

	var sprite := unit_tex("master_%s" % p.master.id)
	if sprite != null:
		_standing_sprite(sprite, true)
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
		# Ombre portée au sol : ancre l'unité sur le logement.
		var shadow := TextureRect.new()
		var sw := size.x * 0.5
		var sh := size.y * 0.18
		shadow.position = Vector2((size.x - sw) / 2.0,
				size.y - maxf(16.0, size.y * 0.17) - sh * 0.5)
		shadow.size = Vector2(sw, sh)
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_SCALE
		shadow.texture = UiTheme.tex("res://assets/sprites/ui/battle/glow_master.png")
		shadow.modulate = Color(0, 0, 0, 0.4)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(shadow)
		_standing_sprite(sprite, true)
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

	# level badge + XP vers le niveau suivant (« 2/3 ») juste dessous
	if m.def.max_level() > 1 or m.level > 1:
		_content.add_child(_badge("★%d" % m.level, Color(0.25, 0.2, 0.05, 0.9), Vector2(4, 4),
				UiTheme.GOLD))
		if not m.at_max_level():
			_content.add_child(_badge("%d/%d" % [m.xp, m.next_level_xp()],
					Color(0.08, 0.1, 0.18, 0.9), Vector2(4, 30), Color(0.72, 0.82, 1.0)))
	# ability indicators (top-right): attack type + keywords
	var abil := _ability_icons(m)
	if abil != null:
		_content.add_child(abil)
	# bouclier : aura magique bleutée enveloppant l'unité (pas de rectangle)
	if m.shield:
		var aura := TextureRect.new()
		var aw := size.x * 0.7
		var ah := size.y * 0.85
		aura.position = Vector2((size.x - aw) / 2.0, size.y - ah - 8)
		aura.size = Vector2(aw, ah)
		aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		aura.stretch_mode = TextureRect.STRETCH_SCALE
		aura.texture = UiTheme.tex("res://assets/sprites/ui/battle/glow_master.png")
		aura.modulate = Color(0.49, 0.85, 1.0, 0.5)
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(aura)
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
		chip.custom_minimum_size = Vector2(24, 24) * UiTheme.touch_scale()
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
	col.position = Vector2(size.x - 28.0 * UiTheme.touch_scale(), 4)
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


var _holding := false
var _long := false


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and state_has_content():
		accept_event()
		inspect_requested.emit(cell)             # desktop: right-click inspects
	elif event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_holding = true
			_long = false
			_long_press()
		else:
			_holding = false                     # released before the long-press fired
			if not _long:
				clicked.emit(cell)               # quick tap / click = act

## Hold ~0.5 s (touch or mouse) on an occupied cell to inspect it — touch = right-click.
func _long_press() -> void:
	await get_tree().create_timer(0.5).timeout
	if _holding and state_has_content():
		_long = true
		inspect_requested.emit(cell)
	_holding = false


## True when the cell currently shows a monster or a master (worth inspecting);
## empty cells let right-click fall through to "cancel selection".
func state_has_content() -> bool:
	return _content != null and _content.get_child_count() > 0
