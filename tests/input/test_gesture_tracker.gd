extends "res://tests/test_case.gd"

const GestureTracker := preload("res://scripts/input/gesture_tracker.gd")


func _types(events: Array[Dictionary]) -> PackedStringArray:
	var result := PackedStringArray()
	for event in events:
		result.append(event["type"])
	return result


func _tracker() -> GestureTracker:
	var tracker := GestureTracker.new()
	tracker.tap_threshold = 12.0
	return tracker


func test_short_touch_is_tap() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2(100, 100), 0.0)
	assert_eq(tracker.touch_move(0, Vector2(105, 104), 0.05).size(), 0)
	var events := tracker.touch_up(0, Vector2(105, 104), 0.1)
	assert_eq(_types(events), PackedStringArray(["tap"]))
	assert_false(events[0]["double"])


func test_moving_past_threshold_is_drag_not_tap() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2(100, 100), 0.0)
	var moved := tracker.touch_move(0, Vector2(120, 100), 0.05)
	assert_eq(_types(moved), PackedStringArray(["drag_start", "drag"]))
	assert_eq(moved[1]["delta"], Vector2(20, 0))
	assert_eq(_types(tracker.touch_move(0, Vector2(100, 100), 0.1)), PackedStringArray(["drag"]))
	var released := tracker.touch_up(0, Vector2(100, 100), 0.12)
	assert_eq(_types(released), PackedStringArray(["drag_end"]))


func test_quick_second_tap_is_double() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2(50, 50), 0.0)
	tracker.touch_up(0, Vector2(50, 50), 0.05)
	tracker.touch_down(0, Vector2(52, 51), 0.2)
	var events := tracker.touch_up(0, Vector2(52, 51), 0.25)
	assert_true(events[0]["double"])
	# A third tap right after starts a new pair.
	tracker.touch_down(0, Vector2(52, 51), 0.3)
	assert_false(tracker.touch_up(0, Vector2(52, 51), 0.35)[0]["double"])


func test_slow_second_tap_is_single() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2(50, 50), 0.0)
	tracker.touch_up(0, Vector2(50, 50), 0.05)
	tracker.touch_down(0, Vector2(50, 50), 0.8)
	assert_false(tracker.touch_up(0, Vector2(50, 50), 0.85)[0]["double"])


func test_pinch_reports_scale_and_never_taps() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2(100, 100), 0.0)
	assert_eq(_types(tracker.touch_down(1, Vector2(200, 100), 0.01)), PackedStringArray(["drag_start"]))
	var events := tracker.touch_move(1, Vector2(300, 100), 0.05)
	assert_eq(_types(events), PackedStringArray(["pinch"]))
	assert_true(is_equal_approx(events[0]["factor"], 2.0))
	assert_eq(tracker.touch_up(1, Vector2(300, 100), 0.1).size(), 0)
	# The finger left behind keeps orbiting from where it is.
	var drag := tracker.touch_move(0, Vector2(110, 100), 0.15)
	assert_eq(_types(drag), PackedStringArray(["drag"]))
	assert_eq(drag[0]["delta"], Vector2(10, 0))
	assert_eq(_types(tracker.touch_up(0, Vector2(110, 100), 0.2)), PackedStringArray(["drag_end"]))


func test_stale_drag_has_no_inertia() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2.ZERO, 0.0)
	tracker.touch_move(0, Vector2(50, 0), 0.02)
	tracker.touch_move(0, Vector2(100, 0), 0.04)
	var fast := tracker.touch_up(0, Vector2(100, 0), 0.05)
	assert_true((fast[0]["velocity"] as Vector2).x > 0.0)
	tracker.touch_down(0, Vector2.ZERO, 1.0)
	tracker.touch_move(0, Vector2(50, 0), 1.02)
	var held := tracker.touch_up(0, Vector2(50, 0), 1.5)
	assert_eq(held[0]["velocity"], Vector2.ZERO)


func test_cancel_ends_drag() -> void:
	var tracker := _tracker()
	tracker.touch_down(0, Vector2.ZERO, 0.0)
	tracker.touch_move(0, Vector2(40, 0), 0.02)
	assert_eq(_types(tracker.cancel()), PackedStringArray(["drag_end"]))
	assert_false(tracker.is_dragging())
