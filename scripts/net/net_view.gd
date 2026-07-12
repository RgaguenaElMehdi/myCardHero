class_name NetView
## Perspective normalization for online play: makes each client see ITSELF as
## player 0 (its units at the bottom of the board), so battle_scene's built-in
## "player 0 = me" assumption holds for both sides unchanged.
##
## Every transform is an involution: viewer 0 = identity, viewer 1 mirrors the
## board (col → 2-col, row → 3-row) and swaps player indices. The client flips
## INCOMING server snapshots/events into its own frame, and flips its OUTGOING
## actions back to server coordinates with the very same functions.
## See docs/multiplayer-plan.md.


static func flip_cell(cell: Vector2i, viewer: int) -> Vector2i:
	if viewer == 1:
		return Vector2i(GameConst.BOARD_COLS - 1 - cell.x, GameConst.BOARD_ROWS - 1 - cell.y)
	return cell


static func flip_col(col: int, viewer: int) -> int:
	return (GameConst.BOARD_COLS - 1 - col) if viewer == 1 else col


static func flip_pidx(p: int, viewer: int) -> int:
	if p < 0:
		return p
	return (1 - p) if viewer == 1 else p


## Server-coords redacted snapshot dict → the viewer's own frame (viewer = index 0).
static func normalize_snapshot(snap: Dictionary, viewer: int) -> Dictionary:
	if viewer == 0:
		return snap
	var out := snap.duplicate(true)
	var pl: Array = out["players"]
	out["players"] = [pl[1], pl[0]]                 # I become player 0
	for p in out["players"]:
		p["master_col"] = flip_col(int(p["master_col"]), viewer)
	var nb: Array = []
	for e in out["board"]:
		var c: Array = e["c"]
		var fc := flip_cell(Vector2i(int(c[0]), int(c[1])), viewer)
		var m: Dictionary = e["m"].duplicate(true)
		m["owner"] = flip_pidx(int(m["owner"]), viewer)
		nb.append({ "c": [fc.x, fc.y], "m": m })
	out["board"] = nb
	out["current"] = flip_pidx(int(out.get("current", 0)), viewer)
	out["winner"] = flip_pidx(int(out.get("winner", -1)), viewer)
	return out


## Public event stream (server coords) → the viewer's frame.
static func flip_events(events: Array, viewer: int) -> Array:
	if viewer == 0:
		return events
	var out: Array = []
	for ev in events:
		out.append(_flip_spatial(ev, viewer))
	return out


## A single action (viewer's frame) → server coordinates.
static func flip_action(action: Dictionary, viewer: int) -> Dictionary:
	return _flip_spatial(action, viewer)


static func _flip_spatial(src: Dictionary, viewer: int) -> Dictionary:
	if viewer == 0:
		return src
	var d := src.duplicate(true)
	for k in ["cell", "from", "to", "target"]:
		if d.has(k) and d[k] is Vector2i:
			d[k] = flip_cell(d[k], viewer)
	if d.has("col"):
		d["col"] = flip_col(int(d["col"]), viewer)
	for k in ["player", "owner"]:
		if d.has(k):
			d[k] = flip_pidx(int(d[k]), viewer)
	return d
