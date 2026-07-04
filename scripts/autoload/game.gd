extends Node
## Game autoload: player profile (collection, deck, progress, settings),
## save/load, scene routing and the battle hand-off (battle_config).

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 1

signal profile_changed

var profile: Dictionary = {}
## Set before entering battle.tscn / dialogue.tscn:
## { "mode": "campaign"|"free", "chapter": int, "ai_level": int,
##   "opponent_master": String, "opponent_deck": Array, "opponent_name": String,
##   "opponent_portrait": String, "background": String }
var battle_config: Dictionary = {}
## Result of the last battle, read by dialogue/campaign scenes.
var last_battle_won := false
## Which half of a chapter the dialogue scene should play: "pre" or "post".
var dialogue_phase := "pre"


func _ready() -> void:
	load_profile()
	# Test instrumentation: --screenshot=<path> captures the running scene
	# after 2.5s and quits (used by automated visual verification).
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--screenshot="):
			_schedule_screenshot(String(arg).split("=", true, 1)[1])
		elif String(arg) == "--probe":
			_schedule_input_probe()
		elif String(arg).begins_with("--clickflow="):
			_schedule_clickflow(String(arg).split("=", true, 1)[1].split("|"))


## Debug: synthesizes real mouse clicks on a sequence of buttons ("A|B|C"),
## exercising the whole input pipeline end to end.
func _schedule_clickflow(steps: PackedStringArray) -> void:
	await get_tree().create_timer(2.0, true, false, true).timeout
	for step in steps:
		var b := _find_button(get_tree().root, String(step))
		if b == null:
			print("[clickflow] ÉCHEC : bouton '%s' introuvable dans %s"
					% [step, get_tree().current_scene.name])
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
	print("[clickflow] terminé")
	get_tree().quit(0)


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


## Debug: reports, for every Button on screen, which Control actually receives
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


# --- Profile ------------------------------------------------------------

func default_profile() -> Dictionary:
	var starter: Dictionary = Db.campaign.get("starter", {})
	return {
		"save_version": SAVE_VERSION,
		"campaign_progress": 0,
		"collection": starter.get("collection", {}).duplicate(),
		"deck": starter.get("deck", []).duplicate(),
		"masters": starter.get("masters", []).duplicate(),
		"active_master": starter.get("master", "kiran"),
		"settings": { "music_volume": 0.8, "sfx_volume": 0.9, "fullscreen": false },
	}


func load_profile() -> void:
	profile = default_profile()
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var data = JSON.parse_string(text)
		if data is Dictionary and int(data.get("save_version", 0)) == SAVE_VERSION:
			for key in profile:
				if data.has(key):
					profile[key] = data[key]
	_sanitize_profile()
	profile_changed.emit()


func save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d'écrire la sauvegarde : %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(profile, "\t"))
	f.close()


func reset_profile() -> void:
	profile = default_profile()
	save_profile()
	profile_changed.emit()


## Repairs anything inconsistent (deck not owned/invalid, unknown master...).
func _sanitize_profile() -> void:
	var deck: Array = profile.get("deck", [])
	if Rules.validate_deck(Db.cards, deck) != "" or not _deck_owned(deck):
		profile.deck = Db.campaign.starter.deck.duplicate()
	if not profile.masters.has(profile.active_master):
		profile.active_master = profile.masters[0] if not profile.masters.is_empty() else "kiran"
	profile.campaign_progress = clampi(int(profile.campaign_progress), 0, Db.chapters().size())


func _deck_owned(deck: Array) -> bool:
	var counts := {}
	for id in deck:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		if counts[id] > int(profile.collection.get(id, 0)):
			return false
	return true


# --- Collection / campaign ----------------------------------------------

func owned_count(card_id: String) -> int:
	return int(profile.collection.get(card_id, 0))


func is_chapter_unlocked(index: int) -> bool:
	return index <= int(profile.campaign_progress)


func is_chapter_done(index: int) -> bool:
	return index < int(profile.campaign_progress)


## Applies chapter rewards (only the first time) and advances progress.
## Returns { "cards": {id: count}, "masters": [id] } actually granted.
func complete_chapter(index: int) -> Dictionary:
	var granted := { "cards": {}, "masters": [] }
	if index != int(profile.campaign_progress):
		return granted  # replay of an already-completed chapter
	var rewards: Dictionary = Db.chapter(index).get("rewards", {})
	for id in rewards.get("cards", {}):
		var count := int(rewards.cards[id])
		profile.collection[id] = owned_count(id) + count
		granted.cards[id] = count
	for mid in rewards.get("masters", []):
		if not profile.masters.has(mid):
			profile.masters.append(mid)
			granted.masters.append(mid)
	profile.campaign_progress = index + 1
	save_profile()
	profile_changed.emit()
	return granted


# --- Battle hand-off -----------------------------------------------------

func start_chapter(index: int) -> void:
	var ch := Db.chapter(index)
	var opp: Dictionary = ch.opponent
	battle_config = {
		"mode": "campaign",
		"chapter": index,
		"ai_level": int(opp.ai_level),
		"opponent_master": String(opp.master),
		"opponent_deck": opp.deck,
		"opponent_name": String(opp.name),
		"opponent_portrait": String(opp.portrait),
		"background": String(ch.get("background", "arena_day")),
	}
	dialogue_phase = "pre"
	goto("dialogue")


func start_free_battle(ai_level: int, opponent_master: String, opponent_deck: Array) -> void:
	battle_config = {
		"mode": "free",
		"chapter": -1,
		"ai_level": ai_level,
		"opponent_master": opponent_master,
		"opponent_deck": opponent_deck,
		"opponent_name": "Adversaire",
		"opponent_portrait": opponent_master,
		"background": "arena_day",
	}
	goto("battle")


func goto(scene_name: String) -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/%s.tscn" % scene_name)
