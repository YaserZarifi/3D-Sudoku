extends "res://tests/test_case.gd"

const Tutorial := preload("res://scripts/core/tutorial.gd")


func test_steps_advance_in_order() -> void:
	var tutorial := Tutorial.new()
	assert_eq(tutorial.step_id(), "turn")
	assert_false(tutorial.handle("select"), "events for later steps are ignored")
	for event in ["orbit", "select", "place_ok", "slice", "notes_on"]:
		assert_true(tutorial.handle(event), event)
	assert_eq(tutorial.step_id(), "finish")
	assert_true(tutorial.handle("solved"))
	assert_true(tutorial.is_finished())
	assert_eq(tutorial.text(), "")
	assert_false(tutorial.handle("solved"))


func test_conflict_shows_retry_text_once() -> void:
	var tutorial := Tutorial.new()
	tutorial.handle("orbit")
	tutorial.handle("select")
	var intro := tutorial.text()
	assert_true(tutorial.handle("place_conflict"))
	assert_true(tutorial.text() != intro)
	assert_false(tutorial.handle("place_conflict"))
	tutorial.handle("place_ok")
	assert_eq(tutorial.step_id(), "slice")


func test_jump_to() -> void:
	var tutorial := Tutorial.new()
	tutorial.jump_to("finish")
	assert_eq(tutorial.step_id(), "finish")
