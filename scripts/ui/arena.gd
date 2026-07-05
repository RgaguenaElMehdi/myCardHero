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
## Position/échelle du plateau peint dans l'arène (mêmes valeurs que le
## node BoardPlate ; exportées pour que cell_rect() reste pur calcul).
@export var board_pos := Vector2(312, 60)
@export var board_scale := 950.0 / 1050.0


## Rectangle écran d'une cellule sur la grille peinte.
func cell_rect(cell: Vector2i) -> Rect2:
	# Rangées ennemies en haut (rangée 3 d'abord), joueur en bas.
	var screen_row := 3 - cell.y
	var y0: float = grid_seps_y[screen_row]
	var y1: float = grid_seps_y[screen_row + 1]
	var t := ((y0 + y1) / 2.0 - grid_seps_y[0]) / (grid_seps_y[4] - grid_seps_y[0])
	var xl := lerpf(grid_xl_top, grid_xl_bot, t)
	var xr := lerpf(grid_xr_top, grid_xr_bot, t)
	var pitch := (xr - xl) / 3.0
	return Rect2(board_pos + Vector2(xl + cell.x * pitch, y0) * board_scale,
			Vector2(pitch, y1 - y0) * board_scale)
