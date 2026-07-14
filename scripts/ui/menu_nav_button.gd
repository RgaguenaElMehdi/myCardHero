@tool
extends "res://scripts/ui/ui_scale_button.gd"
## Bouton de navigation principale du menu (icône + titre + sous-titre).
## Style dans ui_theme.tres (MenuNavButton / MenuNavFeatured) — ici seulement
## l'application des propriétés exportées aux nœuds de la scène.

const TITLE_COLOR := Color(0.95, 0.88, 0.72)
const TITLE_FEATURED := Color(0.16, 0.11, 0.04)
const SUB_COLOR := Color(0.74, 0.7, 0.6)
const SUB_FEATURED := Color(0.35, 0.25, 0.1)

@export var title := "TITRE":
	set(v):
		title = v
		_apply()
@export var subtitle := "":
	set(v):
		subtitle = v
		_apply()
@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		_apply()
## Bouton mis en avant (plaque dorée, texte sombre) — ex. CAMPAGNE.
@export var featured := false:
	set(v):
		featured = v
		_apply()
## Taille de police du titre (0 = valeur de la scène) — tuiles compactes du hub.
@export var title_size := 0:
	set(v):
		title_size = v
		_apply()


func _ready() -> void:
	super()
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	theme_type_variation = &"MenuNavFeatured" if featured else &"MenuNavButton"
	%Title.text = title
	%Subtitle.text = subtitle
	%Subtitle.visible = not subtitle.is_empty()
	%Icon.texture = icon_texture
	%Title.add_theme_color_override("font_color",
			TITLE_FEATURED if featured else TITLE_COLOR)
	if title_size > 0:
		%Title.add_theme_font_size_override("font_size", title_size)
	%Subtitle.add_theme_color_override("font_color",
			SUB_FEATURED if featured else SUB_COLOR)
