extends Control
## Codex : le lore consultable, jamais imposé. Histoire des Pierres de Lien
## (codex.json), fiches des 8 Maîtres (masters.json : épithète, pouvoir,
## passif), guildes & royaumes, et renvoi vers la Collection pour les Gardiens.

const CODEX_PATH := "res://resources/data/codex.json"
const CARD_SCENE: PackedScene = preload("res://scenes/widgets/opponent_card.tscn")
const GUILD_SCENE: PackedScene = preload("res://scenes/widgets/codex_guild.tscn")
const GUILD_ICONS := {
	"flame": "res://assets/sprites/ui/deck/guild_flame.png",
	"sylvan": "res://assets/sprites/ui/deck/guild_sylvan.png",
	"shadow": "res://assets/sprites/ui/deck/guild_shadow.png",
	"light": "res://assets/sprites/ui/deck/guild_light.png",
}
const GUILD_ENUM := {
	"flame": GameConst.Guild.FLAME, "sylvan": GameConst.Guild.SYLVAN,
	"shadow": GameConst.Guild.SHADOW, "light": GameConst.Guild.LIGHT,
}

var _codex: Dictionary = {}


func _ready() -> void:
	if get_viewport_rect().size.x > 2000:
		%BG.texture = UiTheme.tex("res://assets/backgrounds/freeplay_2400.png")
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%OpenCollection as Button).pressed.connect(func() -> void: Game.goto("collection"))
	for b: Button in [%BackBtn, %OpenCollection, %TabStory, %TabMasters,
			%TabGuilds, %TabGuardians]:
		b.pressed.connect(UiTheme._click_sfx)
	for tab: Button in [%TabStory, %TabMasters, %TabGuilds, %TabGuardians]:
		tab.pressed.connect(_show_tab)

	var data = JSON.parse_string(FileAccess.get_file_as_string(CODEX_PATH))
	if data is Dictionary:
		_codex = data
	_build_story()
	_build_masters()
	_build_guilds()
	_show_tab()
	Audio.play_music("menu")


func _show_tab() -> void:
	%StoryPanel.visible = (%TabStory as Button).button_pressed
	%MastersScroll.visible = (%TabMasters as Button).button_pressed
	%GuildsGrid.visible = (%TabGuilds as Button).button_pressed
	%GuardiansBox.visible = (%TabGuardians as Button).button_pressed


## L'histoire des Pierres de Lien : le lore court de la campagne en ouverture,
## puis les chapitres du codex.
func _build_story() -> void:
	var paras: Array = [String(Db.campaign.get("lore", ""))]
	paras.append_array(_codex.get("story", []))
	for text in paras:
		if String(text).is_empty():
			continue
		var lbl := Label.new()  # contenu dynamique par nature (paragraphes du lore)
		lbl.text = String(text)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", UiTheme.title_font())
		lbl.add_theme_font_size_override("font_size", 19)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
		lbl.add_theme_constant_override("outline_size", 0)
		%StoryList.add_child(lbl)


## Une fiche par Maître (widget de la partie libre) : épithète, pouvoir, passif.
func _build_masters() -> void:
	var ids: Array = Db.masters.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ma: MasterDef = Db.masters[a]
		var mb: MasterDef = Db.masters[b]
		return ma.guild < mb.guild if ma.guild != mb.guild \
				else ma.display_name < mb.display_name)
	for id in ids:
		var m: MasterDef = Db.masters[id]
		var card := CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(222, 0)
		(card.get_node("%Portrait") as TextureRect).texture = UiTheme.tex(m.portrait)
		(card.get_node("%Name") as Label).text = m.display_name
		var title := card.get_node("%Title") as Label
		title.text = m.title
		title.add_theme_color_override("font_color",
				GameConst.GUILD_COLORS.get(m.guild, Color.WHITE))
		(card.get_node("%Desc") as Label).text = "%s : %s\n\nPassif : %s" \
				% [m.power_name, m.power_desc, m.passive_desc]
		%MastersRow.add_child(card)


func _build_guilds() -> void:
	var guilds: Dictionary = _codex.get("guilds", {})
	for key in ["flame", "sylvan", "shadow", "light"]:
		var g: Dictionary = guilds.get(key, {})
		var panel := GUILD_SCENE.instantiate()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		(panel.get_node("%Icon") as TextureRect).texture = UiTheme.tex(GUILD_ICONS[key])
		var name_l := panel.get_node("%GName") as Label
		name_l.text = String(g.get("name", key)).to_upper()
		name_l.add_theme_color_override("font_color",
				GameConst.GUILD_COLORS.get(GUILD_ENUM[key], Color.WHITE))
		(panel.get_node("%GRealm") as Label).text = String(g.get("realm", ""))
		(panel.get_node("%GDesc") as Label).text = String(g.get("desc", ""))
		var names: PackedStringArray = []
		for id in Db.masters:
			var m: MasterDef = Db.masters[id]
			if m.guild == GUILD_ENUM[key]:
				names.append(m.display_name)
		(panel.get_node("%GMasters") as Label).text = "Maîtres : " + ", ".join(names)
		%GuildsGrid.add_child(panel)
