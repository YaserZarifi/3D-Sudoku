extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const CellStates := preload("res://scripts/board/cell_states.gd")


func _board() -> Board:
	var variant := Variants.slice_sudoku(3)
	var clues := PackedByteArray()
	clues.resize(variant.cell_count)
	clues[0] = 4
	return Board.from_givens(variant, clues)


func test_selection_marks_peers_only() -> void:
	var board := _board()
	var states := CellStates.compute(board, 13)
	assert_true(states[13]["is_selected"])
	assert_false(states[13]["is_peer"])
	var peer_count := 0
	for state in states:
		if state["is_peer"]:
			peer_count += 1
	assert_eq(peer_count, 18)


func test_same_digit_and_conflict() -> void:
	var board := _board()
	board.set_value(1, 4)
	board.set_value(26, 4)
	var states := CellStates.compute(board, 26)
	assert_true(states[0]["is_same_digit"])
	assert_true(states[1]["is_same_digit"])
	assert_false(states[26]["is_same_digit"], "the selected cell isn't its own match")
	assert_true(states[1]["is_conflict"])
	assert_false(states[0]["is_conflict"], "givens are never blamed")
	assert_true(states[0]["is_given"])


func test_no_selection() -> void:
	var states := CellStates.compute(_board(), -1)
	for state in states:
		assert_false(state["is_selected"] or state["is_peer"] or state["is_same_digit"])


func test_slice_focus_dims_other_layers() -> void:
	var board := _board()
	var variant := board.variant
	var states := CellStates.compute(board, -1, 2, 1)
	for index in variant.cell_count:
		assert_eq(states[index]["is_dimmed"], variant.coord_of(index).z != 1)
