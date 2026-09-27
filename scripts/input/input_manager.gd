extends Control
## Transparent area over the board. Only touches that start here reach the
## board, so buttons laid over or around it keep their own input.
## Mouse input on desktop arrives as emulated touches (see project settings).

const GestureTracker := preload("res://scripts/input/gesture_tracker.gd")

## ~12 px at 160 dpi, scaled by screen density.
const TAP_THRESHOLD_DP := 12.0
const BASE_DPI := 160.0
const WHEEL_ZOOM_STEP := 1.1

signal tapped(screen_position: Vector2, is_double: bool)
signal orbit_started
signal orbited(delta: Vector2)
signal orbit_released(velocity: Vector2)
signal zoomed(factor: float)

var _tracker := GestureTracker.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tracker.tap_threshold = _threshold_in_canvas_pixels()
	resized.connect(func() -> void: _tracker.tap_threshold = _threshold_in_canvas_pixels())


func _gui_input(event: InputEvent) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var events: Array[Dictionary] = []
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var point := _to_viewport(touch.position)
		if touch.pressed:
			events = _tracker.touch_down(touch.index, point, now)
		elif touch.canceled:
			events = _tracker.cancel()
		else:
			events = _tracker.touch_up(touch.index, point, now)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		events = _tracker.touch_move(drag.index, _to_viewport(drag.position), now)
		accept_event()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomed.emit(WHEEL_ZOOM_STEP)
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomed.emit(1.0 / WHEEL_ZOOM_STEP)
			accept_event()
	elif event is InputEventMagnifyGesture:
		zoomed.emit((event as InputEventMagnifyGesture).factor)
		accept_event()
	_dispatch(events)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_dispatch(_tracker.cancel())


func _dispatch(events: Array[Dictionary]) -> void:
	for gesture in events:
		match gesture["type"]:
			"tap":
				tapped.emit(gesture["position"], gesture["double"])
			"drag_start":
				orbit_started.emit()
			"drag":
				orbited.emit(gesture["delta"])
			"drag_end":
				orbit_released.emit(gesture["velocity"])
			"pinch":
				zoomed.emit(gesture["factor"])


func _to_viewport(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position


func _threshold_in_canvas_pixels() -> float:
	var dpi := float(DisplayServer.screen_get_dpi())
	var physical := TAP_THRESHOLD_DP * maxf(dpi / BASE_DPI, 1.0)
	var stretch := get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	return physical / maxf(stretch, 0.01)
