extends Control
## Rules guide: scrollable, sectioned explanation of every game rule.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UiTheme.title_label("Guide du jeu", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	add_child(title)

	var back := Button.new()
	back.text = "← Menu"
	back.position = Vector2(40, 36)
	back.custom_minimum_size = Vector2(160, 52)
	UiTheme.style_button(back, UiTheme.PANEL_LIGHT, 20)
	back.pressed.connect(func() -> void: Game.goto("main_menu"))
	add_child(back)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(460, 120)
	scroll.custom_minimum_size = Vector2(1000, 900)
	add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(980, 0)
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_font_size_override("bold_font_size", 19)
	text.add_theme_color_override("default_color", UiTheme.TEXT)
	text.text = _guide_text()
	scroll.add_child(text)


func _guide_text() -> String:
	var gold := UiTheme.GOLD.to_html(false)
	var accent := UiTheme.ACCENT.to_html(false)
	var danger := UiTheme.DANGER.to_html(false)
	var h := func(s: String) -> String:
		return "\n[color=#%s][b]%s[/b][/color]\n" % [gold, s]
	var sections: PackedStringArray = []

	sections.append(h.call("🎯 But du jeu"))
	sections.append("Réduisez à zéro les points de vie du [b]Maître adverse[/b]. Votre Maître est une pièce posée sur votre rangée arrière : s'il tombe, vous perdez. Si votre deck est vide au moment de piocher, vous perdez aussi.")

	sections.append(h.call("🗺 Le plateau"))
	sections.append("Chaque joueur possède [b]deux rangées de 3 cases[/b] : une rangée avant (vers l'ennemi) et une rangée arrière. Le Maître occupe une case de la rangée arrière et peut se décaler d'une colonne par tour (cliquez sur lui). Les monstres s'invoquent sur les cases libres de votre côté.")

	sections.append(h.call("💎 Les pierres"))
	sections.append("Vous commencez avec [color=#%s]3 pierres[/color] et en gagnez [color=#%s]2 par tour[/color] (maximum 12). Elles paient tout : invocations, sorts, pouvoir du Maître et évolutions. Détruire un monstre ennemi rapporte des pierres égales à son niveau." % [accent, accent])

	sections.append(h.call("🃏 Le tour de jeu"))
	sections.append("Au début de votre tour : +2 pierres et 1 carte piochée (main limitée à 7 ; le premier joueur ne pioche pas au tour 1). Ensuite, agissez dans l'ordre que vous voulez :\n• [b]Invoquer[/b] un monstre (il ne peut pas agir ce tour-là, sauf Célérité)\n• [b]Lancer[/b] des sorts\n• Chaque monstre a [b]une action[/b] : se déplacer d'une case OU attaquer\n• [b]Déplacer le Maître[/b] (1 fois, gratuit)\n• Utiliser le [b]pouvoir du Maître[/b] (1 fois, coût en pierres)\n• Faire [b]évoluer[/b] un monstre au niveau maximum (action gratuite)")

	sections.append(h.call("⚔ Le combat"))
	sections.append("Trois types d'attaque :\n• [color=#%s]Mêlée[/color] : frappe le monstre non-volant le plus proche dans sa colonne. Un monstre en rangée arrière est bloqué si un allié occupe la case devant lui.\n• [color=#%s]Distance[/color] : peut viser n'importe quel monstre ennemi.\n• [color=#%s]Magie[/color] : vise n'importe quelle cible et [b]ignore Armure et Bouclier[/b].\n\nLes dégâts = ATQ de l'attaquant − Armure de la cible. Le [b]Maître n'est attaquable que si sa colonne est vide de défenseurs[/b] (les monstres en mêlée doivent en plus être en rangée avant, dans la bonne colonne)." % [danger, danger, danger])

	sections.append(h.call("⭐ XP et évolution"))
	sections.append("Un monstre gagne [b]1 XP[/b] quand il blesse un monstre ennemi et [b]2 XP[/b] quand il le détruit. En atteignant le seuil, il monte de niveau : ses stats augmentent et il est [b]entièrement soigné[/b]. Certains monstres, au niveau maximum, peuvent [b]évoluer[/b] en une créature bien plus puissante en payant des pierres — cliquez sur le monstre puis sur le bouton doré « Évoluer ».")

	sections.append(h.call("📜 Les mots-clés"))
	var kw_lines: PackedStringArray = []
	for kw in GameText.KEYWORD_NAMES:
		kw_lines.append("• [b]%s[/b] : %s." % [GameText.KEYWORD_NAMES[kw],
				GameText.KEYWORD_DEFS.get(kw, "")])
	sections.append("\n".join(kw_lines))

	sections.append(h.call("👑 Les Maîtres"))
	var m_lines: PackedStringArray = []
	for id in Db.masters:
		var m: MasterDef = Db.masters[id]
		m_lines.append("• [b]%s[/b] (%s) — Passif : %s Pouvoir [i]%s[/i] (%d pierres) : %s"
				% [m.display_name, GameConst.GUILD_NAMES.get(m.guild, ""), m.passive_desc,
				m.power_name, m.power_cost, m.power_desc])
	sections.append("\n".join(m_lines))

	sections.append(h.call("🂠 Deck et mulligan"))
	sections.append("Un deck contient exactement [b]20 cartes[/b], avec au plus 2 exemplaires d'une même carte. Au début de la partie, vous voyez votre main de 5 cartes et pouvez la remplacer une fois (mulligan). Construisez votre deck dans le [b]Deck builder[/b] avec les cartes gagnées au fil de la campagne.")

	sections.append(h.call("💡 Conseils"))
	sections.append("• Gardez toujours un défenseur dans la colonne de votre Maître.\n• Les monstres volants ne bloquent pas la mêlée : ne comptez pas sur eux pour protéger.\n• Faire monter un monstre de niveau le soigne : un coup de grâce au bon moment vaut un soin.\n• Les évolutions renversent des parties — gardez 2-3 pierres d'avance.\n• Contre les murs d'Armure, cherchez la Magie : elle traverse tout.")

	return "\n".join(sections) + "\n"
