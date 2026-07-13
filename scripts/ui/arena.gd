class_name BattleArena
extends Control
## Base commune des scènes d'arène (scenes/arenas/*.tscn). Porte le décor
## peint et la géométrie de la grille ; battle_scene.gd lui demande où sont
## les cellules au lieu de coder des constantes. Un nouveau thème = une
## nouvelle scène avec ce script, textures échangées, exports ajustés.

## Géométrie de la grille, en pixels texture du plateau peint (BoardPlate).
## Le plateau est un léger trapèze : bords gauche/droit interpolés haut→bas.
@export var grid_seps_y: Array[float] = [145.0, 340.0, 540.0, 745.0, 955.0]
@export var grid_xl_top := 270.0
@export var grid_xl_bot := 190.0
@export var grid_xr_top := 1165.0
@export var grid_xr_bot := 1245.0
## Variante « logements gravés » (arena_iso) : 8 valeurs = haut/bas de chaque
## rangée écran (autorise les espaces entre rangées et la ligne de front) ;
## grid_col_gap = espace horizontal entre deux logements. Si grid_rows_y est
## vide, on retombe sur grid_seps_y (rangées contiguës).
@export var grid_rows_y: Array[float] = []
@export var grid_col_gap := 0.0
## Position/échelle du plateau peint dans l'arène (mêmes valeurs que le
## node BoardPlate ; exportées pour que cell_rect() reste pur calcul).
@export var board_pos := Vector2(312, 60)
@export var board_scale := 950.0 / 1050.0


func _ready() -> void:
	_layout_deco_cells()
	resized.connect(_layout_deco_cells)
	# Vie ambiante : les nœuds décoratifs déclarés dans la scène s'animent ici.
	for child in get_children():
		if String(child.name).begins_with("Cloud"):
			_drift(child)
		elif String(child.name) == "Birds":
			_fly_birds(child)


## Nappe de brume : dérive lente en boucle à travers l'écran.
func _drift(c: Control) -> void:
	var speed := 26.0 + randf() * 18.0
	var tw := create_tween().set_loops()
	tw.tween_property(c, "position:x", 2620.0, 3440.0 / speed).from(-820.0)


## Nuée d'oiseaux lointains : traverse le ciel de temps en temps.
func _fly_birds(c: Control) -> void:
	var tw := create_tween().set_loops()
	tw.tween_interval(7.0 + randf() * 9.0)
	tw.tween_property(c, "position:x", 2620.0, 17.0).from(-220.0)


## Pose les cadres décoratifs Cell_<rangée écran>_<colonne> (déclarés dans la
## scène) sur la grille — la structure vit dans le .tscn, ici on ne fait que
## suivre la taille de la fenêtre.
func _layout_deco_cells() -> void:
	for r in 4:
		for c in 3:
			var n := get_node_or_null("Cell_%d_%d" % [r, c]) as Control
			if n == null:
				continue
			var rect := cell_rect(Vector2i(c, 3 - r))
			# marge généreuse entre cases : les unités respirent
			n.position = rect.position + Vector2(9, 7)
			n.size = rect.size - Vector2(18, 14)


## Rectangle écran d'une cellule sur la grille peinte.
## La géométrie est exprimée en pixels de la TEXTURE de fond ; elle est mappée
## à travers la même transformation "cover" que le TextureRect Environment
## (stretch KEEP_ASPECT_COVERED), pour rester calée quelle que soit la taille
## ou le ratio de la fenêtre.
func cell_rect(cell: Vector2i) -> Rect2:
	# Rangées ennemies en haut (rangée 3 d'abord), joueur en bas.
	var screen_row := 3 - cell.y
	var y0: float
	var y1: float
	var top: float
	var bot: float
	if grid_rows_y.size() == 8:
		y0 = grid_rows_y[screen_row * 2]
		y1 = grid_rows_y[screen_row * 2 + 1]
		top = grid_rows_y[0]
		bot = grid_rows_y[7]
	else:
		y0 = grid_seps_y[screen_row]
		y1 = grid_seps_y[screen_row + 1]
		top = grid_seps_y[0]
		bot = grid_seps_y[4]
	var t := ((y0 + y1) / 2.0 - top) / (bot - top)
	var xl := lerpf(grid_xl_top, grid_xl_bot, t)
	var xr := lerpf(grid_xr_top, grid_xr_bot, t)
	var w := (xr - xl - 2.0 * grid_col_gap) / 3.0
	var pos := board_pos + Vector2(xl + cell.x * (w + grid_col_gap), y0) * board_scale
	var sz := Vector2(w, y1 - y0) * board_scale
	var env := get_node_or_null("Environment") as TextureRect
	if env != null and env.texture != null:
		var ts := env.texture.get_size()
		var k := maxf(size.x / ts.x, size.y / ts.y)
		var off := (size - ts * k) / 2.0
		return Rect2(off + pos * k, sz * k)
	return Rect2(pos, sz)
