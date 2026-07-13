extends Control
## Deck builder "Stonebound" (mockup deck_builder_v3) : collection filtrable à
## gauche, deck + courbe de coût au centre, héros / identité / statistiques à
## droite, détails de la carte sélectionnée en bas.
## Structure et style dans deck_builder[_mobile].tscn — logique seulement ici.
## La scène mobile affiche les mêmes nœuds répartis en onglets (%PageXxx).

## Largeurs de cartes, portées par la scène (desktop et mobile diffèrent).
@export var deck_card_w := 112.0
@export var coll_card_w := 118.0
## true sur mobile : boutons +/− superposés aux cartes (pas de double-clic requis).
@export var touch_buttons := false

const SORT_LABELS := ["Tri : coût", "Tri : nom", "Tri : guilde", "Tri : rareté", "Tri : possédées"]
const SORT_KEYS := ["cost", "name", "guild", "rarity", "owned"]
const RARITY_ORDER := { "commune": 0, "rare": 1, "epique": 2, "legendaire": 3 }

var decks: Array = []      ## working copy of profile.decks ({name, master, cards})
var current := 0           ## index of the deck being edited
var sel_id := ""           ## card shown in the detail pane
var _deck_valid := false
var _dirty := false        ## modifications non enregistrées
var _filter_guild := -1    ## -1 = toutes
var _filter_cost := -1     ## -1 = tous, 6 = 6+
var _filter_kind := -1     ## -1 tous, 0 monstres, 1 sorts
var _sort_key := "cost"
var _search := ""
var _coll_widgets := {}    ## id -> CardWidget (mise à jour ciblée des badges)


func _ready() -> void:
	decks = Game.profile.decks.duplicate(true)
	current = clampi(int(Game.profile.active_deck), 0, decks.size() - 1)

	_wire_top_bar()
	_wire_collection()
	_wire_actions()
	_wire_overlays()
	_wire_mobile_tabs()
	_fill_currencies()

	# Colonnes adaptées à la largeur réellement disponible (16:9, 20:9, 16:10) :
	# évite tout débordement quel que soit le ratio de l'écran.
	%CollScroll.resized.connect(func() -> void: _fit_columns(%CollList, coll_card_w))
	%DeckScroll.resized.connect(func() -> void: _fit_columns(%DeckGrid, deck_card_w))

	_rebuild_all()
	# Harnais de test : sélectionne une carte pour vérifier le panneau détails.
	if OS.get_cmdline_user_args().has("--select-first"):
		var defs := _sorted_defs()
		if not defs.is_empty():
			_select.call_deferred(String((defs[defs.size() / 2] as CardDef).id))


## Nombre de colonnes tenant dans le conteneur (séparation 10 px).
func _fit_columns(grid: GridContainer, card_w: float) -> void:
	var avail: float = (grid.get_parent() as Control).size.x
	if avail > card_w:
		grid.columns = maxi(2, int((avail + 10.0) / (card_w + 10.0)))


## ---- câblage ---------------------------------------------------------------

func _wire_top_bar() -> void:
	%BackBtn.pressed.connect(func() -> void: Game.goto("main_menu"))
	%SaveBtn.pressed.connect(_save)
	%GearBtn.pressed.connect(func() -> void: Game.goto("settings"))
	%DecksBtn.pressed.connect(func() -> void: _open_overlay(%DecksOverlay))
	%HelpBtn.pressed.connect(func() -> void: _open_overlay(%HelpOverlay))
	for b: Button in [%BackBtn, %SaveBtn, %GearBtn, %DecksBtn, %HelpBtn]:
		b.pressed.connect(UiTheme._click_sfx)
	# Bouton libellé « MES DECKS » dans l'en-tête du deck (même overlay).
	var decks_btn2 := get_node_or_null("%DecksBtn2") as Button
	if decks_btn2 != null:
		decks_btn2.pressed.connect(func() -> void: _open_overlay(%DecksOverlay))
		decks_btn2.pressed.connect(UiTheme._click_sfx)


func _wire_collection() -> void:
	%SearchEdit.text_changed.connect(func(t: String) -> void:
		_search = t.strip_edges().to_lower()
		_refresh_coll())
	var cost: OptionButton = %CostFilter
	cost.add_item("Coût : tous")
	for i in 6:
		cost.add_item(str(i))
	cost.add_item("6+")
	cost.item_selected.connect(func(i: int) -> void:
		_filter_cost = i - 1
		_refresh_coll())
	var kind: OptionButton = %TypeFilter
	for label in ["Tous types", "Monstres", "Sorts"]:
		kind.add_item(label)
	kind.item_selected.connect(func(i: int) -> void:
		_filter_kind = i - 1
		_refresh_coll())
	var sort: OptionButton = %SortFilter
	for label in SORT_LABELS:
		sort.add_item(label)
	sort.item_selected.connect(func(i: int) -> void:
		_sort_key = SORT_KEYS[i]
		_refresh_coll())
	var chips: Array = [%GuildAll, %GuildFlame, %GuildSylvan, %GuildShadow, %GuildLight]
	for i in chips.size():
		var chip: Button = chips[i]
		chip.pressed.connect(func() -> void:
			_filter_guild = i - 1
			_refresh_coll())


func _wire_actions() -> void:
	%AddBtn.pressed.connect(func() -> void: _add(sel_id))
	%RemoveBtn.pressed.connect(func() -> void: _remove(sel_id))
	%ValidateBtn.pressed.connect(_save)
	%MasterBtn.pressed.connect(func() -> void: _open_overlay(%MasterOverlay))
	%MissingBtn.pressed.connect(func() -> void:
		_rebuild_missing()
		_open_overlay(%MissingOverlay))
	%NameEdit.text_changed.connect(func(t: String) -> void:
		_cur().name = t
		%DeckNameLabel.text = t
		_set_dirty(true))
	for b: Button in [%AddBtn, %RemoveBtn, %ValidateBtn, %MasterBtn, %MissingBtn]:
		b.pressed.connect(UiTheme._click_sfx)
	# Dépôt d'une carte glissée depuis la collection (desktop).
	%DeckScroll.set_drag_forwarding(Callable(),
			func(_pos: Vector2, data: Variant) -> bool:
				return data is String and _add_block_reason(String(data)) == "",
			func(_pos: Vector2, data: Variant) -> void:
				_add(String(data)))


func _wire_overlays() -> void:
	%Dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_overlays())
	for b: Button in [%CloseDecksBtn, %CloseMasterBtn, %CloseMissingBtn, %CloseHelpBtn]:
		b.pressed.connect(_close_overlays)
	%NewDeckBtn.pressed.connect(_new_deck)
	%DupDeckBtn.pressed.connect(_duplicate_deck)
	%DeleteDeckBtn.pressed.connect(func() -> void: %DeleteConfirm.popup_centered())
	%DeleteConfirm.confirmed.connect(_delete_current)


## Onglets de la scène mobile (absents sur desktop).
func _wire_mobile_tabs() -> void:
	if get_node_or_null("%MobileTabs") == null:
		return
	var tabs: Array = [%TabCollectionBtn, %TabDeckBtn, %TabDetailsBtn, %TabStatsBtn]
	for i in tabs.size():
		(tabs[i] as Button).pressed.connect(_show_page.bind(i))
	_show_page(0)


func _show_page(i: int) -> void:
	var pages: Array = [%PageCollection, %PageDeck, %PageDetails, %PageStats]
	var tabs: Array = [%TabCollectionBtn, %TabDeckBtn, %TabDetailsBtn, %TabStatsBtn]
	for j in pages.size():
		(pages[j] as Control).visible = j == i
		(tabs[j] as Button).set_pressed_no_signal(j == i)


func _fill_currencies() -> void:
	var cur: Dictionary = Game.profile.get("currency", {})
	%GoldLabel.text = UiTheme.fmt_thousands(int(cur.get("gold", 0)))
	%ShardLabel.text = UiTheme.fmt_thousands(int(cur.get("shards", 0)))
	%GemLabel.text = UiTheme.fmt_thousands(int(cur.get("gems", 0)))


## ---- état -------------------------------------------------------------------

func _cur() -> Dictionary:
	return decks[current]


func _cur_cards() -> Array:
	return decks[current].cards


func _deck_count(id: String) -> int:
	return _cur_cards().count(id)


func _set_dirty(on: bool) -> void:
	_dirty = on
	%DirtyLabel.visible = on


## Pourquoi cette carte ne peut PAS être ajoutée ("" si elle le peut).
func _add_block_reason(id: String) -> String:
	if id == "" or Db.card(StringName(id)) == null:
		return "Aucune carte sélectionnée."
	var owned := Game.owned_count(id)
	var used := _deck_count(id)
	if owned <= 0:
		return "Carte verrouillée — débloquez-la en campagne."
	if used >= GameConst.MAX_COPIES:
		return "Limite de %d exemplaires atteinte." % GameConst.MAX_COPIES
	if used >= owned:
		return "Tous vos exemplaires sont déjà dans le deck."
	if _cur_cards().size() >= GameConst.DECK_SIZE:
		return "Deck complet (%d cartes)." % GameConst.DECK_SIZE
	return ""


## ---- reconstructions --------------------------------------------------------

func _rebuild_all() -> void:
	%NameEdit.text = String(_cur().name)
	%DeckNameLabel.text = String(_cur().name)
	_refresh_coll()
	_refresh_deck()
	_refresh_identity()


func _passes_filters(def: CardDef) -> bool:
	if _filter_guild >= 0 and def.guild != _filter_guild:
		return false
	if _filter_kind == 0 and not def.is_monster():
		return false
	if _filter_kind == 1 and def.is_monster():
		return false
	if _filter_cost >= 0:
		if _filter_cost == 6 and def.cost < 6:
			return false
		if _filter_cost < 6 and def.cost != _filter_cost:
			return false
	if _search != "" and not def.display_name.to_lower().contains(_search):
		return false
	return true


func _sorted_defs() -> Array:
	var defs: Array = []
	for def in Db.constructible_cards():
		if _passes_filters(def):
			defs.append(def)
	defs.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		match _sort_key:
			"name":
				return a.display_name < b.display_name
			"guild":
				if a.guild != b.guild:
					return a.guild < b.guild
			"rarity":
				var ra := int(RARITY_ORDER.get(String(a.rarity), 0))
				var rb := int(RARITY_ORDER.get(String(b.rarity), 0))
				if ra != rb:
					return ra > rb
			"owned":
				var oa := Game.owned_count(String(a.id))
				var ob := Game.owned_count(String(b.id))
				if oa != ob:
					return oa > ob
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name)
	return defs


func _refresh_coll() -> void:
	for child in %CollList.get_children():
		child.queue_free()
	_coll_widgets.clear()
	# Toutes les cartes restent visibles : les non-possédées sont grisées et
	# cadenassées (consultables, non ajoutables).
	var owned_kinds := 0
	var total_kinds := 0
	for def: CardDef in Db.constructible_cards():
		total_kinds += 1
		if Game.owned_count(String(def.id)) > 0:
			owned_kinds += 1
	%CollCount.text = "%d / %d" % [owned_kinds, total_kinds]
	for def: CardDef in _sorted_defs():
		var id := String(def.id)
		var w := CardWidget.create(def, coll_card_w)
		_coll_widgets[id] = w
		w.pressed.connect(func(_w: CardWidget) -> void: _select(id))
		w.activated.connect(func(_w: CardWidget) -> void: _add(id))  # double-clic
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		if Game.owned_count(id) > 0:
			# Glisser-déposer vers le deck (desktop) ; la cible est %DeckScroll.
			w.set_drag_forwarding(_coll_drag.bind(id, w), Callable(), Callable())
			if touch_buttons:
				w.add_child(_overlay_btn("+", func() -> void: _add(id)))
		%CollList.add_child(w)
	_update_coll_states()


## Payload de drag : l'id de la carte, avec un aperçu réduit sous le doigt.
func _coll_drag(_pos: Vector2, id: String, w: CardWidget) -> Variant:
	if _add_block_reason(id) != "":
		return null
	var preview := TextureRect.new()
	preview.texture = UiTheme.tex(CardWidget.full_card_path(StringName(id)))
	preview.custom_minimum_size = Vector2(coll_card_w, coll_card_w * 1.385)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	w.set_drag_preview(preview)
	return id


## Badges ×N et verrouillage, sans reconstruire la grille.
func _update_coll_states() -> void:
	for id: String in _coll_widgets:
		var w: CardWidget = _coll_widgets[id]
		var owned := Game.owned_count(id)
		if owned <= 0:
			w.modulate = Color(0.42, 0.42, 0.48)
			if not w.has_node("Lock"):
				w.add_child(_lock_icon())
		else:
			w.set_count(owned - _deck_count(id))


func _lock_icon() -> TextureRect:
	var lock := TextureRect.new()
	lock.name = "Lock"
	lock.texture = UiTheme.tex("res://assets/sprites/ui/gold/icon_lock.png")
	lock.custom_minimum_size = Vector2(44, 44)
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lock


## Petit bouton superposé à une carte (+ collection / − deck, tactile).
## Enveloppé dans un Control : CardWidget est un PanelContainer, qui étire
## ses enfants directs sur toute la carte.
func _overlay_btn(txt: String, action: Callable) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var b := Button.new()
	b.text = txt
	b.theme_type_variation = &"MenuIconButton"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -46.0
	b.offset_top = -46.0
	b.offset_right = -4.0
	b.offset_bottom = -4.0
	b.pressed.connect(action)
	b.pressed.connect(UiTheme._click_sfx)
	holder.add_child(b)
	return holder


func _refresh_deck() -> void:
	for child in %DeckGrid.get_children():
		child.queue_free()
	var cards := _cur_cards()
	var unique := {}
	for id in cards:
		unique[id] = int(unique.get(id, 0)) + 1
	var ids := unique.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ca := Db.card(StringName(String(a)))
		var cb := Db.card(StringName(String(b)))
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.display_name < cb.display_name)
	for id in ids:
		var idd := String(id)
		var w := CardWidget.create(Db.card(StringName(idd)), deck_card_w)
		w.set_count(unique[id])
		w.pressed.connect(func(_w: CardWidget) -> void: _select(idd))
		w.activated.connect(func(_w: CardWidget) -> void: _remove(idd))
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		w.add_child(_overlay_btn("−", func() -> void: _remove(idd)))
		%DeckGrid.add_child(w)
	# Emplacements vides : un par carte manquante (dos discret).
	var slot_tex := UiTheme.tex("res://assets/sprites/ui/deck/slot_empty.png")
	for i in maxi(0, GameConst.DECK_SIZE - cards.size()):
		var slot := TextureRect.new()
		slot.texture = slot_tex
		slot.custom_minimum_size = Vector2(deck_card_w, deck_card_w * 1.385)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.modulate.a = 0.55
		%DeckGrid.add_child(slot)

	%DeckCount.text = "%d / %d" % [cards.size(), GameConst.DECK_SIZE]
	_refresh_curve(cards)
	_refresh_stats(cards)
	_refresh_validity(cards)
	_update_coll_states()
	_update_actions()


func _refresh_curve(cards: Array) -> void:
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for id in cards:
		var def := Db.card(StringName(String(id)))
		counts[mini(def.cost, 6)] += 1
	%CostCurve.set_counts(counts)


func _refresh_stats(cards: Array) -> void:
	var monsters := 0
	var spells := 0
	var total_cost := 0
	var per_guild := {}
	for id in cards:
		var def := Db.card(StringName(String(id)))
		if def.is_monster():
			monsters += 1
		else:
			spells += 1
		total_cost += def.cost
		per_guild[def.guild] = int(per_guild.get(def.guild, 0)) + 1
	%StatCards.text = "%d / %d" % [cards.size(), GameConst.DECK_SIZE]
	%StatMonsters.text = str(monsters)
	%StatSpells.text = str(spells)
	%StatAvg.text = "%.1f" % (float(total_cost) / cards.size()) if not cards.is_empty() else "—"
	var dominant := -1
	var best := 0
	for g in per_guild:
		if per_guild[g] > best:
			best = per_guild[g]
			dominant = g
	if dominant >= 0:
		%StatGuild.text = String(GameConst.GUILD_NAMES.get(dominant, "—"))
		%StatGuild.add_theme_color_override("font_color", UiTheme.guild_color(dominant))
		var icon := UiTheme.tex(_guild_icon_path(dominant))
		%DeckGuildIcon.texture = icon
		%DeckGuildIcon.visible = icon != null
	else:
		%StatGuild.text = "—"
		%DeckGuildIcon.visible = false


static func _guild_icon_path(guild: int) -> String:
	var names := { GameConst.Guild.FLAME: "flame", GameConst.Guild.SYLVAN: "sylvan",
			GameConst.Guild.SHADOW: "shadow", GameConst.Guild.LIGHT: "light" }
	return "res://assets/sprites/ui/deck/guild_%s.png" % names.get(guild, "flame")


func _refresh_validity(cards: Array) -> void:
	var err := ""
	if cards.size() == GameConst.DECK_SIZE:
		err = Rules.validate_deck(Db.cards, cards)
	else:
		err = "Le deck doit contenir exactement %d cartes (%d actuellement)." \
				% [GameConst.DECK_SIZE, cards.size()]
	_deck_valid = err == ""
	%ValidateBtn.disabled = not _deck_valid
	%ValidLabel.text = "Deck valide — prêt au combat !" if _deck_valid else err
	%ValidLabel.add_theme_color_override("font_color",
			Color(0.55, 1.0, 0.62) if _deck_valid else Color(1.0, 0.62, 0.45))


## Identité du deck (panneau droit) : maître réel + son passif comme effet.
func _refresh_identity() -> void:
	var m: MasterDef = Db.master(StringName(String(_cur().master)))
	if m == null:
		return
	%EffectLabel.text = "Maître : %s (%s)\nPassif : %s\nPouvoir — %s (%d pierres) : %s" \
			% [m.display_name, GameConst.GUILD_NAMES.get(m.guild, ""), m.passive_desc,
			m.power_name, m.power_cost, m.power_desc]
	# L'illustration du panneau droit = portrait du Maître sélectionné.
	var hero := get_node_or_null("%HeroArt") as TextureRect
	if hero != null:
		var tex := UiTheme.tex(m.portrait)
		if tex != null:
			hero.texture = tex


## ---- détails de carte -------------------------------------------------------

func _select(id: String) -> void:
	sel_id = id
	var def := Db.card(StringName(id))
	if def == null:
		return
	%DetailEmpty.visible = false
	%DetailBox.visible = true
	var tex := UiTheme.tex(CardWidget.full_card_path(def.id))
	%DetailArt.texture = tex if tex != null else UiTheme.tex(def.art)
	%DetailName.text = def.display_name
	var kind_name := "Monstre" if def.is_monster() else "Sort"
	%DetailType.text = "%s • %s • %d pierre(s) • %s" % [kind_name,
			GameConst.GUILD_NAMES.get(def.guild, ""), def.cost, String(def.rarity).capitalize()]
	var body: PackedStringArray = []
	if def.is_monster():
		body.append("%s : %s." % [GameText.ATTACK_TYPE_NAMES[def.attack_type],
				GameText.ATTACK_TYPE_DEFS[def.attack_type]])
		for kw in def.keywords:
			var value = def.keywords[kw]
			var shown: String = GameText.KEYWORD_NAMES.get(String(kw), String(kw))
			if not (value is bool):
				shown += " %d" % int(value)
			body.append("%s : %s." % [shown, GameText.KEYWORD_DEFS.get(String(kw), "")])
		if not def.on_summon.is_empty():
			body.append("Invocation : " + GameText.describe_effect(def.on_summon))
		if not def.on_death.is_empty():
			body.append("Mort : " + GameText.describe_effect(def.on_death))
		if not def.on_attack.is_empty():
			body.append("Attaque : " + GameText.describe_effect(def.on_attack))
	else:
		body.append("Sort : " + GameText.describe_effect(def.effect))
	if def.description != "":
		body.append("« %s »" % def.description)
	%DetailKeywords.text = "\n".join(body)

	# Niveaux + évolution (colonne de droite du panneau détails).
	var lv_lines: PackedStringArray = []
	if def.is_monster():
		for i in def.levels.size():
			var lv: Dictionary = def.levels[i]
			var seuil := "" if i == 0 else "  (%d XP)" % int(lv.xp)
			lv_lines.append("Niveau %d%s : %d ATQ / %d PV" % [i + 1, seuil,
					int(lv.atk), int(lv.hp)])
	%DetailLevels.text = "\n".join(lv_lines)
	# Les sorts n'ont ni niveaux ni évolution : masquer la colonne pour
	# laisser toute la largeur à la description.
	(%DetailLevels.get_parent() as Control).visible = def.is_monster()
	var evo: CardDef = Db.card(def.evolves_to) if def.evolves_to != &"" else null
	%EvoBox.visible = evo != null
	if evo != null:
		%DetailEvo.text = "Évolution : %s\nCoût : %d pierres" % [evo.display_name, def.evolve_cost]
		var evo_tex := UiTheme.tex(CardWidget.full_card_path(evo.id))
		%EvoArt.texture = evo_tex if evo_tex != null else UiTheme.tex(evo.art)
	_update_actions()
	if get_node_or_null("%MobileTabs") != null:
		_show_page(2)   # sur mobile, la sélection ouvre l'onglet DÉTAILS


func _update_actions() -> void:
	var reason := _add_block_reason(sel_id)
	%AddBtn.disabled = reason != ""
	%RemoveBtn.disabled = sel_id == "" or _deck_count(sel_id) <= 0
	%ReasonLabel.text = reason if sel_id != "" else ""


func _add(id: String) -> void:
	if _add_block_reason(id) != "":
		Audio.play_sfx("error")
		return
	_cur_cards().append(id)
	Audio.play_sfx("move")
	_set_dirty(true)
	_refresh_deck()


func _remove(id: String) -> void:
	if not _cur_cards().has(id):
		return
	_cur_cards().erase(id)
	Audio.play_sfx("move")
	_set_dirty(true)
	_refresh_deck()


## ---- overlays ----------------------------------------------------------------

func _open_overlay(panel: Control) -> void:
	_close_overlays()
	%Dim.visible = true
	panel.visible = true
	if panel == %DecksOverlay:
		_rebuild_deck_list()
	elif panel == %MasterOverlay:
		_rebuild_masters()


func _close_overlays() -> void:
	%Dim.visible = false
	for p: Control in [%DecksOverlay, %MasterOverlay, %MissingOverlay, %HelpOverlay]:
		p.visible = false


## ---- mes decks -----------------------------------------------------------------

func _rebuild_deck_list() -> void:
	for c in %DeckList.get_children():
		c.queue_free()
	for i in decks.size():
		var b := Button.new()
		var star := "★ " if i == int(Game.profile.active_deck) else ""
		var here := "  (en cours)" if i == current else ""
		b.text = "%s%s%s" % [star, decks[i].name, here]
		b.theme_type_variation = &"MenuNavButton" if i != current else &"MenuNavFeatured"
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func() -> void:
			current = i
			sel_id = ""
			Audio.play_sfx("move")
			_close_overlays()
			_rebuild_all())
		%DeckList.add_child(b)
	%NewDeckBtn.disabled = decks.size() >= Game.MAX_DECKS
	%DupDeckBtn.disabled = decks.size() >= Game.MAX_DECKS
	%DeleteDeckBtn.disabled = decks.size() <= 1


func _new_deck() -> void:
	if decks.size() >= Game.MAX_DECKS:
		return
	var master = Game.profile.masters[0] if not Game.profile.masters.is_empty() else "kiran"
	decks.append(Game.make_deck("Deck %d" % (decks.size() + 1), master, []))
	current = decks.size() - 1
	_after_deck_change()


func _duplicate_deck() -> void:
	if decks.size() >= Game.MAX_DECKS:
		return
	var src := _cur()
	decks.append(Game.make_deck(String(src.name) + " (copie)", src.master, src.cards))
	current = decks.size() - 1
	_after_deck_change()


func _delete_current() -> void:
	if decks.size() <= 1:
		return
	decks.remove_at(current)
	current = clampi(current, 0, decks.size() - 1)
	_after_deck_change()


func _after_deck_change() -> void:
	sel_id = ""
	Audio.play_sfx("move")
	_set_dirty(true)
	_close_overlays()
	_rebuild_all()


## ---- maître ---------------------------------------------------------------------

## Tous les maîtres en grille ; les non possédés sont grisés + cadenassés.
func _rebuild_masters() -> void:
	var cur_id := String(_cur().master)
	for c in %MasterPick.get_children():
		c.queue_free()
	for m: MasterDef in Db.masters.values():
		var mid := String(m.id)
		var owned: bool = Game.profile.masters.has(mid)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 170)
		b.icon = UiTheme.tex(m.portrait)
		b.expand_icon = true
		b.disabled = not owned
		b.theme_type_variation = &"MenuNavFeatured" if mid == cur_id else &"MenuNavButton"
		b.tooltip_text = "%s — %s\nPassif : %s\nPouvoir — %s (%d pierres) : %s%s" % [
				m.display_name, GameConst.GUILD_NAMES.get(m.guild, ""),
				m.passive_desc, m.power_name, m.power_cost, m.power_desc,
				"" if owned else "\n(Verrouillé — débloquer en campagne)"]
		if not owned:
			b.modulate = Color(0.4, 0.4, 0.46)
		else:
			b.pressed.connect(func() -> void:
				_cur().master = mid
				Audio.play_sfx("move")
				_set_dirty(true)
				_close_overlays()
				_refresh_identity())
		%MasterPick.add_child(b)


## ---- cartes absentes --------------------------------------------------------------

func _rebuild_missing() -> void:
	for c in %MissingList.get_children():
		c.queue_free()
	var none := true
	for def: CardDef in Db.constructible_cards():
		if Game.owned_count(String(def.id)) > 0:
			continue
		none = false
		var lbl := Label.new()   # contenu dynamique par nature (liste)
		lbl.text = "%d — %s  (%s, %s)" % [def.cost, def.display_name,
				GameConst.GUILD_NAMES.get(def.guild, ""), String(def.rarity)]
		lbl.add_theme_font_override("font", UiTheme.title_font())
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.add_theme_color_override("font_color", UiTheme.guild_color(def.guild))
		%MissingList.add_child(lbl)
	if none:
		var lbl := Label.new()
		lbl.text = "Aucune — vous possédez toutes les cartes !"
		lbl.add_theme_constant_override("outline_size", 0)
		%MissingList.add_child(lbl)


## ---- sauvegarde ---------------------------------------------------------------------

func _save() -> void:
	if not _deck_valid:
		Audio.play_sfx("error")
		return
	Game.profile.decks = decks.duplicate(true)
	Game.profile.active_deck = current   # le deck construit devient actif
	Game.save_profile()
	Game.profile_changed.emit()
	Audio.play_sfx("levelup")
	_set_dirty(false)
	%ValidLabel.text = "Deck « %s » enregistré et actif !" % _cur().name
	%ValidLabel.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
