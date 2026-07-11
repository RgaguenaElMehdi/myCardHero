extends Control
## Écran « Partie libre » : choix du DECK actif (liste à gauche — chaque deck
## porte son maître ; grand visuel + compétence/attribut du maître au centre/
## droite), puis difficulté et lancement. Structure dans free_setup.tscn.

signal launched(master_id: String, level: int)

const PICK_BTN := preload("res://scenes/widgets/master_pick_btn.tscn")

@onready var portrait_list: VBoxContainer = %PortraitList
@onready var master_art: TextureRect = %MasterArt
@onready var deck_title: Label = %DeckTitle
@onready var master_name: Label = %MasterName
@onready var master_lore: Label = %MasterLore
@onready var power_name: Label = %PowerName
@onready var power_desc: Label = %PowerDesc
@onready var passive_desc: Label = %PassiveDesc
@onready var card_btn: Button = %CardBtn
@onready var cancel_btn: Button = %CancelBtn
@onready var launch_btn: Button = %LaunchBtn
@onready var diff_buttons: Array[Button] = [%DiffNovice, %DiffAdept, %DiffMaster]

var _sel_deck := 0
var _level := int(AiPlayer.Level.ADEPT)
var _deck_buttons: Array[Button] = []


func _ready() -> void:
	UiTheme.style_button(launch_btn, UiTheme.OK.darkened(0.2), 22)
	UiTheme.style_button(cancel_btn, UiTheme.PANEL_LIGHT, 18)
	UiTheme.style_button(card_btn, UiTheme.PANEL_LIGHT, 16)
	var diffs := [AiPlayer.Level.NOVICE, AiPlayer.Level.ADEPT, AiPlayer.Level.MASTER]
	for i in diff_buttons.size():
		var b := diff_buttons[i]
		UiTheme.style_toggle(b, UiTheme.PANEL_LIGHT, 18)
		b.pressed.connect(_on_diff.bind(int(diffs[i]), b))
	for i in Game.profile.decks.size():
		var d: Dictionary = Game.profile.decks[i]
		var m: MasterDef = Db.master(StringName(String(d.master)))
		var btn: Button = PICK_BTN.instantiate()
		if m != null:
			btn.icon = UiTheme.tex(m.portrait)
		btn.text = String(d.name)
		UiTheme.style_toggle(btn, UiTheme.PANEL_LIGHT, 16)
		btn.pressed.connect(_select.bind(i))
		portrait_list.add_child(btn)
		_deck_buttons.append(btn)
	cancel_btn.pressed.connect(queue_free)
	card_btn.pressed.connect(func() -> void:
		var m := Db.master(StringName(String(Game.profile.decks[_sel_deck].master)))
		if m != null:
			CardPopup.open_master(self, m))
	launch_btn.pressed.connect(func() -> void:
		Game.set_active_deck(_sel_deck)
		launched.emit(String(Game.profile.decks[_sel_deck].master), _level))
	_select(clampi(int(Game.profile.active_deck), 0, Game.profile.decks.size() - 1))


func _on_diff(level: int, pressed_btn: Button) -> void:
	_level = level
	for b in diff_buttons:
		b.set_pressed_no_signal(b == pressed_btn)


func _select(i: int) -> void:
	_sel_deck = i
	var d: Dictionary = Game.profile.decks[i]
	var m: MasterDef = Db.master(StringName(String(d.master)))
	deck_title.text = String(d.name)
	if m != null:
		master_art.texture = UiTheme.tex(
				"res://assets/sprites/cards_full/master_%s.png" % String(d.master))
		master_name.text = "Maître : %s (%s)" % [m.display_name,
				GameConst.GUILD_NAMES.get(m.guild, "")]
		master_lore.text = m.lore
		power_name.text = "%s  (%d pierres)" % [m.power_name, m.power_cost]
		power_desc.text = m.power_desc
		passive_desc.text = m.passive_desc
	for j in _deck_buttons.size():
		_deck_buttons[j].set_pressed_no_signal(j == i)
