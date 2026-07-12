extends Control
## Paramètres (mockup utilisateur) : barre latérale d'onglets + panneau central de
## réglages + panneau droit. Onglet GÉNÉRAL = qualité, affichage, FPS, langue,
## vibrations, tutoriels, économie d'énergie. AUDIO = volumes. Les autres onglets
## sont des espaces réservés. Structure dans settings[_mobile].tscn — logique ici.

const FPS_VALUES := [30, 60, 90, 120, 144, 0]   # 0 = illimité
const NAV := ["General", "Graphics", "Audio", "Commands", "Language", "Account", "Others"]

@onready var pages: Dictionary = {
	"General": %PageGeneral, "Audio": %PageAudio, "Other": %PageOther,
}
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var lang_option: OptionButton = %LangOption
@onready var vibr_check: CheckButton = %VibrCheck
@onready var tuto_check: CheckButton = %TutoCheck
@onready var power_check: CheckButton = %PowerCheck
@onready var reset_btn: Button = %ResetBtn
@onready var save_btn: Button = %SaveBtn
@onready var help_btn: Button = %HelpBtn
@onready var back_btn: Button = %BackBtn
@onready var info_popup: PanelContainer = %InfoPopup

var _quality: Array[Button] = []
var _display: Array[Button] = []
var _fps: Array[Button] = []
var reset_armed := false


func _ready() -> void:
	var s: Dictionary = Game.profile.settings
	for i in 4:
		_quality.append(get_node("%%Q%d" % i))
	for i in 3:
		_display.append(get_node("%%D%d" % i))
	for i in 6:
		_fps.append(get_node("%%F%d" % i))

	# --- segments (radio visuel) ---
	_wire_segment(_quality, int(s.get("gfx_quality", 3)), func(i: int) -> void:
		Game.profile.settings.gfx_quality = i)
	_wire_segment(_display, int(s.get("display_mode", 1)), func(i: int) -> void:
		Game.set_display_mode(i))
	var fps_idx := FPS_VALUES.find(int(s.get("max_fps", 60)))
	_wire_segment(_fps, maxi(fps_idx, 0), func(i: int) -> void:
		Game.set_max_fps(FPS_VALUES[i]))

	# --- langue / toggles ---
	lang_option.clear()
	lang_option.add_item("Français")
	lang_option.disabled = true      # jeu en français uniquement pour l'instant
	vibr_check.button_pressed = bool(s.get("vibrations", true))
	tuto_check.button_pressed = bool(s.get("tutorials", true))
	power_check.button_pressed = bool(s.get("power_saving", false))
	vibr_check.toggled.connect(func(on: bool) -> void:
		Game.profile.settings.vibrations = on)
	tuto_check.toggled.connect(func(on: bool) -> void:
		Game.profile.settings.tutorials = on)
	power_check.toggled.connect(func(on: bool) -> void:
		Game.profile.settings.power_saving = on
		Game.set_max_fps(30 if on else int(FPS_VALUES[_selected(_fps)])))

	# --- audio ---
	music_slider.value = float(s.get("music_volume", 0.8))
	sfx_slider.value = float(s.get("sfx_volume", 0.9))
	music_slider.value_changed.connect(func(v: float) -> void:
		Game.profile.settings.music_volume = v
		Audio.apply_settings())
	sfx_slider.value_changed.connect(func(v: float) -> void:
		Game.profile.settings.sfx_volume = v
		Audio.apply_settings()
		Audio.play_sfx("hit"))

	# --- navigation onglets ---
	for name in NAV:
		var btn: Button = get_node("%%Nav%s" % name)
		btn.pressed.connect(_show_tab.bind(name))
		btn.pressed.connect(UiTheme._click_sfx)

	# --- boutons bas ---
	reset_btn.pressed.connect(_on_reset)
	save_btn.pressed.connect(_on_save)
	help_btn.pressed.connect(func() -> void:
		_info("ASSISTANCE", "Besoin d'aide ?\nContactez-nous ou consultez le Guide du jeu."))
	back_btn.pressed.connect(func() -> void: Game.goto("main_menu"))
	%InfoCloseBtn.pressed.connect(func() -> void: info_popup.visible = false)
	for b: Button in [reset_btn, save_btn, help_btn, back_btn]:
		b.pressed.connect(UiTheme._click_sfx)

	_show_tab("General")


## Radio visuel : surligne l'option choisie, connecte le changement.
func _wire_segment(btns: Array[Button], selected: int, on_pick: Callable) -> void:
	for i in btns.size():
		var idx := i
		btns[i].pressed.connect(func() -> void:
			_highlight(btns, idx)
			on_pick.call(idx)
			Audio.play_sfx("move"))
	_highlight(btns, selected)


func _highlight(btns: Array[Button], sel: int) -> void:
	for i in btns.size():
		btns[i].modulate = Color(1.35, 1.2, 0.7) if i == sel else Color(0.7, 0.68, 0.62)


func _selected(btns: Array[Button]) -> int:
	for i in btns.size():
		if btns[i].modulate.r > 1.0:
			return i
	return 0


func _show_tab(name: String) -> void:
	# Les onglets sans page dédiée montrent la page « Autres » (espace réservé).
	var page: String = name if pages.has(name) else "Other"
	for key in pages:
		pages[key].visible = key == page
	for n in NAV:
		var btn: Button = get_node("%%Nav%s" % n)
		btn.modulate = Color(1.3, 1.2, 0.85) if n == name else Color.WHITE


func _info(title: String, text: String) -> void:
	%InfoTitle.text = title
	%InfoLabel.text = text
	info_popup.visible = true


func _on_save() -> void:
	Game.save_profile()
	Audio.play_sfx("levelup")
	_info("SAUVEGARDÉ", "Vos préférences ont été enregistrées.")


func _on_reset() -> void:
	if not reset_armed:
		reset_armed = true
		reset_btn.text = "CONFIRMER ?"
		return
	Game.reset_profile()
	reset_armed = false
	reset_btn.text = "RÉINITIALISÉ"
	reset_btn.disabled = true
