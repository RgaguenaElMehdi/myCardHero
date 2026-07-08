extends Node
## Test instrumentation (automated verification). Does nothing in normal play.
##   --screenshot=<path>  capture the scene after 2.5 s and quit
##   --probe              report which Control receives each button's click
##   --clickflow=A|B|C    synthesize real clicks on a button sequence
##   --clicklog           log every real mouse click received (position, hover)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--screenshot="):
			_schedule_screenshot(String(arg).split("=", true, 1)[1])
		elif String(arg) == "--probe":
			_schedule_input_probe()
		elif String(arg).begins_with("--clickflow="):
			_schedule_clickflow(String(arg).split("=", true, 1)[1].split("|"))
		elif String(arg) == "--clicklog":
			_log_clicks = true


## Synthesizes real mouse clicks on a sequence of buttons ("A|B|C"),
## exercising the whole input pipeline end to end.
func _schedule_clickflow(steps: PackedStringArray) -> void:
	await get_tree().create_timer(2.0, true, false, true).timeout
	for step in steps:
		var b := _find_button(get_tree().root, String(step))
		if b == null:
			var all_buttons: Array = []
			_collect_buttons(get_tree().root, all_buttons)
			var texts: Array = []
			for btn in all_buttons:
				texts.append((btn as Button).text)
			print("[clickflow] ÉCHEC : bouton '%s' introuvable dans %s — visibles : %s"
					% [step, get_tree().current_scene.name, texts])
			get_tree().quit(1)
			return
		var center: Vector2 = b.get_global_rect().get_center()
		var was_disabled: bool = b.disabled
		_synth_click(center)
		print("[clickflow] clic sur '%s' @%s%s" % [step, center,
				" (DISABLED!)" if was_disabled else ""])
		await get_tree().create_timer(2.0, true, false, true).timeout
	var scene := get_tree().current_scene
	if scene != null and scene.get("state") != null:
		var st: GameState = scene.get("state")
		print("[clickflow] état final : scène=%s, tour=%d, phase=%d"
				% [scene.name, st.turn, st.phase])
	else:
		print("[clickflow] état final : scène=%s" % (scene.name if scene else "?"))
	print("[clickflow] fenêtre : mode=%d taille=%s fullscreen_setting=%s"
			% [get_window().mode, get_window().size,
			Game.profile.get("settings", {}).get("fullscreen", "?")])
	print("[clickflow] terminé")
	get_tree().quit(0)


var _log_clicks := false

func _input(event: InputEvent) -> void:
	if _log_clicks and event is InputEventMouseButton and event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		print("[clicklog] bouton souris @position=%s | OS écran=%s fenêtre pos=%s taille=%s | hover=%s"
				% [event.position, DisplayServer.mouse_get_position(),
				get_window().position, get_window().size,
				hovered.get_path() if hovered != null else "AUCUN"])


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).is_visible_in_tree() \
			and (node as Button).text.begins_with(text):
		return node
	for child in node.get_children():
		var r := _find_button(child, text)
		if r != null:
			return r
	return null


func _synth_click(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	Input.parse_input_event(release)


## Reports, for every Button on screen, which Control actually receives
## a click at its center (finds invisible blockers).
func _schedule_input_probe() -> void:
	await get_tree().create_timer(2.0, true, false, true).timeout
	var buttons: Array = []
	_collect_buttons(get_tree().root, buttons)
	print("[probe] %d bouton(s) trouvés" % buttons.size())
	for b in buttons:
		var center: Vector2 = (b as Control).get_global_rect().get_center()
		var hit := _hit_test(get_tree().root, center)
		var status := "OK" if hit == b else "BLOQUÉ par %s" % (hit.get_path() if hit != null else "?")
		if (b as Button).disabled:
			status += " (disabled)"
		print("[probe] '%s' @%s -> %s" % [(b as Button).text, center, status])
	get_tree().quit()


func _collect_buttons(node: Node, out: Array) -> void:
	if node is Button and (node as Button).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)


## Approximates the GUI hit test: top-most visible non-IGNORE Control at point.
func _hit_test(node: Node, point: Vector2) -> Control:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var r := _hit_test(child, point)
		if r != null:
			return r
	if node is Control:
		var c := node as Control
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and c.get_global_rect().has_point(point):
			return c
	return null


func _schedule_screenshot(path: String) -> void:
	await get_tree().create_timer(2.5, true, false, true).timeout  # real time
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[screenshot] %s -> %s" % [path, error_string(err)])
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
