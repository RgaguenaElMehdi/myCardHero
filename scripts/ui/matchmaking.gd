extends Control
## Matchmaking search screen (Classé / Partie normale). Connects to the shared
## server and waits for a real opponent. If none is found within FALLBACK_SEC (or
## the server is unreachable), it silently drops in a random AI dressed up as a
## real player — the user isn't told. Ranked flag comes from Game.matchmaking_ranked.

const FALLBACK_SEC := 120.0        ## 2 minutes before falling back to an AI
const REVEAL_SEC := 1.2            ## brief "Adversaire trouvé !" before the battle

@onready var title: Label = %Title
@onready var status: Label = %Status
@onready var cancel_btn: Button = %CancelBtn

var _ranked := false
var _resolved := false
var _elapsed := 0.0
var _deadline := FALLBACK_SEC


func _ready() -> void:
	_ranked = Game.matchmaking_ranked
	title.text = "Partie classée" if _ranked else "Partie normale"
	UiTheme.style_button(cancel_btn, UiTheme.PANEL_LIGHT, 20)
	cancel_btn.pressed.connect(_cancel)

	Net.match_ready.connect(_on_found_real)
	Net.searching.connect(func() -> void:
		if not _resolved:
			status.text = "En file d'attente…")
	Net.connection_failed.connect(func(_r: String) -> void:
		_to_ai())                       # server issue → give them an AI game, disguised

	var err := Net.join(Net.MATCH_SERVER, Game.active_deck())
	if err != "":
		# server unreachable: still look like a search, then drop an AI in quickly
		_deadline = randf_range(4.0, 8.0)
	get_tree().create_timer(_deadline, false).timeout.connect(_to_ai)


func _process(delta: float) -> void:
	if _resolved:
		return
	_elapsed += delta
	var left := int(maxf(0.0, _deadline - _elapsed))
	status.text = "Recherche d'un adversaire…   (%d s)" % left


func _on_found_real(my_player: int) -> void:
	if _resolved:
		return
	_resolved = true
	Game.battle_config = {
		"mode": "online",
		"my_player": my_player,
		"ranked": _ranked,
		"ai_level": 0,
		"opponent_name": "Adversaire",
		"opponent_portrait": "",
		"background": "arena_day",
	}
	_reveal_then_battle()


func _to_ai() -> void:
	if _resolved:
		return
	_resolved = true
	Net.reset()
	Game.battle_config = Game.matchmaking_ai_config(_ranked)
	_reveal_then_battle()


func _reveal_then_battle() -> void:
	set_process(false)
	status.text = "Adversaire trouvé !"
	status.add_theme_color_override("font_color", UiTheme.OK)
	cancel_btn.disabled = true
	await get_tree().create_timer(REVEAL_SEC).timeout
	Game.goto("battle")


func _cancel() -> void:
	_resolved = true
	set_process(false)
	Net.reset()
	Game.goto("main_menu")
