extends Control
## Battle scene controller. The UI structure lives in battle.tscn (panels,
## arena, buttons — see CLAUDE.md); this script only owns the match logic:
## it renders GameState into the scene nodes, translates clicks into Rules
## actions and animates the returned events.
## The human is always player 0; the AI is player 1.

const BOARD_CELL_SCENE: PackedScene = preload("res://scenes/widgets/board_cell.tscn")

const HAND_CARD_W := 118.0
## Horizontal center of the board (hand, toasts and banners align on it).
const BOARD_CENTER_X := 960.0

@onready var arena: BattleArena = %Arena
@onready var board_area: Control = %BoardArea
@onready var hand_area: Control = %HandArea
@onready var fx_layer: Control = %FxLayer
@onready var log_box: RichTextLabel = %LogText
@onready var detail_holder: VBoxContainer = %DetailHolder
@onready var toast_label: Label = %ToastLabel
@onready var turn_label: Label = %TurnLabel
@onready var turn_info: Label = %TurnInfo
@onready var end_turn_btn: Button = %EndTurnBtn
@onready var power_btn: Button = %PowerBtn
@onready var evolve_btn: Button = %EvolveBtn
@onready var legend_panel: PanelContainer = %LegendPanel
@onready var legend_box: VBoxContainer = %LegendBox
@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var player_panel: PanelContainer = %PlayerPanel

var state: GameState
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
	elif state.current == 1 and stuck_ms > 20000:
		# The AI coroutine died mid-turn: recover by force-ending its turn.
		push_warning("Watchdog : tour IA interrompu, fin de tour forcée.")
		Rules.apply(state, { "type": "end_turn" })
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
	var m0: MasterDef = Db.master(StringName(String(Game.profile.active_master)))
	var m1: MasterDef = Db.master(StringName(String(cfg.opponent_master)))
	state = Rules.setup(Db.cards, [m0, m1],
			[Game.profile.deck, cfg.opponent_deck], randi())
	ai = AiPlayer.new(int(cfg.ai_level), randi())
	_refresh_all()
	_show_mulligan()


func _show_mulligan() -> void:
	mulligan_overlay = _overlay()
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var title := UiTheme.title_label("Main de départ", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	for id in state.players[0].hand:
		var cw := CardWidget.create(state.card(id), 170)
		cw.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		row.add_child(cw)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	vbox.add_child(buttons)
	var keep := Button.new()
	keep.text = "Garder"
	keep.custom_minimum_size = Vector2(180, 48)
	keep.pressed.connect(_on_mulligan_choice.bind(false))
	buttons.add_child(keep)
	var redraw := Button.new()
	redraw.text = "Nouvelle main"
	redraw.theme_type_variation = &"ButtonSecondary"
	redraw.custom_minimum_size = Vector2(180, 48)
	redraw.pressed.connect(_on_mulligan_choice.bind(true))
	buttons.add_child(redraw)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	mulligan_overlay.add_child(center)


func _on_mulligan_choice(redraw: bool) -> void:
	Rules.apply(state, { "type": "mulligan", "redraw": redraw })
	var res := Rules.apply(state, ai.choose_action(state))  # AI mulligan → starts turn 1
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

	# Numéros de rangée alignés sur la grille du thème courant.
	for r in GameConst.BOARD_ROWS:
		var marker: TextureRect = get_node("RowMarker%d" % r)
		var rect := _cell_rect(Vector2i(0, r))
		marker.position = Vector2(rect.position.x - 44, rect.get_center().y - 17)

	# Buttons.
	end_turn_btn.pressed.connect(func() -> void: _submit({ "type": "end_turn" }))
	power_btn.pressed.connect(_on_power_pressed)
	evolve_btn.pressed.connect(_on_evolve_pressed)
	%BagBtn.pressed.connect(func() -> void:
		if state != null:
			CardPopup.open_master(self, state.players[0].master))
	%BookBtn.pressed.connect(func() -> void:
		legend_panel.visible = not legend_panel.visible)
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

	# Keyword legend content (data-driven from GameText).
	legend_box.add_child(UiTheme.title_label("Mots-clés", 18))
	for kw in GameText.KEYWORD_NAMES:
		var line := UiTheme.label("%s : %s." % [GameText.KEYWORD_NAMES[kw],
				GameText.KEYWORD_DEFS.get(kw, "")], 14, UiTheme.TEXT_DIM)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		legend_box.add_child(line)
	legend_box.add_child(UiTheme.label(
			"Mêlée : sa colonne · Distance : partout · Magie : ignore Armure/Bouclier",
			14, UiTheme.GOLD.lightened(0.15)))

	# Fx above everything.
	move_child(fx_layer, -1)


## Screen rectangle of one board cell (délégué à la scène d'arène du thème).
func _cell_rect(cell: Vector2i) -> Rect2:
	return arena.cell_rect(cell)


## Radial darkness for full-screen overlays (game over).
func _add_vignette(parent: Control, strength: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, strength))
	grad.add_point(0.62, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, -0.15)
	gt.width = 512
	gt.height = 288
	var rect := TextureRect.new()
	rect.texture = gt
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)


func _overlay() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	add_child(layer)
	return layer


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


func _fill_pips(box: HBoxContainer, stones: int) -> void:
	for c in box.get_children():
		c.queue_free()
	var gem := UiTheme.tex(UiTheme.ICON_STONE)
	for i in GameConst.MAX_STONES:
		var pip := TextureRect.new()
		pip.texture = gem
		pip.custom_minimum_size = Vector2(18, 18)
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.modulate = Color(1, 1, 1, 1) if i < stones else Color(0.28, 0.31, 0.42, 0.5)
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
	var overlap := minf(HAND_CARD_W + 8.0, hand_area.size.x / count)
	var total := overlap * (count - 1) + HAND_CARD_W
	var start := (hand_area.size.x - total) / 2.0
	for i in count:
		# Full composed cards in hand, like the mockup reference screen.
		var w := CardWidget.create(state.card(hand[i]), HAND_CARD_W)
		w.position = Vector2(start + i * overlap, 8)
		var base_y := w.position.y
		w.pressed.connect(_on_hand_card_pressed.bind(i))
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
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
		info.deck.text = "Deck  %d cartes" % p.deck.size()
		var row: HBoxContainer = info.hand_row
		for child in row.get_children():
			child.queue_free()
		if back_tex != null:
			for i in mini(p.hand.size(), GameConst.HAND_LIMIT):
				var back := TextureRect.new()
				back.texture = back_tex
				back.custom_minimum_size = Vector2(26, 38)
				back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				back.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(back)
	var p0 := state.players[0]
	power_btn.text = "%s (%d)" % [p0.master.power_name, p0.master.power_cost]
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


## Right-click inspection: works at any moment, even during the enemy turn.
func _on_cell_inspect(cell: Vector2i) -> void:
	if state == null:
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
	var res := Rules.apply(state, action)
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
		var res := Rules.apply(state, action)
		if not res.ok:
			push_error("Action IA illégale : %s (%s)" % [action, res.error])
			res = Rules.apply(state, { "type": "end_turn" })
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
				var ptarget = ev.get("target")
				if ptarget is Vector2i:
					BattleFx.sparkles(fx_layer, _cell_center(ptarget), UiTheme.ACCENT, 18)
				await _wait(0.3)
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


# --- Detail panel / log / toast ---------------------------------------------

func _show_detail_card(def: CardDef) -> void:
	_clear_detail()
	var w := CardWidget.create(def, 210)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(w)
	_add_detail_text(_keyword_explanations(def))


func _show_detail_monster(m: MonsterInst) -> void:
	_clear_detail()
	var w := CardWidget.create(m.def, 210)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(w)
	var status := "Niv %d — ATQ %d, PV %d/%d" % [m.level, m.atk(), m.hp, m.max_hp()]
	if not m.at_max_level():
		status += "\nXP %d / %d" % [m.xp, m.next_level_xp()]
	if m.shield:
		status += "\nBouclier actif"
	var l := UiTheme.label(status, 15, UiTheme.TEXT)
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
	var info := UiTheme.label(text, 13, UiTheme.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(240, 0)
	detail_holder.add_child(info)


func _clear_detail() -> void:
	for child in detail_holder.get_children():
		child.queue_free()


## Colored battle-log line. Default: dim; pass a side (0/1) tinted color or
## a semantic color (gold for level-ups, etc.) from the call site.
func _log(text: String, color: Color = UiTheme.TEXT_DIM) -> void:
	log_box.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


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
	var overlay := _overlay()
	# Full-screen illustrated backdrop, fading in.
	var art := TextureRect.new()
	art.texture = UiTheme.tex(UiTheme.TEX_VICTORY if won else UiTheme.TEX_DEFEAT)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate.a = 0.0
	overlay.add_child(art)
	create_tween().tween_property(art, "modulate:a", 1.0, 0.8)
	_add_vignette(overlay, 0.6)
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
	# Big display title with a punch-in.
	var title := UiTheme.title_label("VICTOIRE" if won else "DÉFAITE", 120,
			UiTheme.GOLD if won else Color("d96a6a"))
	var display := UiTheme.display_font()
	if display != null:
		title.add_theme_font_override("font", display)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 260
	title.pivot_offset = Vector2(960, 80)
	title.scale = Vector2(1.8, 1.8)
	title.modulate.a = 0.0
	overlay.add_child(title)
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
	var sub_l := UiTheme.label(sub, 20, UiTheme.TEXT)
	sub_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub_l.add_theme_constant_override("outline_size", 8)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub_l.offset_top = 460
	sub_l.modulate.a = 0.0
	overlay.add_child(sub_l)
	create_tween().tween_property(sub_l, "modulate:a", 1.0, 0.4).set_delay(0.7)
	# Actions.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	buttons.set_anchors_preset(Control.PRESET_TOP_WIDE)
	buttons.offset_top = 620
	overlay.add_child(buttons)
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
