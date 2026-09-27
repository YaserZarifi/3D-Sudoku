extends Node3D
## The game scene. Wires input, camera, board and UI to the GameManager.
## These pieces only talk through signals and never call each other.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const GameState := preload("res://scripts/core/game_state.gd")
const CellStates := preload("res://scripts/board/cell_states.gd")
const GameUi := preload("res://scripts/ui/game_ui.gd")

## Largest step, in radians, the camera takes to show a selected cell.
const SELECTION_ASSIST_ANGLE := 0.35

signal menu_requested

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _key_light: DirectionalLight3D = $KeyLight
@onready var _fill_light: DirectionalLight3D = $FillLight
@onready var _camera_rig: Node3D = $CameraRig
@onready var _board: Node3D = $Board3D
@onready var _game: Node = $GameManager
@onready var _ui: GameUi = $UI/GameUI

var _focus_axis := CellStates.NO_FOCUS
var _focus_layer := 0
var _celebrating := false


func _ready() -> void:
	_ui.digit_pressed.connect(_on_digit)
	_ui.erase_pressed.connect(_on_erase)
	_ui.undo_pressed.connect(_game.undo)
	_ui.hint_pressed.connect(_game.hint)
	_ui.pause_pressed.connect(_set_paused.bind(true))
	_ui.resume_pressed.connect(_set_paused.bind(false))
	_ui.restart_pressed.connect(_on_restart)
	_ui.new_game_pressed.connect(_on_new_game)
	_ui.menu_pressed.connect(_on_menu)
	_ui.reset_view_pressed.connect(_camera_rig.reset_view)
	_ui.slice_pressed.connect(_on_slice)
	_ui.board_area_changed.connect(_camera_rig.set_view_area)

	var board_input := _ui.board_input
	board_input.tapped.connect(_on_tap)
	board_input.orbit_started.connect(_board.set_exploded.bind(true))
	board_input.orbited.connect(_camera_rig.orbit)
	board_input.orbit_released.connect(_on_orbit_released)
	board_input.zoomed.connect(_camera_rig.zoom)

	_game.game_started.connect(_on_game_started)
	_game.selection_changed.connect(_on_selection_changed)
	_game.board_changed.connect(_on_board_changed)
	_game.digit_placed.connect(_on_digit_placed)
	_game.puzzle_solved.connect(_on_solved)

	ThemeManager.theme_changed.connect(_apply_palette)
	SaveManager.settings_changed.connect(_apply_motion_setting)
	_apply_palette()
	_apply_motion_setting()


func start_new(variant_id: String, difficulty: String) -> void:
	SaveManager.set_setting("last_variant", variant_id)
	SaveManager.set_setting("last_difficulty", difficulty)
	_game.new_game(variant_id, difficulty)
	SaveManager.record_start(_stats_key())
	_save()


## Returns false when the saved game can't be restored.
func resume(saved: Dictionary) -> bool:
	var state := GameState.from_dict(saved)
	if state == null or state.solved:
		SaveManager.clear_game()
		return false
	_game.start_with(state)
	return true


func _process(delta: float) -> void:
	if _game.has_game():
		_ui.set_time(_game.state.elapsed)
	if _celebrating:
		_board.rotate_y(TAU * ThemeTokens.SOLVED_SPIN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for digit in range(1, 10):
		if event.is_action("digit_%d" % digit):
			_on_digit(digit)
			get_viewport().set_input_as_handled()
			return
	if event.is_action("erase"):
		_on_erase()
	elif event.is_action("undo"):
		_game.undo()
	elif event.is_action("camera_reset"):
		_camera_rig.reset_view()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_save()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _game.has_game() and not _game.state.solved:
				_set_paused(not _game.paused)


func _on_game_started() -> void:
	var variant = _game.state.variant()
	_celebrating = false
	_board.rotation = Vector3.ZERO
	_board.build(variant, ThemeManager.palette)
	_board.reduced_motion = ThemeManager.reduced_motion()
	_camera_rig.frame_board(_board.extent())
	_camera_rig.reset_view()
	_focus_axis = CellStates.NO_FOCUS
	_focus_layer = 0
	var level: String = _game.state.difficulty.capitalize()
	_ui.setup(variant.digit_count, "%s · %s" % [variant.display_name, level] if level != "" else variant.display_name)
	_ui.set_slice(_focus_axis, _focus_layer, variant.size)
	_camera_rig.set_view_area(_ui.board_area())


func _on_tap(screen_position: Vector2, is_double: bool) -> void:
	if not _game.is_playing():
		return
	var camera: Camera3D = _camera_rig.get_camera()
	var hit: int = _board.pick(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if hit != _board.NO_CELL:
		_game.select_index(hit)
		AudioManager.play("select")
		HapticsManager.play("light")
	elif is_double:
		_camera_rig.reset_view()
	else:
		_game.deselect()


func _on_orbit_released(velocity: Vector2) -> void:
	_board.set_exploded(false)
	_camera_rig.release(velocity)


func _on_digit(digit: int) -> void:
	if digit > 0 and _game.has_game() and digit <= _game.state.variant().digit_count:
		_game.enter_digit(digit)


func _on_erase() -> void:
	if _game.is_playing() and _game.state.has_selection() and not _game.state.board.is_empty(_game.state.selected):
		_game.erase()
		AudioManager.play("erase")
		HapticsManager.play("light")


func _on_selection_changed(index: int) -> void:
	_refresh_board()
	if index >= 0:
		_assist_view(index)


func _on_board_changed(_changed: PackedInt32Array) -> void:
	_refresh_board()
	var variant = _game.state.variant()
	for digit in range(1, variant.digit_count + 1):
		var progress: Vector2i = _game.digit_progress(digit)
		_ui.set_digit_done(digit, progress.x >= progress.y)
	_ui.set_undo_enabled(not _game.state.undo_stack.is_empty())
	_save()


func _on_digit_placed(index: int, conflict: bool) -> void:
	if conflict:
		_board.shake_cell(index)
		AudioManager.play("conflict")
		HapticsManager.play("medium")
	else:
		_board.pop_cell(index)
		AudioManager.play("place")
		HapticsManager.play("light")


func _on_solved() -> void:
	var state: GameState = _game.state
	SaveManager.record_solve(_stats_key(), state.elapsed)
	SaveManager.clear_game()
	_focus_axis = CellStates.NO_FOCUS
	_refresh_board()
	_ui.set_slice(_focus_axis, 0, state.variant().size)
	AudioManager.play("solved")
	HapticsManager.play("success")
	await _board.play_solved_wave(ThemeTokens.SOLVED_WAVE_STEP)
	_celebrating = not ThemeManager.reduced_motion()
	await get_tree().create_timer(ThemeTokens.SOLVED_PANEL_DELAY).timeout
	if _game.state != state:
		return
	var summary := "Time %s" % GameUi.format_time(state.elapsed)
	summary += "\nMistakes %d" % state.mistakes
	if state.hints_used > 0:
		summary += "\nHints %d" % state.hints_used
	var best: float = SaveManager.stats().get(_stats_key(), {}).get("best_time", 0.0)
	if best > 0.0:
		summary += "\nBest %s" % GameUi.format_time(best)
	_ui.show_solved(true, summary)


func _on_slice(axis: int) -> void:
	if not _game.has_game():
		return
	var size: int = _game.state.variant().size
	if axis == _focus_axis:
		_focus_layer += 1
		if _focus_layer >= size:
			_focus_axis = CellStates.NO_FOCUS
			_focus_layer = 0
	else:
		_focus_axis = axis
		_focus_layer = 0
	_ui.set_slice(_focus_axis, _focus_layer, size)
	_refresh_board()


func _on_restart() -> void:
	_game.restart()
	_ui.show_pause(false)
	_save()


func _on_new_game() -> void:
	_ui.show_pause(false)
	_ui.show_solved(false)
	start_new(SaveManager.get_setting("last_variant"), SaveManager.get_setting("last_difficulty"))


func _on_menu() -> void:
	_save()
	menu_requested.emit()


func _set_paused(value: bool) -> void:
	if not _game.has_game() or _game.state.solved:
		return
	_game.set_paused(value)
	_ui.show_pause(value)
	if value:
		_save()


func _refresh_board() -> void:
	if not _game.has_game():
		return
	var state: GameState = _game.state
	if state.solved:
		_board.apply_states(CellStates.compute(state.board, GameState.NO_SELECTION))
		_board.show_solved()
		return
	_board.apply_states(CellStates.compute(state.board, state.selected, _focus_axis, _focus_layer))


## Eases the camera a little toward a selected cell that other cells hide
## from view. Never snaps, and leaves visible cells alone.
func _assist_view(index: int) -> void:
	var cell: Node3D = _board.cells[index]
	var eye: Vector3 = _camera_rig.get_camera().global_position
	if _board.pick(eye, cell.global_position - eye) == index:
		return
	var to_cell := cell.global_position - _board.global_position
	if to_cell.length() < 0.01:
		return
	_camera_rig.look_toward(to_cell.normalized(), SELECTION_ASSIST_ANGLE)


func _save() -> void:
	if _game.has_game() and not _game.state.solved:
		SaveManager.store_game(_game.state.to_dict())


func _stats_key() -> String:
	return "%s/%s" % [_game.state.variant().id, _game.state.difficulty]


func _apply_palette() -> void:
	var palette: Dictionary = ThemeManager.palette
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = palette["bg"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = ThemeTokens.AMBIENT_ENERGY
	_environment.environment = environment
	_key_light.light_energy = ThemeTokens.KEY_LIGHT_ENERGY
	_fill_light.light_energy = ThemeTokens.FILL_LIGHT_ENERGY
	if _board.variant != null:
		_board.set_palette(palette)
		_refresh_board()


func _apply_motion_setting() -> void:
	var reduced := ThemeManager.reduced_motion()
	_board.reduced_motion = reduced
	_camera_rig.reduced_motion = reduced
