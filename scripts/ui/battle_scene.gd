extends Control
## Battle scene controller. The UI structure lives in battle.tscn (panels,
## arena, buttons — see CLAUDE.md); this script only owns the match logic:
## it renders GameState into the scene nodes, translates clicks into Rules
## actions and animates the returned events.
## The human is always player 0; the AI is player 1.

const BOARD_CELL_SCENE: PackedScene = preload("res://scenes/widgets/board_cell.tscn")
const MULLIGAN_SCENE: PackedScene = preload("res://scenes/widgets/mulligan.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/widgets/game_over.tscn")

const HAND_CARD_W := 140.0
## Horizontal center of the board (hand, toasts and banners align on it).
const BOARD_CENTER_X := 960.0

@onready var arena: BattleArena = %Arena
@onready var board_area: Control = %BoardArea
@onready var hand_area: Control = %HandArea
@onready var fx_layer: Control = %FxLayer
@onready var log_box: VBoxContainer = %LogList
@onready var detail_holder: VBoxContainer = %DetailHolder
@onready var toast_label: Label = %ToastLabel
@onready var turn_label: Label = %TurnLabel
@onready var turn_info: Label = %TurnInfo
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var power_btn: Button = %PowerBtn
@onready var evolve_btn: Button = %EvolveBtn
@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var player_panel: PanelContainer = %PlayerPanel

var state: GameState
## Seam between UI and rules. Local = a plain MatchController; online = the
## NetworkMatchController from Net (authoritative server behind it).
var _match := MatchController.new()
var _online := false
var _net: NetworkMatchController
var ai: AiPlayer
## --autoplay: both sides AI-driven through the normal UI action path
## (integration smoke test of the full battle scene).
var autoplay := false
var autoplay_ai: AiPlayer
var busy := false          ## input locked (animations / AI turn)
## Watchdog: if an animation chain ever fails and leaves `busy` stuck during
## the player's turn, input is force-unlocked after a few seconds.
var _busy_since_ms := 0
var sel_hand := -1
var sel_cell := Vector2i(-1, -1)
var sel_power := false

var cells := {}            ## Vector2i -> BoardCell
var hand_widgets: Array[CardWidget] = []
## Monsters destroyed [by player 0, by player 1] (end-screen stats).
var kills := [0, 0]

var enemy_info: Dictionary = {}
var player_info: Dictionary = {}
var mulligan_overlay: Control


func _ready() -> void:
	if Game.battle_config.is_empty():
		# Direct launch (F6/debug): free battle against the chapter 4 deck.
		Game.battle_config = {
			"mode": "free", "chapter": -1, "ai_level": 1,
			"opponent_master": "willow",
			"opponent_deck": Db.chapter(3).opponent.deck,
			"opponent_name": "Bruna", "opponent_portrait": "bruna",
			"background": "arena_day",
		}
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	_init_ui()
	_setup_match()
	Audio.play_music("battle")
	if autoplay:
		Engine.time_scale = 20.0
		autoplay_ai = AiPlayer.new(AiPlayer.Level.ADEPT, 42)
		_run_autoplay()


func _process(_delta: float) -> void:
	if not busy:
		_busy_since_ms = 0
		return
	if _busy_since_ms == 0:
		_busy_since_ms = Time.get_ticks_msec()
		return
	var stuck_ms := Time.get_ticks_msec() - _busy_since_ms
	if state == null or state.phase != GameState.Phase.MAIN:
		return
	if state.current == 0 and stuck_ms > 8000:
		push_warning("Watchdog : déblocage forcé de l'interface (tour du joueur).")
		busy = false
		_busy_since_ms = 0
		_refresh_all()
	elif state.current == 1 and stuck_ms > 20000 and not _online:
		# The AI coroutine died mid-turn: recover by force-ending its turn.
		# (online: never force the opponent's turn — the server is authoritative.)
		push_warning("Watchdog : tour IA interrompu, fin de tour forcée.")
		_match.apply({ "type": "end_turn" })
		busy = false
		_busy_since_ms = 0
		_refresh_all()


func _run_autoplay() -> void:
	await get_tree().process_frame
	if mulligan_overlay != null:
		_on_mulligan_choice(false)
	var guard := 0
	while not state.is_over() and guard < 600:
		guard += 1
		if busy or state.phase != GameState.Phase.MAIN or state.current != 0:
			await get_tree().create_timer(0.2).timeout
			continue
		await _submit(autoplay_ai.choose_action(state))
	if not state.is_over():
		push_error("[autoplay] la partie ne s'est pas terminée (garde-fou %d)" % guard)
		get_tree().quit(1)


# --- Match setup ---------------------------------------------------------

func _setup_match() -> void:
	var cfg := Game.battle_config
	if String(cfg.get("mode", "")) == "online":
		_setup_online()
		return
	var my_deck := Game.active_deck()
	var m0: MasterDef = Db.master(StringName(String(my_deck.master)))
	var m1: MasterDef = Db.master(StringName(String(cfg.opponent_master)))
	state = _match.setup(Db.cards, [m0, m1],
			[my_deck.cards, cfg.opponent_deck], randi())
	ai = AiPlayer.new(int(cfg.ai_level), randi())
	_refresh_all()
	_show_mulligan()


## Online: the authoritative server drives everything. `state` is Net.controller's
## normalized view (I am always player 0), refreshed on each server push; the
## opponent's moves arrive as pushed events — no AI, no local rule application.
func _setup_online() -> void:
	_online = true
	_net = Net.controller
	_match = _net
	_net.remote_events.connect(_on_remote_events)
	Net.connection_failed.connect(func(msg: String) -> void:
		busy = false
		_toast(msg)
		_refresh_all())
	Net.opponent_left.connect(func() -> void:
		_toast("Adversaire déconnecté."))
	state = _net.state
	_refresh_all()
	if state.phase == GameState.Phase.MULLIGAN and state.current == 0:
		_show_mulligan()


## Authoritative update pushed by the server: adopt the new (normalized) state and
## animate the public events. Winner is in my view (0 = me).
func _on_remote_events(events: Array, over: bool, _winner: int) -> void:
	state = _net.state
	busy = true
	_refresh_all()
	await _play_events(events)
	busy = false
	_refresh_all()
	if over or state.is_over():
		_show_game_over()
		return
	if state.phase == GameState.Phase.MULLIGAN and state.current == 0 and mulligan_overlay == null:
		_show_mulligan()


func _show_mulligan() -> void:
	mulligan_overlay = MULLIGAN_SCENE.instantiate()
	mulligan_overlay.get_node("%KeepBtn").pressed.connect(_on_mulligan_choice.bind(false))
	mulligan_overlay.get_node("%RedrawBtn").pressed.connect(_on_mulligan_choice.bind(true))
	add_child(mulligan_overlay)
	for id in state.players[0].hand:
		var cw := CardWidget.create(state.card(id), 170.0 * minf(UiTheme.touch_scale(), 1.6))
		cw.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		mulligan_overlay.get_node("%CardRow").add_child(cw)


func _on_mulligan_choice(redraw: bool) -> void:
	if _online:
		_match.apply({ "type": "mulligan", "redraw": redraw })
		mulligan_overlay.queue_free()
		mulligan_overlay = null
		busy = true                    # wait for the server push (opponent + start)
		return
	_match.apply({ "type": "mulligan", "redraw": redraw })
	var res := _match.apply(ai.choose_action(state))  # AI mulligan → starts turn 1
	mulligan_overlay.queue_free()
	mulligan_overlay = null
	_log("La partie commence !")
	_refresh_all()
	busy = true
	await _play_events(res.events)
	busy = false
	_refresh_all()


# --- UI wiring (structure lives in battle.tscn) -----------------------------

func _init_ui() -> void:
	# Board cells laid over the painted arena tiles.
	for row in GameConst.BOARD_ROWS:
		for col in GameConst.BOARD_COLS:
			var cell := Vector2i(col, row)
			var widget: BoardCell = BOARD_CELL_SCENE.instantiate()
			widget.setup(cell)
			var rect := _cell_rect(cell)
			widget.position = rect.position
			widget.custom_minimum_size = rect.size
			widget.size = rect.size
			widget.clicked.connect(_on_cell_clicked)
			widget.inspect_requested.connect(_on_cell_inspect)
			board_area.add_child(widget)
			cells[cell] = widget

	# Numéros de rangée masqués (look épuré).
	for r in GameConst.BOARD_ROWS:
		get_node("RowMarker%d" % r).visible = false

	# Buttons.
	end_turn_btn.pressed.connect(func() -> void:
		_clear_selection()
		_submit({ "type": "end_turn" }))
	power_btn.pressed.connect(_on_power_pressed)
	evolve_btn.pressed.connect(_on_evolve_pressed)
	%BagBtn.pressed.connect(func() -> void:
		if state != null:
			CardPopup.open_master(self, state.players[0].master))
	%BookBtn.pressed.connect(func() -> void:
		%LogPanel.visible = not %LogPanel.visible)
	%GearBtn.pressed.connect(func() -> void: Game.goto("main_menu"))

	# Right-click a side panel = inspect that master.
	for side in 2:
		var panel: PanelContainer = player_panel if side == 0 else enemy_panel
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed \
					and ev.button_index == MOUSE_BUTTON_RIGHT and state != null:
				panel.accept_event()
				CardPopup.open_master(self, state.players[side].master))

	# Side-panel node references, one dictionary per side (used by _refresh_panels).
	enemy_info = { "portrait": %EnemyPortrait, "name": %EnemyName,
			"master": %EnemyMaster, "hp_bar": %EnemyHpBar, "hp": %EnemyHp,
			"stones": %EnemyStones, "hand": %EnemyHand,
			"hand_row": %EnemyHandRow, "deck": %EnemyDeck }
	player_info = { "portrait": %PlayerPortrait, "name": %PlayerName,
			"master": %PlayerMaster, "hp_bar": %PlayerHpBar, "hp": %PlayerHp,
			"stones": %PlayerStones, "hand": %PlayerHand,
			"hand_row": %PlayerHandRow, "deck": %PlayerDeck }

	# Fx above everything.
	move_child(fx_layer, -1)


## Screen rectangle of one board cell (délégué à la scène d'arène du thème).
func _cell_rect(cell: Vector2i) -> Rect2:
	return arena.cell_rect(cell)


# --- Refresh --------------------------------------------------------------

func _refresh_all() -> void:
	for cell in cells:
		cells[cell].render(state)
	_refresh_hand()
	_refresh_panels()
	_refresh_resources()
	_refresh_buttons()
	_clear_highlights()
	_apply_selection_highlights()


## Pierres en pips de gemmes + compteurs de deck (les deux joueurs).
func _refresh_resources() -> void:
	_fill_pips(%PlayerPips, state.players[0].stones)
	_fill_pips(%EnemyPips, state.players[1].stones)
	(%PlayerDeckCount as Label).text = str(state.players[0].deck.size())
	(%EnemyDeckCount as Label).text = str(state.players[1].deck.size())
	_fill_enemy_hand()


## Main adverse en dos de cartes (haut), jamais la face.
func _fill_enemy_hand() -> void:
	var row: HBoxContainer = %EnemyHandRow2
	for c in row.get_children():
		c.queue_free()
	var back := UiTheme.tex("res://assets/sprites/ui/card_back.png")
	if back == null:
		return
	for i in state.players[1].hand.size():
		var b := TextureRect.new()
		b.texture = back
		b.custom_minimum_size = Vector2(46, 66)
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(b)


func _fill_pips(box: BoxContainer, stones: int) -> void:
	for c in box.get_children():
		c.queue_free()
	var gem := UiTheme.tex(UiTheme.ICON_STONE)
	var vertical := box is VBoxContainer
	# A big readable count on top of the column, then the gems.
	var count := Label.new()
	count.text = str(stones)
	count.custom_minimum_size = Vector2(30, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 24)
	count.add_theme_color_override("font_color", Color("bfe3ff"))
	count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	count.add_theme_constant_override("outline_size", 6)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := UiTheme.title_font()
	if f != null:
		count.add_theme_font_override("font", f)
	box.add_child(count)
	# Vertical mana fills bottom-up: empty slots on top, filled crystals below.
	for i in GameConst.MAX_STONES:
		var filled := i >= GameConst.MAX_STONES - stones if vertical else i < stones
		var pip := TextureRect.new()
		pip.texture = gem
		# ponytail: pips capped at 1.5 — 14 stones × 33 px must fit the side rail.
		pip.custom_minimum_size = Vector2(22, 22) * minf(UiTheme.touch_scale(), 1.5)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if filled:
			pip.modulate = Color(1, 1, 1, 1)
		else:
			pip.modulate = Color(0.35, 0.4, 0.55, 0.32)
		box.add_child(pip)
	box.tooltip_text = "Pierres : %d / %d" % [stones, GameConst.MAX_STONES]


func _refresh_hand() -> void:
	for w in hand_widgets:
		w.queue_free()
	hand_widgets.clear()
	var hand := state.players[0].hand
	var count := hand.size()
	if count == 0:
		return
	# ponytail: hand magnification capped at 1.6 — full touch_scale (2.0) would
	# push 388px-tall cards past the bottom of a 1080px screen.
	var card_w := HAND_CARD_W * minf(UiTheme.touch_scale(), 1.6)
	var overlap := minf(card_w + 8.0, hand_area.size.x / count)
	var total := overlap * (count - 1) + card_w
	var start := (hand_area.size.x - total) / 2.0
	for i in count:
		# Full composed cards in hand, like the mockup reference screen.
		var w := CardWidget.create(state.card(hand[i]), card_w)
		w.position = Vector2(start + i * overlap, 6)
		var base_y := w.position.y
		w.pressed.connect(_on_hand_card_pressed.bind(i))
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			if _has_selection():
				_clear_selection()
			else:
				CardPopup.open(self, w2.def))
		w.mouse_entered.connect(_on_hand_hover.bind(w, i))
		w.set_selected(i == sel_hand)
		if i == sel_hand:
			w.position.y -= 24
		# Hovered cards rise above their neighbours.
		w.mouse_entered.connect(func() -> void:
			w.z_index = 10
			if not w.selected:
				create_tween().tween_property(w, "position:y", base_y - 22, 0.09))
		w.mouse_exited.connect(func() -> void:
			w.z_index = 0
			if not w.selected:
				create_tween().tween_property(w, "position:y", base_y, 0.12))
		hand_area.add_child(w)
		hand_widgets.append(w)


func _refresh_panels() -> void:
	var cfg := Game.battle_config
	var names := [Db.campaign.get("hero_name", "Vous"), String(cfg.opponent_name)]
	var portraits := [Db.portrait_path("milo"), Db.portrait_path(String(cfg.opponent_portrait))]
	var back_tex := UiTheme.tex("res://assets/sprites/ui/card_back.png")
	for side in 2:
		var info: Dictionary = player_info if side == 0 else enemy_info
		var p := state.players[side]
		info.portrait.texture = UiTheme.tex(portraits[side])
		info.name.text = names[side]
		info.master.text = "Maître : %s" % p.master.display_name
		info.hp_bar.max_value = p.master.hp
		info.hp_bar.value = maxi(p.master_hp, 0)
		info.hp.text = "%d / %d" % [maxi(p.master_hp, 0), p.master.hp]
		info.stones.text = "Pierres  %d / %d" % [p.stones, GameConst.MAX_STONES]
		info.hand.text = "Main  %d carte%s" % [p.hand.size(), "s" if p.hand.size() > 1 else ""]
		# (compteur de deck désormais géré par _refresh_resources ; %*Deck = piles TextureRect)
		var row: HBoxContainer = info.hand_row
		for child in row.get_children():
			child.queue_free()
		if back_tex != null:
			for i in mini(p.hand.size(), GameConst.HAND_LIMIT):
				var back := TextureRect.new()
				back.texture = back_tex
				back.custom_minimum_size = Vector2(26, 38) * UiTheme.touch_scale()
				back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				back.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(back)
	var p0 := state.players[0]
	power_btn.text = "✦ %s (%d)" % [p0.master.power_name, p0.master.power_cost]
	power_btn.tooltip_text = "%s\nPassif : %s" % [p0.master.power_desc, p0.master.passive_desc]


func _refresh_buttons() -> void:
	var my_turn := state.phase == GameState.Phase.MAIN and state.current == 0 and not busy
	end_turn_btn.disabled = not my_turn
	var p0 := state.players[0]
	power_btn.disabled = not my_turn or p0.power_used or p0.stones < p0.master.power_cost
	if p0.power_used:
		power_btn.tooltip_text = "Pouvoir déjà utilisé ce tour."
	elif p0.stones < p0.master.power_cost:
		power_btn.tooltip_text = "Il vous faut %d pierres (vous en avez %d)." \
				% [p0.master.power_cost, p0.stones]
	else:
		power_btn.tooltip_text = "%s\nPassif : %s" % [p0.master.power_desc, p0.master.passive_desc]
	turn_label.text = ""
	if state.phase == GameState.Phase.MAIN:
		turn_label.text = "Tour %d — %s" % [state.player_turn_count(),
				"Votre tour" if state.current == 0 else "Tour adverse…"]
	# « Actions restantes » : ce qu'il vous reste à jouer.
	if turn_info != null:
		var actable := 0
		for cell in state.board.monster_cells_of(0):
			if Rules._check_can_act(state, state.board.at(cell)) == "":
				actable += 1
		var playable := 0
		for id in p0.hand:
			var d := state.card(id)
			if d != null and d.cost <= p0.stones:
				playable += 1
		turn_info.text = "• Monstres pouvant agir : %d\n• Cartes jouables : %d\n• Pouvoir Maître : %s\n• Déplacer Maître : %s" % [
			actable, playable,
			"utilisé ✔" if p0.power_used else "1/1",
			"fait ✔" if p0.master_moved else "1/1"]
	_refresh_evolve_button()


func _refresh_evolve_button() -> void:
	evolve_btn.visible = false
	if busy or state.current != 0 or sel_cell == Vector2i(-1, -1):
		return
	var m := state.board.at(sel_cell)
	if m != null and m.owner_idx == 0 and m.can_evolve() \
			and state.players[0].stones >= m.def.evolve_cost:
		var evo := state.card(m.def.evolves_to)
		evolve_btn.text = "Évoluer en %s (%d pierres)" % [evo.display_name, m.def.evolve_cost]
		evolve_btn.visible = true
		evolve_btn.position = _cell_rect(sel_cell).position + Vector2(-30, -44)


func _clear_highlights() -> void:
	for cell in cells:
		cells[cell].set_highlight("")


func _apply_selection_highlights() -> void:
	if state.phase != GameState.Phase.MAIN or state.current != 0 or busy:
		return
	if sel_hand >= 0 and sel_hand < state.players[0].hand.size():
		var def := state.card(state.players[0].hand[sel_hand])
		if def.is_monster():
			for cell in state.board.summon_cells(0, state.players[0].master_col):
				cells[cell].set_highlight("summon")
		else:
			for cell in Rules._target_cells(state, def.target_kind()):
				cells[cell].set_highlight("target")
	elif sel_power:
		for cell in Rules._target_cells(state, state.players[0].master.power_target_kind()):
			cells[cell].set_highlight("target")
	elif sel_cell != Vector2i(-1, -1):
		var p0 := state.players[0]
		if sel_cell == Board.master_cell(0, p0.master_col):
			cells[sel_cell].set_highlight("selected")
			if not p0.master_moved:
				for col in Rules.legal_master_cols(state):
					cells[Vector2i(col, Board.back_row(0))].set_highlight("move")
		else:
			var m := state.board.at(sel_cell)
			if m != null and m.owner_idx == 0:
				cells[sel_cell].set_highlight("selected")
				if Rules._check_can_act(state, m) == "":
					for cell in Rules.legal_move_cells(state, sel_cell):
						cells[cell].set_highlight("move")
					for cell in Rules.legal_attack_targets(state, sel_cell):
						cells[cell].set_highlight("attack")


# --- Input ------------------------------------------------------------

func _has_selection() -> bool:
	return sel_hand >= 0 or sel_cell != Vector2i(-1, -1) or sel_power


func _clear_selection() -> void:
	sel_hand = -1
	sel_cell = Vector2i(-1, -1)
	sel_power = false
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_clear_selection()
	elif event.is_action_pressed("ui_cancel"):
		_clear_selection()


func _on_hand_hover(w: CardWidget, _i: int) -> void:
	_show_detail_card(w.def)


## True when player input is locked right now; shows the reason as a toast so
## ignored clicks never feel like a dead mouse.
func _input_locked() -> bool:
	if state == null or state.is_over():
		return true
	if state.phase == GameState.Phase.MULLIGAN:
		return true
	if busy:
		_toast("Un instant — résolution en cours…" if state.current == 0
				else "C'est le tour de l'adversaire.")
		return true
	if state.current != 0:
		_toast("C'est le tour de l'adversaire.")
		return true
	return false


func _on_hand_card_pressed(_w: CardWidget, i: int) -> void:
	if _input_locked():
		return
	var def := state.card(state.players[0].hand[i])
	_show_detail_card(def)
	if def.cost > state.players[0].stones:
		_toast("Pas assez de pierres (%d requises)." % def.cost)
		return
	sel_cell = Vector2i(-1, -1)
	sel_power = false
	if sel_hand == i:
		sel_hand = -1
	else:
		sel_hand = i
		if def.is_spell() and def.target_kind() == "":
			var idx := i
			sel_hand = -1
			_submit({ "type": "cast", "hand_index": idx })
			return
	_refresh_all()


## Right-click: cancels a pending selection first; otherwise inspects (works at
## any moment, even during the enemy turn).
func _on_cell_inspect(cell: Vector2i) -> void:
	if state == null:
		return
	if _has_selection():
		_clear_selection()
		return
	for side in 2:
		if Board.master_cell(side, state.players[side].master_col) == cell:
			CardPopup.open_master(self, state.players[side].master)
			return
	var m := state.board.at(cell)
	if m != null:
		CardPopup.open(self, m.def, m)


func _on_cell_clicked(cell: Vector2i) -> void:
	if _input_locked():
		return
	var mode: String = cells[cell].highlight
	# 1) Complete a pending action on a highlighted cell.
	if sel_hand >= 0 and mode == "summon":
		var idx := sel_hand
		sel_hand = -1
		_submit({ "type": "summon", "hand_index": idx, "cell": cell })
		return
	if sel_hand >= 0 and mode == "target":
		var idx := sel_hand
		sel_hand = -1
		_submit({ "type": "cast", "hand_index": idx, "target": cell })
		return
	if sel_power and mode == "target":
		sel_power = false
		_submit({ "type": "master_power", "target": cell })
		return
	if sel_cell != Vector2i(-1, -1):
		if mode == "move":
			var p0 := state.players[0]
			if sel_cell == Board.master_cell(0, p0.master_col):
				sel_cell = Vector2i(-1, -1)
				_submit({ "type": "master_move", "col": cell.x })
			else:
				var from := sel_cell
				sel_cell = Vector2i(-1, -1)
				_submit({ "type": "move", "from": from, "to": cell })
			return
		if mode == "attack":
			var from := sel_cell
			sel_cell = Vector2i(-1, -1)
			_submit({ "type": "attack", "from": from, "to": cell })
			return
	# 2) Otherwise (re)select.
	sel_hand = -1
	sel_power = false
	var m := state.board.at(cell)
	if m != null:
		_show_detail_monster(m)
		sel_cell = cell if m.owner_idx == 0 else Vector2i(-1, -1)
	elif cell == Board.master_cell(0, state.players[0].master_col):
		sel_cell = cell
	else:
		sel_cell = Vector2i(-1, -1)
	_refresh_all()


func _on_power_pressed() -> void:
	if _input_locked():
		return
	var kind := state.players[0].master.power_target_kind()
	if kind == "":
		_submit({ "type": "master_power" })
	else:
		sel_hand = -1
		sel_cell = Vector2i(-1, -1)
		sel_power = true
		_refresh_all()


func _on_evolve_pressed() -> void:
	if sel_cell == Vector2i(-1, -1):
		return
	var cell := sel_cell
	sel_cell = Vector2i(-1, -1)
	_submit({ "type": "evolve", "cell": cell })


# --- Action submission & AI ------------------------------------------------

func _submit(action: Dictionary) -> void:
	if busy or state.is_over():
		return
	if _online:
		if state.current != 0:
			return                        # not my turn (server would reject anyway)
		_match.apply(action)              # fire to the server; result via _on_remote_events
		busy = true
		_refresh_buttons()
		return
	var res := _match.apply(action)
	if not res.ok:
		_toast(res.error)
		return
	busy = true
	_refresh_buttons()
	await _play_events(res.events)
	busy = false
	_refresh_all()
	if state.is_over():
		_show_game_over()
		return
	if String(action.type) == "end_turn":
		await _ai_turn()


func _ai_turn() -> void:
	busy = true
	_refresh_all()
	await get_tree().create_timer(0.5).timeout
	var guard := 0
	while not state.is_over() and state.current == 1 and guard < 200:
		guard += 1
		var action := ai.choose_action(state)
		var res := _match.apply(action)
		if not res.ok:
			push_error("Action IA illégale : %s (%s)" % [action, res.error])
			res = _match.apply({ "type": "end_turn" })
		await _play_events(res.events)
		for cell in cells:
			cells[cell].render(state)
		_refresh_panels()
		await get_tree().create_timer(0.25).timeout
	busy = false
	_refresh_all()
	if state.is_over():
		_show_game_over()


# --- Event animation --------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()


func _play_events(events: Array) -> void:
	for ev in events:
		match String(ev.e):
			"summon":
				Audio.play_sfx("summon")
				_log("%s invoque %s." % [_pname(ev.player), _cname(ev.card_id)],
						_side_color(ev.player))
				for cell in cells:
					cells[cell].render(state)
				_pop(cells[ev.cell])
				BattleFx.burst(fx_layer, _cell_center(ev.cell) + Vector2(0, 40),
						Color(0.75, 0.7, 0.6), 12, 130.0, 220.0, 0.4)
				BattleFx.ring(fx_layer, _cell_center(ev.cell), UiTheme.GOLD, 70.0, 0.35)
				await _wait(0.25)
			"attack":
				Audio.play_sfx("attack")
				var attacker := state.board.at(ev.from)
				var from_c := _cell_center(ev.from)
				var to_c := _cell_center(ev.to)
				if attacker != null:
					match attacker.def.attack_type:
						GameConst.AttackType.MELEE:
							var lunge_tex := BoardCell.unit_tex(String(attacker.def.id))
							if lunge_tex == null:
								lunge_tex = UiTheme.tex(Db.card_art_path(attacker.def.id))
							BattleFx.lunge(fx_layer, from_c, to_c, lunge_tex)
							await _wait(0.14)  # impact lands mid-lunge
						GameConst.AttackType.RANGED:
							BattleFx.projectile(fx_layer, from_c, to_c, Color("ffd27d"))
							await _wait(0.24)
						GameConst.AttackType.MAGIC:
							BattleFx.projectile(fx_layer, from_c, to_c, Color("c09aff"))
							await _wait(0.24)
				else:
					await _wait(0.1)
			"damage":
				Audio.play_sfx("hit")
				BattleFx.burst(fx_layer, _cell_center(ev.cell), Color("ff6b5e"), 16, 220.0)
				_float_text(ev.cell, "-%d" % int(ev.amount), Color("ff6b5e"), 28)
				_shake(4.0)
				await _wait(0.32)
			"master_damage":
				Audio.play_sfx("master_hit")
				var mcell := Board.master_cell(int(ev.player),
						state.players[int(ev.player)].master_col)
				BattleFx.vignette(fx_layer, Color("d1341f"))
				BattleFx.burst(fx_layer, _cell_center(mcell), Color("ff3b30"), 26, 300.0)
				_float_text(mcell, "-%d" % int(ev.amount), Color("ff3b30"), 34)
				_shake(12.0)
				_refresh_panels()
				await _wait(0.45)
			"master_heal":
				var my_cell := Board.master_cell(int(ev.player),
						state.players[int(ev.player)].master_col)
				BattleFx.sparkles(fx_layer, _cell_center(my_cell), Color("7de07d"))
				_refresh_panels()
				await _wait(0.25)
			"heal":
				Audio.play_sfx("heal")
				if state.board.at(ev.cell) != null:
					BattleFx.sparkles(fx_layer, _cell_center(ev.cell), Color("7de07d"))
					_float_text(ev.cell, "+%d" % int(ev.amount), Color("7de07d"))
				await _wait(0.28)
			"death":
				Audio.play_sfx("death")
				kills[1 - int(ev.owner)] += 1
				_log("%s est détruit." % _cname(ev.card_id), Color("c9832f"))
				var death_tex := BoardCell.unit_tex(String(ev.card_id))
				if death_tex == null:
					death_tex = UiTheme.tex(Db.card_art_path(StringName(String(ev.card_id))))
				BattleFx.death(fx_layer, _cell_center(ev.cell), death_tex)
				await _wait(0.15)
				for cell in cells:
					cells[cell].render(state)
				await _wait(0.3)
			"shield_break":
				Audio.play_sfx("shield")
				BattleFx.ring(fx_layer, _cell_center(ev.cell), Color("7dd8ff"), 95.0, 0.4)
				BattleFx.burst(fx_layer, _cell_center(ev.cell), Color("7dd8ff"), 14, 190.0)
				_float_text(ev.cell, "Bouclier brisé !", Color("7dd8ff"), 19)
				await _wait(0.32)
			"shield":
				Audio.play_sfx("shield")
				BattleFx.ring(fx_layer, _cell_center(ev.cell), Color("7dd8ff"), 80.0, 0.45)
				_float_text(ev.cell, "Bouclier", Color("7dd8ff"), 19)
				await _wait(0.25)
			"riposte":
				BattleFx.burst(fx_layer, _cell_center(ev.to), Color("ffb27d"), 12, 170.0)
				_float_text(ev.to, "Riposte !", Color("ffb27d"), 19)
				await _wait(0.22)
			"xp":
				if bool(ev.leveled):
					Audio.play_sfx("levelup")
					BattleFx.ring(fx_layer, _cell_center(ev.cell), UiTheme.GOLD, 100.0, 0.5)
					BattleFx.sparkles(fx_layer, _cell_center(ev.cell), UiTheme.GOLD, 20)
					_float_text(ev.cell, "NIVEAU %d !" % int(ev.level), UiTheme.GOLD, 26)
					_log("%s passe niveau %d !" % [_cell_cname(ev.cell), int(ev.level)],
							UiTheme.GOLD)
					for cell in cells:
						cells[cell].render(state)
					_pop(cells[ev.cell])
					await _wait(0.4)
			"evolve":
				Audio.play_sfx("evolve")
				_log("%s évolue en %s !" % [_cname(ev.from_id), _cname(ev.to_id)],
						UiTheme.GOLD)
				BattleFx.flash_cell(fx_layer, _cell_center(ev.cell), Color(1, 1, 1, 0.9),
						cells[ev.cell].size, 0.5)
				BattleFx.ring(fx_layer, _cell_center(ev.cell), UiTheme.GOLD, 130.0, 0.55)
				BattleFx.sparkles(fx_layer, _cell_center(ev.cell), UiTheme.GOLD, 26)
				await _wait(0.25)
				for cell in cells:
					cells[cell].render(state)
				_pop(cells[ev.cell])
				_float_text(ev.cell, "ÉVOLUTION !", UiTheme.GOLD, 28)
				await _wait(0.45)
			"cast":
				Audio.play_sfx("cast")
				_log("%s lance %s." % [_pname(ev.player), _cname(ev.card_id)],
						_side_color(ev.player))
				var target = ev.get("target")
				if target is Vector2i:
					BattleFx.sparkles(fx_layer, _cell_center(target), Color("c09aff"), 18)
				await _show_spell_preview(ev.card_id)
			"power":
				Audio.play_sfx("cast")
				_log("%s utilise son pouvoir." % _pname(ev.player), _side_color(ev.player))
				var pm := state.players[int(ev.player)]
				var pcell := Board.master_cell(int(ev.player), pm.master_col)
				var gcol: Color = GameConst.GUILD_COLORS.get(pm.master.guild, UiTheme.ACCENT)
				BattleFx.flash_cell(fx_layer, _cell_center(pcell),
						Color(gcol.r, gcol.g, gcol.b, 0.5), cells[pcell].size, 0.45)
				BattleFx.ring(fx_layer, _cell_center(pcell), gcol, 125.0, 0.5)
				BattleFx.sparkles(fx_layer, _cell_center(pcell), gcol, 22)
				var ptarget = ev.get("target")
				if ptarget is Vector2i:
					BattleFx.sparkles(fx_layer, _cell_center(ptarget), UiTheme.ACCENT, 18)
				await _wait(0.35)
			"move":
				Audio.play_sfx("move")
				for cell in cells:
					cells[cell].render(state)
				_pop(cells[ev.to])
				await _wait(0.16)
			"master_move":
				Audio.play_sfx("move")
				for cell in cells:
					cells[cell].render(state)
				await _wait(0.2)
			"kill_reward":
				_log("%s gagne %d pierre(s) (kill)." % [_pname(ev.player), int(ev.amount)])
			"draw":
				_draw_anim(int(ev.player))
				await _wait(0.16)
			"turn_start":
				_refresh_panels()
				if int(ev.player) == 0:
					Audio.play_sfx("turn")
					BattleFx.banner(fx_layer, "À vous de jouer !", UiTheme.GOLD)
				else:
					BattleFx.banner(fx_layer, "Tour de %s" % _pname(1), UiTheme.DANGER)
				await _wait(0.45)
			"fatigue":
				Audio.play_sfx("master_hit")
				var fcell := Board.master_cell(int(ev.player),
						state.players[int(ev.player)].master_col)
				_float_text(fcell, "FATIGUE %d" % int(ev.amount), Color("c9a0ff"), 24)
				_log("%s n'a plus de cartes : fatigue %d !" % [_pname(ev.player), int(ev.amount)])
				await _wait(0.35)
			"deck_out":
				_log("%s n'a plus de cartes !" % _pname(ev.player))
			"win":
				pass
			_:
				pass


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(node: Control, color: Color) -> void:
	var prev := node.modulate
	node.modulate = color
	var tw := create_tween()
	tw.tween_property(node, "modulate", prev, 0.3)


func _shake(intensity: float = 6.0) -> void:
	var tw := create_tween()
	var origin := position
	for i in 5:
		tw.tween_property(self, "position", origin + Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity * 0.75, intensity * 0.75)), 0.04)
	tw.tween_property(self, "position", origin, 0.05)


func _float_text(cell: Vector2i, text: String, color: Color, size: int = 22) -> void:
	var l := UiTheme.label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.position = _cell_center(cell) + Vector2(-40, -18)
	l.pivot_offset = Vector2(50, 12)
	l.scale = Vector2(1.7, 1.7)
	fx_layer.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 66, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(l.queue_free)


func _show_spell_preview(card_id) -> void:
	var def := state.card(card_id)
	if def == null:
		return
	var w := CardWidget.create(def, 220)
	w.position = Vector2(850, 300)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(w)
	UiTheme.pass_through(w)
	_pop(w)
	await _wait(0.55)
	var tw := create_tween()
	tw.tween_property(w, "modulate:a", 0.0, 0.25)
	await tw.finished
	w.queue_free()


## Carte (dos) qui jaillit du deck vers la main (joueur bas / adversaire haut).
func _draw_anim(player: int) -> void:
	var back := UiTheme.tex("res://assets/sprites/ui/card_back.png")
	if back == null:
		return
	var deck: Control = %PlayerDeck if player == 0 else %EnemyDeck
	var from: Vector2 = deck.global_position + deck.size / 2.0
	var to := Vector2(960, 980) if player == 0 else Vector2(960, 70)
	var csize := Vector2(154, 216)
	var card := TextureRect.new()
	card.texture = back
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	card.custom_minimum_size = csize
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(card)
	# Forcer la taille APRÈS l'ajout (sinon la TextureRect prend la taille native de la texture).
	card.size = csize
	card.pivot_offset = csize / 2.0
	card.position = from - csize / 2.0
	# Face révélée (joueur seulement ; l'adversaire garde le dos).
	var face: Texture2D = null
	if player == 0 and not state.players[0].hand.is_empty():
		var id = state.players[0].hand[-1]
		face = UiTheme.tex(CardWidget.full_card_path(id))
		if face == null:
			face = UiTheme.tex(Db.card_art_path(StringName(String(id))))
	var tw := create_tween()
	if player == 0 and face != null:
		# Monte au centre → se retourne pour révéler → marque un temps → descend dans la main.
		var center := Vector2(960, 470)
		tw.tween_property(card, "position", center - csize / 2.0, 0.4) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale:x", 0.0, 0.16)
		tw.tween_callback(func() -> void: card.texture = face)
		tw.tween_property(card, "scale:x", 1.0, 0.16)
		tw.tween_interval(0.55)
		tw.tween_property(card, "position", to - csize / 2.0, 0.4) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "scale", Vector2(0.5, 0.5), 0.4)
		tw.parallel().tween_property(card, "modulate:a", 0.0, 0.4)
		tw.tween_callback(card.queue_free)
	else:
		# Adversaire : simple montée du deck vers sa main, en dos.
		tw.tween_property(card, "position", to - csize / 2.0, 0.4) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 0.0, 0.18)
		tw.tween_callback(card.queue_free)


# --- Detail panel / log / toast ---------------------------------------------

func _show_detail_card(def: CardDef) -> void:
	_clear_detail()
	var w := CardWidget.create(def, 250)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(w)
	_add_detail_text(_keyword_explanations(def))


func _show_detail_monster(m: MonsterInst) -> void:
	_clear_detail()
	var w := CardWidget.create(m.def, 250)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(w)
	var status := "Niv %d — ATQ %d, PV %d/%d" % [m.level, m.atk(), m.hp, m.max_hp()]
	if not m.at_max_level():
		status += "\nXP %d / %d" % [m.xp, m.next_level_xp()]
	if m.shield:
		status += "\nBouclier actif"
	var l := UiTheme.label(status, 17, UiTheme.TEXT)
	detail_holder.add_child(l)
	_add_detail_text(_keyword_explanations(m.def))


func _keyword_explanations(def: CardDef) -> String:
	var lines: PackedStringArray = []
	if def.is_monster():
		lines.append("%s : %s." % [GameText.ATTACK_TYPE_NAMES[def.attack_type],
				GameText.ATTACK_TYPE_DEFS[def.attack_type]])
		for kw in def.keywords:
			lines.append("%s : %s." % [GameText.KEYWORD_NAMES.get(String(kw), String(kw)),
					GameText.KEYWORD_DEFS.get(String(kw), "")])
	return "\n".join(lines)


func _add_detail_text(text: String) -> void:
	if text == "":
		return
	var info := UiTheme.label(text, 16, UiTheme.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(260.0 * minf(UiTheme.touch_scale(), 1.3), 0)
	detail_holder.add_child(info)


func _clear_detail() -> void:
	for child in detail_holder.get_children():
		child.queue_free()


## Colored battle-log line. Default: dim; pass a side (0/1) tinted color or
## a semantic color (gold for level-ups, etc.) from the call site.
func _log(text: String, color: Color = UiTheme.TEXT_DIM) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = text
	var icon_path := _log_icon(text)
	if icon_path != "":
		var ic := TextureRect.new()
		ic.texture = UiTheme.tex(icon_path)
		ic.custom_minimum_size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var l := UiTheme.label(text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	log_box.add_child(row)
	while log_box.get_child_count() > 16:
		log_box.get_child(0).free()
	var scroll := log_box.get_parent() as ScrollContainer
	if scroll != null:
		scroll.set_deferred("scroll_vertical", 100000)


## Icône de type déduite du texte (jeu d'icônes limité → best-effort).
func _log_icon(text: String) -> String:
	const P := "res://assets/sprites/ui/pixel/"
	if "invoque" in text:
		return P + "icon_stat_shield.png"
	if "détruit" in text or "fatigue" in text:
		return P + "res_shadow.png"
	if "niveau" in text or "évolue" in text or "pouvoir" in text:
		return P + "ind_light.png"
	if "lance" in text:
		return P + "ind_shadow.png"
	if "pierre" in text:
		return P + "res_crystal.png"
	if "attaque" in text or "inflige" in text:
		return P + "ind_attack.png"
	if "soigne" in text or "PV" in text:
		return P + "ind_heal.png"
	return ""


## Log color for actions of one side: green for the player, red for the enemy.
func _side_color(player) -> Color:
	return Color("9fd18a") if int(player) == 0 else Color("e0938a")


func _pname(player) -> String:
	if int(player) == 0:
		return String(Db.campaign.get("hero_name", "Vous"))
	return String(Game.battle_config.opponent_name)


func _cname(card_id) -> String:
	var def := state.card(StringName(String(card_id)))
	return def.display_name if def != null else String(card_id)


func _cell_cname(cell: Vector2i) -> String:
	var m := state.board.at(cell)
	return m.def.display_name if m != null else "?"


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 0.0, 1.6).set_delay(0.6)


# --- Game over ---------------------------------------------------------------

func _show_game_over() -> void:
	var won := state.winner == 0
	Game.last_battle_won = won
	# Ranked match → update the local MMR (Glicko-2). Opponent rating is neutral
	# here; a hosted backend would exchange the real rating via the server.
	if bool(Game.battle_config.get("ranked", false)):
		LocalBackend.new().report_result(1.0 if won else 0.0,
				{ "rating": 1500.0, "rd": 200.0 })
	var end_shot := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--end-shot="):
			end_shot = String(arg).split("=", true, 1)[1]
	if autoplay and end_shot == "":
		print("[autoplay] partie terminée — vainqueur : joueur %d, demi-tours : %d"
				% [state.winner, state.turn])
		get_tree().quit(0)
		return
	if autoplay:
		Engine.time_scale = 1.0
	Audio.play_sfx("win" if won else "lose")
	Audio.stop_music()

	var overlay: Control = GAME_OVER_SCENE.instantiate()
	add_child(overlay)

	# Background art fading in.
	var art: TextureRect = overlay.get_node("%Art")
	art.texture = UiTheme.tex(UiTheme.TEX_VICTORY if won else UiTheme.TEX_DEFEAT)
	art.modulate.a = 0.0
	create_tween().tween_property(art, "modulate:a", 1.0, 0.8)

	if won:
		# Golden confetti raining from the top.
		var confetti := CPUParticles2D.new()
		confetti.position = Vector2(960, -30)
		confetti.amount = 90
		confetti.lifetime = 5.0
		confetti.preprocess = 2.0
		confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		confetti.emission_rect_extents = Vector2(980, 10)
		confetti.direction = Vector2.DOWN
		confetti.spread = 20.0
		confetti.gravity = Vector2(0, 140)
		confetti.initial_velocity_min = 60.0
		confetti.initial_velocity_max = 190.0
		confetti.scale_amount_min = 2.5
		confetti.scale_amount_max = 6.0
		confetti.color = UiTheme.GOLD
		confetti.hue_variation_min = -0.12
		confetti.hue_variation_max = 0.12
		overlay.add_child(confetti)

	# Title with a punch-in.
	var title: Label = overlay.get_node("%Title")
	title.text = "VICTOIRE" if won else "DÉFAITE"
	title.add_theme_color_override("font_color", UiTheme.GOLD if won else Color("d96a6a"))
	title.scale = Vector2(1.8, 1.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(title, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3)
	tw.tween_property(title, "modulate:a", 1.0, 0.3).set_delay(0.3)

	# Sub-line + battle stats.
	var sub := ""
	if state.winner == -2:
		sub = "Égalité — limite de tours atteinte."
	elif won:
		sub = "Le Maître adverse est vaincu !"
	else:
		sub = "Votre Maître est tombé…"
	sub += "\nTours joués : %d      Monstres vaincus : %d      Monstres perdus : %d" \
			% [state.player_turn_count(), int(kills[0]), int(kills[1])]
	var sub_l: Label = overlay.get_node("%SubText")
	sub_l.text = sub
	create_tween().tween_property(sub_l, "modulate:a", 1.0, 0.4).set_delay(0.7)

	var buttons: HBoxContainer = overlay.get_node("%Buttons")
	if autoplay and end_shot != "":
		await _wait(1.8)
		var img := get_viewport().get_texture().get_image()
		img.save_png(end_shot)
		print("[end-shot] %s" % end_shot)
		get_tree().quit(0)
		return
	var is_campaign: bool = String(Game.battle_config.get("mode", "free")) == "campaign"
	if is_campaign:
		if won:
			_add_btn(buttons, "Continuer", false, func() -> void:
				Game.dialogue_phase = "post"
				Game.goto("dialogue"))
		else:
			_add_btn(buttons, "Réessayer", false, func() -> void:
				Game.goto("battle"))
			_add_btn(buttons, "Retour à la carte", true, func() -> void:
				Game.goto("campaign"))
	else:
		_add_btn(buttons, "Rejouer", false, func() -> void:
			Game.goto("battle"))
		_add_btn(buttons, "Menu principal", true, func() -> void:
			Game.goto("main_menu"))


func _add_btn(parent: Control, text: String, secondary: bool, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 54)
	if secondary:
		b.theme_type_variation = &"ButtonSecondary"
	b.pressed.connect(action)
	parent.add_child(b)
