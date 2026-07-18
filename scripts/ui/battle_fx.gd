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


## Sliding turn banner ("À vous de jouer !") on the generated golden ribbon.
static func banner(layer: Control, text: String, color: Color) -> void:
	var panel: Control
	var ribbon := UiTheme.tex(UiTheme.TEX_BANNER)
	if ribbon != null:
		panel = Control.new()
		panel.size = Vector2(680, 390)
		var img := TextureRect.new()
		img.texture = ribbon
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(img)
		var l := UiTheme.title_label(text, 34, color)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(l)
	else:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.72)
		sb.set_corner_radius_all(14)
		sb.border_color = color
		sb.set_border_width_all(2)
		sb.content_margin_left = 46
		sb.content_margin_right = 46
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		pc.add_theme_stylebox_override("panel", sb)
		var l := UiTheme.label(text, 40, color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		panel = pc
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.pass_through(panel)
	panel.modulate.a = 0.0  # hidden until positioned (avoids a 1-frame flash at 0,0)
	layer.add_child(panel)
	await layer.get_tree().process_frame  # let the panel compute its size
	panel.position = Vector2((layer.size.x - panel.size.x) / 2.0 - 46.0,
			330 if ribbon != null else 430)
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "position:x", panel.position.x + 46.0, 0.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.55)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(panel.queue_free)


## Lancer de PILE ou FACE du début de partie : une pièce à deux faces (côté
## joueur bleu / côté adverse rouge, chacune frappée du portrait du duelliste)
## tournoie, décélère et retombe sur le camp qui ouvre, puis une bannière annonce
## le résultat. Bloque l'entrée pendant l'animation. `await`-able.
static func coin_flip(layer: Control, winner_is_player: bool,
		player_tex: Texture2D = null, enemy_tex: Texture2D = null) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.0)
	# Taille/position explicites (comme la pièce) : les presets d'ancrage laissent
	# un rect 0×0 sur un enfant tout juste ajouté → aucun assombrissement.
	backdrop.size = layer.size
	backdrop.position = Vector2.ZERO
	backdrop.z_index = 100                              # au-dessus du plateau et des panneaux
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP   # gèle les clics pendant le tirage
	layer.add_child(backdrop)
	layer.create_tween().tween_property(backdrop, "color", Color(0, 0, 0, 0.62), 0.2)

	const SIZE := 208.0
	var win_color := UiTheme.GOLD if winner_is_player else UiTheme.DANGER

	var coin := Control.new()
	coin.size = Vector2(SIZE, SIZE)
	coin.pivot_offset = Vector2(SIZE / 2.0, SIZE / 2.0)
	coin.position = Vector2((layer.size.x - SIZE) / 2.0, (layer.size.y - SIZE) / 2.0 - 40.0)
	coin.z_index = 101                                  # au-dessus du voile
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.modulate = Color(1, 1, 1, 0)
	layer.add_child(coin)

	# Les deux faces superposées : on n'en montre qu'une à la fois (l'autre est
	# masquée), on bascule à chaque tranche du flip → illusion pile/face.
	var face_player := _coin_face(SIZE, Color("22406e"), player_tex)   # bleu = joueur
	var face_enemy := _coin_face(SIZE, Color("6e2323"), enemy_tex)     # rouge = adversaire
	coin.add_child(face_player)
	coin.add_child(face_enemy)
	face_enemy.visible = false

	var durs := [0.09, 0.10, 0.12, 0.14, 0.17, 0.20, 0.24]
	var flip := layer.create_tween()
	flip.tween_property(coin, "modulate:a", 1.0, 0.12)
	for i in durs.size():
		var d: float = durs[i]
		flip.tween_property(coin, "scale:x", 0.05, d).set_ease(Tween.EASE_IN)
		var show_enemy := (i % 2 == 0)   # tranche invisible : on retourne la pièce
		flip.tween_callback(func() -> void: face_enemy.set_visible(show_enemy); face_player.set_visible(not show_enemy))
		flip.tween_property(coin, "scale:x", 1.0, d).set_ease(Tween.EASE_OUT)
	# atterrissage garanti sur le gagnant
	flip.tween_callback(func() -> void: face_player.set_visible(winner_is_player); face_enemy.set_visible(not winner_is_player))
	flip.tween_property(coin, "scale", Vector2(1.22, 1.22), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip.tween_property(coin, "scale", Vector2.ONE, 0.1)
	await flip.finished

	banner(layer, "VOUS COMMENCEZ" if winner_is_player else "L'ADVERSAIRE COMMENCE", win_color)
	await layer.get_tree().create_timer(1.05).timeout

	var out := layer.create_tween()
	out.tween_property(coin, "modulate:a", 0.0, 0.22)
	out.parallel().tween_property(backdrop, "color", Color(0, 0, 0, 0.0), 0.22)
	await out.finished
	coin.queue_free()
	backdrop.queue_free()


## Une face de la pièce : disque coloré + portrait du duelliste révélé par
## l'ouverture ovale du médaillon (dont le cadre gravé masque les bords carrés).
static func _coin_face(size: float, disc_col: Color, portrait: Texture2D) -> Control:
	var face := Control.new()
	face.size = Vector2(size, size)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = disc_col
	sb.set_corner_radius_all(999)
	sb.border_color = Color("d8b24e")   # liséré doré
	sb.set_border_width_all(6)
	disc.add_theme_stylebox_override("panel", sb)
	disc.size = Vector2(size, size)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(disc)
	if portrait != null:
		var inset := size * 0.22
		var pr := TextureRect.new()
		pr.texture = portrait
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pr.position = Vector2(inset, inset)
		pr.size = Vector2(size - 2.0 * inset, size - 2.0 * inset)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(pr)
	var orn := TextureRect.new()                        # médaillon gravé par-dessus
	orn.texture = UiTheme.tex("res://assets/sprites/ui/gold/medallion.png")
	orn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	orn.size = Vector2(size, size)
	orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(orn)
	return face


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
