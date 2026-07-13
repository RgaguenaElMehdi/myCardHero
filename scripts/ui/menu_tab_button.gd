@tool
extends "res://scripts/ui/ui_scale_button.gd"
## Bouton de navigation secondaire du menu (icône au-dessus, libellé dessous,
## badge de notification optionnel). Style : variation MenuTabButton du thème.

@export var title := "ONGLET":
	set(v):
		title = v
		_apply()
@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		_apply()
## 0 = pas de badge affiché.
@export var badge_count := 0:
	set(v):
		badge_count = v
		_apply()


func _ready() -> void:
	super()
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	%TabLabel.text = title
	%TabIcon.texture = icon_texture
	%Badge.visible = badge_count > 0
	%BadgeLabel.text = str(badge_count)
