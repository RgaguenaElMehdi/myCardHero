extends Control
## Histogramme de courbe de coût (0 → 6+). Les 7 colonnes vivent dans la scène
## (cost_curve.tscn) ; ici on ne fait que régler hauteurs et compteurs.

const BAR_MAX := 52.0


## counts : 7 entiers (coût 0,1,2,3,4,5,6+).
func set_counts(counts: Array) -> void:
	var top := 1
	for c in counts:
		top = maxi(top, int(c))
	var cols := %Bars.get_children()
	for i in mini(7, cols.size()):
		var col: Control = cols[i]
		(col.get_node("Count") as Label).text = str(int(counts[i]))
		var bar: ColorRect = col.get_node("BarBox/Bar")
		bar.custom_minimum_size.y = maxf(3.0, BAR_MAX * int(counts[i]) / top)
		bar.modulate.a = 1.0 if int(counts[i]) > 0 else 0.35
