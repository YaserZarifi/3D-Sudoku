extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")


func _board_with_given() -> Board:
	var variant := Variants.slice_sudoku(3)
	var clues := PackedByteArray()
	clues.resize(variant.cell_count)
	clues[0] = 5
	return Board.from_givens(variant, clues)


func test_set_and_clear() -> void:
	var board := _board_with_given()
	assert_true(board.set_value(1, 3))
	assert_eq(board.get_value(1), 3)
	assert_false(board.set_value(1, 3), "same digit is not a change")
	assert_true(board.clear_value(1))
	assert_true(board.is_empty(1))
	assert_false(board.clear_value(1))


func test_rejects_invalid_input() -> void:
	var board := _board_with_given()
	assert_false(board.set_value(0, 1), "givens are locked")
	assert_eq(board.get_value(0), 5)
	assert_false(board.set_value(1, 10))
	assert_false(board.set_value(1, -1))
	assert_false(board.set_value(27, 1))
	assert_false(board.set_value(-1, 1))
	assert_true(board.is_empty(1))


func test_latin_cube_digit_range() -> void:
	var board := Board.new(Variants.latin_cube(3))
	assert_false(board.set_value(0, 4))
	assert_true(board.set_value(0, 3))


func test_conflicts_blame_entries_only() -> void:
	var board := _board_with_given()
	# Cell 1 shares the x-row with the given 5 at cell 0.
	board.set_value(1, 5)
	assert_eq(Validator.conflicts(board), PackedInt32Array([1]))
	assert_true(Validator.is_conflict(board, 1))
	assert_false(Validator.is_conflict(board, 0))


func test_conflicts_between_entries() -> void:
	var board := Board.new(Variants.latin_cube(3))
	board.set_value(0, 2)
	board.set_value(2, 2)
	board.set_value(4, 2)
	assert_eq(Validator.conflicts(board), PackedInt32Array([0, 2]))


func test_empty_cells_never_conflict() -> void:
	var board := Board.new(Variants.slice_sudoku(3))
	assert_true(Validator.conflicts(board).is_empty())
	assert_false(Validator.is_complete(board))
	assert_false(Validator.is_solved(board))


func test_complete_with_conflict_is_not_solved() -> void:
	var board := Board.new(Variants.latin_cube(3))
	for index in board.variant.cell_count:
		board.set_value(index, 1)
	assert_true(Validator.is_complete(board))
	assert_false(Validator.is_solved(board))


func test_clear_entries_keeps_givens() -> void:
	var board := _board_with_given()
	board.set_value(4, 7)
	board.clear_entries()
	assert_eq(board.get_value(0), 5)
	assert_true(board.is_empty(4))


func test_duplicate_is_independent() -> void:
	var board := _board_with_given()
	var copy := board.duplicate_board()
	copy.set_value(3, 2)
	assert_true(board.is_empty(3))
