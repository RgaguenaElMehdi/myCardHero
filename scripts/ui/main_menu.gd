extends Control
## Accueil "Stonebound" (mockup anime fantasy) : navigation principale à gauche,
## ressources en haut à droite, bannière d'événement, profil joueur, actualités.
## Structure et style dans main_menu[_mobile].tscn — logique seulement ici.

const FEED_PATH := "res://resources/data/menu_feed.json"
const COMING_SOON := "Bientôt disponible !"

var _toast_tween: Tween


func _ready() -> void:
	# The boot scene is the desktop menu; hop to the mobile variant on a phone.
	# (Every other screen is reached through Game.goto, which resolves this.)
	if OS.has_feature("mobile") and not scene_file_path.ends_with("_mobile.tscn") \
			and ResourceLoader.exists("res://scenes/main_menu_mobile.tscn"):
		Game.goto("main_menu")
		return

	_wire_navigation()
	_fill_profile()
	Game.profile_changed.connect(_fill_profile)
	_fill_feed()
	_fill_quests()
	if not OS.has_feature("mobile"):
		%PlayBtn.grab_focus()  # navigation clavier/manette immédiate
	_animate_entrance()
	_animate_play_btn.call_deferred()
	Audio.play_music("menu")


func _wire_navigation() -> void:
	# JOUER = partie rapide : matchmaking non classé (repli IA déguisé).
	(%PlayBtn as Button).pressed.connect(func() -> void:
		Game.matchmaking_ranked = false
		Game.goto("matchmaking"))
	(%PlayBtn as Button).pressed.connect(UiTheme._click_sfx)
	_route(%CampaignBtn, "campaign")
	_route(%ArenaBtn, "arena_hub")
	_route(%FreeBtn, "free_setup")
	_route(%ChallengesBtn, "challenges")
	_route(%CollectionBtn, "collection")
	_route(%DeckBtn, "deck_builder")
	_route(%ShopBtn, "shop")
	_route(%PassBtn, "season_pass")
	_route(%CodexBtn, "codex")
	_route(%SettingsBtn, "settings")
	# Écrans pas encore construits : retour visuel au lieu d'une erreur.
	for btn: Button in [%MailBtn, %GiftBtn, %SocialBtn]:
		btn.pressed.connect(_toast.bind(COMING_SOON))
		btn.pressed.connect(UiTheme._click_sfx)
	# Carte profil → Profil ; offres → Boutique ; quêtes du jour → Quêtes ;
	# bannière → Événements (ou Défis si aucun événement actif).
	_click_panel(%ProfilePanel, func() -> void: Game.goto("profile"))
	_click_panel(%OffersPanel, func() -> void: Game.goto("shop"))
	_click_panel(%QuestsPanel, func() -> void: Game.goto("quests"))
	_click_panel(%EventBanner, func() -> void:
		Game.goto("events" if not Game.active_events().is_empty() else "challenges"))
	# Présents uniquement sur desktop.
	var gear: Button = get_node_or_null("%GearBtn")
	if gear:
		_route(gear, "settings")
	var quit: Button = get_node_or_null("%QuitBtn")
	if quit:
		quit.pressed.connect(func() -> void: get_tree().quit())
		quit.pressed.connect(UiTheme._click_sfx)


func _click_panel(panel: Control, action: Callable) -> void:
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			UiTheme._click_sfx()
			action.call())


func _route(btn: Button, scene: String) -> void:
	btn.pressed.connect(func() -> void: Game.goto(scene))
	btn.pressed.connect(UiTheme._click_sfx)


func _fill_profile() -> void:
	var p: Dictionary = Game.profile.get("player", {})
	%PlayerName.text = str(p.get("name", "Joueur"))
	%LevelLabel.text = "Niv. %d" % int(p.get("level", 1))
	%XpLabel.text = "%s / %s XP" % [UiTheme.fmt_thousands(int(p.get("xp", 0))),
			UiTheme.fmt_thousands(int(p.get("xp_next", 100)))]
	%XpBar.max_value = maxi(1, int(p.get("xp_next", 100)))
	%XpBar.value = int(p.get("xp", 0))
	var cur: Dictionary = Game.profile.get("currency", {})
	%GoldLabel.text = UiTheme.fmt_thousands(int(cur.get("gold", 0)))
	%ShardLabel.text = UiTheme.fmt_thousands(int(cur.get("shards", 0)))
	%GemLabel.text = UiTheme.fmt_thousands(int(cur.get("gems", 0)))


## Bannière = défi de la semaine (rotation réelle, compte à rebours) ;
## actualités déclaratives dans menu_feed.json ; offres = boutique réelle.
func _fill_feed() -> void:
	# Bannière : l'événement actif en priorité, sinon le défi de la semaine.
	var events := Game.active_events()
	var weekly := Game.weekly_challenge()
	if not events.is_empty():
		%EventKicker.text = "ÉVÉNEMENT EN COURS"
		%EventTitle.text = String(events[0].name).to_upper()
		(%EventArt as TextureRect).texture = UiTheme.tex(String(events[0].get("icon", "")))
		(%EventArt as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif not weekly.is_empty():
		%EventKicker.text = "DÉFI DE LA SEMAINE — RÉCOMPENSE ×2"
		%EventTitle.text = String(weekly.name).to_upper()
		(%EventArt as TextureRect).texture = \
				UiTheme.tex(Db.portrait_path(String(weekly.opponent.master)))
	if not events.is_empty() or not weekly.is_empty():
		_tick_event_ends()
		var t := Timer.new()
		t.wait_time = 60.0
		t.timeout.connect(_tick_event_ends)
		add_child(t)
		t.start()
	var data = JSON.parse_string(FileAccess.get_file_as_string(FEED_PATH))
	if not (data is Dictionary):
		return
	for child in %NewsList.get_children():
		child.queue_free()
	for line in data.get("news", []):
		var lbl := Label.new()  # contenu dynamique par nature (fil d'actus)
		lbl.text = "•  %s" % line
		lbl.add_theme_font_override("font", UiTheme.title_font())
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.83, 0.76))
		lbl.add_theme_constant_override("outline_size", 0)
		%NewsList.add_child(lbl)
	_fill_offers()


## Compte à rebours réel jusqu'à la rotation du défi de la semaine.
func _tick_event_ends() -> void:
	var now := Time.get_unix_time_from_system()
	var secs := int((int(now / 604800.0) + 1) * 604800.0 - now)
	%EventEnds.text = "Fin dans %dj %dh" % [secs / 86400, (secs % 86400) / 3600]


## Offres du jour : les boosters réels de la boutique (nom + prix en Or).
func _fill_offers() -> void:
	var row := get_node_or_null("%OffersPanel")
	if row == null:
		return
	var boosters: Array = []
	var data = JSON.parse_string(
			FileAccess.get_file_as_string("res://resources/data/shop.json"))
	if data is Dictionary:
		boosters = data.get("boosters", [])
	var chips: Array = row.get_node("OBox/OffersRow").get_children()
	for i in mini(boosters.size(), chips.size()):
		(chips[i].get_node("V/N") as Label).text = String(boosters[i].name)
		(chips[i].get_node("V/S") as Label).text = \
				"%d Or" % int(boosters[i].price)
		(chips[i].get_node("V/I") as TextureRect).texture = \
				UiTheme.tex("res://assets/sprites/ui/gold/icon_chest.png")


## Entrée en scène : fondu du fond, nav depuis la gauche (décalée bouton par
## bouton), barre du haut depuis le haut, panneaux de droite et profil ensuite.
func _animate_entrance() -> void:
	get_node("Background").modulate.a = 0.0
	# Les conteneurs posent leurs enfants après _ready : attendre une frame
	# pour capturer les positions finales avant de les décaler.
	await get_tree().process_frame
	create_tween().tween_property(get_node("Background"), "modulate:a", 1.0, 0.45)
	var delay := 0.05
	for target: Array in [
			[get_node_or_null("%LogoBox"), Vector2(-50, 0)],
			[get_node_or_null("%PlayBtn"), Vector2(-60, 0)],
			[get_node_or_null("%FreeBtn"), Vector2(-60, 0)],
			[get_node_or_null("%TopBar"), Vector2(0, -40)],
			[get_node_or_null("%EventBanner"), Vector2(50, 0)],
			[get_node_or_null("%QuestsPanel"), Vector2(50, 0)],
			[get_node_or_null("%OffersPanel"), Vector2(50, 0)],
			[get_node_or_null("%ProfilePanel"), Vector2(0, 40)],
			[get_node_or_null("%SecondaryNav"), Vector2(0, 40)],
			[get_node_or_null("%NewsPanel"), Vector2(0, 40)]]:
		if target[0]:
			_slide_in(target[0], target[1], delay)
	for btn in %NavColumn.get_children():
		_slide_in(btn, Vector2(-60, 0), delay)
		delay += 0.06


func _slide_in(node: Control, offset: Vector2, delay: float) -> void:
	var to := node.position
	node.position = to + offset
	node.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(node, "position", to, 0.35).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.3).set_delay(delay)


## Quêtes du jour : les 3 premières de quests.json, compteurs réels du profil.
func _fill_quests() -> void:
	if get_node_or_null("%Quest0Label") == null:
		return
	var defs := Game.daily_quests()
	for i in mini(3, defs.size()):
		var goal := int(defs[i].goal)
		var done := mini(Game.quest_progress("d", String(defs[i].key)), goal)
		(get_node("%%Quest%dLabel" % i) as Label).text = String(defs[i].label)
		(get_node("%%Quest%dCount" % i) as Label).text = "%d/%d" % [done, goal]
		var bar := get_node("%%Quest%dBar" % i) as ProgressBar
		bar.max_value = goal
		bar.value = done


## Battement doré du bouton JOUER (élément principal du hub).
func _animate_play_btn() -> void:
	await get_tree().process_frame
	var btn := %PlayBtn as Button
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 1.1)
	tw.parallel().tween_property(btn, "modulate", Color(1.15, 1.1, 0.95), 1.1)
	tw.tween_property(btn, "scale", Vector2.ONE, 1.1)
	tw.parallel().tween_property(btn, "modulate", Color.WHITE, 1.1)


## Message temporaire en bas de l'écran (fonctions pas encore disponibles).
func _toast(msg: String) -> void:
	%ToastLabel.text = msg
	var t: Control = %Toast
	t.visible = true
	t.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(t, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void: t.visible = false)
