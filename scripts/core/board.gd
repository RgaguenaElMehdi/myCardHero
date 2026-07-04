class_name Board
extends RefCounted
## The 3x4 battle grid. Rows 0-1 belong to player 0 (0 = back, 1 = front),
## rows 2-3 to player 1 (2 = front, 3 = back). Masters occupy a back-row cell;
## their positions live in PlayerState.master_col.

## Vector2i(col, row) -> MonsterInst
var cells: Dictionary = {}


static func back_row(player: int) -> int:
	return 0 if player == 0 else 3


static func front_row(player: int) -> int:
	return 1 if player == 0 else 2


static func row_owner(row: int) -> int:
	return 0 if row <= 1 else 1


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GameConst.BOARD_COLS \
		and cell.y >= 0 and cell.y < GameConst.BOARD_ROWS


static func master_cell(player: int, master_col: int) -> Vector2i:
	return Vector2i(master_col, back_row(player))


func at(cell: Vector2i) -> MonsterInst:
	return cells.get(cell)


func place(cell: Vector2i, monster: MonsterInst) -> void:
	assert(not cells.has(cell))
	cells[cell] = monster


func remove(cell: Vector2i) -> MonsterInst:
	var m: MonsterInst = cells.get(cell)
	cells.erase(cell)
	return m


func move(from: Vector2i, to: Vector2i) -> void:
	assert(cells.has(from) and not cells.has(to))
	cells[to] = cells[from]
	cells.erase(from)


func cell_of(monster: MonsterInst) -> Vector2i:
	for cell in cells:
		if cells[cell] == monster:
			return cell
	return Vector2i(-1, -1)


func monsters_of(player: int) -> Array[MonsterInst]:
	var result: Array[MonsterInst] = []
	for cell in cells:
		if (cells[cell] as MonsterInst).owner_idx == player:
			result.append(cells[cell])
	return result


func monster_cells_of(player: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if (cells[cell] as MonsterInst).owner_idx == player:
			result.append(cell)
	result.sort()
	return result


## Cells of `player`'s side where a monster may be summoned (empty, not the master's cell).
func summon_cells(player: int, master_col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var mcell := Board.master_cell(player, master_col)
	for row in [back_row(player), front_row(player)]:
		for col in GameConst.BOARD_COLS:
			var cell := Vector2i(col, row)
			if cell != mcell and not cells.has(cell):
				result.append(cell)
	return result


## Column cells of `defender` in the given column, ordered nearest-first from
## the attacker's perspective (front row before back row).
func defender_column_cells(defender: int, col: int) -> Array[Vector2i]:
	return [Vector2i(col, front_row(defender)), Vector2i(col, back_row(defender))]


## True if `player`'s monster in `cell` (back row) is blocked for melee by an
## ally in the front cell of the same column.
func melee_blocked(player: int, cell: Vector2i) -> bool:
	if cell.y != back_row(player):
		return false
	return cells.has(Vector2i(cell.x, front_row(player)))


## Number of `player` monsters in a column, optionally counting only monsters
## that provide cover against the given attack type (flying monsters give no
## cover against melee).
func column_cover(player: int, col: int, vs_melee: bool) -> int:
	var count := 0
	for cell in defender_column_cells(player, col):
		var m: MonsterInst = cells.get(cell)
		if m == null:
			continue
		if vs_melee and m.has_keyword(GameConst.KW_FLYING):
			continue
		count += 1
	return count
