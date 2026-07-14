extends Control
## Boutique : boosters achetés à l'Or (contenu déclaratif dans
## resources/data/shop.json), révélation des cartes tirées, onglets Cristaux /
## Cosmétiques en attente de contenu. Structure dans shop.tscn — logique ici.

const SHOP_PATH := "res://resources/data/shop.json"
const ITEM_SCENE: PackedScene = preload("res://scenes/widgets/shop_item.tscn")
const CHEST_ICON := "res://assets/sprites/ui/gold/icon_chest.png"

var _boosters: Array = []
var _toast_tween: Tween


func _ready() -> void:
	if get_viewport_rect().size.x > 2000:
		%BG.texture = UiTheme.tex("res://assets/backgrounds/freeplay_2400.png")
	(%BackBtn as Button).pressed.connect(func() -> void: Game.goto("main_menu"))
	(%BackBtn as Button).pressed.connect(UiTheme._click_sfx)
	(%ContinueBtn as Button).pressed.connect(func() -> void: %RevealOverlay.visible = false)
	(%ContinueBtn as Button).pressed.connect(UiTheme._click_sfx)
	for tab: Button in [%TabFeatured, %TabBoosters, %TabGems, %TabCosmetics]:
		tab.pressed.connect(_show_tab)
		tab.pressed.connect(UiTheme._click_sfx)

	var data = JSON.parse_string(FileAccess.get_file_as_string(SHOP_PATH))
	if data is Dictionary:
		_boosters = data.get("boosters", [])
	_fill_currencies()
	Game.profile_changed.connect(_fill_currencies)
	_show_tab()
	Audio.play_music("menu")


func _fill_currencies() -> void:
	%GoldLabel.text = UiTheme.fmt_thousands(Game.currency("gold"))
	%ShardLabel.text = UiTheme.fmt_thousands(Game.currency("shards"))
	%GemLabel.text = UiTheme.fmt_thousands(Game.currency("gems"))


## Onglets : À la une = boosters mis en avant ; Cristaux / Cosmétiques à venir.
func _show_tab() -> void:
	for child in %ItemsRow.get_children():
		child.queue_free()
	var soon := ""
	if (%TabGems as Button).button_pressed:
		soon = "Bientôt disponible !\nLes Cristaux financeront les cosmétiques\n(skins de Maîtres, plateaux, dos de cartes)."
	elif (%TabCosmetics as Button).button_pressed:
		soon = "Bientôt disponible !\nSkins des Maîtres, plateaux, dos de cartes et emotes\narriveront avec les saisons."
	%SoonLabel.text = soon
	%SoonLabel.visible = soon != ""
	%ItemsRow.visible = soon == ""
	if soon != "":
		return
	var featured_only: bool = (%TabFeatured as Button).button_pressed
	for spec in _boosters:
		if featured_only and not bool(spec.get("featured", false)):
			continue
		%ItemsRow.add_child(_make_item(spec))


func _make_item(spec: Dictionary) -> Control:
	var item := ITEM_SCENE.instantiate()
	(item.get_node("%Icon") as TextureRect).texture = UiTheme.tex(CHEST_ICON)
	(item.get_node("%Name") as Label).text = String(spec.get("name", "?"))
	(item.get_node("%Desc") as Label).text = String(spec.get("desc", ""))
	(item.get_node("%Price") as Label).text = UiTheme.fmt_thousands(int(spec.get("price", 0)))
	var buy := item.get_node("%BuyBtn") as Button
	buy.pressed.connect(_buy.bind(spec))
	buy.pressed.connect(UiTheme._click_sfx)
	return item


func _buy(spec: Dictionary) -> void:
	var ids := Game.open_booster(spec)
	if ids.is_empty():
		_toast("Or insuffisant ! (il vous faut %d)" % int(spec.get("price", 0)))
		return
	Audio.play_sfx("levelup")
	_reveal(ids)


## Révélation : les cartes tirées apparaissent une à une, les inédites (1er
## exemplaire) sont marquées « NOUVELLE ! ».
func _reveal(ids: Array) -> void:
	for child in %RevealRow.get_children():
		child.queue_free()
	%RevealOverlay.visible = true
	var delay := 0.15
	for id in ids:
		var def: CardDef = Db.card(StringName(String(id)))
		if def == null:
			continue
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		var w := CardWidget.create(def, 176.0)
		w.inspect_requested.connect(func(w2: CardWidget) -> void:
			CardPopup.open(self, w2.def))
		box.add_child(w)
		var tag := UiTheme.label("NOUVELLE !" if Game.owned_count(String(id)) == 1
				else "×%d possédées" % Game.owned_count(String(id)), 14,
				UiTheme.GOLD if Game.owned_count(String(id)) == 1 else Color(0.7, 0.68, 0.62))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tag)
		box.modulate.a = 0.0
		box.scale = Vector2(0.6, 0.6)
		%RevealRow.add_child(box)
		var tw := create_tween().set_parallel()
		tw.tween_property(box, "modulate:a", 1.0, 0.25).set_delay(delay)
		tw.tween_property(box, "scale", Vector2.ONE, 0.3).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.12


func _toast(msg: String) -> void:
	%ToastLabel.text = msg
	var t: Control = %Toast
	t.visible = true
	t.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(t, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void: t.visible = false)
