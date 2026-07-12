extends Control
## Deck builder: manage up to Game.MAX_DECKS decks. Each deck carries its own
## master (swappable) + a name + a legal card list, assembled from the owned
## collection. Saving persists all decks and makes the edited one active.

@onready var filters: HBoxContainer = %Filters
@onready var collection_grid: GridContainer = %CollectionGrid
@onready var deck_tabs: HBoxContainer = %DeckTabs
@onready var name_edit: LineEdit = %NameEdit
@onready var delete_btn: Button = %DeleteBtn
@onready var master_card: TextureRect = %MasterCard
@onready var master_pick: HFlowContainer = %MasterPick
@onready var deck_list: VBoxContainer = %DeckList
@onready var count_label: Label = %CountLabel
@onready var status_label: Label = %StatusLabel
@onready var save_btn: Button = %SaveBtn
@onready var back_btn: Button = %BackBtn

var decks: Array = []      ## working copy of profile.decks ({name, master, cards})
var current := 0           ## index of the deck being edited
var filter_guild := -1


func _ready() -> void:
	decks = Game.profile.decks.duplicate(true)
	current = clampi(int(Game.profile.active_deck), 0, decks.size() - 1)

	UiTheme.style_button(save_btn, UiTheme.OK.darkened(0.25), 20)
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 18)
	UiTheme.style_button(delete_btn, UiTheme.DANGER.darkened(0.35), 16)

	_filter_btn(filters, "Toutes", -1)
	for guild in GameConst.GUILD_NAMES:
		_filter_btn(filters, GameConst.GUILD_NAMES[guild], guild)

	save_btn.pressed.connect(_save)
	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))
	delete_btn.pressed.connect(_delete_current)
	name_edit.text_changed.connect(func(t: String) -> void:
		_cur().name = t
		_rebuild_tabs())

	_rebuild_all()


func _cur() -> Dictionary:
	return decks[current]


func _cur_cards() -> Array:
	return decks[current].cards


func _rebuild_all() -> void:
	name_edit.text = String(_cur().name)
	delete_btn.disabled = decks.size() <= 1
	_rebuild_tabs()
	_rebuild_masters()
	_refresh()


func _filter_btn(parent: Control, text: String, guild: int) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 30.0 * UiTheme.touch_scale())
	var color := UiTheme.PANEL_LIGHT if guild < 0 else UiTheme.guild_color(guild).darkened(0.45)
	UiTheme.style_button(b, color, 17)
	b.pressed.connect(func() -> void:
		filter_guild = guild
		_refresh())
	parent.add_child(b)


## One tab per deck (★ marks the active one), plus a "+" slot while under the cap.
func _rebuild_tabs() -> void:
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
		add.text = "+ Nouveau"
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


func _deck_count(id: String) -> int:
	return _cur_cards().count(id)


func _refresh() -> void:
	for child in collection_grid.get_children():
		child.queue_free()
	for def in Db.constructible_cards():
		var id := String(def.id)
		var owned := Game.owned_count(id)
		if owned <= 0:
			continue
		if filter_guild >= 0 and def.guild != filter_guild:
			continue
		# ponytail: capped at 1.6 — full 2.0 leaves less than 4 columns on phones.
		var w := CardWidget.create(def, 178.0 * minf(UiTheme.touch_scale(), 1.6))
		var used := _deck_count(id)
		w.set_count(owned - used)
		if used >= owned:
			w.modulate = Color(0.5, 0.5, 0.55)
		w.pressed.connect(_on_collection_card.bind(id))
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		collection_grid.add_child(w)
	_refresh_deck()


func _refresh_deck() -> void:
	for child in deck_list.get_children():
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
		var b := Button.new()
		b.text = "%d×  %s   (%d pierres)" % [unique[id], def.display_name, def.cost]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 28.0 * UiTheme.touch_scale())
		b.tooltip_text = "Cliquer pour retirer un exemplaire"
		UiTheme.style_button(b, UiTheme.guild_color(def.guild).darkened(0.55), 16)
		b.pressed.connect(_on_deck_row.bind(String(id)))
		deck_list.add_child(b)
	count_label.text = "Deck : %d / %d" % [cards.size(), GameConst.DECK_SIZE]
	var err := ""
	if cards.size() == GameConst.DECK_SIZE:
		err = Rules.validate_deck(Db.cards, cards)
	else:
		err = "Le deck doit contenir exactement %d cartes." % GameConst.DECK_SIZE
	status_label.text = "Deck valide !" if err == "" else err
	status_label.add_theme_color_override("font_color",
			UiTheme.OK if err == "" else UiTheme.DANGER)
	save_btn.disabled = err != ""


func _on_collection_card(_w: CardWidget, id: String) -> void:
	var owned := Game.owned_count(id)
	var used := _deck_count(id)
	if _cur_cards().size() >= GameConst.DECK_SIZE:
		return
	if used >= owned or used >= GameConst.MAX_COPIES:
		return
	_cur_cards().append(id)
	Audio.play_sfx("move")
	_refresh()


func _on_deck_row(id: String) -> void:
	_cur_cards().erase(id)
	Audio.play_sfx("move")
	_refresh()


func _save() -> void:
	Game.profile.decks = decks.duplicate(true)
	Game.profile.active_deck = current   # the deck you just built becomes active
	Game.save_profile()
	Game.profile_changed.emit()
	status_label.text = "Deck « %s » enregistré et actif !" % _cur().name
	Audio.play_sfx("levelup")
	_rebuild_tabs()
