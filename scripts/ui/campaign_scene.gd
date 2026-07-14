extends Control
## Campagne (mockup utilisateur, style bleu nuit/doré) : chapitres (actes de
## 5 étapes) en cartes illustrées à gauche, aperçu du chapitre au centre
## (illustration, description, progression + jalons), panneau droit
## informations / objectifs / récompense finale. « COMMENCER L'ÉTAPE » lance
## la prochaine bataille du chapitre. Structure dans campaign[_mobile].tscn.

const CARD_SCENE: PackedScene = preload("res://scenes/widgets/chapter_card.tscn")
const ROMANS := ["I", "II", "III", "IV", "V", "VI"]
const GOLD := Color(0.902, 0.765, 0.353)
const DIM := Color(0.55, 0.52, 0.46)

var _act := 0
var _cards: Array[Button] = []


func _ready() -> void:
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%GearBtn as Button).pressed.connect(func() -> void: Game.goto("settings"))
	(%JournalBtn as Button).pressed.connect(_open_journal)
	(%StartBtn as Button).pressed.connect(_start_step)
	(%InfoCloseBtn as Button).pressed.connect(func() -> void: %InfoPopup.visible = false)
	for b: Button in [%BackBtn, %GearBtn, %JournalBtn, %StartBtn, %InfoCloseBtn]:
		b.pressed.connect(UiTheme._click_sfx)

	var cur: Dictionary = Game.profile.get("currency", {})
	%GoldLabel.text = UiTheme.fmt_thousands(int(cur.get("gold", 0)))
	%ShardLabel.text = UiTheme.fmt_thousands(int(cur.get("shards", 0)))

	for a in _act_count():
		_cards.append(_make_card(a))
	var prog: int = clampi(int(Game.profile.campaign_progress), 0,
			Db.chapters().size() - 1)
	_select_act(_act_of(prog))
	Audio.play_music("menu")


# ---- découpage en chapitres (actes) -----------------------------------------
# Chaque acte déclare son nombre d'étapes dans campaign.json (acts[i].steps) ;
# repli : répartition égale.

func _acts_meta() -> Array:
	return Db.campaign.get("acts", [])


func _act_count() -> int:
	var n := _acts_meta().size()
	return n if n > 0 else 1


func _act_steps(a: int) -> int:
	var meta := _acts_meta()
	var fallback := int(ceil(float(Db.chapters().size()) / _act_count()))
	if a < meta.size():
		return int(meta[a].get("steps", fallback))
	return fallback


func _act_range(a: int) -> Array[int]:
	var start := 0
	for i in a:
		start += _act_steps(i)
	return [mini(start, Db.chapters().size()),
			mini(start + _act_steps(a), Db.chapters().size())]


func _act_of(chapter_idx: int) -> int:
	for a in _act_count():
		var rng := _act_range(a)
		if chapter_idx < rng[1]:
			return a
	return _act_count() - 1


func _act_name(a: int) -> String:
	var meta := _acts_meta()
	if a < meta.size():
		return String(meta[a].get("name", ""))
	return "Chapitre %d" % (a + 1)


func _act_desc(a: int) -> String:
	var meta := _acts_meta()
	return String(meta[a].get("description", "")) if a < meta.size() else ""


func _act_unlocked(a: int) -> bool:
	var first: int = _act_range(a)[0]
	return Game.is_chapter_unlocked(first) or Game.is_chapter_done(first)


func _done_count(a: int) -> int:
	var rng := _act_range(a)
	var n := 0
	for k in range(rng[0], rng[1]):
		if Game.is_chapter_done(k):
			n += 1
	return n


## Prochaine étape jouable du chapitre ; -1 si tout est terminé.
func _next_step(a: int) -> int:
	var rng := _act_range(a)
	for k in range(rng[0], rng[1]):
		if not Game.is_chapter_done(k) and Game.is_chapter_unlocked(k):
			return k
	return -1


func _roman(a: int) -> String:
	return ROMANS[a] if a < ROMANS.size() else str(a + 1)


# ---- liste de gauche ---------------------------------------------------------

func _make_card(a: int) -> Button:
	var card: Button = CARD_SCENE.instantiate()
	%ChapterList.add_child(card)
	var rng := _act_range(a)
	var bg := String(Db.chapter(rng[0]).get("background", ""))
	(card.get_node("%Art") as TextureRect).texture = UiTheme.tex(Db.background_path(bg))
	(card.get_node("%Kicker") as Label).text = "CHAPITRE %s" % _roman(a)
	(card.get_node("%Name") as Label).text = _act_name(a).to_upper()
	var unlocked := _act_unlocked(a)
	(card.get_node("%Badge") as Control).visible = unlocked
	(card.get_node("%Count") as Label).text = "%d/%d" % [_done_count(a), rng[1] - rng[0]]
	(card.get_node("%Lock") as Control).visible = not unlocked
	(card.get_node("%Art") as TextureRect).modulate = \
			Color.WHITE if unlocked else Color(0.45, 0.45, 0.5)
	card.disabled = not unlocked
	card.pressed.connect(_select_act.bind(a))
	card.pressed.connect(UiTheme._click_sfx)
	return card


# ---- aperçu central + panneau droit ------------------------------------------

func _select_act(a: int) -> void:
	_act = clampi(a, 0, _act_count() - 1)
	for i in _cards.size():
		_cards[i].set_pressed_no_signal(i == _act)
	var rng := _act_range(_act)
	var steps: int = rng[1] - rng[0]
	var done := _done_count(_act)
	var next := _next_step(_act)
	var shown: int = next if next >= 0 else rng[1] - 1   # illustration : étape en cours

	%ChKicker.text = "✦  CHAPITRE %s  ✦" % _roman(_act)
	%ChTitle.text = _act_name(_act).to_upper()
	(%ChArt as TextureRect).texture = UiTheme.tex(
			Db.background_path(String(Db.chapter(shown).get("background", ""))))
	%ChDesc.text = _act_desc(_act)
	(%ChBar as ProgressBar).max_value = steps
	(%ChBar as ProgressBar).value = done
	%ChCount.text = "%d / %d" % [done, steps]
	_build_milestones(rng)
	_fill_right(rng, done, steps, next)


func _build_milestones(rng: Array[int]) -> void:
	for c in %MilestoneRow.get_children():
		c.queue_free()
	for k in range(rng[0], rng[1]):
		%MilestoneRow.add_child(_milestone(k))


## Jalon d'étape : icône de la récompense (portrait de Maître ou cartes),
## nimbé si l'étape est terminée. CLIQUABLE quand l'étape est jouable —
## y compris pour REJOUER une étape déjà terminée.
func _milestone(k: int) -> Control:
	var ch := Db.chapter(k)
	var rewards: Dictionary = ch.get("rewards", {})
	var masters: Array = rewards.get("masters", [])
	var done := Game.is_chapter_done(k)
	var playable := done or Game.is_chapter_unlocked(k)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.tooltip_text = "Étape %d — %s%s" % [k + 1, String(ch.title),
			"\nCliquez pour rejouer." if done else ""]

	var frame := Button.new()
	frame.disabled = not playable
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = GOLD if done else Color(0.35, 0.3, 0.18)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	for st in ["normal", "pressed", "focus", "disabled"]:
		frame.add_theme_stylebox_override(st, sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.border_color = Color(1, 0.9, 0.55)
	sb_hover.bg_color = Color(0.1, 0.13, 0.2, 0.95)
	frame.add_theme_stylebox_override("hover", sb_hover)
	if playable:
		frame.pressed.connect(func() -> void:
			UiTheme._click_sfx()
			Game.start_chapter(k))
	frame.custom_minimum_size = Vector2(74, 74)
	var ic := TextureRect.new()
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 8
	ic.offset_top = 8
	ic.offset_right = -8
	ic.offset_bottom = -8
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if masters.size() > 0:
		ic.texture = UiTheme.tex(Db.portrait_path(String(masters[0])))
	else:
		ic.texture = UiTheme.tex("res://assets/sprites/ui/gold/icon_scroll.png")
	ic.modulate = Color.WHITE if done or masters.size() > 0 else Color(0.8, 0.75, 0.6)
	if not done:
		ic.modulate = ic.modulate.darkened(0.25)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(ic)
	vb.add_child(frame)

	var cap := UiTheme.label("✔ Étape %d" % (k + 1) if done else "Étape %d" % (k + 1),
			13, GOLD if done else DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	return vb


func _fill_right(rng: Array[int], done: int, steps: int, next: int) -> void:
	# Informations : le lore du monde tant qu'aucune étape n'est jouée,
	# ensuite la prochaine étape à jouer.
	if next == 0 and done == 0:
		%InfoText.text = String(Db.campaign.get("lore", ""))
	elif next >= 0:
		var ch := Db.chapter(next)
		var opp: Dictionary = ch.opponent
		var m: MasterDef = Db.master(StringName(String(opp.master)))
		%InfoText.text = "Étape %d — %s\nAffrontez %s, qui manie la guilde %s." % [
			next + 1, String(ch.title), String(opp.get("name", "?")),
			GameConst.GUILD_NAMES.get(m.guild, "?") if m != null else "?"]
	else:
		%InfoText.text = "Chapitre terminé ! Vous pouvez rejouer la dernière étape pour la gloire."

	# Objectifs : progression réelle du chapitre.
	for c in %ObjList.get_children():
		c.queue_free()
	var boss_done := Game.is_chapter_done(rng[1] - 1)
	%ObjList.add_child(_objective("Terminez toutes les étapes du chapitre.", done >= steps))
	%ObjList.add_child(_objective("Vainquez %s (étape finale)."
			% String(Db.chapter(rng[1] - 1).opponent.get("name", "?")), boss_done))
	var final_master := _final_master(rng)
	if final_master != null:
		%ObjList.add_child(_objective("Recrutez %s." % final_master.display_name,
				Game.profile.masters.has(String(final_master.id))))

	# Récompense finale : le Maître débloqué dans le chapitre, sinon les cartes.
	if final_master != null:
		(%FinalArt as TextureRect).texture = UiTheme.tex(final_master.portrait)
		%FinalKicker.text = "Nouveau Maître"
		%FinalName.text = final_master.display_name
		%FinalSub.text = final_master.title
	else:
		(%FinalArt as TextureRect).texture = UiTheme.tex(
				"res://assets/sprites/ui/gold/icon_scroll.png")
		%FinalKicker.text = "Butin du chapitre"
		%FinalName.text = "Cartes rares"
		%FinalSub.text = "De nouvelles cartes à chaque étape."

	var btn := %StartBtn as Button
	if next >= 0:
		btn.text = "COMMENCER L'ÉTAPE %d  ❯" % (next + 1)
	else:
		btn.text = "REJOUER LA FINALE  ❯"


func _objective(text: String, done: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := UiTheme.label("★" if done else "☆", 20, GOLD if done else DIM)
	hb.add_child(star)
	var l := UiTheme.label(text, 16, Color(0.85, 0.82, 0.74) if done else DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	return hb


## Dernier Maître offert dans le chapitre (récompense phare), null sinon.
func _final_master(rng: Array[int]) -> MasterDef:
	var found: MasterDef = null
	for k in range(rng[0], rng[1]):
		for mid in Db.chapter(k).get("rewards", {}).get("masters", []):
			var m: MasterDef = Db.master(StringName(String(mid)))
			if m != null:
				found = m
	return found


func _start_step() -> void:
	var next := _next_step(_act)
	var idx: int = next if next >= 0 else _act_range(_act)[1] - 1
	Game.start_chapter(idx)


func _open_journal() -> void:
	var total := Db.chapters().size()
	var done: int = clampi(int(Game.profile.campaign_progress), 0, total)
	var txt := ""
	for i in done:
		txt += "✔ %d. %s\n" % [i + 1, Db.chapter(i).title]
	if done == 0:
		txt = "Aucune étape terminée pour l'instant.\nVotre légende commence ici."
	%InfoTitle.text = "JOURNAL DE CAMPAGNE"
	%InfoLabel.text = txt.strip_edges()
	%InfoPopup.visible = true
