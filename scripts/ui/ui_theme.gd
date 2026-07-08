class_name UiTheme
## Shared colors and style helpers for every scene. All UI chrome is built
## programmatically; generated art (assets/) provides the imagery.

# Palette dark fantasy (maquette) : anthracite chaud, or antique, rouge profond.
const BG := Color("15121a")
const PANEL := Color("201c26")
const PANEL_LIGHT := Color("2b2533")
const TEXT := Color("e8e4d8")
const TEXT_DIM := Color("a89f93")
const ACCENT := Color("58a6ff")
const GOLD := Color("e6c35a")
const DANGER := Color("a83a28")
const OK := Color("5aa864")

# Palette de faction : source unique dans GameConst (Règle des couleurs).
const GUILD_COLORS := GameConst.GUILD_COLORS

# UI chrome: pixel pack generated via tools/generate_ui_pack.py. Everything
# falls back to the flat style when a texture is missing.
const TEX_BANNER := "res://assets/sprites/ui/pixel/banner_ribbon.png"
const TEX_LOGO := "res://assets/sprites/ui/logo.png"
const TEX_PANEL := "res://assets/sprites/ui/pixel/panel_stone.png"
const TEX_BUTTON := "res://assets/sprites/ui/pixel/btn_primary.png"
const TEX_BUTTON_SECONDARY := "res://assets/sprites/ui/pixel/btn_secondary.png"
const TEX_BUTTON_DISABLED := "res://assets/sprites/ui/pixel/btn_disabled.png"
const TEX_VICTORY := "res://assets/sprites/ui/victory_bg.png"
const TEX_DEFEAT := "res://assets/sprites/ui/defeat_bg.png"

const FONT_TITLE := "res://assets/fonts/BoldPixels.ttf"
const FONT_DISPLAY := "res://assets/fonts/BoldPixels.ttf"


static func title_font() -> Font:
	return load(FONT_TITLE) if ResourceLoader.exists(FONT_TITLE) else null


static func display_font() -> Font:
	return load(FONT_DISPLAY) if ResourceLoader.exists(FONT_DISPLAY) else null


## Title text in the game's pixel face (BoldPixels), with a dark outline.
static func title_label(text: String, size: int = 32, color: Color = GOLD) -> Label:
	var l := label(text, size, color)
	var f := title_font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", int(size / 4.0))
	return l


## Ornate 9-slice stone panel (sliced from the mockup), tinted by `tint`.
static func panel_ornate(tint: Color = Color.WHITE) -> StyleBox:
	var tex := UiTheme.tex(TEX_PANEL)
	if tex == null:
		return panel(PANEL, 12)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := tex.get_width() * 0.06
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.modulate_color = tint
	return sb


static func _button_tex_style(tex_path: String, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = UiTheme.tex(tex_path)
	# The gold rim sits at the very edge after cropping; thin 9-slice border.
	var m := sb.texture.get_width() * 0.06
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	# Prevent visual from bleeding ABOVE the rect (would shift click area down).
	sb.expand_margin_left = 0
	sb.expand_margin_top = 0
	sb.expand_margin_right = 0
	sb.expand_margin_bottom = 0
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.modulate_color = tint
	return sb


static func _click_sfx() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio := tree.root.get_node_or_null("Audio")
	if audio != null:
		audio.play_sfx("click")


static func guild_color(guild: int) -> Color:
	return GUILD_COLORS.get(guild, ACCENT)


static func panel(color: Color = PANEL, radius: int = 10, border: Color = Color.TRANSPARENT,
		border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	return sb


## Flat HUD panel (mockup style): clean dark panel for HUD elements.
static func panel_flat(alpha: float = 0.94) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.125, 0.14, 0.17, alpha)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.36, 0.39, 0.45)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	return sb


## Flat HUD button (mockup style): clean dark button with colored tint.
static func style_button_flat(btn: Button, base: Color, font_size: int = 18) -> void:
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(6)
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		return sb
	btn.add_theme_stylebox_override("normal", mk.call(base, Color(0.55, 0.6, 0.7)))
	btn.add_theme_stylebox_override("hover", mk.call(base.lightened(0.12), Color(0.75, 0.8, 0.9)))
	btn.add_theme_stylebox_override("pressed", mk.call(base.darkened(0.2), Color(0.5, 0.55, 0.65)))
	btn.add_theme_stylebox_override("disabled",
			mk.call(Color(base.darkened(0.45), 0.6), Color(0.35, 0.38, 0.44)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", TEXT.darkened(0.45))
	btn.add_theme_font_size_override("font_size", font_size)
	var f := title_font()
	if f != null:
		btn.add_theme_font_override("font", f)
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	if not btn.pressed.is_connected(_click_sfx):
		btn.pressed.connect(_click_sfx)


static func button_style(base: Color) -> Dictionary:
	return {
		"normal": panel(base, 8),
		"hover": panel(base.lightened(0.12), 8),
		"pressed": panel(base.darkened(0.15), 8),
		"disabled": panel(Color(base.darkened(0.55), 0.55), 8),
	}


static func style_button(btn: Button, base: Color = PANEL_LIGHT, font_size: int = 20) -> void:
	if UiTheme.tex(TEX_BUTTON) != null:
		# The mockup buttons carry their own paint; the caller's base color only
		# picks the plate: reddish/danger -> secondary, anything else -> primary.
		var tex := TEX_BUTTON_SECONDARY \
				if (base.r > base.g + 0.06 and base.r > base.b + 0.06) else TEX_BUTTON
		btn.add_theme_stylebox_override("normal", _button_tex_style(tex, Color.WHITE))
		btn.add_theme_stylebox_override("hover",
				_button_tex_style(tex, Color(1.18, 1.18, 1.18)))
		btn.add_theme_stylebox_override("pressed",
				_button_tex_style(tex, Color(0.78, 0.78, 0.78)))
		btn.add_theme_stylebox_override("disabled",
				_button_tex_style(TEX_BUTTON_DISABLED, Color.WHITE))
	else:
		var styles := button_style(base)
		btn.add_theme_stylebox_override("normal", styles.normal)
		btn.add_theme_stylebox_override("hover", styles.hover)
		btn.add_theme_stylebox_override("pressed", styles.pressed)
		btn.add_theme_stylebox_override("disabled", styles.disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", TEXT.darkened(0.5))
	btn.add_theme_font_size_override("font_size", font_size)
	var f := title_font()
	if f != null:
		btn.add_theme_font_override("font", f)
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		btn.add_theme_constant_override("outline_size", 4)
	if not btn.pressed.is_connected(_click_sfx):
		btn.pressed.connect(_click_sfx)


## Toggle buttons: the pressed (selected) state reads clearly as golden.
static func style_toggle(btn: Button, base: Color = PANEL_LIGHT, font_size: int = 20) -> void:
	style_button(btn, base, font_size)
	if UiTheme.tex(TEX_BUTTON) != null:
		btn.add_theme_stylebox_override("pressed",
				_button_tex_style(TEX_BUTTON, GOLD.lerp(Color.WHITE, 0.6)))
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("pressed", panel(base.lightened(0.18), 8, GOLD, 3))
		btn.add_theme_color_override("font_pressed_color", Color("2a2410"))


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Makes every Control in a subtree ignore the mouse, so clicks always reach
## the interactive ancestor (card, cell...) in one click.
static func pass_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		pass_through(child)


## Loads a texture, returning null (not an error) when the asset is absent.
static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


## Small "icon + value" group (falls back to text-only when the icon is absent).
static func icon_label(icon_path: String, text: String, size: int, color: Color) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := tex(icon_path)
	if t != null:
		var icon := TextureRect.new()
		icon.texture = t
		icon.custom_minimum_size = Vector2(size + 2, size + 2)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		box.add_child(icon)
	box.add_child(label(text, size, color))
	return box

const ICON_STONE := "res://assets/sprites/ui/pixel/res_crystal.png"
