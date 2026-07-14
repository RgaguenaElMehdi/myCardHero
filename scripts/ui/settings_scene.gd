extends Control
## Paramètres (mockup utilisateur, style bleu nuit/doré) : barre latérale
## d'onglets (Général / Audio / Graphismes / Compte), panneau central de
## réglages, panneau droit (aperçu, astuce, support/crédits/déconnexion).
## Structure dans settings[_mobile].tscn — logique ici.

const FPS_VALUES := [30, 60, 90, 120, 144, 0]   # 0 = illimité
const FPS_LABELS := ["30", "60", "90", "120", "144", "Illimité"]
const QUALITY_LABELS := ["Faible", "Moyenne", "Élevée", "Ultra"]
const DISPLAY_LABELS := ["Plein écran", "Fenêtré", "Sans bordure"]
const DEFAULTS := { "gfx_quality": 3, "display_mode": 1, "max_fps": 60,
		"vibrations": true, "tutorials": true, "power_saving": false,
		"music_volume": 0.8, "sfx_volume": 0.9 }

@onready var _navs: Dictionary = {
	"General": %NavGeneral, "Audio": %NavAudio,
	"Graphics": %NavGraphics, "Account": %NavAccount,
}
@onready var _pages: Dictionary = {
	"General": %PageGeneral, "Audio": %PageAudio,
	"Graphics": %PageGraphics, "Account": %PageAccount,
}


func _ready() -> void:
	for key in _navs:
		(_navs[key] as Button).pressed.connect(_show_tab.bind(key))
		(_navs[key] as Button).pressed.connect(UiTheme._click_sfx)

	_fill_options()
	_load_values()
	_wire_controls()

	(%CloseBtn as Button).pressed.connect(_close)
	(%DefaultsBtn as Button).pressed.connect(_restore_defaults)
	(%SaveBtn as Button).pressed.connect(func() -> void:
		Game.save_profile()
		Audio.play_sfx("levelup")
		_info("SAUVEGARDÉ", "Vos préférences ont été enregistrées."))
	(%SupportBtn as Button).pressed.connect(func() -> void:
		_info("SUPPORT", "Besoin d'aide ?\nConsultez le Guide du jeu depuis le menu principal."))
	(%CreditsBtn as Button).pressed.connect(func() -> void:
		_info("CRÉDITS", "Stonebound — un jeu de cartes tactique.\nCode, art et données : projet CardeHeroClone."))
	(%ResetProfileBtn as Button).pressed.connect(_on_reset_profile)
	(%InfoCloseBtn as Button).pressed.connect(func() -> void: %InfoPopup.visible = false)
	for b: Button in [%CloseBtn, %DefaultsBtn, %SaveBtn, %SupportBtn, %CreditsBtn,
			%ResetProfileBtn, %InfoCloseBtn]:
		b.pressed.connect(UiTheme._click_sfx)

	%VersionLabel.text = "Version %s" % str(ProjectSettings.get_setting(
			"application/config/version", "0.1"))
	_show_tab("General")


func _fill_options() -> void:
	var lang := %LangOption as OptionButton
	lang.clear()
	lang.add_item("Français")
	lang.disabled = true             # jeu en français uniquement pour l'instant
	for label in QUALITY_LABELS:
		(%QualityOption as OptionButton).add_item(label)
	for label in DISPLAY_LABELS:
		(%DisplayOption as OptionButton).add_item(label)
	for label in FPS_LABELS:
		(%FpsOption as OptionButton).add_item(label)


func _load_values() -> void:
	var s: Dictionary = Game.profile.settings
	_set_toggle(%TutoCheck, bool(s.get("tutorials", true)))
	_set_toggle(%VibrCheck, bool(s.get("vibrations", true)))
	_set_toggle(%PowerCheck, bool(s.get("power_saving", false)))
	(%QualityOption as OptionButton).selected = int(s.get("gfx_quality", 3))
	(%DisplayOption as OptionButton).selected = int(s.get("display_mode", 1))
	(%FpsOption as OptionButton).selected = maxi(FPS_VALUES.find(int(s.get("max_fps", 60))), 0)
	(%MusicSlider as HSlider).value = float(s.get("music_volume", 0.8))
	(%SfxSlider as HSlider).value = float(s.get("sfx_volume", 0.9))
	_update_pcts()


## Interrupteur maison (variation ToggleSwitch) : pilule bleue « ON » /
## sombre « OFF », le texte suit l'état.
func _set_toggle(btn: Button, on: bool) -> void:
	btn.set_pressed_no_signal(on)
	btn.text = "ON" if on else "OFF"


func _wire_toggle(btn: Button, apply: Callable) -> void:
	btn.toggled.connect(func(on: bool) -> void:
		btn.text = "ON" if on else "OFF"
		apply.call(on))


func _wire_controls() -> void:
	_wire_toggle(%TutoCheck, func(on: bool) -> void:
		Game.profile.settings.tutorials = on)
	_wire_toggle(%VibrCheck, func(on: bool) -> void:
		Game.profile.settings.vibrations = on)
	_wire_toggle(%PowerCheck, func(on: bool) -> void:
		Game.profile.settings.power_saving = on
		Game.set_max_fps(30 if on else FPS_VALUES[(%FpsOption as OptionButton).selected]))
	(%QualityOption as OptionButton).item_selected.connect(func(i: int) -> void:
		Game.profile.settings.gfx_quality = i)
	(%DisplayOption as OptionButton).item_selected.connect(func(i: int) -> void:
		Game.set_display_mode(i))
	(%FpsOption as OptionButton).item_selected.connect(func(i: int) -> void:
		Game.set_max_fps(FPS_VALUES[i]))
	(%MusicSlider as HSlider).value_changed.connect(func(v: float) -> void:
		Game.profile.settings.music_volume = v
		Audio.apply_settings()
		_update_pcts())
	(%SfxSlider as HSlider).value_changed.connect(func(v: float) -> void:
		Game.profile.settings.sfx_volume = v
		Audio.apply_settings()
		Audio.play_sfx("hit")
		_update_pcts())


func _update_pcts() -> void:
	%MusicPct.text = "%d%%" % roundi((%MusicSlider as HSlider).value * 100)
	%SfxPct.text = "%d%%" % roundi((%SfxSlider as HSlider).value * 100)


func _show_tab(key: String) -> void:
	for k in _pages:
		(_pages[k] as Control).visible = k == key
		(_navs[k] as Button).button_pressed = k == key


## Remet les RÉGLAGES à leurs valeurs par défaut (pas le profil).
func _restore_defaults() -> void:
	for k in DEFAULTS:
		Game.profile.settings[k] = DEFAULTS[k]
	Game.set_display_mode(int(DEFAULTS.display_mode))
	Game.set_max_fps(int(DEFAULTS.max_fps))
	Audio.apply_settings()
	_load_values()
	_info("PAR DÉFAUT", "Les réglages ont été rétablis à leurs valeurs d'origine.")


var _reset_armed := false


func _on_reset_profile() -> void:
	if not _reset_armed:
		_reset_armed = true
		(%ResetProfileBtn as Button).text = "CONFIRMER ?"
		return
	Game.reset_profile()
	_reset_armed = false
	(%ResetProfileBtn as Button).text = "RÉINITIALISÉ"
	(%ResetProfileBtn as Button).disabled = true


func _close() -> void:
	Game.save_profile()
	Game.goto("main_menu")


func _info(title: String, text: String) -> void:
	%InfoTitle.text = title
	%InfoLabel.text = text
	%InfoPopup.visible = true
