extends Control
## "Combattre" popup: pick a mode. Emits a signal and closes; the menu handles it.
##   Classé / Partie normale → matchmaking (ranked flag differs).
##   Partie libre → vs AI.

signal chose_ranked
signal chose_normal
signal chose_free

@onready var ranked_btn: Button = %RankedBtn
@onready var normal_btn: Button = %NormalBtn
@onready var free_btn: Button = %FreeBtn
@onready var close_btn: Button = %CloseBtn


func _ready() -> void:
	# Touch sizing: widen the panel and thicken the rows on phones.
	var ts := UiTheme.touch_scale()
	if ts > 1.0:
		($Center/Panel/VBox as Control).custom_minimum_size = Vector2(1100, 0)
		for b: Button in [ranked_btn, normal_btn, free_btn]:
			b.custom_minimum_size = Vector2(0, 74 * ts)
		close_btn.custom_minimum_size = Vector2(0, 48 * ts)
		($Center/Panel/VBox/Title as Label).add_theme_font_size_override(
				"font_size", int(40 * ts))

	UiTheme.style_button(ranked_btn, UiTheme.GOLD.darkened(0.15), 22)
	UiTheme.style_button(normal_btn, UiTheme.ACCENT.darkened(0.2), 22)
	UiTheme.style_button(free_btn, UiTheme.OK.darkened(0.25), 22)
	UiTheme.style_button(close_btn, UiTheme.PANEL_LIGHT, 18)
	ranked_btn.pressed.connect(func() -> void: chose_ranked.emit(); queue_free())
	normal_btn.pressed.connect(func() -> void: chose_normal.emit(); queue_free())
	free_btn.pressed.connect(func() -> void: chose_free.emit(); queue_free())
	close_btn.pressed.connect(queue_free)
