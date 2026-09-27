extends RefCounted
## Everything about the puzzle in progress: the board plus session data.
## Undo is a stack of {index, previous, next} moves, never board snapshots.

const Variants := preload("res://scripts/sudoku/variants.gd")
const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")
const Puzzle := preload("res://scripts/sudoku/puzzle.gd")

const NO_SELECTION := -1
const SAVE_VERSION := 1

var board: Board
var difficulty: String = ""
var puzzle_seed: int = 0
var selected: int = NO_SELECTION
var undo_stack: Array[Dictionary] = []
var elapsed: float = 0.0
var mistakes: int = 0
var hints_used: int = 0
var solved: bool = false


static func from_puzzle(puzzle: Puzzle) -> RefCounted:
	var state := new()
	state.board = puzzle.to_board()
	state.difficulty = puzzle.difficulty
	state.puzzle_seed = puzzle.seed
	return state


func variant() -> SudokuVariant:
	return board.variant


func has_selection() -> bool:
	return board.variant.is_valid_index(selected)


## Places a digit (0 erases) and records it for undo. Returns whether the
## board changed.
func place(index: int, digit: int) -> bool:
	if solved:
		return false
	var previous := board.get_value(index)
	if not board.set_value(index, digit):
		return false
	undo_stack.append({"index": index, "previous": previous, "next": digit})
	if digit != 0 and Validator.is_conflict(board, index):
		mistakes += 1
	solved = Validator.is_solved(board)
	return true


## Reverts the last move. Returns the changed cell, or NO_SELECTION.
func undo() -> int:
	if undo_stack.is_empty() or solved:
		return NO_SELECTION
	var move: Dictionary = undo_stack.pop_back()
	var index: int = move["index"]
	board.set_value(index, move["previous"])
	return index


## Fills one cell from the stored solution. Prefers the selected cell.
func hint() -> int:
	if solved or board.solution.size() != board.variant.cell_count:
		return NO_SELECTION
	var target := NO_SELECTION
	if has_selection() and not board.is_given(selected) and board.get_value(selected) != board.solution[selected]:
		target = selected
	else:
		for index in board.variant.cell_count:
			if not board.is_given(index) and board.get_value(index) != board.solution[index]:
				target = index
				break
	if target == NO_SELECTION:
		return NO_SELECTION
	hints_used += 1
	place(target, board.solution[target])
	return target


func restart() -> void:
	board.clear_entries()
	undo_stack.clear()
	selected = NO_SELECTION
	elapsed = 0.0
	mistakes = 0
	hints_used = 0
	solved = false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"variant": board.variant.id,
		"difficulty": difficulty,
		"seed": puzzle_seed,
		"givens": _givens_values(),
		"values": Array(board.values),
		"solution": Array(board.solution),
		"undo": undo_stack.duplicate(true),
		"elapsed": elapsed,
		"mistakes": mistakes,
		"hints_used": hints_used,
	}


## Rebuilds a state from to_dict() output. Returns null for anything that
## doesn't describe a consistent, solvable puzzle.
static func from_dict(data: Dictionary) -> RefCounted:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return null
	var variant := Variants.by_id(str(data.get("variant", "")))
	if variant == null:
		return null
	var givens := _to_bytes(data.get("givens"), variant.cell_count)
	var values := _to_bytes(data.get("values"), variant.cell_count)
	var solution := _to_bytes(data.get("solution"), variant.cell_count)
	if givens.is_empty() or values.is_empty() or solution.is_empty():
		return null

	var check := Board.from_givens(variant, solution)
	if not Validator.is_solved(check):
		return null
	var state := new()
	state.board = Board.from_givens(variant, givens, solution)
	for index in variant.cell_count:
		if givens[index] != 0:
			if givens[index] != solution[index] or values[index] != givens[index]:
				return null
		elif values[index] != 0 and not state.board.set_value(index, values[index]):
			return null

	var moves: Variant = data.get("undo", [])
	if moves is Array:
		for move: Variant in moves:
			if move is Dictionary and _valid_move(move, variant):
				state.undo_stack.append({
					"index": int(move["index"]),
					"previous": int(move["previous"]),
					"next": int(move["next"]),
				})
	state.difficulty = str(data.get("difficulty", ""))
	state.puzzle_seed = int(data.get("seed", 0))
	state.elapsed = maxf(float(data.get("elapsed", 0.0)), 0.0)
	state.mistakes = maxi(int(data.get("mistakes", 0)), 0)
	state.hints_used = maxi(int(data.get("hints_used", 0)), 0)
	state.solved = Validator.is_solved(state.board)
	return state


func _givens_values() -> Array:
	var result := []
	for index in board.variant.cell_count:
		result.append(board.values[index] if board.is_given(index) else 0)
	return result


static func _valid_move(move: Dictionary, variant: SudokuVariant) -> bool:
	for key in ["index", "previous", "next"]:
		if not move.has(key) or not (move[key] is int or move[key] is float):
			return false
	var digit_ok := func(value: int) -> bool: return value == 0 or variant.is_valid_digit(value)
	return variant.is_valid_index(int(move["index"])) and digit_ok.call(int(move["previous"])) and digit_ok.call(int(move["next"]))


static func _to_bytes(raw: Variant, expected_size: int) -> PackedByteArray:
	var result := PackedByteArray()
	if not (raw is Array or raw is PackedByteArray) or raw.size() != expected_size:
		return result
	for value: Variant in raw:
		if not (value is int or value is float) or int(value) < 0 or int(value) > 255:
			return PackedByteArray()
		result.append(int(value))
	return result
