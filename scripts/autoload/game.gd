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
	_fit_window()


## Global shortcut: F11 or Alt+Enter toggles fullscreen from any screen.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			set_fullscreen(get_window().mode != Window.MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


func set_fullscreen(on: bool) -> void:
	# Jeu incrusté dans l'éditeur (Godot 4.4+) : changer le mode fenêtre n'est
	# pas supporté et décale le mapping souris (clics qui tombent au-dessus des
	# boutons). On ne touche à rien dans ce cas.
	if Engine.is_embedded_in_editor():
		return
	profile.settings.fullscreen = on
	if on:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
		if get_window().size.x >= usable.size.x or get_window().size.y >= usable.size.y:
			get_window().mode = Window.MODE_MAXIMIZED
	save_profile()
	profile_changed.emit()


## A 1920x1080 window does not fit on most screens once the taskbar and window
## decorations are counted: the bottom of the game (the hand!) ends up
## off-screen and clicks feel broken. Maximize whenever the window would not
## fully fit, and take focus so the first click is never eaten.
func _fit_window() -> void:
	# Jeu incrusté dans l'éditeur : mode fenêtre imposé par l'éditeur, ne pas
	# forcer fullscreen/maximized (non supporté, casse les coordonnées souris).
	if Engine.is_embedded_in_editor():
		return
	# Test harnesses need window coords == canvas coords: skip any resizing.
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--clickflow") or String(arg) == "--probe" \
				or String(arg).begins_with("--screenshot") \
				or String(arg).begins_with("--end-shot") or String(arg) == "--autoplay" \
				or String(arg) == "--clicklog":
			return
	var win := get_window()
	if bool(profile.get("settings", {}).get("fullscreen", false)):
		win.mode = Window.MODE_FULLSCREEN
	else:
		var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
		if win.size.x >= usable.size.x or win.size.y >= usable.size.y:
			win.mode = Window.MODE_MAXIMIZED
	win.grab_focus()


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
	# Grant any starter content added since this profile was created (new
	# masters/cards from a content update). Idempotent, never removes anything.
	var starter: Dictionary = Db.campaign.get("starter", {})
	for mid in starter.get("masters", []):
		if not profile.masters.has(mid):
			profile.masters.append(mid)
	for id in starter.get("collection", {}):
		if owned_count(id) < int(starter.collection[id]):
			profile.collection[id] = int(starter.collection[id])
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
