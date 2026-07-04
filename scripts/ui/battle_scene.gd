extends Control
## Battle scene controller. Owns the match GameState, renders the board/hand/HUD,
## translates clicks into Rules actions and animates the returned events.
## The human is always player 0; the AI is player 1.

const CELL_PITCH := 158.0
const BOARD_ORIGIN := Vector2(686, 84)
const HAND_CARD_W := 176.0

var state: GameState
var ai: AiPlayer
## --autoplay: both sides AI-driven through the normal UI action path
## (integration smoke test of the full battle scene).
var autoplay := false
var autoplay_ai: AiPlayer
var busy := false          ## input locked (animations / AI turn)
var sel_hand := -1
var sel_cell := Vector2i(-1, -1)
var sel_power := false

var cells := {}            ## Vector2i -> BoardCell
var hand_widgets: Array[CardWidget] = []

var board_area: Control
var hand_area: Control
var fx_layer: Control
var log_box: RichTextLabel
var turn_label: Label
var end_turn_btn: Button
var power_btn: Button
var evolve_btn: Button
var detail_holder: VBoxContainer
var enemy_panel: PanelContainer
var player_panel: PanelContainer
var enemy_info: Dictionary = {}
var player_info: Dictionary = {}
var mulligan_overlay: Control
var toast_label: Label


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
	_build_ui()
	_setup_match()
	Audio.play_music("battle")
	if autoplay:
		Engine.time_scale = 20.0
		autoplay_ai = AiPlayer.new(AiPlayer.Level.ADEPT, 42)
		_run_autoplay()


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
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 14))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var title := UiTheme.label("Main de départ", 30, UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	for id in state.players[0].hand:
		row.add_child(CardWidget.create(state.card(id), 170))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	vbox.add_child(buttons)
	var keep := Button.new()
	keep.text = "Garder"
	UiTheme.style_button(keep, UiTheme.OK.darkened(0.3), 22)
	keep.pressed.connect(_on_mulligan_choice.bind(false))
	buttons.add_child(keep)
	var redraw := Button.new()
	redraw.text = "Nouvelle main"
	UiTheme.style_button(redraw, UiTheme.PANEL_LIGHT, 22)
	redraw.pressed.connect(_on_mulligan_choice.bind(true))
	buttons.add_child(redraw)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	mulligan_overlay.add_child(center)


func _on_mulligan_choice(redraw: bool) -> void:
	Rules.apply(state, { "type": "mulligan", "redraw": redraw })
	Rules.apply(state, ai.choose_action(state))  # AI mulligan → starts turn 1
	mulligan_overlay.queue_free()
	mulligan_overlay = null
	_log("La partie commence ! À vous de jouer.")
	Audio.play_sfx("turn")
	_refresh_all()


# --- UI construction ------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = UiTheme.tex(Db.background_path("battle_table"))
	bg.modulate = Color(0.75, 0.75, 0.8)
	add_child(bg)
	if bg.texture == null:
		var solid := ColorRect.new()
		solid.color = UiTheme.BG
		solid.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(solid)

	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_area)
	for row in GameConst.BOARD_ROWS:
		for col in GameConst.BOARD_COLS:
			var cell := Vector2i(col, row)
			var widget := BoardCell.create(cell)
			widget.position = _cell_pos(cell)
			widget.clicked.connect(_on_cell_clicked)
			board_area.add_child(widget)
			cells[cell] = widget
	# median line
	var median := ColorRect.new()
	median.color = Color(1, 1, 1, 0.15)
	median.position = BOARD_ORIGIN + Vector2(-10, 2 * CELL_PITCH - 7)
	median.size = Vector2(3 * CELL_PITCH + 10, 4)
	median.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(median)

	enemy_panel = _master_panel(1)
	enemy_panel.position = Vector2(30, 84)
	add_child(enemy_panel)
	player_panel = _master_panel(0)
	player_panel.position = Vector2(30, 560)
	add_child(player_panel)

	turn_label = UiTheme.label("", 26, UiTheme.GOLD)
	turn_label.position = Vector2(760, 24)
	turn_label.custom_minimum_size = Vector2(400, 0)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(turn_label)

	end_turn_btn = Button.new()
	end_turn_btn.text = "Fin du tour"
	UiTheme.style_button(end_turn_btn, UiTheme.OK.darkened(0.25), 24)
	end_turn_btn.position = Vector2(1620, 480)
	end_turn_btn.custom_minimum_size = Vector2(240, 60)
	end_turn_btn.pressed.connect(func() -> void: _submit({ "type": "end_turn" }))
	add_child(end_turn_btn)

	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0.45), 10))
	log_panel.position = Vector2(1560, 84)
	log_panel.custom_minimum_size = Vector2(330, 360)
	add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 14)
	log_box.add_theme_color_override("default_color", UiTheme.TEXT_DIM)
	log_panel.add_child(log_box)

	detail_holder = VBoxContainer.new()
	detail_holder.position = Vector2(1620, 560)
	detail_holder.add_theme_constant_override("separation", 8)
	add_child(detail_holder)

	evolve_btn = Button.new()
	evolve_btn.text = "Évoluer"
	UiTheme.style_button(evolve_btn, UiTheme.GOLD.darkened(0.45), 20)
	evolve_btn.visible = false
	evolve_btn.pressed.connect(_on_evolve_pressed)
	add_child(evolve_btn)

	hand_area = Control.new()
	hand_area.position = Vector2(400, 790)
	hand_area.size = Vector2(1120, 280)
	add_child(hand_area)

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

	toast_label = UiTheme.label("", 22, Color("ffd2c0"))
	toast_label.position = Vector2(660, 730)
	toast_label.custom_minimum_size = Vector2(600, 0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	add_child(toast_label)


func _master_panel(side: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0.5), 12))
	panel.custom_minimum_size = Vector2(300, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top.add_child(portrait)
	var names := VBoxContainer.new()
	top.add_child(names)
	var name_l := UiTheme.label("", 20, UiTheme.GOLD)
	names.add_child(name_l)
	var master_l := UiTheme.label("", 15, UiTheme.TEXT_DIM)
	names.add_child(master_l)
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 22)
	hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.DANGER if side == 1 else UiTheme.OK
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.6)
	back.set_corner_radius_all(6)
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.add_theme_stylebox_override("background", back)
	vbox.add_child(hp_bar)
	var hp_l := UiTheme.label("", 16)
	vbox.add_child(hp_l)
	var res_l := UiTheme.label("", 16, UiTheme.ACCENT)
	vbox.add_child(res_l)
	var info := { "portrait": portrait, "name": name_l, "master": master_l,
			"hp_bar": hp_bar, "hp": hp_l, "res": res_l }
	if side == 0:
		power_btn = Button.new()
		UiTheme.style_button(power_btn, UiTheme.ACCENT.darkened(0.45), 18)
		power_btn.pressed.connect(_on_power_pressed)
		vbox.add_child(power_btn)
		player_info = info
	else:
		enemy_info = info
	return panel


func _cell_pos(cell: Vector2i) -> Vector2:
	# Enemy rows on top (board row 3 first), player rows at the bottom.
	var screen_row := 3 - cell.y
	return BOARD_ORIGIN + Vector2(cell.x * CELL_PITCH, screen_row * CELL_PITCH)


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
	_refresh_buttons()
	_clear_highlights()
	_apply_selection_highlights()


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
		var w := CardWidget.create(state.card(hand[i]), HAND_CARD_W)
		w.position = Vector2(start + i * overlap, 20)
		w.pressed.connect(_on_hand_card_pressed.bind(i))
		w.mouse_entered.connect(_on_hand_hover.bind(w, i))
		w.set_selected(i == sel_hand)
		if i == sel_hand:
			w.position.y -= 24
		hand_area.add_child(w)
		hand_widgets.append(w)


func _refresh_panels() -> void:
	var cfg := Game.battle_config
	var names := [Db.campaign.get("hero_name", "Vous"), String(cfg.opponent_name)]
	var portraits := [Db.portrait_path("milo"), Db.portrait_path(String(cfg.opponent_portrait))]
	for side in 2:
		var info: Dictionary = player_info if side == 0 else enemy_info
		var p := state.players[side]
		info.portrait.texture = UiTheme.tex(portraits[side])
		info.name.text = names[side]
		info.master.text = "Maître : %s" % p.master.display_name
		info.hp_bar.max_value = p.master.hp
		info.hp_bar.value = maxi(p.master_hp, 0)
		info.hp.text = "PV %d / %d" % [maxi(p.master_hp, 0), p.master.hp]
		info.res.text = "Pierres %d   Deck %d   Main %d" % [p.stones, p.deck.size(), p.hand.size()]
	var p0 := state.players[0]
	power_btn.text = "%s (%d)" % [p0.master.power_name, p0.master.power_cost]
	power_btn.tooltip_text = "%s\nPassif : %s" % [p0.master.power_desc, p0.master.passive_desc]


func _refresh_buttons() -> void:
	var my_turn := state.phase == GameState.Phase.MAIN and state.current == 0 and not busy
	end_turn_btn.disabled = not my_turn
	var p0 := state.players[0]
	power_btn.disabled = not my_turn or p0.power_used or p0.stones < p0.master.power_cost
	turn_label.text = ""
	if state.phase == GameState.Phase.MAIN:
		turn_label.text = "Tour %d — %s" % [state.player_turn_count(),
				"à vous de jouer" if state.current == 0 else "l'adversaire réfléchit…"]
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
		evolve_btn.position = _cell_pos(sel_cell) + Vector2(-40, -44)


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


func _on_hand_card_pressed(_w: CardWidget, i: int) -> void:
	if busy or state.phase != GameState.Phase.MAIN or state.current != 0:
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


func _on_cell_clicked(cell: Vector2i) -> void:
	if busy or state.phase != GameState.Phase.MAIN or state.current != 0:
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
	if busy or state.current != 0:
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

func _play_events(events: Array) -> void:
	for ev in events:
		match String(ev.e):
			"summon":
				Audio.play_sfx("summon")
				_log("%s invoque %s." % [_pname(ev.player), _cname(ev.card_id)])
				for cell in cells:
					cells[cell].render(state)
				_pop(cells[ev.cell])
				await _wait(0.2)
			"attack":
				Audio.play_sfx("attack")
				_flash(cells[ev.from], Color.WHITE)
				await _wait(0.15)
			"damage":
				Audio.play_sfx("hit")
				_float_text(ev.cell, "-%d" % int(ev.amount), Color("ff6b5e"))
				await _wait(0.3)
			"master_damage":
				Audio.play_sfx("master_hit")
				var mcell := Board.master_cell(int(ev.player),
						state.players[int(ev.player)].master_col)
				_float_text(mcell, "-%d" % int(ev.amount), Color("ff3b30"), 26)
				_shake()
				_refresh_panels()
				await _wait(0.4)
			"master_heal":
				_refresh_panels()
				await _wait(0.2)
			"heal":
				Audio.play_sfx("heal")
				if state.board.at(ev.cell) != null:
					_float_text(ev.cell, "+%d" % int(ev.amount), Color("7de07d"))
				await _wait(0.25)
			"death":
				Audio.play_sfx("death")
				_log("%s est détruit." % _cname(ev.card_id))
				_flash(cells[ev.cell], Color(1, 0.2, 0.2))
				await _wait(0.3)
				for cell in cells:
					cells[cell].render(state)
			"shield_break":
				Audio.play_sfx("shield")
				_float_text(ev.cell, "Bouclier brisé !", Color("7dd8ff"), 18)
				await _wait(0.3)
			"shield":
				Audio.play_sfx("shield")
				_float_text(ev.cell, "Bouclier", Color("7dd8ff"), 18)
				await _wait(0.2)
			"riposte":
				_float_text(ev.to, "Riposte !", Color("ffb27d"), 18)
				await _wait(0.2)
			"xp":
				if bool(ev.leveled):
					Audio.play_sfx("levelup")
					_float_text(ev.cell, "NIVEAU %d !" % int(ev.level), UiTheme.GOLD, 22)
					_log("%s passe niveau %d !" % [_cell_cname(ev.cell), int(ev.level)])
					await _wait(0.35)
			"evolve":
				Audio.play_sfx("evolve")
				_log("%s évolue en %s !" % [_cname(ev.from_id), _cname(ev.to_id)])
				for cell in cells:
					cells[cell].render(state)
				_flash(cells[ev.cell], Color.WHITE)
				_float_text(ev.cell, "ÉVOLUTION !", UiTheme.GOLD, 24)
				await _wait(0.5)
			"cast":
				Audio.play_sfx("cast")
				_log("%s lance %s." % [_pname(ev.player), _cname(ev.card_id)])
				await _show_spell_preview(ev.card_id)
			"power":
				Audio.play_sfx("cast")
				_log("%s utilise son pouvoir." % _pname(ev.player))
				await _wait(0.3)
			"move":
				Audio.play_sfx("move")
				for cell in cells:
					cells[cell].render(state)
				await _wait(0.15)
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


func _shake() -> void:
	var tw := create_tween()
	var origin := position
	for i in 4:
		tw.tween_property(self, "position", origin + Vector2(randf_range(-8, 8),
				randf_range(-6, 6)), 0.04)
	tw.tween_property(self, "position", origin, 0.05)


func _float_text(cell: Vector2i, text: String, color: Color, size: int = 22) -> void:
	var l := UiTheme.label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = _cell_pos(cell) + Vector2(30, 40)
	fx_layer.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


func _show_spell_preview(card_id) -> void:
	var def := state.card(card_id)
	if def == null:
		return
	var w := CardWidget.create(def, 220)
	w.position = Vector2(850, 300)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(w)
	_pop(w)
	await _wait(0.7)
	var tw := create_tween()
	tw.tween_property(w, "modulate:a", 0.0, 0.25)
	await tw.finished
	w.queue_free()


# --- Detail panel / log / toast ---------------------------------------------

func _show_detail_card(def: CardDef) -> void:
	_clear_detail()
	var w := CardWidget.create(def, 230)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(w)


func _show_detail_monster(m: MonsterInst) -> void:
	_clear_detail()
	var w := CardWidget.create(m.def, 230)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(w)
	var status := "Niv %d — ATQ %d, PV %d/%d" % [m.level, m.atk(), m.hp, m.max_hp()]
	if not m.at_max_level():
		status += "\nXP %d / %d" % [m.xp, m.next_level_xp()]
	if m.shield:
		status += "\nBouclier actif"
	var l := UiTheme.label(status, 15, UiTheme.TEXT)
	detail_holder.add_child(l)


func _clear_detail() -> void:
	for child in detail_holder.get_children():
		child.queue_free()


func _log(text: String) -> void:
	log_box.append_text(text + "\n")


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
	if autoplay:
		print("[autoplay] partie terminée — vainqueur : joueur %d, demi-tours : %d"
				% [state.winner, state.turn])
		get_tree().quit(0)
		return
	Audio.play_sfx("win" if won else "lose")
	var overlay := _overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			UiTheme.panel(UiTheme.PANEL, 16, UiTheme.GOLD if won else UiTheme.DANGER, 3))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)
	var title := UiTheme.label("Victoire !" if won else "Défaite…", 42,
			UiTheme.GOLD if won else UiTheme.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sub := ""
	if state.winner == -2:
		sub = "Égalité — limite de tours atteinte."
	elif won:
		sub = "Le Maître adverse est vaincu."
	else:
		sub = "Votre Maître est tombé."
	var sub_l := UiTheme.label(sub, 18, UiTheme.TEXT_DIM)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_l)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)
	var is_campaign: bool = String(Game.battle_config.get("mode", "free")) == "campaign"
	if is_campaign:
		if won:
			_add_btn(buttons, "Continuer", UiTheme.OK.darkened(0.25), func() -> void:
				Game.dialogue_phase = "post"
				Game.goto("dialogue"))
		else:
			_add_btn(buttons, "Réessayer", UiTheme.OK.darkened(0.25), func() -> void:
				Game.goto("battle"))
			_add_btn(buttons, "Retour à la carte", UiTheme.PANEL_LIGHT, func() -> void:
				Game.goto("campaign"))
	else:
		_add_btn(buttons, "Rejouer", UiTheme.OK.darkened(0.25), func() -> void:
			Game.goto("battle"))
		_add_btn(buttons, "Menu principal", UiTheme.PANEL_LIGHT, func() -> void:
			Game.goto("main_menu"))


func _add_btn(parent: Control, text: String, color: Color, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 54)
	UiTheme.style_button(b, color, 20)
	b.pressed.connect(action)
	parent.add_child(b)
