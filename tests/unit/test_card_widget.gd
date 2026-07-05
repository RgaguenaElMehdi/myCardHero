extends TestCase
## card_widget.tscn s'instancie et se remplit sans erreur.

func _make_monster() -> CardDef:
	var d := CardDef.new()
	d.id = &"test_card"
	d.display_name = "Bête Test"
	d.guild = GameConst.Guild.SYLVAN
	d.kind = GameConst.CardKind.MONSTER
	d.cost = 3
	d.attack_type = GameConst.AttackType.MELEE
	d.levels = [{"atk": 2, "hp": 5}]
	d.keywords = {}
	return d

func test_spawn_fills_named_nodes() -> void:
	var scene: PackedScene = load("res://scenes/widgets/card_widget.tscn")
	ok(scene != null, "card_widget.tscn introuvable")
	if scene == null:
		return
	var w = scene.instantiate()
	w.setup(_make_monster())
	eq(w.get_node("%Name").text, "Bête Test", "nom rempli")
	eq(w.get_node("%Atk").text, "2", "atk rempli")
	eq(w.get_node("%Hp").text, "5", "hp rempli")
	w.free()
