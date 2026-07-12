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
	UiTheme.style_button(ranked_btn, UiTheme.GOLD.darkened(0.15), 22)
	UiTheme.style_button(normal_btn, UiTheme.ACCENT.darkened(0.2), 22)
	UiTheme.style_button(free_btn, UiTheme.OK.darkened(0.25), 22)
	UiTheme.style_button(close_btn, UiTheme.PANEL_LIGHT, 18)
	ranked_btn.pressed.connect(func() -> void: chose_ranked.emit(); queue_free())
	normal_btn.pressed.connect(func() -> void: chose_normal.emit(); queue_free())
	free_btn.pressed.connect(func() -> void: chose_free.emit(); queue_free())
	close_btn.pressed.connect(queue_free)
