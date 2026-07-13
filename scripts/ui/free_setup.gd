extends Control
## Préparation au combat (mockup utilisateur) : liste des decks du joueur (à
## gauche), aperçu du deck sélectionné + courbe de coût (centre), choix de la
## difficulté (droite). « Commencer le combat » émet launched(master, niveau IA).
## Structure dans free_setup.tscn — logique ici.

signal launched(master_id: String, level: int)

const GOLD := Color(0.855, 0.71, 0.42)
const DIM := Color(0.62, 0.5, 0.3)
const TXT := Color(0.82, 0.78, 0.7)

## [nom, couleur, description, niveau IA]
const DIFFS := [
	["FACILE", Color(0.45, 0.75, 0.4), "Pour les nouveaux joueurs.\nEnnemis plus faibles.", AiPlayer.Level.NOVICE],
	["NORMALE", Color(0.9, 0.72, 0.3), "Un défi équilibré.\nRecommandé.", AiPlayer.Level.ADEPT],
	["DIFFICILE", Color(0.85, 0.3, 0.25), "Pour les joueurs expérimentés.\nEnnemis coriaces.", AiPlayer.Level.MASTER],
	["EXTRÊME", Color(0.62, 0.35, 0.8), "Un véritable défi.\nRéservé aux maîtres.", AiPlayer.Level.MASTER],
]

@onready var deck_list: VBoxContainer = %DeckList
@onready var preview_grid: GridContainer = %PreviewGrid
@onready var curve_box: HBoxContainer = %CurveBox
@onready var count_label: Label = %CountLabel
@onready var diff_list: VBoxContainer = %DiffList
@onready var cancel_btn: Button = %CancelBtn
@onready var launch_btn: Button = %LaunchBtn
@onready var rewards_btn: Button = %RewardsBtn
@onready var info_popup: PanelContainer = %InfoPopup

var _sel_deck := 0
var _level := int(AiPlayer.Level.ADEPT)
var _deck_rows: Array[Button] = []
var _diff_rows: Array[Button] = []


func _ready() -> void:
	for i in Game.profile.decks.size():
		_deck_rows.append(_make_deck_row(i))
	for i in DIFFS.size():
		_diff_rows.append(_make_diff_row(i))

	cancel_btn.pressed.connect(queue_free)
	launch_btn.pressed.connect(func() -> void:
		Game.set_active_deck(_sel_deck)
		launched.emit(String(Game.profile.decks[_sel_deck].master), _level))
	rewards_btn.pressed.connect(func() -> void:
		%InfoTitle.text = "RÉCOMPENSES"
		%InfoLabel.text = "Gagnez de l'expérience et des cristaux\nen remportant le combat.\nLa difficulté augmente les gains."
		info_popup.visible = true)
	%InfoCloseBtn.pressed.connect(func() -> void: info_popup.visible = false)
	for b: Button in [cancel_btn, launch_btn, rewards_btn]:
		b.pressed.connect(UiTheme._click_sfx)

	_select(clampi(int(Game.profile.active_deck), 0, Game.profile.decks.size() - 1))
	_pick_diff(1)                    # NORMALE par défaut
	_animate_launch.call_deferred()


# ---- lignes de deck (gauche) -------------------------------------------------

func _make_deck_row(i: int) -> Button:
	var d: Dictionary = Game.profile.decks[i]
	var m: MasterDef = Db.master(StringName(String(d.master)))
	var col := UiTheme.guild_color(m.guild) if m != null else GOLD

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 132)
	UiTheme.style_button(btn, UiTheme.PANEL_LIGHT, 16)
	btn.add_child(_deck_row_content(d, m, col))
	btn.pressed.connect(_select.bind(i))
	btn.pressed.connect(UiTheme._click_sfx)
	deck_list.add_child(btn)
	return btn


func _deck_row_content(d: Dictionary, m: MasterDef, col: Color) -> Control:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = UiTheme.tex("res://assets/sprites/ui/gold/icon_selection.png")
	icon.custom_minimum_size = Vector2(88, 88)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = col.lerp(Color.WHITE, 0.35)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_child(_label(String(d.name), 24, GOLD))
	vb.add_child(_label("Maître : %s" % (m.display_name if m != null else "?"), 16, DIM))
	vb.add_child(_stats_row(d))
	row.add_child(vb)
	return row


func _stats_row(d: Dictionary) -> Control:
	var atk := 0.0
	var hp := 0.0
	var cost := 0.0
	var mono := 0
	for id in d.cards:
		var c := Db.card(StringName(String(id)))
		if c == null:
			continue
		cost += c.cost
		if c.is_monster():
			atk += c.levels[0].atk
			hp += c.levels[0].hp
			mono += 1
	var n: int = maxi(int(d.cards.size()), 1)
	var mn: int = maxi(mono, 1)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_stat("res://assets/sprites/ui/gold/icon_sword1.png",
			roundi(atk / mn), Color.WHITE))
	hb.add_child(_stat("res://assets/sprites/ui/gold/icon_shield_q.png",
			roundi(cost / n), Color(0.55, 0.7, 1.0)))
	hb.add_child(_stat("res://assets/sprites/ui/pixel/res_heart.png",
			roundi(hp / mn), Color(1, 0.5, 0.5)))
	return hb


func _stat(icon_path: String, value: int, tint: Color) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UiTheme.tex(icon_path)
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = tint
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	hb.add_child(_label(str(value), 22, TXT))
	return hb


# ---- difficultés (droite) ----------------------------------------------------

func _make_diff_row(i: int) -> Button:
	var dname: String = DIFFS[i][0]
	var col: Color = DIFFS[i][1]
	var desc: String = DIFFS[i][2]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 120)
	UiTheme.style_button(btn, UiTheme.PANEL_LIGHT, 16)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UiTheme.tex("res://assets/sprites/ui/gold/icon_skull.png")
	ic.custom_minimum_size = Vector2(78, 78)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = col
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_child(_label(dname, 26, GOLD))
	vb.add_child(_label(desc, 18, TXT))
	row.add_child(vb)
	btn.add_child(row)
	btn.pressed.connect(_pick_diff.bind(i))
	btn.pressed.connect(UiTheme._click_sfx)
	diff_list.add_child(btn)
	return btn


func _pick_diff(i: int) -> void:
	_level = int(DIFFS[i][3])
	for j in _diff_rows.size():
		_diff_rows[j].modulate = Color(1.3, 1.25, 1.05) if j == i else Color(0.72, 0.7, 0.66)


# ---- sélection + aperçu ------------------------------------------------------

func _select(i: int) -> void:
	_sel_deck = i
	for j in _deck_rows.size():
		_deck_rows[j].modulate = Color(1.28, 1.22, 1.0) if j == i else Color(0.75, 0.73, 0.68)
	var d: Dictionary = Game.profile.decks[i]

	# aperçu : une mini-carte par exemplaire unique
	for c in preview_grid.get_children():
		c.queue_free()
	var seen := {}
	for id in d.cards:
		if seen.has(id):
			continue
		seen[id] = true
		var def := Db.card(StringName(String(id)))
		if def != null:
			preview_grid.add_child(CardWidget.create_mini(def, 120.0))
	count_label.text = "Cartes dans le deck : %d/%d" % [d.cards.size(), GameConst.DECK_SIZE]

	_build_curve(d)


func _build_curve(d: Dictionary) -> void:
	for c in curve_box.get_children():
		c.queue_free()
	var buckets := [0, 0, 0, 0, 0, 0, 0, 0]     # 0,1,2,3,4,5,6,7+
	for id in d.cards:
		var def := Db.card(StringName(String(id)))
		if def != null:
			buckets[mini(def.cost, 7)] += 1
	var peak: int = maxi(buckets.max(), 1)
	for b in buckets.size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", 3)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := _label(str(buckets[b]), 16, TXT)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bar := ColorRect.new()
		bar.color = Color(0.28, 0.5, 0.85)
		bar.custom_minimum_size = Vector2(0, 6.0 + 100.0 * buckets[b] / peak)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := _label("7+" if b == 7 else str(b), 15, DIM)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(num)
		col.add_child(bar)
		col.add_child(lbl)
		curve_box.add_child(col)


func _animate_launch() -> void:
	await get_tree().process_frame
	launch_btn.pivot_offset = launch_btn.size / 2.0
	var tw := launch_btn.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(launch_btn, "modulate", Color(1.22, 1.15, 0.95), 0.8)
	tw.tween_property(launch_btn, "modulate", Color.WHITE, 0.8)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	var f := UiTheme.title_font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
