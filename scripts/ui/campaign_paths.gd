class_name CampaignPaths
extends Control
## Trace les chemins en pointillés reliant les niveaux de la carte (dessine sous
## les blasons, qui sont ses enfants). points remplis par campaign_scene.gd.

var points: PackedVector2Array = PackedVector2Array()
var done_upto := 0                        # nb de segments déjà parcourus (or vif)


func set_points(pts: PackedVector2Array, done: int) -> void:
	points = pts
	done_upto = done
	queue_redraw()


func _draw() -> void:
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var bright := i < done_upto
		var col := Color(0.98, 0.93, 0.72, 0.95) if bright else Color(0.86, 0.78, 0.55, 0.72)
		_dashed(a, b, col)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var dist := a.distance_to(b)
	var dir := (b - a).normalized()
	var dash := 20.0
	var gap := 14.0
	var t := 0.0
	while t < dist:
		var p0 := a + dir * t
		var p1 := a + dir * minf(t + dash, dist)
		# léger contour sombre pour lisibilité sur la carte claire
		draw_line(p0, p1, Color(0, 0, 0, 0.5), 8.0)
		draw_line(p0, p1, col, 5.0)
		t += dash + gap
