extends SceneTree
## Headless test runner with no addon dependencies.
## Usage: godot --headless --path . -s tests/run_tests.gd
## Finds every tests/**/test_*.gd, runs each test_* method on a fresh instance,
## and exits with code 1 if anything failed.

const TEST_ROOT := "res://tests"


func _initialize() -> void:
	var passed := 0
	var failed := 0

	for path in _find_test_files(TEST_ROOT):
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s (could not load)" % path)
			failed += 1
			continue

		for method_name in _test_methods(script):
			# Untyped so the failures property resolves at runtime.
			var test_case = script.new()
			test_case.call(method_name)
			if test_case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [path.get_file(), method_name])
				for message in test_case.failures:
					print("    " + message)

	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _find_test_files(directory: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name in DirAccess.get_files_at(directory):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			found.append(directory.path_join(file_name))
	for sub_directory in DirAccess.get_directories_at(directory):
		found.append_array(_find_test_files(directory.path_join(sub_directory)))
	found.sort()
	return found


func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names
