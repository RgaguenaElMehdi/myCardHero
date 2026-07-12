extends Control
## Deck builder (design "or baroque sur noir", mockup utilisateur).
## Gauche : MON DECK (grille de cartes) + COLLECTION (rangée horizontale) +
## SAUVEGARDER. Droite : trois onglets — détail de carte / maître / mes decks.
## Structure et style dans deck_builder[_mobile].tscn — logique seulement ici.

## Largeurs de cartes, portées par la scène (desktop et mobile diffèrent).
@export var deck_card_w := 148.0
@export var coll_card_w := 214.0

const GOLD := Color(0.855, 0.71, 0.42)

@onready var count_label: Label = %CountLabel
@onready var deck_grid: GridContainer = %DeckGrid
@onready var coll_list: HBoxContainer = %CollList
@onready var coll_scroll: ScrollContainer = %CollScroll
@onready var filter_btn: Button = %FilterBtn
@onready var prev_btn: Button = %PrevBtn
@onready var next_btn: Button = %NextBtn
@onready var save_btn: Button = %SaveBtn
@onready var back_btn: Button = %BackBtn
@onready var status_label: Label = %StatusLabel
@onready var tab_btns: Array[Button] = [%TabCardsBtn, %TabMasterBtn, %TabDecksBtn]
@onready var tab_line: ColorRect = %TabLine
@onready var pages: Array[Control] = [%PageCards, %PageMaster, %PageDecks]
@onready var placeholder: Label = %Placeholder
@onready var detail_card: TextureRect = %DetailCard
@onready var detail_text: Label = %DetailText
@onready var add_btn: Button = %AddBtn
@onready var remove_btn: Button = %RemoveBtn
@onready var master_card: TextureRect = %MasterCard
@onready var master_pick: HFlowContainer = %MasterPick
@onready var deck_tabs: VBoxContainer = %DeckTabs
@onready var name_edit: LineEdit = %NameEdit
@onready var delete_btn: Button = %DeleteBtn

var decks: Array = []      ## working copy of profile.decks ({name, master, cards})
var current := 0           ## index of the deck being edited
var filter_guild := -1
var sel_id := ""           ## card shown in the detail pane
var _deck_valid := false    ## dernier état de validité (garde le bouton vert/rouge)


func _ready() -> void:
	decks = Game.profile.decks.duplicate(true)
	current = clampi(int(Game.profile.active_deck), 0, decks.size() - 1)

	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))
	save_btn.pressed.connect(_save)
	# Bouton MENU au style or (plaque sombre + liseré + texte doré), comme le hub.
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 26)
	back_btn.add_theme_color_override("font_color", GOLD)
	back_btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6))
	delete_btn.pressed.connect(_delete_current)
	add_btn.pressed.connect(func() -> void: _add(sel_id))
	remove_btn.pressed.connect(func() -> void: _remove(sel_id))
	name_edit.text_changed.connect(func(t: String) -> void:
		_cur().name = t
		_rebuild_deck_tabs())
	filter_btn.pressed.connect(_show_filter_menu)
	prev_btn.pressed.connect(func() -> void: _page_collection(-1))
	next_btn.pressed.connect(func() -> void: _page_collection(1))
	for i in tab_btns.size():
		tab_btns[i].pressed.connect(_show_tab.bind(i))
	for b: Button in [save_btn, add_btn, remove_btn, delete_btn, back_btn]:
		b.pressed.connect(UiTheme._click_sfx)

	_rebuild_all()
	_show_tab.call_deferred(0)


func _cur() -> Dictionary:
	return decks[current]


func _cur_cards() -> Array:
	return decks[current].cards


func _deck_count(id: String) -> int:
	return _cur_cards().count(id)


func _rebuild_all() -> void:
	name_edit.text = String(_cur().name)
	delete_btn.disabled = decks.size() <= 1
	_rebuild_deck_tabs()
	_rebuild_masters()
	_refresh()


## ---- onglets du panneau droit -------------------------------------------

func _show_tab(i: int) -> void:
	for j in pages.size():
		pages[j].visible = j == i
		tab_btns[j].modulate = Color.WHITE if j == i else Color(0.45, 0.45, 0.45)
	await get_tree().process_frame        # layout des onglets avant la ligne
	var b := tab_btns[i]
	tab_line.global_position.x = b.global_position.x
	tab_line.size.x = b.size.x


## ---- collection -----------------------------------------------------------

func _show_filter_menu() -> void:
	var menu := PopupMenu.new()
	menu.add_item("Toutes", 0)
	for guild in GameConst.GUILD_NAMES:
		menu.add_item(GameConst.GUILD_NAMES[guild], guild + 1)
	menu.id_pressed.connect(func(id: int) -> void:
		filter_guild = id - 1
		_refresh())
	add_child(menu)
	menu.popup(Rect2i(Vector2i(filter_btn.global_position) + Vector2i(0, 60),
			Vector2i(300, 0)))


func _page_collection(dir: int) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(coll_scroll, "scroll_horizontal",
			coll_scroll.scroll_horizontal + dir * int(coll_scroll.size.x * 0.8), 0.25)


func _refresh() -> void:
	for child in coll_list.get_children():
		child.queue_free()
	for def in Db.constructible_cards():
		var id := String(def.id)
		var owned := Game.owned_count(id)
		if owned <= 0:
			continue
		if filter_guild >= 0 and def.guild != filter_guild:
			continue
		var w := CardWidget.create(def, coll_card_w)
		var used := _deck_count(id)
		w.set_count(owned - used)
		if used >= owned:
			w.modulate = Color(0.5, 0.5, 0.55)
		w.pressed.connect(func(_w: CardWidget) -> void: _select(id))
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		coll_list.add_child(w)
	_refresh_deck()


## ---- MON DECK -------------------------------------------------------------

func _refresh_deck() -> void:
	for child in deck_grid.get_children():
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
		var def := Db.card(StringName(String(id)))
		var w := CardWidget.create(def, deck_card_w)
		w.set_count(unique[id])
		w.pressed.connect(func(_w: CardWidget) -> void: _select(String(id)))
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		deck_grid.add_child(w)
	# emplacements vides (esthétique mockup) pour compléter la grille
	var slot_tex := UiTheme.tex("res://assets/sprites/ui/gold/slot.png")
	var min_slots := deck_grid.columns * 2
	for _i in range(maxi(min_slots - ids.size(), 0)):
		var slot := TextureRect.new()
		slot.texture = slot_tex
		slot.custom_minimum_size = Vector2(deck_card_w, deck_card_w * 1.385)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_grid.add_child(slot)

	count_label.text = "%d/%d" % [cards.size(), GameConst.DECK_SIZE]
	var err := ""
	if cards.size() == GameConst.DECK_SIZE:
		err = Rules.validate_deck(Db.cards, cards)
	else:
		err = "Le deck doit contenir exactement %d cartes." % GameConst.DECK_SIZE
	# État montré par la COULEUR du bouton (vert = valide, rouge = non), plus de
	# texte qui chevauche. La raison d'invalidité reste en infobulle.
	_deck_valid = err == ""
	status_label.visible = false
	save_btn.modulate = Color(0.55, 1.0, 0.62) if _deck_valid else Color(1.0, 0.5, 0.5)
	save_btn.tooltip_text = "Deck valide — cliquer pour enregistrer" if _deck_valid else err


## ---- détail de carte ------------------------------------------------------

func _select(id: String) -> void:
	sel_id = id
	var def := Db.card(StringName(id))
	if def == null:
		return
	_show_tab(0)
	placeholder.visible = false
	detail_card.visible = true
	detail_text.visible = true
	var tex := UiTheme.tex(CardWidget.full_card_path(def.id))
	detail_card.texture = tex if tex != null else UiTheme.tex(def.art)
	var evo_name := ""
	if def.evolves_to != &"" and Db.card(def.evolves_to) != null:
		evo_name = Db.card(def.evolves_to).display_name
	detail_text.text = GameText.card_tooltip(def, evo_name)
	_update_actions()


func _update_actions() -> void:
	if sel_id == "":
		add_btn.visible = false
		remove_btn.visible = false
		return
	var owned := Game.owned_count(sel_id)
	var used := _deck_count(sel_id)
	add_btn.visible = _cur_cards().size() < GameConst.DECK_SIZE \
			and used < owned and used < GameConst.MAX_COPIES
	remove_btn.visible = used > 0


func _add(id: String) -> void:
	if id == "":
		return
	_cur_cards().append(id)
	Audio.play_sfx("move")
	_refresh()
	_update_actions()


func _remove(id: String) -> void:
	_cur_cards().erase(id)
	Audio.play_sfx("move")
	_refresh()
	_update_actions()


## ---- mes decks ------------------------------------------------------------

func _rebuild_deck_tabs() -> void:
	for c in deck_tabs.get_children():
		c.queue_free()
	for i in decks.size():
		var b := Button.new()
		var star := "★ " if i == int(Game.profile.active_deck) else ""
		b.text = "%s%s" % [star, decks[i].name]
		b.custom_minimum_size = Vector2(0, 30.0 * UiTheme.touch_scale())
		var col := UiTheme.GOLD.darkened(0.2) if i == current else UiTheme.PANEL_LIGHT
		UiTheme.style_button(b, col, 16)
		b.pressed.connect(_switch_to.bind(i))
		deck_tabs.add_child(b)
	if decks.size() < Game.MAX_DECKS:
		var add := Button.new()
		add.text = "+ Nouveau deck"
		add.custom_minimum_size = Vector2(0, 30.0 * UiTheme.touch_scale())
		UiTheme.style_button(add, UiTheme.OK.darkened(0.3), 16)
		add.pressed.connect(_new_deck)
		deck_tabs.add_child(add)


func _switch_to(i: int) -> void:
	current = i
	Audio.play_sfx("move")
	_rebuild_all()


func _new_deck() -> void:
	if decks.size() >= Game.MAX_DECKS:
		return
	var master = Game.profile.masters[0] if not Game.profile.masters.is_empty() else "kiran"
	decks.append(Game.make_deck("Deck %d" % (decks.size() + 1), master, []))
	current = decks.size() - 1
	Audio.play_sfx("move")
	_rebuild_all()


func _delete_current() -> void:
	if decks.size() <= 1:
		return
	decks.remove_at(current)
	current = clampi(current, 0, decks.size() - 1)
	Audio.play_sfx("move")
	_rebuild_all()


## ---- maître ---------------------------------------------------------------

## Shows the deck's master as its full card (art + power + passive), with a row of
## owned-master portraits to swap it (hover shows the effect).
func _rebuild_masters() -> void:
	var cur_id := String(_cur().master)
	master_card.texture = UiTheme.tex(
			"res://assets/sprites/cards_full/master_%s.png" % cur_id)
	for c in master_pick.get_children():
		c.queue_free()
	for mid in Game.profile.masters:
		var m: MasterDef = Db.master(StringName(String(mid)))
		if m == null:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 74) * minf(UiTheme.touch_scale(), 1.35)
		b.icon = UiTheme.tex(m.portrait)
		b.expand_icon = true
		b.tooltip_text = "%s — %s\nPassif : %s\nPouvoir — %s (%d pierres) : %s" % [
				m.display_name, GameConst.GUILD_NAMES.get(m.guild, ""),
				m.passive_desc, m.power_name, m.power_cost, m.power_desc]
		var selected := String(mid) == cur_id
		UiTheme.style_button(b, UiTheme.guild_color(m.guild).darkened(
				0.25 if selected else 0.6), 12)
		b.modulate = Color.WHITE if selected else Color(0.65, 0.65, 0.7)
		b.pressed.connect(func() -> void:
			_cur().master = String(mid)
			Audio.play_sfx("move")
			_rebuild_masters())
		master_pick.add_child(b)


func _save() -> void:
	if not _deck_valid:
		Audio.play_sfx("error")
		return
	Game.profile.decks = decks.duplicate(true)
	Game.profile.active_deck = current   # the deck you just built becomes active
	Game.save_profile()
	Game.profile_changed.emit()
	status_label.text = "Deck « %s » enregistré et actif !" % _cur().name
	status_label.add_theme_color_override("font_color", UiTheme.OK)
	Audio.play_sfx("levelup")
	_rebuild_deck_tabs()
