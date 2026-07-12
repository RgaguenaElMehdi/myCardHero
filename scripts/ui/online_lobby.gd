extends Control
## Online lobby (Phase 1): host or join a 1v1 by IP, bring the active deck, and on
## match_ready jump into the battle scene in online mode. Structure in the .tscn;
## here only logic + Net signals. See docs/multiplayer-plan.md.

@onready var deck_label: Label = %DeckLabel
@onready var matchmake_btn: Button = %MatchmakeBtn
@onready var host_btn: Button = %HostBtn
@onready var ip_edit: LineEdit = %IpEdit
@onready var join_btn: Button = %JoinBtn
@onready var status_label: Label = %StatusLabel
@onready var back_btn: Button = %BackBtn


func _ready() -> void:
	UiTheme.style_button(matchmake_btn, UiTheme.GOLD.darkened(0.15), 24)
	UiTheme.style_button(host_btn, UiTheme.OK.darkened(0.2), 18)
	UiTheme.style_button(join_btn, UiTheme.ACCENT.darkened(0.2), 20)
	UiTheme.style_button(back_btn, UiTheme.PANEL_LIGHT, 18)

	var d := Game.active_deck()
	var m: MasterDef = Db.master(StringName(String(d.master)))
	deck_label.text = "Deck : %s%s" % [String(d.name),
			("  —  %s" % m.display_name) if m != null else ""]

	matchmake_btn.pressed.connect(_on_matchmake)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	Net.searching.connect(func() -> void:
		_set_status("Recherche d'un adversaire…", UiTheme.GOLD))
	back_btn.pressed.connect(func() -> void:
		Net.reset()
		Game.goto("main_menu"))

	Net.opponent_joined.connect(func() -> void:
		_set_status("Adversaire connecté — démarrage…", UiTheme.OK))
	Net.connection_failed.connect(func(r: String) -> void:
		_set_status(r, UiTheme.DANGER)
		_enable(true))
	Net.opponent_left.connect(func() -> void:
		_set_status("Adversaire déconnecté.", UiTheme.DANGER)
		_enable(true))
	Net.match_ready.connect(_on_match_ready)


## Matchmaking: connect to the shared server and wait to be paired (no IP typing).
func _on_matchmake() -> void:
	_enable(false)
	var err := Net.join(Net.MATCH_SERVER, Game.active_deck())
	if err != "":
		_set_status(err, UiTheme.DANGER)
		_enable(true)
	else:
		_set_status("Recherche d'un adversaire…", UiTheme.GOLD)


func _on_host() -> void:
	_enable(false)
	var err := Net.host(Game.active_deck())
	if err != "":
		_set_status(err, UiTheme.DANGER)
		_enable(true)
	else:
		_set_status("En attente d'un adversaire… (port %d)" % Net.DEFAULT_PORT, UiTheme.GOLD)


func _on_join() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	_enable(false)
	var err := Net.join(ip, Game.active_deck())
	if err != "":
		_set_status(err, UiTheme.DANGER)
		_enable(true)
	else:
		_set_status("Connexion à %s…" % ip, UiTheme.GOLD)


func _on_match_ready(my_player: int) -> void:
	Game.battle_config = {
		"mode": "online",
		"my_player": my_player,
		"ai_level": 0,
		"opponent_name": "Adversaire",
		"opponent_portrait": "",
		"background": "arena_day",
	}
	Game.goto("battle")


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _enable(on: bool) -> void:
	matchmake_btn.disabled = not on
	host_btn.disabled = not on
	join_btn.disabled = not on
	ip_edit.editable = on
