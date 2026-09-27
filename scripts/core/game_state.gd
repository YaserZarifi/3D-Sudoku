extends RefCounted
## Everything about the puzzle in progress: the board plus session data.
## Undo is a stack of {index, previous, next} moves, never board snapshots.
## A move that changed pencil marks also carries "notes": [[cell, old mask]].

const Variants := preload("res://scripts/sudoku/variants.gd")
const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")
const Puzzle := preload("res://scripts/sudoku/puzzle.gd")

const NO_SELECTION := -1
const MODE_CLASSIC := "classic"
const MODE_DAILY := "daily"
const MODE_TUTORIAL := "tutorial"
const MODES: PackedStringArray = [MODE_CLASSIC, MODE_DAILY, MODE_TUTORIAL]
const SAVE_VERSION := 2
## Oldest save format from_dict() still reads.
const MIN_SAVE_VERSION := 1

var board: Board
var difficulty: String = ""
var mode: String = MODE_CLASSIC
## Local date the daily puzzle belongs to, empty for other modes.
var date: String = ""
var puzzle_seed: int = 0
var selected: int = NO_SELECTION
var undo_stack: Array[Dictionary] = []
## Pencil marks per cell, as digit bitmasks (bit d set means d is noted).
var notes: PackedInt32Array
var elapsed: float = 0.0
var mistakes: int = 0
var hints_used: int = 0
var solved: bool = false


static func from_puzzle(puzzle: Puzzle) -> RefCounted:
	var state := new()
	state.board = puzzle.to_board()
	state.difficulty = puzzle.difficulty
	state.puzzle_seed = puzzle.seed
	state.notes.resize(state.board.variant.cell_count)
	return state


func variant() -> SudokuVariant:
	return board.variant


func has_selection() -> bool:
	return board.variant.is_valid_index(selected)


## Places a digit (0 erases) and records it for undo. Placing a digit also
## clears the cell's own notes and that digit from its peers' notes.
## Erasing a cell with no digit clears its notes. Returns whether anything
## changed.
func place(index: int, digit: int) -> bool:
	if solved or not board.variant.is_valid_index(index) or board.is_given(index):
		return false
	var previous := board.get_value(index)
	if digit == 0 and previous == 0:
		if notes[index] == 0:
			return false
		undo_stack.append({"index": index, "previous": 0, "next": 0, "notes": [[index, notes[index]]]})
		notes[index] = 0
		return true
	if not board.set_value(index, digit):
		return false

	var changed := []
	if notes[index] != 0:
		changed.append([index, notes[index]])
		notes[index] = 0
	if digit != 0:
		var bit := 1 << digit
		for peer in board.variant.peers[index]:
			if notes[peer] & bit != 0:
				changed.append([peer, notes[peer]])
				notes[peer] &= ~bit
	var move := {"index": index, "previous": previous, "next": digit}
	if not changed.is_empty():
		move["notes"] = changed
	undo_stack.append(move)
	if digit != 0 and Validator.is_conflict(board, index):
		mistakes += 1
	solved = Validator.is_solved(board)
	return true


## Adds or removes a pencil mark on an empty cell. Returns whether it changed.
func toggle_note(index: int, digit: int) -> bool:
	if solved or not board.variant.is_valid_index(index) or not board.variant.is_valid_digit(digit):
		return false
	if board.is_given(index) or board.get_value(index) != 0:
		return false
	undo_stack.append({"index": index, "previous": 0, "next": 0, "notes": [[index, notes[index]]]})
	notes[index] ^= 1 << digit
	return true


func has_note(index: int, digit: int) -> bool:
	return notes[index] & (1 << digit) != 0


## Reverts the last move. Returns the changed cell, or NO_SELECTION.
func undo() -> int:
	if undo_stack.is_empty() or solved:
		return NO_SELECTION
	var move: Dictionary = undo_stack.pop_back()
	var index: int = move["index"]
	board.set_value(index, move["previous"])
	for pair: Array in move.get("notes", []):
		notes[int(pair[0])] = int(pair[1])
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
	notes.fill(0)
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
		"mode": mode,
		"date": date,
		"seed": puzzle_seed,
		"givens": _givens_values(),
		"values": Array(board.values),
		"solution": Array(board.solution),
		"undo": undo_stack.duplicate(true),
		"notes": Array(notes),
		"elapsed": elapsed,
		"mistakes": mistakes,
		"hints_used": hints_used,
	}


## Rebuilds a state from to_dict() output. Returns null for anything that
## doesn't describe a consistent, solvable puzzle.
static func from_dict(data: Dictionary) -> RefCounted:
	var version := int(data.get("version", 0))
	if version < MIN_SAVE_VERSION or version > SAVE_VERSION:
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
	state.notes = _to_notes(data.get("notes"), variant)
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
				var clean := {
					"index": int(move["index"]),
					"previous": int(move["previous"]),
					"next": int(move["next"]),
				}
				var pairs := _to_note_pairs(move.get("notes"), variant)
				if not pairs.is_empty():
					clean["notes"] = pairs
				state.undo_stack.append(clean)
	state.difficulty = str(data.get("difficulty", ""))
	var saved_mode := str(data.get("mode", MODE_CLASSIC))
	state.mode = saved_mode if MODES.has(saved_mode) else MODE_CLASSIC
	state.date = str(data.get("date", ""))
	state.puzzle_seed = int(data.get("seed", 0))
	state.elapsed = maxf(float(data.get("elapsed", 0.0)), 0.0)
	state.mistakes = maxi(int(data.get("mistakes", 0)), 0)
	state.hints_used = maxi(int(data.get("hints_used", 0)), 0)
	for index in variant.cell_count:
		if state.board.values[index] != 0:
			state.notes[index] = 0
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


## Notes from a save, or all empty when missing or malformed. Marks on
## filled cells are dropped.
static func _to_notes(raw: Variant, variant: SudokuVariant) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(variant.cell_count)
	if not raw is Array or raw.size() != variant.cell_count:
		return result
	for index in variant.cell_count:
		var value: Variant = raw[index]
		if value is int or value is float:
			result[index] = int(value) & variant.all_digits_mask()
	return result


static func _to_note_pairs(raw: Variant, variant: SudokuVariant) -> Array:
	var pairs := []
	if not raw is Array:
		return pairs
	for pair: Variant in raw:
		if pair is Array and pair.size() == 2 and (pair[0] is int or pair[0] is float) and (pair[1] is int or pair[1] is float):
			if variant.is_valid_index(int(pair[0])):
				pairs.append([int(pair[0]), int(pair[1]) & variant.all_digits_mask()])
	return pairs


static func _to_bytes(raw: Variant, expected_size: int) -> PackedByteArray:
	var result := PackedByteArray()
	if not (raw is Array or raw is PackedByteArray) or raw.size() != expected_size:
		return result
	for value: Variant in raw:
		if not (value is int or value is float) or int(value) < 0 or int(value) > 255:
			return PackedByteArray()
		result.append(int(value))
	return result
