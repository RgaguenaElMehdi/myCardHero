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
	if not OS.has_feature("mobile"):
		%CampaignBtn.grab_focus()  # navigation clavier/manette immédiate
	_animate_entrance()
	Audio.play_music("menu")


func _wire_navigation() -> void:
	_route(%CampaignBtn, "selection")
	_route(%FreeBtn, "free_setup")
	_route(%DeckBtn, "deck_builder")
	_route(%QuestsBtn, "arena_hub")
	_route(%SettingsBtn, "settings")
	# Écrans pas encore construits : retour visuel au lieu d'une erreur.
	for btn: Button in [%CollectionBtn, %ShopBtn, %PassBtn, %RankingBtn,
			%MailBtn, %GiftBtn, %SocialBtn]:
		btn.pressed.connect(_toast.bind(COMING_SOON))
		btn.pressed.connect(UiTheme._click_sfx)
	# Présents uniquement sur desktop.
	var gear: Button = get_node_or_null("%GearBtn")
	if gear:
		_route(gear, "settings")
	var quit: Button = get_node_or_null("%QuitBtn")
	if quit:
		quit.pressed.connect(func() -> void: get_tree().quit())
		quit.pressed.connect(UiTheme._click_sfx)


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


## Bannière d'événement + fil d'actualités : contenu déclaratif dans
## resources/data/menu_feed.json, remplaçable sans toucher au code.
func _fill_feed() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FEED_PATH))
	if not (data is Dictionary):
		return
	var ev: Dictionary = data.get("event", {})
	%EventKicker.text = str(ev.get("kicker", "ÉVÉNEMENT"))
	%EventTitle.text = str(ev.get("title", ""))
	%EventEnds.text = str(ev.get("ends", ""))
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
			[get_node_or_null("%TopBar"), Vector2(0, -40)],
			[get_node_or_null("%EventBanner"), Vector2(50, 0)],
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
