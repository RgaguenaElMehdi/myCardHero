class_name UiTheme
## Shared colors and style helpers for every scene. All UI chrome is built
## programmatically; generated art (assets/) provides the imagery.

const BG := Color("1b2130")
const PANEL := Color("252c3e")
const PANEL_LIGHT := Color("323b52")
const TEXT := Color("e8e4d8")
const TEXT_DIM := Color("a9b0c2")
const ACCENT := Color("58a6ff")
const GOLD := Color("e6c35a")
const DANGER := Color("e2603c")
const OK := Color("5aa864")

const GUILD_COLORS := {
	GameConst.Guild.FLAME: Color("e2603c"),
	GameConst.Guild.SYLVAN: Color("5aa864"),
	GameConst.Guild.SHADOW: Color("8b6bc7"),
	GameConst.Guild.LIGHT: Color("e6c35a"),
}

# Generated HQ chrome (assets/sprites/ui). Everything falls back to the flat
# style when a texture is missing.
const TEX_CARD_FRAME := "res://assets/sprites/ui/card_frame.png"
const TEX_PORTRAIT_RING := "res://assets/sprites/ui/portrait_ring.png"
const TEX_BANNER := "res://assets/sprites/ui/banner_ribbon.png"
const TEX_LOGO := "res://assets/sprites/ui/logo.png"
const TEX_CELL_TILE := "res://assets/sprites/ui/cell_tile.png"
const TEX_PANEL := "res://assets/sprites/ui/panel_ornate.png"
const TEX_BUTTON := "res://assets/sprites/ui/button_plate.png"
const TEX_VICTORY := "res://assets/sprites/ui/victory_bg.png"
const TEX_DEFEAT := "res://assets/sprites/ui/defeat_bg.png"

const FONT_TITLE := "res://assets/fonts/Cinzel.ttf"
const FONT_DISPLAY := "res://assets/fonts/CinzelDecorative-Bold.ttf"


static func title_font() -> Font:
	return load(FONT_TITLE) if ResourceLoader.exists(FONT_TITLE) else null


static func display_font() -> Font:
	return load(FONT_DISPLAY) if ResourceLoader.exists(FONT_DISPLAY) else null


## Title text in the game's serif face (Cinzel), with a dark outline.
static func title_label(text: String, size: int = 32, color: Color = GOLD) -> Label:
	var l := label(text, size, color)
	var f := title_font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", int(size / 4.0))
	return l


## Ornate 9-slice panel (generated texture), tinted by `tint`.
static func panel_ornate(tint: Color = Color.WHITE) -> StyleBox:
	var tex := UiTheme.tex(TEX_PANEL)
	if tex == null:
		return panel(PANEL, 12)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := tex.get_width() * 0.09
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


static func _button_tex_style(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = UiTheme.tex(TEX_BUTTON)
	# The gold rim sits at the very edge after cropping; thin 9-slice border.
	var m := sb.texture.get_width() * 0.035
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
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


static func button_style(base: Color) -> Dictionary:
	return {
		"normal": panel(base, 8),
		"hover": panel(base.lightened(0.12), 8),
		"pressed": panel(base.darkened(0.15), 8),
		"disabled": panel(Color(base.darkened(0.55), 0.55), 8),
	}


static func style_button(btn: Button, base: Color = PANEL_LIGHT, font_size: int = 20) -> void:
	if UiTheme.tex(TEX_BUTTON) != null:
		var tint := base.lerp(Color.WHITE, 0.62)
		btn.add_theme_stylebox_override("normal", _button_tex_style(tint))
		btn.add_theme_stylebox_override("hover", _button_tex_style(tint.lightened(0.22)))
		btn.add_theme_stylebox_override("pressed", _button_tex_style(tint.darkened(0.22)))
		btn.add_theme_stylebox_override("disabled",
				_button_tex_style(Color(tint.darkened(0.55), 0.5)))
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
	# Fire on press (not release): far more forgiving when the mouse moves
	# slightly during the click, and the whole UI feels snappier.
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	if not btn.pressed.is_connected(_click_sfx):
		btn.pressed.connect(_click_sfx)


## Toggle buttons: the pressed (selected) state reads clearly as golden.
static func style_toggle(btn: Button, base: Color = PANEL_LIGHT, font_size: int = 20) -> void:
	style_button(btn, base, font_size)
	if UiTheme.tex(TEX_BUTTON) != null:
		btn.add_theme_stylebox_override("pressed", _button_tex_style(GOLD.lerp(Color.WHITE, 0.25)))
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

const ICON_ATK := "res://assets/sprites/ui/icon_atk.png"
const ICON_HP := "res://assets/sprites/ui/icon_hp.png"
const ICON_STONE := "res://assets/sprites/ui/icon_stone.png"
const ICON_XP := "res://assets/sprites/ui/icon_xp.png"
