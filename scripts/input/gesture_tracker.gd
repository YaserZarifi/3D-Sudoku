extends RefCounted
## Turns raw touch points into gestures: tap, double tap, drag and pinch.
## Pure logic with explicit timestamps, so it can be tested headless.
## Every call returns a list of gesture dictionaries with a "type" key.

const DOUBLE_TAP_SECONDS := 0.3
## A second tap counts as a double tap within this many tap thresholds.
const DOUBLE_TAP_RADIUS := 3.0
## Weight of the newest sample in the smoothed drag velocity.
const VELOCITY_SMOOTHING := 0.4
## A drag that stops this long before release has no inertia.
const VELOCITY_STALE_SECONDS := 0.08

enum Mode { IDLE, PENDING, DRAG, PINCH }

## Movement in pixels before a touch becomes a drag.
var tap_threshold := 12.0

var _mode := Mode.IDLE
var _points := {}
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _last_time := 0.0
var _velocity := Vector2.ZERO
var _pinch_distance := 0.0
var _last_tap_time := -1000.0
var _last_tap_position := Vector2.ZERO


func is_dragging() -> bool:
	return _mode == Mode.DRAG or _mode == Mode.PINCH


func touch_down(finger: int, position: Vector2, time: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_points[finger] = position
	if _points.size() == 1:
		_mode = Mode.PENDING
		_start = position
		_last = position
		_last_time = time
		_velocity = Vector2.ZERO
	elif _points.size() == 2:
		if _mode != Mode.DRAG:
			events.append({"type": "drag_start"})
		_mode = Mode.PINCH
		_pinch_distance = _finger_distance()
	return events


func touch_move(finger: int, position: Vector2, time: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _points.has(finger):
		return events
	_points[finger] = position
	match _mode:
		Mode.PENDING:
			if position.distance_to(_start) > tap_threshold:
				_mode = Mode.DRAG
				events.append({"type": "drag_start"})
				events.append(_drag(position, time))
		Mode.DRAG:
			events.append(_drag(position, time))
		Mode.PINCH:
			if _points.size() >= 2:
				var spread := _finger_distance()
				if _pinch_distance > 0.0 and spread > 0.0:
					events.append({"type": "pinch", "factor": spread / _pinch_distance})
				_pinch_distance = spread
	return events


func touch_up(finger: int, position: Vector2, time: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _points.has(finger):
		return events
	_points.erase(finger)
	match _mode:
		Mode.PENDING:
			if _points.is_empty():
				var is_double := time - _last_tap_time <= DOUBLE_TAP_SECONDS \
					and position.distance_to(_last_tap_position) <= tap_threshold * DOUBLE_TAP_RADIUS
				events.append({"type": "tap", "position": position, "double": is_double})
				# A double tap consumes the pair, so a third tap starts fresh.
				_last_tap_time = -1000.0 if is_double else time
				_last_tap_position = position
				_mode = Mode.IDLE
		Mode.DRAG:
			if _points.is_empty():
				var fresh := time - _last_time <= VELOCITY_STALE_SECONDS
				events.append({"type": "drag_end", "velocity": _velocity if fresh else Vector2.ZERO})
				_mode = Mode.IDLE
		Mode.PINCH:
			if _points.size() == 1:
				# The remaining finger keeps orbiting without a jump.
				_mode = Mode.DRAG
				_last = _points.values()[0]
				_last_time = time
				_velocity = Vector2.ZERO
			elif _points.is_empty():
				events.append({"type": "drag_end", "velocity": Vector2.ZERO})
				_mode = Mode.IDLE
	return events


## Forgets every touch, for example when the app loses focus.
func cancel() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_dragging():
		events.append({"type": "drag_end", "velocity": Vector2.ZERO})
	_points.clear()
	_mode = Mode.IDLE
	return events


func _drag(position: Vector2, time: float) -> Dictionary:
	var delta := position - _last
	var elapsed := time - _last_time
	if elapsed > 0.0:
		_velocity = _velocity.lerp(delta / elapsed, VELOCITY_SMOOTHING)
	_last = position
	_last_time = time
	return {"type": "drag", "delta": delta}


func _finger_distance() -> float:
	var positions: Array = _points.values()
	return (positions[0] as Vector2).distance_to(positions[1])
