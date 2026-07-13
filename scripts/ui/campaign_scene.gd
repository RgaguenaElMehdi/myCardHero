extends Control
## Carte de campagne (design "or baroque", mockup utilisateur) : les chapitres
## sont des blasons posés sur une carte peinte, reliés par des chemins en
## pointillés. Panneau droit = détail du niveau sélectionné (portrait, récompenses,
## AFFRONTER). Onglets d'actes en bas. Structure dans campaign[_mobile].tscn.

const NODE_SCENE := preload("res://scenes/widgets/campaign_node.tscn")
const PER := 5                                   # niveaux par acte
const GOLD := Color(0.855, 0.71, 0.42)

## Position de chaque blason en fractions de la carte (chemin sinueux du mockup).
const ANCHORS := [
	Vector2(0.16, 0.24), Vector2(0.44, 0.17), Vector2(0.76, 0.26),
	Vector2(0.32, 0.50), Vector2(0.58, 0.64),
	Vector2(0.82, 0.78), Vector2(0.13, 0.72),
]
## Noms d'actes (habillage) ; repli "Acte N" si dépassé.
const ACT_NAMES := ["Terres oubliées", "Royaumes brisés", "Désert éternel",
	"Empire des ténèbres", "Cité céleste", "Abîme final"]
const ROMANS := ["I", "II", "III", "IV", "V", "VI"]
const NODE_ICONS := ["icon_swords", "icon_skull", "icon_helmet", "icon_skull",
	"icon_swords"]

@export var node_scale := 1.0

@onready var map: TextureRect = %Map
@onready var node_layer: CampaignPaths = %NodeLayer
@onready var act_banner: Label = %ActBanner
@onready var subtitle: Label = %Subtitle
@onready var act_tabs: HBoxContainer = %ActTabs
@onready var back_btn: Button = %BackBtn
@onready var shop_btn: Button = %ShopBtn
@onready var chest_top_btn: Button = %ChestTopBtn
@onready var gear_btn: Button = %GearBtn
@onready var journal_btn: Button = %JournalBtn
@onready var collection_btn: Button = %CollectionBtn
@onready var progress_label: Label = %ProgressLabel
@onready var cards_label: Label = %CardsLabel
@onready var info_popup: PanelContainer = %InfoPopup

# panneau de détail
@onready var d_title: Label = %DTitle
@onready var d_portrait: TextureRect = %DPortrait
@onready var d_desc: Label = %DDesc
@onready var d_diff: Label = %DDiff
@onready var reward_row: HBoxContainer = %RewardRow
@onready var fight_btn: Button = %FightBtn

var _act := 0
var _sel := -1
var _nodes: Array[CampaignNode] = []


func _ready() -> void:
	var mtex := UiTheme.tex("res://assets/backgrounds/campaign_map.png")
	if mtex != null:
		map.texture = mtex

	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))
	collection_btn.pressed.connect(func() -> void: Game.goto("deck_builder"))
	gear_btn.pressed.connect(func() -> void: Game.goto("settings"))
	journal_btn.pressed.connect(_open_journal)
	var shop := func() -> void:
		_popup("BOUTIQUE", "La boutique arrive bientôt !\nRevenez plus tard.")
	shop_btn.pressed.connect(shop)
	chest_top_btn.pressed.connect(shop)
	%InfoCloseBtn.pressed.connect(func() -> void: info_popup.visible = false)
	fight_btn.pressed.connect(func() -> void:
		if _sel >= 0:
			Game.start_chapter(_sel))
	for b: Button in [back_btn, fight_btn, collection_btn, journal_btn,
			shop_btn, chest_top_btn]:
		b.pressed.connect(UiTheme._click_sfx)

	_update_topbar()
	_build_act_tabs()
	# ouvre l'acte du chapitre courant
	var prog: int = clampi(int(Game.profile.campaign_progress), 0,
			Db.chapters().size() - 1)
	_show_act(prog / PER)
	Audio.play_music("menu")


func _act_count() -> int:
	return int(ceil(float(Db.chapters().size()) / PER))


func _act_range(a: int) -> Array[int]:
	var start := a * PER
	return [start, mini(start + PER, Db.chapters().size())]


# ---- onglets d'actes (bas) --------------------------------------------------

func _build_act_tabs() -> void:
	for c in act_tabs.get_children():
		c.queue_free()
	for a in _act_count():
		var unlocked := Game.is_chapter_unlocked(a * PER)
		var b := Button.new()
		b.custom_minimum_size = Vector2(310, 82) * node_scale
		b.disabled = not unlocked
		_style_tab(b, false)
		b.add_child(_act_tab_content(a, unlocked))
		b.pressed.connect(func() -> void:
			Audio.play_sfx("move")
			_show_act(a))
		act_tabs.add_child(b)


## Badge romain + nom sur deux lignes (+ cadenas si verrouillé), comme le mockup.
func _act_tab_content(a: int, unlocked: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.08, 0.1, 0.17, 0.95)
	bs.set_border_width_all(1)
	bs.border_color = Color(0.55, 0.45, 0.26)
	bs.set_corner_radius_all(8)
	bs.content_margin_left = 12
	bs.content_margin_right = 12
	bs.content_margin_top = 4
	bs.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", bs)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rom := UiTheme.label(ROMANS[a] if a < ROMANS.size() else str(a + 1),
			int(24 * node_scale), GOLD)
	var f := UiTheme.title_font()
	if f != null:
		rom.add_theme_font_override("font", f)
	badge.add_child(rom)
	hb.add_child(badge)

	var nm: String = ACT_NAMES[a] if a < ACT_NAMES.size() else "Acte %d" % (a + 1)
	var nl := UiTheme.label(nm.to_upper(), int(18 * node_scale),
			GOLD if unlocked else Color(0.5, 0.47, 0.42))
	if f != null:
		nl.add_theme_font_override("font", f)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD
	nl.custom_minimum_size = Vector2(150 * node_scale, 0)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(nl)

	if not unlocked:
		var lk := TextureRect.new()
		lk.texture = UiTheme.tex("res://assets/sprites/ui/gold/icon_lock.png")
		lk.custom_minimum_size = Vector2(30, 30) * node_scale
		lk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(lk)
	return hb


## Panneau plat sombre à liseré or (mockup), variante bleue si actif.
func _style_tab(b: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.17, 0.3, 0.97) if active else Color(0.07, 0.065, 0.08, 0.94)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.76, 0.62, 0.35) if active else Color(0.34, 0.28, 0.17)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, sb)


func _show_act(a: int) -> void:
	_act = clampi(a, 0, _act_count() - 1)
	var rom: String = ROMANS[_act] if _act < ROMANS.size() else str(_act + 1)
	var nm: String = ACT_NAMES[_act] if _act < ACT_NAMES.size() else "Acte %d" % (_act + 1)
	act_banner.text = "%s. %s" % [rom, nm.to_upper()]
	subtitle.text = "— CHAPITRE %s : %s —" % [rom, nm.to_upper()]
	for i in act_tabs.get_child_count():
		_style_tab(act_tabs.get_child(i) as Button, i == _act)
	_place_nodes()


func _place_nodes() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	await get_tree().process_frame            # taille de node_layer connue
	var size := node_layer.size
	var rng := _act_range(_act)
	var start: int = rng[0]
	var end: int = rng[1]
	var centers := PackedVector2Array()
	var done_upto := -1
	var first_selectable := -1
	for k in range(start, end):
		var local_i: int = k - start
		var anchor: Vector2 = ANCHORS[local_i % ANCHORS.size()]
		var center := Vector2(anchor.x * size.x, anchor.y * size.y)
		centers.append(center)

		var node: CampaignNode = NODE_SCENE.instantiate()
		node.base_scale = node_scale
		node.scale = Vector2(node_scale, node_scale)
		node_layer.add_child(node)
		var ch := Db.chapter(k)
		var state := "locked"
		if Game.is_chapter_done(k):
			state = "done"
			done_upto = local_i
		elif Game.is_chapter_unlocked(k):
			state = "current"
		if state != "locked" and first_selectable < 0:
			first_selectable = k
		var col := _guild_color(ch)
		node.setup(k, "%d. %s" % [k + 1, String(ch.title).to_upper()],
				_icon_for(local_i), state, col)
		node.position = center - CampaignNode.SHIELD_CENTER * node_scale
		node.chosen.connect(_select_node)
		_nodes.append(node)

	node_layer.set_points(centers, done_upto + 1)
	# sélection par défaut : chapitre courant s'il est dans l'acte, sinon 1er
	var default := clampi(int(Game.profile.campaign_progress), start, end - 1)
	if not (Game.is_chapter_unlocked(default) or Game.is_chapter_done(default)):
		default = first_selectable if first_selectable >= 0 else start
	_select_node(default)


func _select_node(idx: int) -> void:
	_sel = idx
	for n in _nodes:
		n.set_selected(n.index == idx)
	_fill_detail(idx)
	Audio.play_sfx("move")


# ---- panneau de détail (droite) --------------------------------------------

func _fill_detail(idx: int) -> void:
	var ch := Db.chapter(idx)
	var opp: Dictionary = ch.opponent
	var locked := not (Game.is_chapter_unlocked(idx) or Game.is_chapter_done(idx))
	d_title.text = "%d. %s" % [idx + 1, String(ch.title).to_upper()]
	# titre teinté par la guilde de l'adversaire (mockup : titre violet nécro)
	d_title.add_theme_color_override("font_color",
			Color(0.6, 0.57, 0.52) if locked
			else _guild_color(ch).lerp(Color.WHITE, 0.45))
	d_portrait.texture = UiTheme.tex(Db.portrait_path(String(opp.portrait)))
	d_portrait.modulate = Color(0.25, 0.25, 0.3) if locked else Color.WHITE
	d_desc.text = _description(ch, opp) if not locked \
			else "Niveau verrouillé. Terminez le niveau précédent pour le débloquer."
	var diff := _diff_name(int(opp.get("ai_level", 0)))
	d_diff.text = diff[0]
	d_diff.add_theme_color_override("font_color", diff[1])
	_build_rewards(ch)
	fight_btn.visible = not locked
	fight_btn.text = "REJOUER" if Game.is_chapter_done(idx) else "AFFRONTER"


func _description(ch: Dictionary, opp: Dictionary) -> String:
	var pre: Array = ch.get("pre_dialogue", [])
	for line in pre:
		var t := String(line.get("text", "")).strip_edges()
		if t.length() > 20:
			return t if t.length() <= 170 else t.substr(0, 167) + "…"
	var m: MasterDef = Db.master(StringName(String(opp.master)))
	var g: String = GameConst.GUILD_NAMES.get(m.guild, "") if m != null else ""
	return "Affrontez %s, qui manie la guilde %s." % [String(opp.name), g]


func _build_rewards(ch: Dictionary) -> void:
	for c in reward_row.get_children():
		c.queue_free()
	var rewards: Dictionary = ch.get("rewards", {})
	var cards: Dictionary = rewards.get("cards", {})
	var total := 0
	for id in cards:
		total += int(cards[id])
	if total > 0:
		reward_row.add_child(_reward_slot(
				"res://assets/sprites/ui/gold/icon_scroll.png", "×%d" % total,
				"Cartes", Color.WHITE))
	for mid in rewards.get("masters", []):
		var m: MasterDef = Db.master(StringName(String(mid)))
		reward_row.add_child(_reward_slot(
				"res://assets/sprites/ui/gold/medallion.png", "×1",
				"Maître : %s" % (m.display_name if m != null else "?"),
				UiTheme.guild_color(m.guild) if m != null else GOLD))
	if reward_row.get_child_count() == 0:
		reward_row.add_child(_reward_slot(
				"res://assets/sprites/ui/gold/icon_laurel.png", "", "Gloire", GOLD))


## Case de récompense (mockup) : cadre sombre à liseré or, icône + quantité DANS
## la case. Le libellé complet reste en infobulle.
func _reward_slot(icon_path: String, qty: String, caption: String,
		tint: Color) -> Control:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.068, 0.09, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.42, 0.35, 0.2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(118, 128) * node_scale
	frame.tooltip_text = caption
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UiTheme.tex(icon_path)
	ic.custom_minimum_size = Vector2(72, 72) * node_scale
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = tint
	vb.add_child(ic)
	if qty != "":
		var q := UiTheme.label(qty, int(20 * node_scale), GOLD)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(q)
	frame.add_child(vb)
	return frame


# ---- divers ----------------------------------------------------------------

func _diff_name(ai: int) -> Array:
	match ai:
		0: return ["Facile", Color(0.45, 0.75, 0.4)]
		1: return ["Normale", Color(0.92, 0.88, 0.8)]
		2: return ["Difficile", Color(0.85, 0.35, 0.28)]
	return ["Extrême", Color(0.7, 0.4, 0.85)]


func _icon_for(local_i: int) -> Texture2D:
	var boss := local_i == PER - 1
	var icon_name: String = "icon_skull" if boss else NODE_ICONS[local_i % NODE_ICONS.size()]
	return UiTheme.tex("res://assets/sprites/ui/gold/%s.png" % icon_name)


func _guild_color(ch: Dictionary) -> Color:
	var m: MasterDef = Db.master(StringName(String(ch.opponent.master)))
	return UiTheme.guild_color(m.guild) if m != null else GOLD


func _update_topbar() -> void:
	var total := Db.chapters().size()
	var done: int = clampi(int(Game.profile.campaign_progress), 0, total)
	progress_label.text = "%d/%d" % [done, total]
	var owned := 0
	for def in Db.constructible_cards():
		if Game.owned_count(String(def.id)) > 0:
			owned += 1
	cards_label.text = str(owned)


func _open_journal() -> void:
	var total := Db.chapters().size()
	var done: int = clampi(int(Game.profile.campaign_progress), 0, total)
	var txt := ""
	for i in done:
		txt += "✔ %d. %s\n" % [i + 1, Db.chapter(i).title]
	if done == 0:
		txt = "Aucun niveau terminé pour l'instant.\nVotre légende commence ici."
	_popup("JOURNAL DE CAMPAGNE", txt.strip_edges())


func _popup(title: String, body: String) -> void:
	%InfoTitle.text = title
	%InfoLabel.text = body
	info_popup.visible = true
