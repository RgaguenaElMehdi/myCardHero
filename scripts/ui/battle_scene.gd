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
# Stats du combat pour l'écran de fin.
var _stat_start_ms := 0
var _stat_cards := 0
var _stat_summons := 0
## PV de départ des Maîtres (max des barres de vie — un défi peut les modifier).
var _start_hp := [0, 0]

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
	_init_tutorial()
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


# --- Tutoriel guidé (chapitres « Académie ») -------------------------------
# Étapes déclarées dans campaign.json (chapter.tutorial : [{text, until}]) :
# le panneau avance quand le joueur réalise l'action attendue.

const TUTORIAL_PANEL: PackedScene = preload("res://scenes/widgets/tutorial_panel.tscn")

var _tuto_steps: Array = []
var _tuto_i := 0
var _tuto_panel: Control
## Leçon scriptée (chapter.mission dans campaign.json) : main forcée,
## adversaire passif, la partie se gagne en atteignant l'objectif.
var _mission: Dictionary = {}
var _mission_done := false


func _init_tutorial() -> void:
	if autoplay or not bool(Game.profile.settings.get("tutorials", true)):
		return
	var idx := int(Game.battle_config.get("chapter", -1))
	if idx < 0:
		return
	_tuto_steps = Db.chapter(idx).get("tutorial", [])
	if _tuto_steps.is_empty():
		return
	_tuto_panel = TUTORIAL_PANEL.instantiate()
	add_child(_tuto_panel)
	(_tuto_panel.get_node("%TutoClose") as Button).pressed.connect(_end_tutorial)
	# Étapes de présentation (until == "next") : on avance avec le bouton.
	(_tuto_panel.get_node("%TutoNext") as Button).pressed.connect(func() -> void:
		UiTheme._click_sfx()
		_tuto_i += 1
		_show_tuto_step())
	_show_tuto_step()


func _show_tuto_step() -> void:
	if _tuto_panel == null:
		return
	if _tuto_i >= _tuto_steps.size():
		_end_tutorial()
		return
	(_tuto_panel.get_node("%TutoStep") as Label).text = \
			"✦  TUTORIEL — %d/%d  ✦" % [_tuto_i + 1, _tuto_steps.size()]
	(_tuto_panel.get_node("%TutoText") as Label).text = \
			String(_tuto_steps[_tuto_i].get("text", ""))
	(_tuto_panel.get_node("%TutoNext") as Button).visible = \
			String(_tuto_steps[_tuto_i].get("until", "")) == "next"


func _end_tutorial() -> void:
	if _tuto_panel != null:
		_tuto_panel.queue_free()
		_tuto_panel = null
	_tuto_steps = []


## Signale une action du joueur ; « play » accepte invocation ET sort.
func _tuto_notify(event: String) -> void:
	if _tuto_panel == null or _tuto_i >= _tuto_steps.size():
		return
	var until := String(_tuto_steps[_tuto_i].get("until", ""))
	if until == event or (until == "play" and (event == "summon" or event == "cast")):
		_tuto_i += 1
		_show_tuto_step()


# --- Match setup ---------------------------------------------------------

func _setup_match() -> void:
	_stat_start_ms = Time.get_ticks_msec()
	var cfg := Game.battle_config
	if String(cfg.get("mode", "")) == "online":
		_setup_online()
		return
	var my_deck := Game.active_deck()
	_mission = Db.chapter(int(cfg.get("chapter", -1))).get("mission", {}) \
			if int(cfg.get("chapter", -1)) >= 0 else {}
	var player_deck: Array = _mission.get("player_deck", my_deck.cards)
	if cfg.has("player_deck"):
		player_deck = cfg.player_deck        # deck imposé par un défi
	var m0: MasterDef = Db.master(StringName(String(my_deck.master)))
	var m1: MasterDef = Db.master(StringName(String(cfg.opponent_master)))
	# Tirage au sort du premier joueur (équité) ; les tutoriels gardent le joueur
	# en premier. Le second joueur est compensé (le starter saute sa 1ʳᵉ pioche).
	var first := 0 if not _mission.is_empty() else randi() % 2
	state = _match.setup(Db.cards, [m0, m1],
			[player_deck, cfg.opponent_deck], randi(), first)
	ai = AiPlayer.new(int(cfg.ai_level), randi())
	# Modificateurs de règles d'un défi : PV de départ des Maîtres.
	var mod: Dictionary = cfg.get("challenge", {}).get("mod", {})
	if mod.has("player_hp"):
		state.players[0].master_hp = int(mod.player_hp)
	if mod.has("opponent_hp"):
		state.players[1].master_hp = int(mod.opponent_hp)
	_start_hp = [state.players[0].master_hp, state.players[1].master_hp]
	if _mission.is_empty():
		_refresh_all()
		_show_mulligan()
		return
	# Leçon scriptée : pas de mulligan, main et plateau imposés.
	_match.apply({ "type": "mulligan", "redraw": false })
	_match.apply(ai.choose_action(state))
	_apply_mission_setup()
	_refresh_all()


## Impose la main du joueur et les monstres pré-placés d'une leçon.
func _apply_mission_setup() -> void:
	var p: PlayerState = state.players[0]
	var want: Array = _mission.get("hand", [])
	for i in mini(want.size(), p.hand.size()):
		var id := StringName(String(want[i]))
		if String(p.hand[i]) == String(id):
			continue
		var di := -1
		for j in p.deck.size():
			if String(p.deck[j]) == String(id):
				di = j
				break
		if di >= 0:
			p.deck[di] = p.hand[i]
			p.hand[i] = id
	for entry in _mission.get("board", []):
		var side := int(entry.get("side", 0))
		var def := Db.card(StringName(String(entry.get("card", ""))))
		if def == null:
			continue
		var row: int = Board.front_row(side) \
				if String(entry.get("row", "front")) == "front" else Board.back_row(side)
		var cell := Vector2i(int(entry.get("col", 0)), row)
		var mcell := Board.master_cell(side, state.players[side].master_col)
		if cell != mcell and state.board.at(cell) == null:
			# turn -1 : pas de mal d'invocation, le monstre peut agir tout de suite
			state.board.place(cell, MonsterInst.create(def, side, -1))


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
	var res := _match.apply(ai.choose_action(state))  # AI mulligan → main phase starts
	mulligan_overlay.queue_free()
	mulligan_overlay = null
	_log("La partie commence !")
	_refresh_all()
	busy = true
	await _play_events(res.events)
	busy = false
	_refresh_all()
	if state.is_over():
		_show_game_over()
		return
	if state.current == 1:              # l'adversaire a gagné le tirage : il ouvre
		_log("L'adversaire commence.")
		await _ai_turn()


# --- UI wiring (structure lives in battle.tscn) -----------------------------

func _init_ui() -> void:
	# Board cells laid over the painted arena tiles.
	for row in GameConst.BOARD_ROWS:
		for col in GameConst.BOARD_COLS:
			var cell := Vector2i(col, row)
			var widget: BoardCell = BOARD_CELL_SCENE.instantiate()
			widget.setup(cell)
			widget.clicked.connect(_on_cell_clicked)
			widget.inspect_requested.connect(_on_cell_inspect)
			board_area.add_child(widget)
			cells[cell] = widget
	_layout_cells()
	# La grille suit le plateau peint quelle que soit la taille de fenêtre.
	arena.resized.connect(_layout_cells)

	# Numéros de rangée masqués (look épuré) — absents des arènes récentes.
	for r in GameConst.BOARD_ROWS:
		var marker := get_node_or_null("RowMarker%d" % r)
		if marker != null:
			marker.visible = false

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
	(%AbandonBtn as Button).pressed.connect(_on_abandon)
	(%AbandonBtn as Button).pressed.connect(UiTheme._click_sfx)

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


## (Re)pose chaque case sur le plateau peint ; rappelé quand l'arène change
## de taille pour que la grille reste collée au décor.
func _layout_cells() -> void:
	for cell in cells:
		var rect := _cell_rect(cell)
		cells[cell].position = rect.position
		cells[cell].size = rect.size
	if state != null:
		for cell in cells:
			cells[cell].render(state)


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
	var back := UiTheme.tex("res://assets/sprites/ui/gold/card_back_red.png")
	if back == null:
		back = UiTheme.tex("res://assets/sprites/ui/card_back.png")
	if back == null:
		return
	for i in state.players[1].hand.size():
		var b := TextureRect.new()
		b.texture = back
		b.custom_minimum_size = Vector2(64, 90)
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
	# ponytail: hand magnification capped at 1.35 — the gold layout tucks the
	# hand under the board, taller cards would run off the bottom edge.
	var card_w := HAND_CARD_W * minf(UiTheme.touch_scale(), 1.1)
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
		# Leçon : la carte à jouer clignote en doré (mission.highlight, ou la
		# carte de l'objectif d'invocation).
		var hi := String(_mission.get("highlight", ""))
		if hi == "" and String(_mission.get("goal", {}).get("type", "")) == "summon":
			hi = String(_mission.goal.get("card", ""))
		if not _mission_done and hi != "" and String(hand[i]) == hi:
			var tw := w.create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(w, "modulate", Color(1.45, 1.3, 0.9), 0.5)
			tw.tween_property(w, "modulate", Color.WHITE, 0.5)


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
		var hp_max: int = maxi(int(_start_hp[side]), p.master.hp) \
				if int(_start_hp[side]) > 0 else p.master.hp
		info.hp_bar.max_value = hp_max
		info.hp_bar.value = maxi(p.master_hp, 0)
		info.hp.text = "%d / %d" % [maxi(p.master_hp, 0), hp_max]
		info.stones.text = "%d / %d" % [p.stones, GameConst.MAX_STONES]
		# Barre d'énergie (scènes or) — optionnelle, les anciennes scènes n'en ont pas.
		var ebar := get_node_or_null("%EnemyEnergyBar" if side == 1 else "%PlayerEnergyBar")
		if ebar != null:
			(ebar as ProgressBar).max_value = GameConst.MAX_STONES
			(ebar as ProgressBar).value = p.stones
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
	(%PowerName as Label).text = "✦ %s (%d)" % [p0.master.power_name, p0.master.power_cost]
	(%PowerDesc as Label).text = "%s\nPassif : %s" \
			% [p0.master.power_desc, p0.master.passive_desc]


func _refresh_buttons() -> void:
	var my_turn := state.phase == GameState.Phase.MAIN and state.current == 0 and not busy
	end_turn_btn.disabled = not my_turn
	var p0 := state.players[0]
	power_btn.disabled = not my_turn or p0.power_used or p0.stones < p0.master.power_cost
	_pulse_power(not power_btn.disabled)
	_pulse_end_turn(my_turn)
	# Le petit texte sous le nom explique le pouvoir (ou pourquoi il est
	# bloqué) ; le passif, toujours actif, reste affiché dessous.
	var power_line := p0.master.power_desc
	if p0.power_used:
		power_line = "Déjà utilisé ce tour."
	elif p0.stones < p0.master.power_cost:
		power_line = "Il vous faut %d pierres (vous en avez %d)." \
				% [p0.master.power_cost, p0.stones]
	(%PowerDesc as Label).text = "%s\nPassif : %s" % [power_line, p0.master.passive_desc]
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
		_tuto_notify("select_hand")
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
	_tuto_notify(String(action.get("type", "")))
	if String(action.get("type", "")) == "master_power":
		Game.quest_bump("powers")          # quête quotidienne « compétences »
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
	match String(action.type):
		"summon":
			_stat_cards += 1
			_stat_summons += 1
		"cast":
			_stat_cards += 1
	busy = true
	_refresh_buttons()
	await _play_events(res.events)
	busy = false
	_refresh_all()
	if state.is_over():
		_show_game_over()
		return
	if _check_mission_goal(action):
		return
	if String(action.type) == "end_turn":
		await _ai_turn()


## Leçon : l'objectif atteint termine la partie sur une victoire.
func _check_mission_goal(action: Dictionary) -> bool:
	if _mission.is_empty() or _mission_done:
		return false
	var goal: Dictionary = _mission.get("goal", {})
	var kind := String(action.get("type", ""))
	var hit := false
	match String(goal.get("type", "")):
		"summon":
			var card := String(goal.get("card", ""))
			for cell in state.board.monster_cells_of(0):
				if String(state.board.at(cell).def.id) == card:
					hit = true
		"attack":
			hit = kind == "attack"
		"master_power":
			hit = kind == "master_power"
		"cast":
			hit = kind == "cast"
		"move":
			hit = kind == "move"
	if not hit:
		return false
	_mission_done = true
	_end_tutorial()
	_toast("Objectif atteint !")
	state.winner = 0
	state.phase = GameState.Phase.OVER
	_show_game_over()
	return true


func _ai_turn() -> void:
	busy = true
	_refresh_all()
	await get_tree().create_timer(0.5).timeout
	var guard := 0
	while not state.is_over() and state.current == 1 and guard < 200:
		guard += 1
		# Leçon : l'instructeur reste passif, il rend simplement la main.
		var action := { "type": "end_turn" } if bool(_mission.get("dummy_opponent", false)) \
				else ai.choose_action(state)
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

## Largeur de la mini-carte : tout le panneau doit tenir SANS scroll.
const DETAIL_CARD_W := 235.0


func _show_detail_card(def: CardDef) -> void:
	_clear_detail()
	if not def.is_monster():
		# Sorts : l'effet en clair (le texte de la mini-carte est illisible).
		_add_detail_text(GameText.describe_effect(def.effect))
	var w := CardWidget.create(def, DETAIL_CARD_W)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_holder.add_child(w)
	_add_detail_text(_keyword_explanations(def))


func _show_detail_monster(m: MonsterInst) -> void:
	_clear_detail()
	var w := CardWidget.create(m.def, DETAIL_CARD_W)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_holder.add_child(w)
	# Une seule ligne compacte : le panneau doit tenir sans scroll.
	var status := "Niv %d — ATQ %d, PV %d/%d" % [m.level, m.atk(), m.hp, m.max_hp()]
	if not m.at_max_level():
		status += " · XP %d/%d" % [m.xp, m.next_level_xp()]
	if m.shield:
		status += " · Bouclier"
	var l := UiTheme.label(status, 16, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var info := UiTheme.label(text, 15, UiTheme.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(280, 0)
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

var _abandon_armed := false


## Abandonner : première pression = demande de confirmation (désarmée après
## 3 s), seconde = défaite immédiate (ou déconnexion propre en ligne).
func _on_abandon() -> void:
	var btn := %AbandonBtn as Button
	if state == null or state.is_over():
		return
	if not _abandon_armed:
		_abandon_armed = true
		btn.text = "CONFIRMER ?"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if _abandon_armed:
				_abandon_armed = false
				btn.text = "ABANDONNER")
		return
	_abandon_armed = false
	btn.text = "ABANDONNER"
	if _online:
		Net.reset()                     # le serveur signalera notre forfait
		Game.goto("main_menu")
		return
	state.winner = 1
	state.phase = GameState.Phase.OVER
	_show_game_over()


func _show_game_over() -> void:
	var won := state.winner == 0
	Game.last_battle_won = won
	# Compteurs de quêtes (jour/semaine) et de succès (à vie).
	Game.report_battle(won, _stat_cards, _stat_summons, int(kills[0]))
	if won and String(Game.battle_config.get("mode", "")) == "challenge":
		Game.complete_challenge(Game.battle_config.get("challenge", {}))
	if won and String(Game.battle_config.get("mode", "")) == "event":
		Game.event_win(Game.battle_config.get("event", {}))
	# Ranked match → update the local MMR (Glicko-2). Opponent rating is neutral
	# here; a hosted backend would exchange the real rating via the server.
	var ranked := bool(Game.battle_config.get("ranked", false))
	var rank_delta := 0
	if ranked:
		var backend := LocalBackend.new()
		var prev := float(backend.rating().rating)
		var updated := backend.report_result(1.0 if won else 0.0,
				{ "rating": 1500.0, "rd": 200.0 })
		rank_delta = int(round(float(updated.rating) - prev))
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

	_fill_summary(overlay, won, ranked, rank_delta)

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

	# Sous-titre (les stats détaillées vivent dans le panneau de droite).
	var sub := "Bien joué, Maître !" if won \
			else "Ne baisse pas les bras, Maître — chaque duel est une leçon."
	if state.winner == -2:
		sub = "Égalité — limite de tours atteinte."
	var sub_l: Label = overlay.get_node("%SubText")
	sub_l.text = sub
	create_tween().tween_property(sub_l, "modulate:a", 1.0, 0.4).set_delay(0.7)

	var buttons: HBoxContainer = overlay.get_node("%Buttons")
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
	if autoplay and end_shot != "":
		await _wait(1.8)
		var img := get_viewport().get_texture().get_image()
		img.save_png(end_shot)
		print("[end-shot] %s" % end_shot)
		get_tree().quit(0)
		return


## Remplit les panneaux de l'écran de fin : rang (classé), progression de
## Maître (XP réelle), adversaire, stats du combat et récompenses.
func _fill_summary(overlay: Control, won: bool, ranked: bool, rank_delta: int) -> void:
	var rewards := Game.grant_battle_rewards(won)

	# Rang actuel : uniquement pour les matchs classés. Sans lui, le panneau XP
	# reprend sa taille naturelle en haut de colonne (miroir du panneau Adversaire).
	overlay.get_node("%RankPanel").visible = ranked
	if not ranked:
		(overlay.get_node("%XpPanel") as Control).size_flags_vertical = Control.SIZE_FILL
	var r := LocalBackend.new().rating()
	var rating := float(r.rating)
	var tier := LocalBackend.tier_of(rating)
	(overlay.get_node("%GoCrest") as TextureRect).modulate = \
			LocalBackend.TIER_COLORS.get(String(tier[0]), Color.WHITE)
	(overlay.get_node("%GoRank") as Label).text = LocalBackend.rank_name(rating)
	var lo := maxf(float(tier[1]), 0.0)
	var hi := float(tier[2])
	var bar := overlay.get_node("%GoRankBar") as ProgressBar
	bar.max_value = hi - lo
	bar.value = clampf(rating - lo, 0.0, hi - lo)
	(overlay.get_node("%GoRankPts") as Label).text = "%d / %d" % [int(round(rating)), int(hi)]
	var delta := overlay.get_node("%GoRankDelta") as Label
	if ranked:
		delta.text = "%+d POINTS DE LIGUE" % rank_delta
		delta.add_theme_color_override("font_color",
				Color(0.45, 0.85, 0.45) if rank_delta >= 0 else Color(0.9, 0.4, 0.35))
	else:
		delta.visible = false

	# Progression de Maître (niveau / XP du profil).
	var p: Dictionary = Game.profile.get("player", {})
	(overlay.get_node("%GoLevel") as Label).text = "NIVEAU %d" % int(p.get("level", 1))
	var xp_bar := overlay.get_node("%GoXpBar") as ProgressBar
	xp_bar.max_value = maxi(1, int(p.get("xp_next", 100)))
	xp_bar.value = int(p.get("xp", 0))
	(overlay.get_node("%GoXpPts") as Label).text = \
			"%d / %d" % [int(p.get("xp", 0)), int(p.get("xp_next", 100))]
	var xp_txt := "+%d EXP" % int(rewards.xp)
	if int(rewards.levels) > 0:
		xp_txt += "  ·  NIVEAU SUPÉRIEUR !"
	(overlay.get_node("%GoXpDelta") as Label).text = xp_txt

	# Adversaire.
	var cfg := Game.battle_config
	(overlay.get_node("%GoOppPortrait") as TextureRect).texture = \
			UiTheme.tex(Db.portrait_path(String(cfg.get("opponent_portrait", ""))))
	(overlay.get_node("%GoOppName") as Label).text = String(cfg.get("opponent_name", "Adversaire"))
	var sub := "Adversaire en ligne" if _online else \
			"IA — %s" % ["Novice", "Adepte", "Maître"][clampi(int(cfg.get("ai_level", 0)), 0, 2)]
	(overlay.get_node("%GoOppSub") as Label).text = sub

	# Stats du combat.
	var secs := (Time.get_ticks_msec() - _stat_start_ms) / 1000
	var stats := [
		["Durée de la partie", "%02d:%02d" % [secs / 60, secs % 60]],
		["Tours joués", str(state.player_turn_count())],
		["Cartes jouées", str(_stat_cards)],
		["Gardiens invoqués", str(_stat_summons)],
		["Monstres vaincus", str(int(kills[0]))],
		["Monstres perdus", str(int(kills[1]))],
	]
	var holder := overlay.get_node("%GoStats") as VBoxContainer
	for s in stats:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiTheme.label(String(s[0]), 17, Color(0.85, 0.82, 0.74))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UiTheme.label(String(s[1]), 17, Color(0.98, 0.96, 0.9)))
		holder.add_child(row)

	# Récompenses.
	(overlay.get_node("%GoGoldDelta") as Label).text = "+%d" % int(rewards.gold)
	(overlay.get_node("%GoShardDelta") as Label).text = "+%d" % int(rewards.shards)

	# Défaite : accents rouges (titres de panneaux, EXP en bleu) + note.
	if not won:
		var red := Color(0.85, 0.38, 0.34)
		for n in ["%RTitle", "%XTitle", "%OTitle", "%STitle", "%RwTitle"]:
			(overlay.get_node(n) as Label).add_theme_color_override("font_color", red)
		(overlay.get_node("%GoXpDelta") as Label).add_theme_color_override(
				"font_color", Color(0.55, 0.72, 1.0))
		overlay.get_node("%GoRwNote").visible = true

	# Fondu d'apparition des panneaux.
	create_tween().tween_property(overlay.get_node("%Panels"), "modulate:a", 1.0, 0.5) \
			.set_delay(0.55)


func _add_btn(parent: Control, text: String, secondary: bool, action: Callable) -> void:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(280, 64)
	b.theme_type_variation = &"MenuTabButton" if secondary else &"MenuNavFeatured"
	var f := UiTheme.title_font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override("outline_size", 5)
	b.pressed.connect(action)
	b.pressed.connect(UiTheme._click_sfx)
	parent.add_child(b)


var _power_tw: Tween


## Pulsation dorée du bouton de pouvoir tant qu'il est activable.
var _end_turn_tw: Tween


## Halo doré pulsant autour de « Fin du tour » tant que c'est à vous de jouer.
func _pulse_end_turn(on: bool) -> void:
	var glow := %EndTurnGlow as TextureRect
	if on and _end_turn_tw == null:
		_end_turn_tw = glow.create_tween().set_loops()
		_end_turn_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_end_turn_tw.tween_property(glow, "modulate:a", 0.9, 0.7)
		_end_turn_tw.tween_property(glow, "modulate:a", 0.25, 0.7)
	elif not on and _end_turn_tw != null:
		_end_turn_tw.kill()
		_end_turn_tw = null
		glow.modulate.a = 0.0


func _pulse_power(on: bool) -> void:
	if on and _power_tw == null:
		_power_tw = power_btn.create_tween().set_loops()
		_power_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_power_tw.tween_property(power_btn, "modulate",
				Color(1.35, 1.25, 0.95), 0.6)
		_power_tw.tween_property(power_btn, "modulate", Color.WHITE, 0.6)
	elif not on and _power_tw != null:
		_power_tw.kill()
		_power_tw = null
		power_btn.modulate = Color.WHITE
