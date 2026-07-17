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


## Mode d'affichage : 0 = plein écran, 1 = fenêtré, 2 = sans bordure (maximisé).
func set_display_mode(mode: int) -> void:
	profile.settings.display_mode = mode
	profile.settings.fullscreen = mode == 0
	save_profile()
	if OS.has_feature("mobile") or Engine.is_embedded_in_editor():
		return
	var win := get_window()
	match mode:
		0:
			win.borderless = false
			win.mode = Window.MODE_FULLSCREEN
		1:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
		2:
			win.mode = Window.MODE_MAXIMIZED
			win.borderless = true
	profile_changed.emit()


## Applique la limite d'images (0 = illimité) et la mémorise.
func set_max_fps(v: int) -> void:
	Engine.max_fps = v
	profile.settings.max_fps = v
	save_profile()


func set_fullscreen(on: bool) -> void:
	# Mobile : plein écran natif, rien à changer. Éditeur incrusté (Godot 4.4+) :
	# changer le mode fenêtre décale le mapping souris — on ne touche à rien.
	if OS.has_feature("mobile") or Engine.is_embedded_in_editor():
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
	# Mobile : toujours plein écran natif, pas de gestion de fenêtre. Éditeur
	# incrusté : mode fenêtre imposé, ne pas forcer fullscreen (casse la souris).
	if OS.has_feature("mobile") or Engine.is_embedded_in_editor():
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

## A deck now carries its own master: { name, master, cards[] }. The active deck
## is chosen by index (active_deck). Up to MAX_DECKS decks.
const MAX_DECKS := 3


func make_deck(name: String, master, cards: Array) -> Dictionary:
	return { "name": name, "master": String(master), "cards": cards.duplicate() }


func default_profile() -> Dictionary:
	var starter: Dictionary = Db.campaign.get("starter", {})
	return {
		"save_version": SAVE_VERSION,
		"campaign_progress": 0,
		"collection": starter.get("collection", {}).duplicate(),
		"masters": starter.get("masters", []).duplicate(),
		"decks": [make_deck("Mon deck", starter.get("master", "kiran"),
				starter.get("deck", []))],
		"active_deck": 0,
		"settings": { "music_volume": 0.8, "sfx_volume": 0.9, "fullscreen": false },
		# Identité et monnaies affichées par le menu d'accueil. Valeurs de départ
		# provisoires (mockup) tant qu'aucun système d'XP/boutique ne les alimente.
		"player": { "name": "Mercure", "level": 12, "xp": 850, "xp_next": 1500 },
		"currency": { "gold": 2350, "shards": 860, "gems": 120 },
	}


func load_profile() -> void:
	profile = default_profile()
	if FileAccess.file_exists(SAVE_PATH):
		var text := FileAccess.get_file_as_string(SAVE_PATH)
		var data = JSON.parse_string(text)
		if data is Dictionary and int(data.get("save_version", 0)) == SAVE_VERSION:
			# Toutes les clés sauvegardées sont reprises (pas seulement celles du
			# profil par défaut) : quêtes, stats à vie, succès réclamés…
			for key in data:
				if key != "save_version":
					profile[key] = data[key]
			_migrate_legacy_deck(data)
	_sanitize_profile()
	profile_changed.emit()


## Old saves stored a single flat `deck` array + a separate `active_master`.
## Wrap them into the new deck object so the player keeps their build.
func _migrate_legacy_deck(data: Dictionary) -> void:
	if data.has("decks"):
		return  # already the new format
	if data.has("deck") or data.has("active_master"):
		var starter: Dictionary = Db.campaign.get("starter", {})
		var master = data.get("active_master", starter.get("master", "kiran"))
		var cards: Array = data.get("deck", starter.get("deck", []))
		profile.decks = [make_deck("Mon deck", master, cards)]
		profile.active_deck = 0


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
	# Date d'inscription (affichée sur l'écran Profil) : posée à la première
	# ouverture, persistée à la prochaine sauvegarde.
	var pl: Dictionary = profile.get("player", {})
	if not pl.has("created"):
		pl["created"] = Time.get_date_string_from_system()
		profile["player"] = pl
	# Grant any starter content added since this profile was created (new
	# masters/cards from a content update). Idempotent, never removes anything.
	var starter: Dictionary = Db.campaign.get("starter", {})
	for mid in starter.get("masters", []):
		if not profile.masters.has(mid):
			profile.masters.append(mid)
	for id in starter.get("collection", {}):
		if owned_count(id) < int(starter.collection[id]):
			profile.collection[id] = int(starter.collection[id])
	# Validate each deck: legal + owned cards, and an owned master. Repair in place.
	var decks: Array = profile.get("decks", [])
	if decks.is_empty():
		decks.append(make_deck("Mon deck", Db.campaign.starter.get("master", "kiran"),
				Db.campaign.starter.get("deck", [])))
	if decks.size() > MAX_DECKS:
		decks.resize(MAX_DECKS)
	for d in decks:
		var cards: Array = d.get("cards", [])
		if Rules.validate_deck(Db.cards, cards) != "" or not _deck_owned(cards):
			d.cards = Db.campaign.starter.deck.duplicate()
		var fallback = profile.masters[0] if not profile.masters.is_empty() else "kiran"
		if not profile.masters.has(d.get("master", "")):
			d.master = String(fallback)
	profile.decks = decks
	profile.active_deck = clampi(int(profile.get("active_deck", 0)), 0, decks.size() - 1)
	profile.campaign_progress = clampi(int(profile.campaign_progress), 0, Db.chapters().size())


## The currently selected deck object { name, master, cards[] }.
func active_deck() -> Dictionary:
	var i := clampi(int(profile.get("active_deck", 0)), 0, profile.decks.size() - 1)
	return profile.decks[i]


func set_active_deck(index: int) -> void:
	profile.active_deck = clampi(index, 0, profile.decks.size() - 1)
	save_profile()
	profile_changed.emit()


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


## Ranked intent carried into the matchmaking screen ("Classé" vs "Partie normale").
var matchmaking_ranked := false

const _PSEUDOS := ["Kael", "Nyx", "Ronin", "Vex", "Astra", "Drake", "Luna", "Cyrus",
	"Iris", "Talon", "Wren", "Zara", "Odin", "Sable", "Fenrix", "Mira", "Kira", "Bram"]


## Battle config for a match vs a random AI, dressed up as a real online opponent
## (player-like name, no difficulty shown). Used when matchmaking finds nobody.
func matchmaking_ai_config(ranked: bool) -> Dictionary:
	# Adversaire « joueur » : un maître au hasard avec un deck cohérent généré
	# pour sa guilde (courbe de mana), pas un vieux deck de chapitre parfois
	# faible. En classé, jamais de Novice — la ladder doit être compétitive.
	var pool: Array = Db.masters.values()
	var m: MasterDef = pool[randi() % pool.size()]
	var levels := ([AiPlayer.Level.ADEPT, AiPlayer.Level.MASTER] if ranked
			else [AiPlayer.Level.NOVICE, AiPlayer.Level.ADEPT, AiPlayer.Level.MASTER])
	return {
		"mode": "free",
		"ranked": ranked,
		"ai_level": int(levels[randi() % levels.size()]),
		"opponent_master": String(m.id),
		"opponent_deck": Db.guild_deck(m.guild),
		"opponent_name": "%s%d" % [_PSEUDOS[randi() % _PSEUDOS.size()], randi() % 900 + 100],
		"opponent_portrait": String(m.id),
		"background": "arena_day",
	}


## Récompenses de fin de combat (écran Victoire) : or, cristaux et XP de
## Maître — le niveau monte quand xp_next est atteint (seuil croissant).
## Retourne { gold, shards, xp, levels } pour l'affichage.
func grant_battle_rewards(won: bool) -> Dictionary:
	var mult := event_multipliers()   # bonus d'événement actif (Double XP…)
	var gold := int((100 if won else 25) * float(mult.gold))
	var shards := 50 if won else 10
	var xp := int((150 if won else 50) * float(mult.xp))
	var cur: Dictionary = profile.get("currency", {})
	cur["gold"] = int(cur.get("gold", 0)) + gold
	cur["shards"] = int(cur.get("shards", 0)) + shards
	profile["currency"] = cur
	var p: Dictionary = profile.get("player", {})
	p["xp"] = int(p.get("xp", 0)) + xp
	var levels := 0
	while int(p.xp) >= int(p.get("xp_next", 100)):
		p["xp"] = int(p.xp) - int(p.get("xp_next", 100))
		p["level"] = int(p.get("level", 1)) + 1
		p["xp_next"] = int(int(p.get("xp_next", 100)) * 1.2)
		levels += 1
	profile["player"] = p
	save_profile()
	profile_changed.emit()
	return { "gold": gold, "shards": shards, "xp": xp, "levels": levels }


## --- Défis PvE (modificateurs de règles, resources/data/challenges.json) -----

const CHALLENGES_PATH := "res://resources/data/challenges.json"
const GUILD_BY_NAME := {
	"flame": GameConst.Guild.FLAME, "sylvan": GameConst.Guild.SYLVAN,
	"shadow": GameConst.Guild.SHADOW, "light": GameConst.Guild.LIGHT,
}

var _challenges_data: Array = []


func challenges() -> Array:
	if _challenges_data.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(CHALLENGES_PATH))
		if data is Array:
			_challenges_data = data
	return _challenges_data


## Le défi mis en avant cette semaine (récompense doublée), en rotation.
func weekly_challenge() -> Dictionary:
	var all := challenges()
	if all.is_empty():
		return {}
	return all[int(Time.get_unix_time_from_system() / 604800.0) % all.size()]


func challenge_done(id: String) -> bool:
	return profile.get("challenges_done", []).has(id)


func start_challenge(ch: Dictionary) -> void:
	var m: MasterDef = Db.master(StringName(String(ch.opponent.master)))
	var mod: Dictionary = ch.get("mod", {})
	battle_config = {
		"mode": "challenge",
		"chapter": -1,
		"challenge": ch,
		"ai_level": int(ch.opponent.get("ai_level", 1)),
		"opponent_master": String(m.id),
		"opponent_deck": Db.guild_deck(m.guild),
		"opponent_name": m.display_name,
		"opponent_portrait": String(m.id),
		"background": "arena_day",
	}
	if mod.has("deck_guild"):
		battle_config["player_deck"] = \
				Db.guild_deck(GUILD_BY_NAME.get(String(mod.deck_guild), GameConst.Guild.FLAME))
	goto("battle")


## Victoire d'un défi : récompense versée une seule fois (x2 le défi de la
## semaine, suivi séparément par semaine).
func complete_challenge(ch: Dictionary) -> Dictionary:
	var id := String(ch.get("id", ""))
	var granted := {}
	if not challenge_done(id):
		var done: Array = profile.get("challenges_done", [])
		done.append(id)
		profile["challenges_done"] = done
		granted = ch.get("reward", {}).duplicate()
	var week := int(Time.get_unix_time_from_system() / 604800.0)
	if String(weekly_challenge().get("id", "")) == id \
			and int(profile.get("weekly_challenge_week", -1)) != week:
		profile["weekly_challenge_week"] = week
		for kind in ch.get("reward", {}):
			granted[kind] = int(granted.get(kind, 0)) + int(ch.reward[kind])
	if not granted.is_empty():
		_grant_reward(granted)
	else:
		save_profile()
	return granted


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


## --- Économie (boosters, recyclage, fabrication) -----------------------------
## Monnaies affichées : gold = Or, gems = Cristaux, shards = Essence.

func currency(kind: String) -> int:
	return int(profile.get("currency", {}).get(kind, 0))


func spend(kind: String, amount: int) -> bool:
	if currency(kind) < amount:
		return false
	profile.currency[kind] = currency(kind) - amount
	save_profile()
	profile_changed.emit()
	return true


func gain(kind: String, amount: int) -> void:
	profile.currency[kind] = currency(kind) + amount
	save_profile()
	profile_changed.emit()


## Achète et ouvre un booster (spec de resources/data/shop.json). Retourne les
## ids tirés, ou [] si l'Or manque. Les cartes rejoignent la collection.
func open_booster(spec: Dictionary) -> Array:
	if not spend("gold", int(spec.get("price", 0))):
		return []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ids: Array = Economy.roll_booster(Economy.pools_of(Db.constructible_cards()),
			int(spec.get("cards", 5)), StringName(String(spec.get("min_rarity", "commune"))), rng)
	for id in ids:
		profile.collection[id] = owned_count(String(id)) + 1
	save_profile()
	profile_changed.emit()
	return ids


## Exemplaires de la carte utilisés par le deck qui en joue le plus
## (on ne peut pas recycler une carte dont un deck a besoin).
func max_deck_use(id: String) -> int:
	var used := 0
	for deck in profile.get("decks", []):
		used = maxi(used, deck.get("cards", []).count(id))
	return used


## Recycle un exemplaire contre de l'Essence. -1 si impossible.
func recycle_card(id: String) -> int:
	var def: CardDef = Db.card(StringName(id))
	if def == null or owned_count(id) <= max_deck_use(id):
		return -1
	var value := int(Economy.RECYCLE_VALUE.get(def.rarity, 5))
	profile.collection[id] = owned_count(id) - 1
	profile.currency["shards"] = currency("shards") + value
	save_profile()
	profile_changed.emit()
	return value


## Fabrique un exemplaire contre de l'Essence (plafonné à la limite de deck).
func craft_card(id: String) -> bool:
	var def: CardDef = Db.card(StringName(id))
	if def == null or owned_count(id) >= GameConst.MAX_COPIES:
		return false
	if not spend("shards", int(Economy.CRAFT_COST.get(def.rarity, 25))):
		return false
	profile.collection[id] = owned_count(id) + 1
	save_profile()
	profile_changed.emit()
	return true


## --- Quêtes (quotidiennes / hebdomadaires) et succès --------------------------
## Définitions déclaratives dans resources/data/quests.json ; compteurs du jour
## ("d"), de la semaine ("w") et à vie (profile.stats) + réclamations dans le
## profil. Équilibrage / nouveau contenu = éditer le JSON.

const QUESTS_PATH := "res://resources/data/quests.json"

var _quests_data: Dictionary = {}


func _quests() -> Dictionary:
	if _quests_data.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_PATH))
		if data is Dictionary:
			_quests_data = data
	return _quests_data


func daily_quests() -> Array:
	return _quests().get("daily", [])


func weekly_quests() -> Array:
	return _quests().get("weekly", [])


func achievements() -> Array:
	return _quests().get("achievements", [])


## Compteurs remis à zéro chaque jour ("d") / chaque semaine ("w").
func quest_state() -> Dictionary:
	var today := Time.get_date_string_from_system()
	var week := int(Time.get_unix_time_from_system() / 604800.0)
	var q: Dictionary = profile.get("quests", {})
	if String(q.get("date", "")) != today:
		q["date"] = today
		q["d"] = {}
		q["dclaimed"] = []
	if int(q.get("week", -1)) != week:
		q["week"] = week
		q["w"] = {}
		q["wclaimed"] = []
	profile["quests"] = q
	return q


## Incrémente un compteur du jour, de la semaine et à vie (succès).
func quest_bump(key: String, n: int = 1) -> void:
	var q := quest_state()
	for scope in ["d", "w"]:
		var c: Dictionary = q.get(scope, {})
		c[key] = int(c.get(key, 0)) + n
		q[scope] = c
	profile["quests"] = q
	var st: Dictionary = profile.get("stats", {})
	st[key] = int(st.get(key, 0)) + n
	profile["stats"] = st
	save_profile()


## Bilan de fin de partie → compteurs de quêtes, de succès et XP du passe.
func report_battle(won: bool, cards: int, summons: int, kills: int) -> void:
	quest_bump("games")
	if won:
		quest_bump("wins")
	if cards > 0:
		quest_bump("cards", cards)
	if summons > 0:
		quest_bump("summons", summons)
	if kills > 0:
		quest_bump("kills", kills)
	var bxp: Dictionary = season_config().get("battle_xp", {})
	season_add_xp(int((int(bxp.get("win", 60)) if won else int(bxp.get("loss", 30)))
			* float(event_multipliers().xp)))


## --- Événements (resources/data/events.json) ---------------------------------
## Sans serveur : planification locale honnête. "week" = un événement en
## rotation par semaine ; "weekend" = actifs du vendredi au dimanche.

const EVENTS_PATH := "res://resources/data/events.json"

var _events_data: Array = []


func events_data() -> Array:
	if _events_data.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
		if data is Array:
			_events_data = data
	return _events_data


func _is_weekend() -> bool:
	return Time.get_datetime_dict_from_system().weekday in [0, 5, 6]  # dim, ven, sam


func active_events() -> Array:
	var week_events: Array = []
	var weekend_events: Array = []
	for ev in events_data():
		(weekend_events if String(ev.get("schedule", "")) == "weekend"
				else week_events).append(ev)
	var active: Array = []
	if not week_events.is_empty():
		active.append(week_events[int(Time.get_unix_time_from_system() / 604800.0)
				% week_events.size()])
	if _is_weekend():
		active.append_array(weekend_events)
	return active


## Événements à venir (affichés grisés) : ceux du week-end hors week-end.
func upcoming_events() -> Array:
	if _is_weekend():
		return []
	return events_data().filter(func(ev) -> bool:
		return String(ev.get("schedule", "")) == "weekend")


## Multiplicateurs des bonus actifs (appliqués aux gains de fin de partie).
func event_multipliers() -> Dictionary:
	var mult := { "gold": 1.0, "xp": 1.0 }
	for ev in active_events():
		for kind in ev.get("bonus", {}):
			mult[kind] = float(mult.get(kind, 1.0)) * float(ev.bonus[kind])
	return mult


## Lance le mode spécial d'un événement "battle" (même moteur que les défis).
func start_event_battle(ev: Dictionary) -> void:
	var m: MasterDef = Db.master(StringName(String(ev.opponent.master)))
	var mod: Dictionary = ev.get("mod", {})
	battle_config = {
		"mode": "event",
		"chapter": -1,
		"event": ev,
		"challenge": { "mod": mod },   # mêmes modificateurs que les défis
		"ai_level": int(ev.opponent.get("ai_level", 1)),
		"opponent_master": String(m.id),
		"opponent_deck": Db.guild_deck(m.guild),
		"opponent_name": m.display_name,
		"opponent_portrait": String(m.id),
		"background": "arena_day",
	}
	if mod.has("deck_guild"):
		battle_config["player_deck"] = \
				Db.guild_deck(GUILD_BY_NAME.get(String(mod.deck_guild), GameConst.Guild.FLAME))
	goto("battle")


## Victoire d'un mode événement : récompense à chaque victoire.
func event_win(ev: Dictionary) -> void:
	_grant_reward(ev.get("win_reward", {}))


## --- Passe de saison (resources/data/season_pass.json) -----------------------
## Saison = mois calendaire ; XP gagnée en jouant ; récompenses par niveau.

const SEASON_PATH := "res://resources/data/season_pass.json"

var _season_config: Dictionary = {}


func season_config() -> Dictionary:
	if _season_config.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(SEASON_PATH))
		if data is Dictionary:
			_season_config = data
	return _season_config


## État persistant de la saison courante (remise à zéro au changement de mois).
func season_state() -> Dictionary:
	var month := Time.get_date_string_from_system().substr(0, 7)  # AAAA-MM
	var s: Dictionary = profile.get("season", {})
	if String(s.get("id", "")) != month:
		s = { "id": month, "xp": 0, "claimed": [] }
		profile["season"] = s
	return s


func season_add_xp(xp: int) -> void:
	var s := season_state()
	s["xp"] = int(s.get("xp", 0)) + xp
	profile["season"] = s
	save_profile()


func season_level() -> int:
	return Season.level_of(int(season_state().get("xp", 0)), season_config())


## Réclame la récompense d'un niveau atteint. {} si pas prête ou déjà prise.
func claim_season_level(level: int) -> Dictionary:
	var s := season_state()
	var claimed: Array = s.get("claimed", [])
	if level < 1 or level > season_level() or claimed.has(level):
		return {}
	var reward := Season.reward_for(level, season_config())
	if reward.is_empty():
		return {}
	claimed.append(level)
	s["claimed"] = claimed
	profile["season"] = s
	_grant_reward(reward)
	return reward


func quest_progress(scope: String, key: String) -> int:
	return int(quest_state().get(scope, {}).get(key, 0))


## Réclame la récompense de la quête n° idx ("d" ou "w"). {} si pas prête.
func claim_quest(scope: String, idx: int) -> Dictionary:
	var defs := daily_quests() if scope == "d" else weekly_quests()
	if idx < 0 or idx >= defs.size():
		return {}
	var quest: Dictionary = defs[idx]
	var q := quest_state()
	var claimed: Array = q.get(scope + "claimed", [])
	if claimed.has(idx) or quest_progress(scope, String(quest.key)) < int(quest.goal):
		return {}
	claimed.append(idx)
	q[scope + "claimed"] = claimed
	profile["quests"] = q
	_grant_reward(quest.get("reward", {}))
	return quest.get("reward", {})


## Valeur d'une statistique de succès (à vie ou dérivée du profil).
func achievement_stat(key: String) -> int:
	match key:
		"level":
			return int(profile.get("player", {}).get("level", 1))
		"campaign":
			return int(profile.get("campaign_progress", 0))
		"collection":
			var distinct := 0
			for id in profile.get("collection", {}):
				if owned_count(String(id)) > 0:
					distinct += 1
			return distinct
		"rating":
			return int(round(float(LocalBackend.new().rating().rating)))
		_:
			return int(profile.get("stats", {}).get(key, 0))


func achievement_unlocked(a: Dictionary) -> bool:
	return achievement_stat(String(a.stat)) >= int(a.goal)


func claim_achievement(a: Dictionary) -> Dictionary:
	var claimed: Array = profile.get("ach_claimed", [])
	if claimed.has(String(a.id)) or not achievement_unlocked(a):
		return {}
	claimed.append(String(a.id))
	profile["ach_claimed"] = claimed
	_grant_reward(a.get("reward", {}))
	return a.get("reward", {})


func _grant_reward(reward: Dictionary) -> void:
	for kind in reward:
		profile.currency[kind] = currency(String(kind)) + int(reward[kind])
	save_profile()
	profile_changed.emit()


func goto(scene_name: String) -> void:
	get_tree().call_deferred("change_scene_to_file", scene_path(scene_name))


## Resolves the mobile variant (<name>_mobile.tscn) when running on a touch
## device and one exists; otherwise the desktop scene. Single navigation point,
## so desktop is untouched and each screen opts into mobile by adding a scene.
func scene_path(scene_name: String) -> String:
	if OS.has_feature("mobile"):
		var mobile := "res://scenes/%s_mobile.tscn" % scene_name
		if ResourceLoader.exists(mobile):
			return mobile
	return "res://scenes/%s.tscn" % scene_name
