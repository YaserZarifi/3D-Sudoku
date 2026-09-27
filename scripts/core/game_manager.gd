extends Node
## Owns the puzzle in progress. Presentation calls these methods with intents
## and reacts to the signals; nothing else edits the board.

const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")
const GameState := preload("res://scripts/core/game_state.gd")

signal game_started
signal selection_changed(index: int)
signal board_changed(changed_indices: PackedInt32Array)
## A digit was placed. `conflict` is true when it broke a rule.
signal digit_placed(index: int, conflict: bool)
signal puzzle_solved

var state: GameState
var paused := false


func new_game(variant_id: String, difficulty: String, puzzle_seed: int = -1) -> void:
	var variant := Variants.by_id(variant_id)
	if variant == null:
		variant = Variants.slice_sudoku(3)
	if puzzle_seed < 0:
		puzzle_seed = randi()
	start_with(GameState.from_puzzle(Generator.generate(variant, difficulty, puzzle_seed)))


func start_with(game_state: GameState) -> void:
	state = game_state
	paused = false
	game_started.emit()
	selection_changed.emit(state.selected)
	board_changed.emit(_all_indices())


func has_game() -> bool:
	return state != null


func is_playing() -> bool:
	return state != null and not state.solved and not paused


func select_index(index: int) -> void:
	if state == null or state.solved:
		return
	if not state.variant().is_valid_index(index):
		index = GameState.NO_SELECTION
	if index == state.selected:
		return
	state.selected = index
	selection_changed.emit(index)


func select_cell(coord: Vector3i) -> void:
	if state == null:
		return
	var variant := state.variant()
	select_index(variant.index_of_coord(coord) if variant.is_valid_coord(coord) else GameState.NO_SELECTION)


func deselect() -> void:
	select_index(GameState.NO_SELECTION)


func enter_digit(digit: int) -> void:
	if not is_playing() or not state.has_selection():
		return
	var index := state.selected
	if not state.place(index, digit):
		return
	var conflict := Validator.is_conflict(state.board, index)
	board_changed.emit(PackedInt32Array([index]))
	digit_placed.emit(index, conflict)
	_check_solved()


func erase() -> void:
	if not is_playing() or not state.has_selection():
		return
	if state.place(state.selected, 0):
		board_changed.emit(PackedInt32Array([state.selected]))


func undo() -> void:
	if not is_playing():
		return
	var index := state.undo()
	if index != GameState.NO_SELECTION:
		board_changed.emit(PackedInt32Array([index]))


func hint() -> void:
	if not is_playing():
		return
	var index := state.hint()
	if index == GameState.NO_SELECTION:
		return
	board_changed.emit(PackedInt32Array([index]))
	digit_placed.emit(index, false)
	_check_solved()


func restart() -> void:
	if state == null:
		return
	state.restart()
	paused = false
	selection_changed.emit(state.selected)
	board_changed.emit(_all_indices())


func set_paused(value: bool) -> void:
	paused = value


## How many copies of a digit are on the board, and how many a solved board has.
func digit_progress(digit: int) -> Vector2i:
	if state == null:
		return Vector2i.ZERO
	return Vector2i(state.board.count_digit(digit), state.variant().copies_per_digit())


func _process(delta: float) -> void:
	if is_playing():
		state.elapsed += delta


func _check_solved() -> void:
	if state.solved:
		state.selected = GameState.NO_SELECTION
		selection_changed.emit(state.selected)
		puzzle_solved.emit()


func _all_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in state.variant().cell_count:
		result.append(index)
	return result
