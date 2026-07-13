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
	# Déjà dans l'arbre ici : set_anchors_preset seul garderait le rect 0×0
	# (offsets compensés) → popup réduit au coin haut-gauche, sans fond sombre.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		# Boîte au ratio exact de la carte : pas de bandes de letterboxing
		# (les cartes composées n'ont pas toutes les mêmes dimensions).
		var h := 780.0
		img.custom_minimum_size = Vector2(h * tex.get_width() / tex.get_height(), h)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return img
	return CardWidget.create(fallback_def, 480) if fallback_def != null else Control.new()


## Ornate 9-slice frame for the inspector panel (gold filigree corners on a
## deep-black centre). Falls back to the shared stone panel if the art is absent.
func _popup_frame() -> StyleBox:
	var tex := UiTheme.tex("res://assets/sprites/ui/pixel/panel_popup.png")
	if tex == null:
		return UiTheme.panel_ornate()
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = tex.get_width() * 0.16
	sb.texture_margin_right = tex.get_width() * 0.16
	sb.texture_margin_top = tex.get_height() * 0.20
	sb.texture_margin_bottom = tex.get_height() * 0.20
	# Keep text clear of the corner flourishes (which fill the top/bottom bands).
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 58
	sb.content_margin_bottom = 56
	return sb


## A thin gold rule used to separate sections.
func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.79, 0.65, 0.31, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## sections: Array of [header, body] (empty header = flavor block, italic-dim).
func _side_panel(title: String, subtitle: String, sections: Array,
		width: float = 480.0) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _popup_frame())
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)
	vbox.add_child(UiTheme.title_label(title, 30))
	if subtitle != "":
		vbox.add_child(UiTheme.label(subtitle, 16, UiTheme.TEXT_DIM))
	for sec in sections:
		var header: String = sec[0]
		var text: String = sec[1]
		if text.strip_edges() == "":
			continue
		vbox.add_child(_divider())
		if header != "":
			var h := UiTheme.label(header, 15, UiTheme.GOLD)
			var f := UiTheme.title_font()
			if f != null:
				h.add_theme_font_override("font", f)
			vbox.add_child(h)
		var color := UiTheme.TEXT_DIM if header == "" else UiTheme.TEXT
		var l := UiTheme.label(text, 16, color)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 50, 0)
		vbox.add_child(l)
	return panel


func _build_card(def: CardDef, live: MonsterInst) -> void:
	var row := _base()
	row.add_child(_card_image(CardWidget.full_card_path(def.id), def))
	var cost_txt := "%d pierre%s" % [def.cost, "" if def.cost <= 1 else "s"]
	var sections: Array = []
	var subtitle := ""
	if def.is_monster():
		subtitle = "%s · %s" % [GameText.ATTACK_TYPE_NAMES[def.attack_type], cost_txt]
		# Niveaux
		var lv_lines: PackedStringArray = []
		for i in def.levels.size():
			var lv: Dictionary = def.levels[i]
			var seuil := "" if i == 0 else " (%d XP)" % int(lv.xp)
			lv_lines.append("Niveau %d%s : %d ATQ / %d PV"
					% [i + 1, seuil, int(lv.atk), int(lv.hp)])
		lv_lines.append("Gagne 1 XP en blessant, 2 en tuant ; monter de niveau restaure les PV.")
		sections.append(["NIVEAUX", "\n".join(lv_lines)])
		# Capacités
		var caps: PackedStringArray = []
		caps.append("%s : %s." % [GameText.ATTACK_TYPE_NAMES[def.attack_type],
				GameText.ATTACK_TYPE_DEFS[def.attack_type]])
		for kw in def.keywords:
			var kw_name: String = GameText.KEYWORD_NAMES.get(String(kw), String(kw))
			var value = def.keywords[kw]
			var shown := kw_name if value is bool else "%s %d" % [kw_name, int(value)]
			caps.append("%s : %s." % [shown, GameText.KEYWORD_DEFS.get(String(kw), "")])
		if not def.on_summon.is_empty():
			caps.append("Invocation : " + GameText.describe_effect(def.on_summon))
		if not def.on_death.is_empty():
			caps.append("Mort : " + GameText.describe_effect(def.on_death))
		if not def.on_attack.is_empty():
			caps.append("Attaque : " + GameText.describe_effect(def.on_attack))
		if def.evolves_to != &"":
			var evo_name := ""
			var tree := Engine.get_main_loop() as SceneTree
			var db = tree.root.get_node_or_null("Db") if tree != null else null
			if db != null and db.card(def.evolves_to) != null:
				evo_name = db.card(def.evolves_to).display_name
			var target := evo_name if evo_name != "" else "sa forme évoluée"
			caps.append("Au niveau max, évolue en %s pour %d pierres (PV restaurés)."
					% [target, def.evolve_cost])
		sections.append(["CAPACITÉS", "\n".join(caps)])
	else:
		subtitle = "Sort · %s" % cost_txt
		sections.append(["EFFET", GameText.describe_effect(def.effect)])
	if def.description != "":
		sections.append(["", "« %s »" % def.description])
	if live != null:
		var live_lines: PackedStringArray = []
		live_lines.append("Niveau %d · %d ATQ · %d/%d PV"
				% [live.level, live.atk(), live.hp, live.max_hp()])
		if not live.at_max_level():
			live_lines.append("XP %d / %d" % [live.xp, live.next_level_xp()])
		if live.shield:
			live_lines.append("Bouclier actif")
		live_lines.append("A déjà agi ce tour" if live.acted else "Peut encore agir")
		sections.append(["EN JEU", "\n".join(live_lines)])
	row.add_child(_side_panel(def.display_name, subtitle, sections))
	_finish(row)


func _build_master(master: MasterDef) -> void:
	var row := _base()
	var path := "res://assets/sprites/cards_full/master_%s.png" % master.id
	row.add_child(_card_image(path, null))
	var subtitle := "Maître — %s · %d PV" \
			% [GameConst.GUILD_NAMES.get(master.guild, ""), master.hp]
	var sections: Array = [
		["COMPÉTENCE", "%s  (%d pierres, 1×/tour)\n%s"
				% [master.power_name, master.power_cost, master.power_desc]],
		["ATTRIBUT", master.passive_desc],
	]
	if master.lore != "":
		sections.append(["", "« %s »" % master.lore])
	row.add_child(_side_panel(master.display_name, subtitle, sections))
	_finish(row)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
