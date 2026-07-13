@tool
extends Button
## Retour visuel commun des boutons du menu : léger zoom au survol (desktop)
## et rétrécissement à la pression (immédiat, donc adapté au tactile).
## Aucune dépendance au survol : le tactile ne voit que button_down/up.

var _fx_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	mouse_entered.connect(func() -> void: _zoom(1.03, 0.12))
	mouse_exited.connect(func() -> void: _zoom(1.0, 0.12))
	button_down.connect(func() -> void: _zoom(0.96, 0.07))
	button_up.connect(func() -> void: _zoom(1.0, 0.1))


func _zoom(target: float, dur: float) -> void:
	if _fx_tween:
		_fx_tween.kill()
	_fx_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(self, "scale", Vector2.ONE * target, dur)
