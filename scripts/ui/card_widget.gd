class_name CardWidget
extends PanelContainer
## Carte visuelle (main, deck builder, aperçu). Structure déclarée dans
## scenes/widgets/card_widget.tscn ; ce script ne fait que remplir les données.

signal pressed(widget: CardWidget)
signal inspect_requested(widget: CardWidget)

const SCENE := preload("res://scenes/widgets/card_widget.tscn")

## Cadres pixel par faction (assets/sprites/ui/pixel).
const FRAMES := {
	GameConst.Guild.FLAME: preload("res://assets/sprites/ui/pixel/frame_flame.png"),
	GameConst.Guild.SYLVAN: preload("res://assets/sprites/ui/pixel/frame_sylvan.png"),
	GameConst.Guild.SHADOW: preload("res://assets/sprites/ui/pixel/frame_shadow.png"),
	GameConst.Guild.LIGHT: preload("res://assets/sprites/ui/pixel/frame_light.png"),
}

## Gemmes de coût 0..7 (7 = 7+), chiffre incrusté dans l'image.
const GEMS := [
	preload("res://assets/sprites/ui/pixel/gem_cost_0.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_1.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_2.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_3.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_4.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_5.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_6.png"),
	preload("res://assets/sprites/ui/pixel/gem_cost_7.png"),
]

var def: CardDef
var selected := false


## Chemin de la carte pré-composée (aperçu détaillé, guide). Conservé pour les
## appelants externes (card_popup, guide_scene).
static func full_card_path(id: StringName) -> String:
	return "res://assets/sprites/cards_full/%s.png" % id


## Instancie la scène-widget et la remplit. `width` fixe la largeur (hauteur ~x1.4).
static func spawn(p_def: CardDef, width: float = 150.0) -> CardWidget:
	var w := SCENE.instantiate()
	w.custom_minimum_size = Vector2(width, width * 1.4)
	w.setup(p_def)
	return w


func setup(p_def: CardDef) -> void:
	def = p_def
	mouse_filter = Control.MOUSE_FILTER_STOP
	%Frame.texture = FRAMES.get(def.guild, FRAMES[GameConst.Guild.FLAME])
	%Cost.texture = GEMS[clampi(def.cost, 0, 7)]
	%Name.text = def.display_name
	var art := UiTheme.tex(def.art)
	if art != null:
		%Art.texture = art
	if def.is_monster():
		%Atk.text = str(def.levels[0].get("atk", 0))
		%Hp.text = str(def.levels[0].get("hp", 0))
		%Keywords.text = GameText.keywords_line(def.keywords)
	else:
		%Atk.visible = false
		%Hp.visible = false
		%Keywords.text = GameText.describe_effect(def.effect)
	tooltip_text = GameText.card_tooltip(def, _evolution_name())
	# Les enfants décoratifs ne doivent jamais manger le clic.
	UiTheme.pass_through(self)


func _evolution_name() -> String:
	if def.evolves_to == &"":
		return ""
	var tree := Engine.get_main_loop() as SceneTree
	var db = tree.root.get_node_or_null("Db") if tree != null else null
	if db != null and db.card(def.evolves_to) != null:
		return db.card(def.evolves_to).display_name
	return ""


func set_selected(on: bool) -> void:
	selected = on
	# Liseré doré quand sélectionné (modulate du cadre — aucun StyleBox runtime).
	%Frame.modulate = Color(1.5, 1.35, 0.7) if on else Color.WHITE


## Affiche "×n" (deck builder / récompenses).
func set_count(n: int) -> void:
	%Count.text = "×%d" % n
	%Count.visible = n > 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			inspect_requested.emit(self)
