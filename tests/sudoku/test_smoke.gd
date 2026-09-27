extends "res://tests/test_case.gd"
## Proves the runner works. Remove once real engine tests exist.


func test_runner_executes_tests() -> void:
	assert_eq(1 + 1, 2)
	assert_true(true)
