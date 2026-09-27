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


func test_notes_only_show_on_empty_cells() -> void:
	var board := _board()
	board.set_value(5, 3)
	var notes := PackedInt32Array()
	notes.resize(board.variant.cell_count)
	notes[5] = 1 << 2
	notes[6] = (1 << 1) | (1 << 9)
	var states := CellStates.compute(board, -1, CellStates.NO_FOCUS, 0, notes)
	assert_eq(states[5]["notes"], 0)
	assert_eq(states[6]["notes"], notes[6])
	assert_eq(CellStates.compute(board, -1)[6]["notes"], 0)


func test_notes_text_keeps_digit_positions() -> void:
	var Cell3D := load("res://scripts/board/cell_3d.gd")
	var space := " "
	var text: String = Cell3D.notes_text((1 << 1) | (1 << 5) | (1 << 9), 9, 3)
	assert_eq(text, "1 %s %s\n%s 5 %s\n%s %s 9" % [space, space, space, space, space, space])
	assert_eq(Cell3D.notes_text(1 << 2, 3, 3), "%s 2 %s" % [space, space])
