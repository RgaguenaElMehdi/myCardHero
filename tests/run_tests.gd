extends SceneTree
## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd
## Discovers tests/unit/*.gd, runs every test_* method on a fresh instance,
## prints a summary and exits non-zero on failure.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	if files.is_empty():
		push_error("No test files found in %s" % TEST_DIR)
	for f in Array(files):
		if not String(f).ends_with(".gd"):
			continue
		var script: GDScript = load(TEST_DIR + "/" + f)
		if script == null or not script.can_instantiate():
			failed += 1
			total += 1
			print("FAIL %s :: le script ne compile pas" % f)
			continue
		var names := {}
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				names[m.name] = true
		var sorted := names.keys()
		sorted.sort()
		for name in sorted:
			var t = script.new()
			t.call(name)
			total += 1
			if t.failures.is_empty():
				print("ok   %s :: %s" % [f, name])
			else:
				failed += 1
				print("FAIL %s :: %s" % [f, name])
				for msg in t.failures:
					print("     %s" % msg)
	print("")
	print("%d tests, %d échec(s)" % [total, failed])
	quit(1 if failed > 0 else 0)
