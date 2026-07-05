extends Control
## Deck builder: browse the owned collection, assemble a legal 20-card deck,
## save it to the profile.

@onready var filters: HBoxContainer = %Filters
@onready var collection_grid: GridContainer = %CollectionGrid
@onready var deck_list: VBoxContainer = %DeckList
@onready var count_label: Label = %CountLabel
@onready var status_label: Label = %StatusLabel
@onready var save_btn: Button = %SaveBtn
@onready var back_btn: Button = %BackBtn

var working_deck: Array = []
var filter_guild := -1


func _ready() -> void:
	working_deck = Game.profile.deck.duplicate()

	# Style buttons
	UiTheme.style_button(save_btn, UiTheme.OK.darkened(0.25), 20)
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 18)

	# Build filter buttons (dynamic: depends on guild data)
	_filter_btn(filters, "Toutes", -1)
	for guild in GameConst.GUILD_NAMES:
		_filter_btn(filters, GameConst.GUILD_NAMES[guild], guild)

	# Connect signals
	save_btn.pressed.connect(_save)
	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))

	_refresh()


func _filter_btn(parent: Control, text: String, guild: int) -> void:
	var b := Button.new()
	b.text = text
	var color := UiTheme.PANEL_LIGHT if guild < 0 else UiTheme.guild_color(guild).darkened(0.45)
	UiTheme.style_button(b, color, 17)
	b.pressed.connect(func() -> void:
		filter_guild = guild
		_refresh())
	parent.add_child(b)


func _deck_count(id: String) -> int:
	return working_deck.count(id)


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
		var w := CardWidget.spawn(def, 178)
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
	var unique := {}
	for id in working_deck:
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
		b.tooltip_text = "Cliquer pour retirer un exemplaire"
		UiTheme.style_button(b, UiTheme.guild_color(def.guild).darkened(0.55), 16)
		b.pressed.connect(_on_deck_row.bind(String(id)))
		deck_list.add_child(b)
	count_label.text = "Deck : %d / %d" % [working_deck.size(), GameConst.DECK_SIZE]
	var err := ""
	if working_deck.size() == GameConst.DECK_SIZE:
		err = Rules.validate_deck(Db.cards, working_deck)
	else:
		err = "Le deck doit contenir exactement %d cartes." % GameConst.DECK_SIZE
	status_label.text = err
	status_label.add_theme_color_override("font_color",
			UiTheme.OK if err == "" else UiTheme.DANGER)
	if err == "":
		status_label.text = "Deck valide !"
	save_btn.disabled = err != ""


func _on_collection_card(w: CardWidget, id: String) -> void:
	var owned := Game.owned_count(id)
	var used := _deck_count(id)
	if working_deck.size() >= GameConst.DECK_SIZE:
		return
	if used >= owned or used >= GameConst.MAX_COPIES:
		return
	working_deck.append(id)
	Audio.play_sfx("move")
	_refresh()


func _on_deck_row(id: String) -> void:
	working_deck.erase(id)
	Audio.play_sfx("move")
	_refresh()


func _save() -> void:
	Game.profile.deck = working_deck.duplicate()
	Game.save_profile()
	status_label.text = "Deck enregistré !"
	Audio.play_sfx("levelup")
