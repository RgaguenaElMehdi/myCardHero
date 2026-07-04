extends Control
## Illustrated rules guide: poster-style numbered panels + an annotated
## "how to read a card" section built around a real composed card.

const ACCENT_CYCLE := [UiTheme.DANGER, UiTheme.OK, Color("8b6bc7"), UiTheme.GOLD,
		UiTheme.ACCENT]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UiTheme.title_label("Guide du jeu", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	add_child(title)

	var back := Button.new()
	back.text = "← Menu"
	back.position = Vector2(40, 32)
	back.custom_minimum_size = Vector2(160, 52)
	UiTheme.style_button(back, UiTheme.PANEL_LIGHT, 20)
	back.pressed.connect(func() -> void: Game.goto("main_menu"))
	add_child(back)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 240
	scroll.offset_right = -240
	scroll.offset_top = 104
	scroll.offset_bottom = -20
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	scroll.add_child(content)

	content.add_child(_anatomy_section())
	content.add_child(_rules_grid())


# --- « Comment lire une carte » ------------------------------------------

func _anatomy_section() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_ornate())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var head := UiTheme.title_label("Comment lire une carte", 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(head)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	vbox.add_child(row)

	var left := [
		[1, "Coût", "Les pierres nécessaires pour jouer la carte (gemme)."],
		[4, "Type", "Écho = créature · Sort = effet immédiat · Ascendant = forme évoluée."],
		[6, "ATQ", "Les dégâts infligés quand la créature attaque."],
		[7, "Portée", "Mêlée : sa colonne · Distance : partout · Magie : ignore Armure et Bouclier."],
	]
	var right := [
		[2, "Nom", "Le nom de la carte."],
		[3, "Faction", "Flamme, Sylve, Ombre ou Lumière — couleur du cadre et emblème."],
		[8, "Niveau max / PV", "Ses niveaux possibles, et ses Points de Vie."],
		[9, "Effets & niveaux", "Mots-clés, stats des niveaux suivants (seuils d'XP) et évolution."],
	]

	row.add_child(_callout_column(left, HORIZONTAL_ALIGNMENT_RIGHT))

	var card := TextureRect.new()
	card.texture = UiTheme.tex(CardWidget.full_card_path(&"squire"))
	card.custom_minimum_size = Vector2(360, 500)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)

	row.add_child(_callout_column(right, HORIZONTAL_ALIGNMENT_LEFT))
	return panel


func _callout_column(items: Array, align: int) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	for item in items:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel",
				UiTheme.panel(Color(0, 0, 0, 0.35), 10, UiTheme.GOLD.darkened(0.35), 1))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		box.add_child(h)
		var chip := _number_chip(int(item[0]))
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(UiTheme.title_label(String(item[1]), 18))
		var body := UiTheme.label(String(item[2]), 14, UiTheme.TEXT_DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(body)
		if align == HORIZONTAL_ALIGNMENT_RIGHT:
			h.add_child(text_box)
			h.add_child(chip)
		else:
			h.add_child(chip)
			h.add_child(text_box)
		col.add_child(box)
	return col


func _number_chip(n: int) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.GOLD.darkened(0.15)
	sb.set_corner_radius_all(99)
	sb.border_color = Color(0, 0, 0, 0.6)
	sb.set_border_width_all(2)
	chip.add_theme_stylebox_override("panel", sb)
	chip.custom_minimum_size = Vector2(36, 36)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiTheme.title_label(str(n), 18, Color("2a2410"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(l)
	return chip


# --- rules sections --------------------------------------------------------

func _rules_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	var sections := _sections()
	for i in sections.size():
		grid.add_child(_section_panel(i + 1, sections[i][0], sections[i][1],
				ACCENT_CYCLE[i % ACCENT_CYCLE.size()]))
	return grid


func _section_panel(num: int, title: String, bbcode: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_ornate())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vbox.add_child(head)
	head.add_child(_number_chip(num))
	var t := UiTheme.title_label(title, 22, accent.lightened(0.2))
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var sep := ColorRect.new()
	sep.color = Color(accent, 0.5)
	sep.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(sep)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 16)
	text.add_theme_color_override("default_color", UiTheme.TEXT)
	text.text = bbcode
	vbox.add_child(text)
	return panel


func _sections() -> Array:
	var accent := UiTheme.ACCENT.to_html(false)
	var danger := UiTheme.DANGER.to_html(false)
	var sections: Array = []
	sections.append(["But du jeu",
		"Réduisez à zéro les PV du [b]Maître adverse[/b] — une pièce posée sur sa rangée arrière. Deck vide ? Chaque pioche manquée inflige une [b]fatigue croissante[/b] à votre Maître (1, puis 2, puis 3…)."])
	sections.append(["Mise en place",
		"Deck de [b]25 cartes[/b] (max 2 exemplaires). Main de départ : 5 cartes, un [b]mulligan[/b] possible. Vous commencez avec [color=#%s]3 pierres[/color] ; le premier joueur ne pioche pas au tour 1.\n[i]Astuce : clic droit sur n'importe quelle carte pour l'inspecter en grand.[/i]" % accent])
	sections.append(["Le plateau",
		"Deux rangées de 3 cases par joueur : [b]avant[/b] (vers l'ennemi) et [b]arrière[/b]. Le Maître occupe une case arrière et peut se décaler d'une colonne par tour. Les monstres s'invoquent sur vos cases libres."])
	sections.append(["Le tour de jeu",
		"Début : [color=#%s]+2 pierres[/color] et 1 carte. Puis, dans l'ordre voulu :\n• [b]Invoquer[/b] (mal d'invocation, sauf Célérité)\n• [b]Lancer des sorts[/b]\n• Chaque monstre : [b]bouger OU attaquer[/b]\n• Déplacer le Maître (1×) · Pouvoir du Maître (1×)\n• [b]Évoluer[/b] un monstre au niveau max (gratuit)" % accent])
	sections.append(["Combat & portées",
		"• [color=#%s]Mêlée[/color] : frappe le premier monstre non-volant de sa colonne ; bloqué si un allié est devant.\n• [color=#%s]Distance[/color] : vise n'importe quel monstre.\n• [color=#%s]Magie[/color] : vise tout et [b]ignore Armure et Bouclier[/b].\nLe Maître n'est attaquable que si sa colonne est vide de défenseurs (et en mêlée, depuis la rangée avant)." % [danger, danger, danger]])
	sections.append(["XP & évolution",
		"[b]+1 XP[/b] en blessant, [b]+2 XP[/b] en détruisant. Au seuil : niveau supérieur, stats accrues et [b]soin complet[/b]. Au niveau max, certains Échos deviennent des [b]Ascendants[/b] en payant des pierres — des créatures bien plus puissantes."])
	var kw_lines: PackedStringArray = []
	for kw in GameText.KEYWORD_NAMES:
		kw_lines.append("• [b]%s[/b] : %s." % [GameText.KEYWORD_NAMES[kw],
				GameText.KEYWORD_DEFS.get(kw, "")])
	sections.append(["Mots-clés", "\n".join(kw_lines)])
	var m_lines: PackedStringArray = []
	for id in Db.masters:
		var m: MasterDef = Db.masters[id]
		m_lines.append("• [b]%s[/b] — %s [i]%s[/i] (%d pierres) : %s"
				% [m.display_name, m.passive_desc, m.power_name, m.power_cost, m.power_desc])
	sections.append(["Les Maîtres", "\n".join(m_lines)])
	sections.append(["Économie des pierres",
		"Les pierres paient tout : invocations, sorts, pouvoirs, évolutions. Plafond : [b]12[/b]. Détruire un monstre ennemi rapporte [b]des pierres égales à son niveau[/b] — l'agression finance votre plan."])
	sections.append(["Conseils",
		"• Gardez toujours un défenseur dans la colonne de votre Maître.\n• Les volants ne bloquent pas la mêlée.\n• Monter de niveau soigne : achevez au bon moment.\n• Gardez 2-3 pierres d'avance pour les évolutions.\n• Contre l'Armure, cherchez la Magie."])
	return sections
