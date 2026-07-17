extends Control
## Partie libre (mockup utilisateur) : choix du MAÎTRE ADVERSAIRE (cartes
## portrait au centre), choix de la difficulté (3 pastilles), « Commencer
## le combat » lance directement la bataille. Structure dans free_setup.tscn.
## Le deck du joueur est son deck actif (géré dans le deck builder).

const OPPONENT_CARD: PackedScene = preload("res://scenes/widgets/opponent_card.tscn")

const SELECTED := Color(1.25, 1.2, 1.05)
const UNSELECTED := Color(0.62, 0.61, 0.58)

var _opponents: Array[Dictionary] = []      # { master: String, deck: Array }
var _cards: Array[Button] = []
var _diffs: Array[Button] = []
var _sel_opp := 0
var _level := int(AiPlayer.Level.ADEPT)


func _ready() -> void:
	# Tous les maîtres du jeu, avec un deck cohérent généré pour leur guilde
	# (courbe de mana) — comme le matchmaking. On n'utilise plus les decks de
	# campagne écrits à la main ici : certains (tuto) étaient trop faibles.
	for id in Db.masters:
		var m: MasterDef = Db.masters[id]
		_opponents.append({ "master": String(m.id), "deck": Db.guild_deck(m.guild) })
	for i in _opponents.size():
		_cards.append(_make_card(i))

	_diffs = [%DiffNovice, %DiffInter, %DiffVeteran]
	var levels := [AiPlayer.Level.NOVICE, AiPlayer.Level.ADEPT, AiPlayer.Level.MASTER]
	for i in _diffs.size():
		_diffs[i].pressed.connect(_pick_diff.bind(i, int(levels[i])))
		_diffs[i].pressed.connect(UiTheme._click_sfx)

	(%LaunchBtn as Button).pressed.connect(func() -> void:
		UiTheme._click_sfx()
		var opp := _opponents[_sel_opp]
		Game.start_free_battle(_level, String(opp.master), opp.deck))
	(%BackBtn as Button).pressed.connect(func() -> void:
		UiTheme._click_sfx()
		Game.goto("main_menu"))

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
