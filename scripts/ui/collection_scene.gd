extends Control
## Écran Collection : toutes les cartes constructibles, filtres élément /
## type / rareté / coût / possession + recherche, clic = inspecteur de carte.
## Possession réelle (Game.owned_count) : cartes manquantes grisées + cadenas.
## Structure dans collection.tscn (ancrée, s'adapte au canvas mobile) —
## logique seulement ici (règle n°1).

const CARD_W := 190.0

const RARITIES := [&"", &"commune", &"rare", &"epique", &"legendaire"]
const COSTS := [[], [0, 2], [3, 4], [5, 99]]

var _widgets := {}   ## id (String) -> CardWidget
var _selected := ""  ## carte sélectionnée (barre recyclage / fabrication)


func _ready() -> void:
	if get_viewport_rect().size.x > 2000:  # canvas mobile : fond adapté
		%BG.texture = UiTheme.tex("res://assets/backgrounds/freeplay_2400.png")
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%BackBtn as Button).pressed.connect(UiTheme._click_sfx)

	for opt_data in [
			[%TypeOpt, ["Tous types", "Monstres", "Sorts"]],
			[%RarityOpt, ["Toutes raretés", "Commune", "Rare", "Épique", "Légendaire"]],
			[%CostOpt, ["Tout coût", "Coût 0 – 2", "Coût 3 – 4", "Coût 5+"]],
			[%OwnOpt, ["Toutes", "Possédées", "Manquantes"]]]:
		var opt := opt_data[0] as OptionButton
		for label in opt_data[1]:
			opt.add_item(label)
		opt.item_selected.connect(func(_i: int) -> void: _refresh())
	for chip: Button in [%GuildAll, %GuildFlame, %GuildSylvan, %GuildShadow, %GuildLight]:
		chip.pressed.connect(_refresh)
		chip.pressed.connect(UiTheme._click_sfx)
	(%SearchEdit as LineEdit).text_changed.connect(func(_t: String) -> void: _refresh())
	(%Scroll as Control).resized.connect(_fit_columns)

	# Barre de sélection : recyclage (→ Essence) / fabrication (← Essence).
	(%RecycleBtn as Button).pressed.connect(_recycle)
	(%CraftBtn as Button).pressed.connect(_craft)
	(%InspectBtn as Button).pressed.connect(func() -> void:
		if _selected != "":
			CardPopup.open(self, Db.card(StringName(_selected))))
	(%CloseSel as Button).pressed.connect(func() -> void: _select(""))
	for b: Button in [%RecycleBtn, %CraftBtn, %InspectBtn, %CloseSel]:
		b.pressed.connect(UiTheme._click_sfx)

	_build()
	_refresh()
	_fit_columns.call_deferred()
	Audio.play_music("menu")


## Une carte = un CardWidget (widget réutilisé du deck builder), créé une fois ;
## les filtres jouent sur la visibilité sans reconstruire la grille.
func _build() -> void:
	var defs: Array = Db.constructible_cards()
	defs.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		if a.guild != b.guild:
			return a.guild < b.guild
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name)
	for def: CardDef in defs:
		var id := String(def.id)
		var w := CardWidget.create(def, CARD_W)
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		w.pressed.connect(func(_w: CardWidget) -> void: _select(id))
		_widgets[id] = w
		_update_widget(id)
		%CardGrid.add_child(w)


func _refresh() -> void:
	var guild := -1
	var chips: Array = [%GuildFlame, %GuildSylvan, %GuildShadow, %GuildLight]
	for i in chips.size():  # ordre = GameConst.Guild (FLAME, SYLVAN, SHADOW, LIGHT)
		if (chips[i] as Button).button_pressed:
			guild = i
	var kind := (%TypeOpt as OptionButton).selected      # 0 tous, 1 monstres, 2 sorts
	var rarity: StringName = RARITIES[(%RarityOpt as OptionButton).selected]
	var cost: Array = COSTS[(%CostOpt as OptionButton).selected]
	var own := (%OwnOpt as OptionButton).selected        # 0 toutes, 1 possédées, 2 manquantes
	var search := (%SearchEdit as LineEdit).text.strip_edges().to_lower()

	var shown := 0
	var owned_kinds := 0
	for id: String in _widgets:
		var w: CardWidget = _widgets[id]
		var def: CardDef = w.def
		var owned := Game.owned_count(id) > 0
		if owned:
			owned_kinds += 1
		var ok := true
		if guild >= 0 and int(def.guild) != guild:
			ok = false
		elif kind == 1 and not def.is_monster():
			ok = false
		elif kind == 2 and def.is_monster():
			ok = false
		elif rarity != &"" and def.rarity != rarity:
			ok = false
		elif not cost.is_empty() and (def.cost < int(cost[0]) or def.cost > int(cost[1])):
			ok = false
		elif own == 1 and not owned:
			ok = false
		elif own == 2 and owned:
			ok = false
		elif search != "" and not def.display_name.to_lower().contains(search):
			ok = false
		w.visible = ok
		if ok:
			shown += 1
	%CountLabel.text = "%d / %d possédées  ·  %d affichées" \
			% [owned_kinds, _widgets.size(), shown]


func _fit_columns() -> void:
	var avail: float = (%Scroll as Control).size.x - 16.0
	(%CardGrid as GridContainer).columns = maxi(3, int((avail + 12.0) / (CARD_W + 12.0)))


## État visuel d'une carte : cadenas si non possédée, badge ×N sinon.
func _update_widget(id: String) -> void:
	var w: CardWidget = _widgets[id]
	var owned := Game.owned_count(id)
	if owned <= 0:
		w.modulate = Color(0.42, 0.42, 0.48)
		if not w.has_node("LockHolder"):
			w.add_child(_lock_icon())
	else:
		w.modulate = Color.WHITE
		if w.has_node("LockHolder"):
			w.get_node("LockHolder").queue_free()
		w.set_count(owned if owned > 1 else 0)


# ---- sélection / recyclage / fabrication ------------------------------------

func _select(id: String) -> void:
	_selected = id
	%ActionBar.visible = id != ""
	if id != "":
		_update_bar()


func _update_bar() -> void:
	var def: CardDef = Db.card(StringName(_selected))
	var owned := Game.owned_count(_selected)
	%SelName.text = def.display_name
	%SelOwned.text = "×%d possédée(s)" % owned if owned > 0 else "non possédée"
	%EssenceLabel.text = UiTheme.fmt_thousands(Game.currency("shards"))
	var recycle := %RecycleBtn as Button
	recycle.text = "♻  Recycler  +%d" % int(Economy.RECYCLE_VALUE.get(def.rarity, 5))
	recycle.disabled = owned <= Game.max_deck_use(_selected)
	recycle.tooltip_text = "" if not recycle.disabled else \
			"Impossible : exemplaires utilisés par vos decks (ou aucun en trop)."
	var craft := %CraftBtn as Button
	var cost := int(Economy.CRAFT_COST.get(def.rarity, 25))
	craft.text = "✦  Fabriquer  −%d" % cost
	craft.disabled = owned >= GameConst.MAX_COPIES or Game.currency("shards") < cost
	craft.tooltip_text = "" if not craft.disabled else \
			("Limite de %d exemplaires atteinte." % GameConst.MAX_COPIES
					if owned >= GameConst.MAX_COPIES else "Essence insuffisante.")


func _recycle() -> void:
	if _selected == "" or Game.recycle_card(_selected) < 0:
		return
	Audio.play_sfx("cast")
	_update_widget(_selected)
	_update_bar()
	_refresh()


func _craft() -> void:
	if _selected == "" or not Game.craft_card(_selected):
		return
	Audio.play_sfx("evolve")
	_update_widget(_selected)
	_update_bar()
	_refresh()


## Enveloppé dans un Control : CardWidget est un PanelContainer, qui étirerait
## le cadenas sur toute la carte.
func _lock_icon() -> Control:
	var holder := Control.new()
	holder.name = "LockHolder"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lock := TextureRect.new()
	lock.texture = UiTheme.tex("res://assets/sprites/ui/gold/icon_lock.png")
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lock.offset_left = -22
	lock.offset_top = -22
	lock.offset_right = 22
	lock.offset_bottom = 22
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lock)
	return holder
