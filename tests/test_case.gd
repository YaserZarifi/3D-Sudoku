extends RefCounted
## Base class for tests run by tests/run_tests.gd.
## Test files extend this by path and define methods named test_*.

var failures: PackedStringArray = []


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail(message if message != "" else "Expected true")


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail(message if message != "" else "Expected false")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		var detail := "Expected %s, got %s" % [var_to_str(expected), var_to_str(actual)]
		fail(detail if message == "" else "%s (%s)" % [message, detail])


func fail(message: String) -> void:
	failures.append(message)
