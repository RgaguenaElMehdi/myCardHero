class_name BattleFx
extends RefCounted
## Procedural battle VFX. Every helper spawns temporary nodes on the given
## layer (a mouse-ignoring Control above the board) and cleans itself up.
## Callers pace themselves with their own awaits; effects are fire-and-forget.


## Explosion of particles (impacts, deaths, dust).
static func burst(layer: Control, pos: Vector2, color: Color, amount: int = 18,
		speed: float = 220.0, gravity: float = 320.0, lifetime: float = 0.5) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = color
	layer.add_child(p)
	_free_later(layer, p, lifetime + 0.6)


## Gentle rising sparkles (heals, buffs, casts).
static func sparkles(layer: Control, pos: Vector2, color: Color, amount: int = 14) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, 20)
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.spread = 55.0
	p.direction = Vector2.UP
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, -40)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = color
	layer.add_child(p)
	_free_later(layer, p, 1.4)


## Expanding ring (shields, level-ups).
static func ring(layer: Control, pos: Vector2, color: Color, radius: float = 85.0,
		duration: float = 0.45) -> void:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(999)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(16, 16)
	panel.position = pos - panel.size / 2.0
	panel.pivot_offset = panel.size / 2.0
	layer.add_child(panel)
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE * (radius / 8.0), duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(panel.queue_free)


## Melee charge: a copy of the attacker's art dashes toward the target and back.
static func lunge(layer: Control, from: Vector2, to: Vector2, texture: Texture2D,
		size := Vector2(110, 110)) -> void:
	if texture == null:
		return
	var spr := TextureRect.new()
	spr.texture = texture
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	spr.size = size
	spr.position = from - size / 2.0
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(spr)
	var hit := from.lerp(to, 0.68) - size / 2.0
	var tw := layer.create_tween()
	tw.tween_property(spr, "position", hit, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "position", from - size / 2.0, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(spr.queue_free)


## Ranged/magic projectile with a small trail, bursting on arrival.
static func projectile(layer: Control, from: Vector2, to: Vector2, color: Color,
		duration: float = 0.22) -> void:
	var dot := _circle(color, 18.0)
	dot.position = from - dot.size / 2.0
	layer.add_child(dot)
	var glow := _circle(Color(color, 0.35), 34.0)
	glow.position = from - glow.size / 2.0
	layer.add_child(glow)
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(dot, "position", to - dot.size / 2.0, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "position", to - glow.size / 2.0, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		burst(layer, to, color, 14, 180.0, 60.0, 0.35)
		dot.queue_free()
		glow.queue_free())


## Death: the victim's art shrinks, spins and fades while dark motes fly.
static func death(layer: Control, pos: Vector2, texture: Texture2D,
		size := Vector2(120, 120)) -> void:
	burst(layer, pos, Color(0.25, 0.2, 0.3), 20, 240.0, 120.0)
	if texture == null:
		return
	var spr := TextureRect.new()
	spr.texture = texture
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	spr.size = size
	spr.position = pos - size / 2.0
	spr.pivot_offset = size / 2.0
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(spr)
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(0.1, 0.1), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "rotation", 0.9, 0.35)
	tw.tween_property(spr, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(spr.queue_free)


## Bright flash covering one cell (evolutions, big hits).
static func flash_cell(layer: Control, pos: Vector2, color: Color,
		size := Vector2(148, 148), duration: float = 0.4) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = pos - size / 2.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw := layer.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)


## Screen-edge colored flash (master damage).
static func vignette(layer: Control, color: Color, duration: float = 0.4) -> void:
	var rect := ColorRect.new()
	rect.color = Color(color, 0.28)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw := layer.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)


## Sliding turn banner ("À vous de jouer !").
static func banner(layer: Control, text: String, color: Color) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_corner_radius_all(14)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.content_margin_left = 46
	sb.content_margin_right = 46
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 40, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	panel.modulate.a = 0.0  # hidden until positioned (avoids a 1-frame flash at 0,0)
	layer.add_child(panel)
	await layer.get_tree().process_frame  # let the panel compute its size
	panel.position = Vector2((layer.size.x - panel.size.x) / 2.0 - 46.0, 430)
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "position:x", panel.position.x + 46.0, 0.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.55)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(panel.queue_free)


static func _circle(color: Color, diameter: float) -> Panel:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(999)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(diameter, diameter)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


static func _free_later(layer: Control, node: Node, seconds: float) -> void:
	layer.get_tree().create_timer(seconds).timeout.connect(node.queue_free)
