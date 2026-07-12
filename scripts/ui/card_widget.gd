class_name CardWidget
extends PanelContainer
## Visual card (hand, deck builder, rewards, detail preview).
## Preferred path: displays the fully-composed card image built offline by
## tools/build_cards.py (frame + art + texts in one picture — nothing can
## overlap). Falls back to the scene-defined composite when the image is missing.

signal pressed(widget: CardWidget)
signal inspect_requested(widget: CardWidget)

var def: CardDef
var selected := false
var hovering := false
var _full := false


static func full_card_path(id: StringName) -> String:
	return "res://assets/sprites/cards_full/%s.png" % id


static func create(p_def: CardDef, width: float = 190.0) -> CardWidget:
	var w: CardWidget = load("res://scenes/widgets/card_widget.tscn").instantiate()
	w.def = p_def
	w.custom_minimum_size = Vector2(width, width * 1.385)
	w._setup()
	return w


## Compact hand format: cost gem, name, big art, ATQ/PV badges, keyword line.
## The full composed card stays one right-click away.
static func create_mini(p_def: CardDef, width: float = 156.0) -> CardWidget:
	var w: CardWidget = load("res://scenes/widgets/card_widget.tscn").instantiate()
	w.def = p_def
	w.custom_minimum_size = Vector2(width, width * 1.34)
	w._setup()
	return w


func _setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var evo_name := ""
	if def.evolves_to != &"":
		var tree := Engine.get_main_loop() as SceneTree
		var db = tree.root.get_node_or_null("Db") if tree != null else null
		if db != null and db.card(def.evolves_to) != null:
			evo_name = db.card(def.evolves_to).display_name
	tooltip_text = GameText.card_tooltip(def, evo_name)

	mouse_entered.connect(func() -> void:
		hovering = true
		_apply_style())
	mouse_exited.connect(func() -> void:
		hovering = false
		_apply_style())

	var full_tex := UiTheme.tex(CardWidget.full_card_path(def.id))
	_full = full_tex != null

	if _full:
		%FullArt.texture = full_tex
		%FullArt.visible = true
		%Frame.visible = false
		%Margin.visible = false
	else:
		var w := custom_minimum_size.x
		var frame_tex := UiTheme.tex(_guild_frame_path())
		if frame_tex != null:
			%Frame.texture = frame_tex
		%Cost.texture = UiTheme.tex(
				"res://assets/sprites/ui/pixel/gem_cost_%d.png" % mini(def.cost, 7))
		var name_fs := int(w * 0.092)
		if def.display_name.length() > 12:
			name_fs = int(w * 0.072)
		%Name.text = def.display_name
		%Name.add_theme_font_size_override("font_size", name_fs)
		%Art.texture = UiTheme.tex(def.art)
		var stat_fs := int(w * 0.082)
		if def.is_monster():
			%Atk.text = str(def.levels[0].atk)
			%Atk.add_theme_font_size_override("font_size", stat_fs)
			%Hp.text = str(def.levels[0].hp)
			%Hp.add_theme_font_size_override("font_size", stat_fs)
			var kw := GameText.keywords_line(def.keywords)
			if def.evolves_to != &"":
				kw = ("%s · Évolue" % kw) if kw != "" else "Évolue"
			%Keywords.text = kw
			%Keywords.add_theme_font_size_override("font_size", int(w * 0.070))
		else:
			%Bottom.visible = false
			%SpellDesc.text = GameText.describe_effect(def.effect)
			%SpellDesc.add_theme_font_size_override("font_size", int(w * 0.070))
			%SpellDesc.visible = true

	_apply_style()
	# Decorative children must never eat the click.
	UiTheme.pass_through(self)


func _guild_frame_path() -> String:
	match def.guild:
		GameConst.Guild.FLAME:  return "res://assets/sprites/ui/pixel/frame_flame.png"
		GameConst.Guild.SYLVAN: return "res://assets/sprites/ui/pixel/frame_sylvan.png"
		GameConst.Guild.SHADOW: return "res://assets/sprites/ui/pixel/frame_shadow.png"
		GameConst.Guild.LIGHT:  return "res://assets/sprites/ui/pixel/frame_light.png"
	return "res://assets/sprites/ui/card_frame.png"


func _apply_style() -> void:
	# Rarity now lives in the composed card frame (build_cards.py), not a runtime
	# glow. The widget only draws selection / hover state.
	var border := Color.TRANSPARENT
	var border_w := 0
	if selected:
		border = Color.WHITE
		border_w = 4
	elif hovering:
		border = UiTheme.GOLD
		border_w = 3
	elif not _full:
		# Dark bronze frame (mockup style) — the guild shows through the art.
		border = Color("554830")
		border_w = 2
	var bg := Color(0, 0, 0, 0.0) if _full else Color(0.09, 0.1, 0.12, 0.94)
	if hovering and not _full:
		bg = bg.lightened(0.07)
	var sb := UiTheme.panel(bg, 12, border, border_w)
	var m := 2.0 if _full else 8.0
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m
	sb.content_margin_bottom = m
	add_theme_stylebox_override("panel", sb)


func set_selected(on: bool) -> void:
	selected = on
	_apply_style()


## Shows "×n" (deck builder / rewards).
func set_count(n: int) -> void:
	%Count.text = "×%d" % n
	%Count.visible = n > 0


var _holding := false
var _long := false


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		inspect_requested.emit(self)            # desktop: right-click inspects
	elif event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_holding = true
			_long = false
			_long_press()
		else:
			_holding = false                    # released before the long-press fired
			if not _long:
				pressed.emit(self)              # quick tap / click = play / select


## Hold ~0.5 s (touch or mouse) to inspect — the touch equivalent of right-click.
func _long_press() -> void:
	await get_tree().create_timer(0.5).timeout
	if _holding:
		_long = true
		inspect_requested.emit(self)
	_holding = false
