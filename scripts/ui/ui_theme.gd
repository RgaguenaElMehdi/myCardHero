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
		"disabled": panel(base.darkened(0.4), 8),
	}


static func style_button(btn: Button, base: Color = PANEL_LIGHT, font_size: int = 20) -> void:
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
