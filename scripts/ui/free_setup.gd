extends Control
## Écran « Partie libre » : choix du Maître (liste de portraits à gauche,
## grand visuel au centre, compétence/attribut à droite) puis difficulté et
## lancement. Structure dans free_setup.tscn — ici, données et signaux.

signal launched(master_id: String, level: int)

const PICK_BTN := preload("res://scenes/widgets/master_pick_btn.tscn")

@onready var portrait_list: VBoxContainer = %PortraitList
@onready var master_art: TextureRect = %MasterArt
@onready var master_name: Label = %MasterName
@onready var master_lore: Label = %MasterLore
@onready var power_name: Label = %PowerName
@onready var power_desc: Label = %PowerDesc
@onready var passive_desc: Label = %PassiveDesc
@onready var card_btn: Button = %CardBtn
@onready var cancel_btn: Button = %CancelBtn
@onready var launch_btn: Button = %LaunchBtn
@onready var diff_buttons: Array[Button] = [%DiffNovice, %DiffAdept, %DiffMaster]

var _selected := ""
var _level := int(AiPlayer.Level.ADEPT)
var _pick_buttons: Dictionary = {}


func _ready() -> void:
	UiTheme.style_button(launch_btn, UiTheme.OK.darkened(0.2), 22)
	UiTheme.style_button(cancel_btn, UiTheme.PANEL_LIGHT, 18)
	UiTheme.style_button(card_btn, UiTheme.PANEL_LIGHT, 16)
	var diffs := [AiPlayer.Level.NOVICE, AiPlayer.Level.ADEPT, AiPlayer.Level.MASTER]
	for i in diff_buttons.size():
		var b := diff_buttons[i]
		UiTheme.style_toggle(b, UiTheme.PANEL_LIGHT, 18)
		b.pressed.connect(_on_diff.bind(int(diffs[i]), b))
	for mid in Game.profile.masters:
		var btn: Button = PICK_BTN.instantiate()
		btn.icon = UiTheme.tex(Db.master(StringName(String(mid))).portrait)
		UiTheme.style_toggle(btn, UiTheme.PANEL_LIGHT, 16)
		btn.pressed.connect(_select.bind(String(mid)))
		portrait_list.add_child(btn)
		_pick_buttons[String(mid)] = btn
	cancel_btn.pressed.connect(queue_free)
	card_btn.pressed.connect(func() -> void:
		CardPopup.open_master(self, Db.master(StringName(_selected))))
	launch_btn.pressed.connect(func() -> void:
		Game.profile.active_master = _selected
		Game.save_profile()
		launched.emit(_selected, _level))
	_select(String(Game.profile.active_master))


func _on_diff(level: int, pressed_btn: Button) -> void:
	_level = level
	for b in diff_buttons:
		b.set_pressed_no_signal(b == pressed_btn)


func _select(mid: String) -> void:
	_selected = mid
	var m := Db.master(StringName(mid))
	master_art.texture = UiTheme.tex("res://assets/sprites/cards_full/master_%s.png" % mid)
	master_name.text = m.display_name
	master_lore.text = m.lore
	power_name.text = "%s  (%d pierres)" % [m.power_name, m.power_cost]
	power_desc.text = m.power_desc
	passive_desc.text = m.passive_desc
	for id in _pick_buttons:
		(_pick_buttons[id] as Button).set_pressed_no_signal(id == mid)
