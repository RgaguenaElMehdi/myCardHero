class_name CampaignNode
extends Control
## Un marqueur de niveau sur la carte de campagne (blason + icône + bandeau de
## nom + étoiles). Instancié par campaign_scene.gd (contenu dynamique).

signal chosen(index: int)

## Centre du blason dans le widget non mis à l'échelle (pour l'ancrage carte).
const SHIELD_CENTER := Vector2(110, 56)

@onready var ring: TextureRect = %Ring
@onready var field: TextureRect = %Field
@onready var shield: TextureRect = %Shield
@onready var icon: TextureRect = %Icon
@onready var lock: TextureRect = %Lock
@onready var stars: Label = %Stars
@onready var plate: Panel = %NamePlate
@onready var name_label: Label = %NameLabel
@onready var button: Button = %Button

var index := -1
var base_scale := 1.0


## state : "done" | "current" | "locked"
func setup(idx: int, title: String, icon_tex: Texture2D, state: String,
		color: Color) -> void:
	index = idx
	pivot_offset = SHIELD_CENTER
	name_label.text = title
	if title.length() > 20:
		name_label.add_theme_font_size_override("font_size", 14)
	icon.texture = icon_tex
	var locked := state == "locked"
	var done := state == "done"
	lock.visible = locked
	icon.visible = not locked
	ring.visible = false
	button.disabled = locked
	# Champ sombre, rebord or ; l'icône porte la couleur de guilde (mockup).
	if locked:
		field.modulate = Color(0.09, 0.09, 0.11)
		shield.modulate = Color(0.5, 0.47, 0.42)
		lock.modulate = Color(0.75, 0.7, 0.62)
		name_label.modulate = Color(0.62, 0.6, 0.64)
		plate.modulate = Color(0.7, 0.7, 0.72)
		stars.add_theme_color_override("font_color", Color(0.32, 0.31, 0.34))
	else:
		field.modulate = color.darkened(0.55) if done else color.darkened(0.45)
		shield.modulate = Color.WHITE
		icon.modulate = color.lerp(Color.WHITE, 0.45)
		stars.add_theme_color_override("font_color",
				Color(1.0, 0.8, 0.32) if done else Color(0.45, 0.44, 0.48))
	button.pressed.connect(func() -> void: chosen.emit(index))


func set_selected(on: bool) -> void:
	ring.visible = on
	# le niveau sélectionné est légèrement plus grand (mockup)
	scale = Vector2.ONE * base_scale * (1.18 if on else 1.0)
