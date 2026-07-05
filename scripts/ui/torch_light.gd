extends PointLight2D
## Vacillement de torche : somme de sinus désynchronisés sur l'énergie.

@export var base_energy := 1.1
@export var flicker := 0.3

var _t := randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	energy = base_energy + flicker * (
			sin(_t * 7.3) * 0.5 + sin(_t * 13.1 + 1.7) * 0.3 + sin(_t * 3.7) * 0.2)
