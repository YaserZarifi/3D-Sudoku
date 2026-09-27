extends Node3D
## Orbit rig around the board. This node rotates (yaw, pitch) and the child
## camera sits at distance() along its local +z.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")

const DEFAULT_YAW := deg_to_rad(32.0)
const DEFAULT_PITCH := deg_to_rad(-24.0)
const PITCH_LIMIT := deg_to_rad(70.0)
## Radians of rotation per canvas pixel of drag.
const ORBIT_SENSITIVITY := 0.0065
## Inertia velocity decays by this factor per second.
const INERTIA_DAMPING := 7.0
const INERTIA_MIN_SPEED := 0.05
const MAX_INERTIA_SPEED := 9.0
## Radius the default view keeps clear around the board, as a multiple of its
## half width. A bit over sqrt(2) so corners never touch the edges.
const FIT_RADIUS_FACTOR := 1.55
## Zoom range relative to the default distance.
const MIN_ZOOM := 0.6
const MAX_ZOOM := 1.6
const HORIZONTAL_FOV := 40.0

var reduced_motion := false
var yaw := DEFAULT_YAW
var pitch := DEFAULT_PITCH
## 1.0 is the default framing. Distance is derived from it on every update,
## so the board stays framed when the screen area changes.
var zoom_level := 1.0

var _board_extent := 1.8
## Board area on screen, in canvas pixels. Empty means the whole viewport.
var _view_area := Rect2()
var _velocity := Vector2.ZERO
var _reset_tween: Tween
var _camera: Camera3D


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = HORIZONTAL_FOV
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_apply)
	_apply()


func get_camera() -> Camera3D:
	return _camera


func frame_board(board_extent: float) -> void:
	_board_extent = board_extent
	_apply()


func distance() -> float:
	return _default_distance() * zoom_level


## Tells the rig where on screen the board should sit and fit.
func set_view_area(area: Rect2) -> void:
	_view_area = area
	_apply()


func orbit(delta_pixels: Vector2) -> void:
	_stop_reset()
	_velocity = Vector2.ZERO
	yaw -= delta_pixels.x * ORBIT_SENSITIVITY
	pitch = clampf(pitch - delta_pixels.y * ORBIT_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	_apply()


## velocity_pixels is the drag speed at release, in canvas pixels per second.
func release(velocity_pixels: Vector2) -> void:
	if reduced_motion:
		return
	_velocity = (velocity_pixels * ORBIT_SENSITIVITY).limit_length(MAX_INERTIA_SPEED)


func zoom(factor: float) -> void:
	if factor <= 0.0:
		return
	_stop_reset()
	zoom_level = clampf(zoom_level / factor, MIN_ZOOM, MAX_ZOOM)
	_apply()


func reset_view() -> void:
	_velocity = Vector2.ZERO
	_stop_reset()
	var duration := ThemeTokens.motion(ThemeTokens.MOTION_SLOW, reduced_motion)
	_reset_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Take the short way round instead of unwinding every full turn.
	var goal_yaw := yaw + wrapf(DEFAULT_YAW - yaw, -PI, PI)
	_reset_tween.tween_method(_set_yaw, yaw, goal_yaw, duration)
	_reset_tween.tween_method(_set_pitch, pitch, DEFAULT_PITCH, duration)
	_reset_tween.tween_method(_set_zoom, zoom_level, 1.0, duration)


## Turns the rig around the vertical axis by at most max_angle, toward a
## horizontal direction. Pitch is left alone so the view never flattens out.
func look_toward(direction: Vector3, max_angle: float) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length() < 0.001:
		return
	var yaw_step := clampf(wrapf(atan2(flat.x, flat.y) - yaw, -PI, PI), -max_angle, max_angle)
	_stop_reset()
	var duration := ThemeTokens.motion(ThemeTokens.MOTION_SLOW, reduced_motion)
	_reset_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_reset_tween.tween_method(_set_yaw, yaw, yaw + yaw_step, duration)


func _process(delta: float) -> void:
	if _velocity.length() > INERTIA_MIN_SPEED:
		yaw -= _velocity.x * delta
		pitch = clampf(pitch - _velocity.y * delta, -PITCH_LIMIT, PITCH_LIMIT)
		_velocity *= exp(-INERTIA_DAMPING * delta)
		_apply()
	else:
		_velocity = Vector2.ZERO


## Distance at which the board fits inside the view area both ways.
func _default_distance() -> float:
	var radius := _board_extent * FIT_RADIUS_FACTOR
	var tan_half := tan(deg_to_rad(HORIZONTAL_FOV) * 0.5)
	var viewport_size := _viewport_size()
	var area := _area(viewport_size)
	if viewport_size.x <= 0.0 or area.size.x <= 0.0 or area.size.y <= 0.0:
		return radius / tan_half
	var by_width := radius / (tan_half * area.size.x / viewport_size.x)
	var by_height := radius / (tan_half * area.size.y / viewport_size.x)
	return maxf(by_width, by_height)


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO


func _area(viewport_size: Vector2) -> Rect2:
	return _view_area if _view_area.has_area() else Rect2(Vector2.ZERO, viewport_size)


func _set_yaw(value: float) -> void:
	yaw = value
	_apply()


func _set_pitch(value: float) -> void:
	pitch = value
	_apply()


func _set_zoom(value: float) -> void:
	zoom_level = value
	_apply()


func _stop_reset() -> void:
	if _reset_tween != null and _reset_tween.is_valid():
		_reset_tween.kill()


func _apply() -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	if _camera != null:
		_camera.position = Vector3(0.0, 0.0, distance())
		_update_offset()


## Shifts the image so the board sits in the middle of its screen area
## instead of the middle of the whole screen.
func _update_offset() -> void:
	if _camera == null:
		return
	var size := _viewport_size()
	if size.x <= 0.0:
		return
	var area := _area(size)
	var world_per_pixel := distance() * tan(deg_to_rad(HORIZONTAL_FOV) * 0.5) * 2.0 / size.x
	_camera.h_offset = (size.x * 0.5 - area.get_center().x) * world_per_pixel
	_camera.v_offset = (area.get_center().y - size.y * 0.5) * world_per_pixel
