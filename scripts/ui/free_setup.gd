extends Control
## Partie libre (mockup utilisateur) : choix du MAÎTRE ADVERSAIRE (cartes
## portrait au centre), choix de la difficulté (3 pastilles), « Commencer
## le combat ». Structure dans free_setup.tscn — logique ici.
## Le deck du joueur est son deck actif (géré dans le deck builder).

signal launched(opponent_master: String, opponent_deck: Array, level: int)

const OPPONENT_CARD: PackedScene = preload("res://scenes/widgets/opponent_card.tscn")

const SELECTED := Color(1.25, 1.2, 1.05)
const UNSELECTED := Color(0.62, 0.61, 0.58)

var _opponents: Array[Dictionary] = []      # { master: String, deck: Array }
var _cards: Array[Button] = []
var _diffs: Array[Button] = []
var _sel_opp := 0
var _level := int(AiPlayer.Level.ADEPT)


func _ready() -> void:
	# Tous les maîtres du jeu : deck de campagne s'il existe, sinon un deck
	# construit sur les cartes de leur guilde.
	var campaign_decks := {}
	for ch in Db.chapters():
		var opp: Dictionary = ch.get("opponent", {})
		if opp.has("master") and not campaign_decks.has(String(opp.master)):
			campaign_decks[String(opp.master)] = opp.deck
	for id in Db.masters:
		var m: MasterDef = Db.masters[id]
		var mid := String(m.id)
		_opponents.append({ "master": mid,
				"deck": campaign_decks.get(mid, _guild_deck(m)) })
	for i in _opponents.size():
		_cards.append(_make_card(i))

	_diffs = [%DiffNovice, %DiffInter, %DiffVeteran]
	var levels := [AiPlayer.Level.NOVICE, AiPlayer.Level.ADEPT, AiPlayer.Level.MASTER]
	for i in _diffs.size():
		_diffs[i].pressed.connect(_pick_diff.bind(i, int(levels[i])))
		_diffs[i].pressed.connect(UiTheme._click_sfx)

	# Scène de destination (menu « Partie libre ») OU overlay (écran Sélection) :
	# en scène autonome on lance/quitte soi-même, en overlay on émet le signal.
	var standalone := get_tree().current_scene == self
	(%LaunchBtn as Button).pressed.connect(func() -> void:
		UiTheme._click_sfx()
		var opp := _opponents[_sel_opp]
		if standalone:
			Game.start_free_battle(_level, String(opp.master), opp.deck)
		else:
			launched.emit(String(opp.master), opp.deck, _level)
			queue_free())
	(%BackBtn as Button).pressed.connect(func() -> void:
		UiTheme._click_sfx()
		if standalone:
			Game.goto("main_menu")
		else:
			queue_free())

	# Flèches de défilement (remplacent la barre de scroll, masquée) : ne
	# s'affichent que si la rangée déborde.
	(%ArrowLeft as Button).pressed.connect(_scroll_by.bind(-1))
	(%ArrowRight as Button).pressed.connect(_scroll_by.bind(1))
	(%ArrowLeft as Button).pressed.connect(UiTheme._click_sfx)
	(%ArrowRight as Button).pressed.connect(UiTheme._click_sfx)
	(%MastersScroll as ScrollContainer).get_h_scroll_bar() \
			.value_changed.connect(func(_v: float) -> void: _update_arrows())
	resized.connect(_update_arrows)
	_update_arrows.call_deferred()

	_pick_opp(0)
	_pick_diff(1, int(AiPlayer.Level.ADEPT))
	_animate_launch.call_deferred()


func _make_card(i: int) -> Button:
	var m: MasterDef = Db.master(StringName(String(_opponents[i].master)))
	var card: Button = OPPONENT_CARD.instantiate()
	%MastersRow.add_child(card)
	(card.get_node("%Portrait") as TextureRect).texture = UiTheme.tex(m.portrait)
	(card.get_node("%Name") as Label).text = m.display_name.to_upper()
	(card.get_node("%Title") as Label).text = m.title
	(card.get_node("%Desc") as Label).text = m.lore
	card.pressed.connect(_pick_opp.bind(i))
	card.pressed.connect(UiTheme._click_sfx)
	return card


## Deck d'un maître sans deck de campagne : ses cartes de guilde en double,
## complété avec les cartes les moins chères des autres guildes.
func _guild_deck(m: MasterDef) -> Array:
	var own: Array[CardDef] = []
	var rest: Array[CardDef] = []
	for c in Db.constructible_cards():
		(own if c.guild == m.guild else rest).append(c)
	var by_cost := func(a: CardDef, b: CardDef) -> bool: return a.cost < b.cost
	own.sort_custom(by_cost)
	rest.sort_custom(by_cost)
	var deck: Array = []
	for c in own:
		deck.append(String(c.id))
		deck.append(String(c.id))
	for c in rest:
		if deck.size() >= GameConst.DECK_SIZE:
			break
		deck.append(String(c.id))
	return deck.slice(0, GameConst.DECK_SIZE)


func _pick_opp(i: int) -> void:
	_sel_opp = i
	for j in _cards.size():
		_cards[j].button_pressed = j == i
		_cards[j].modulate = SELECTED if j == i else UNSELECTED


func _pick_diff(i: int, level: int) -> void:
	_level = level
	for j in _diffs.size():
		_diffs[j].button_pressed = j == i
		_diffs[j].modulate = SELECTED if j == i else UNSELECTED


## Fait défiler la rangée des maîtres d'environ deux cartes, en douceur.
func _scroll_by(direction: int) -> void:
	var sc := %MastersScroll as ScrollContainer
	var target := sc.scroll_horizontal + direction * 480
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) \
			.tween_property(sc, "scroll_horizontal", target, 0.25)


func _update_arrows() -> void:
	var sc := %MastersScroll as ScrollContainer
	var overflow: float = (%MastersRow as Control).size.x - sc.size.x
	(%ArrowLeft as Button).visible = overflow > 1.0 and sc.scroll_horizontal > 0
	(%ArrowRight as Button).visible = overflow > 1.0 \
			and sc.scroll_horizontal < int(overflow)


func _animate_launch() -> void:
	await get_tree().process_frame
	var btn := %LaunchBtn as Button
	btn.pivot_offset = btn.size / 2.0
	var tw := btn.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "modulate", Color(1.22, 1.15, 0.95), 0.8)
	tw.tween_property(btn, "modulate", Color.WHITE, 0.8)
