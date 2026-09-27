extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const HintFinder := preload("res://scripts/core/hint_finder.gd")


func _board(variant_id: String = Variants.SLICE_SUDOKU_ID, seed: int = 11) -> Board:
	var puzzle := Generator.generate(Variants.by_id(variant_id), "easy", seed)
	return puzzle.to_board()


func _first_empty(board: Board) -> int:
	for index in board.variant.cell_count:
		if board.is_empty(index):
			return index
	return -1


func test_wrong_entry_comes_first() -> void:
	var board := _board()
	var index := _first_empty(board)
	var wrong_digit := board.solution[index] % board.variant.digit_count + 1
	board.set_value(index, wrong_digit)
	var hint := HintFinder.find(board)
	assert_eq(hint["kind"], HintFinder.KIND_WRONG)
	assert_eq(hint["index"], index)
	assert_eq(hint["digit"], wrong_digit)


func test_hints_are_always_correct_and_finish_the_puzzle() -> void:
	for variant_id in Variants.all_ids():
		var board := _board(variant_id, 4)
		var steps := 0
		while true:
			var hint := HintFinder.find(board)
			if hint.is_empty():
				break
			assert_true(hint["kind"] != HintFinder.KIND_WRONG, variant_id)
			assert_eq(hint["digit"], board.solution[hint["index"]], variant_id)
			assert_true(board.is_empty(hint["index"]))
			assert_true(HintFinder.explain(hint, board.variant) != "")
			board.set_value(hint["index"], hint["digit"])
			steps += 1
			if steps > board.variant.cell_count:
				fail("hint loop did not finish")
				break
		assert_eq(board.values, board.solution, variant_id)


func test_easy_puzzles_never_need_a_reveal() -> void:
	var board := _board(Variants.SLICE_SUDOKU_ID, 8)
	while true:
		var hint := HintFinder.find(board)
		if hint.is_empty():
			break
		assert_true(hint["kind"] != HintFinder.KIND_REVEAL, "easy puzzles are solvable by singles")
		board.set_value(hint["index"], hint["digit"])


func test_selected_cell_wins_when_it_has_a_step() -> void:
	var board := _board()
	var first := HintFinder.find(board)
	var chosen := HintFinder.find(board, first["index"])
	assert_eq(chosen["index"], first["index"])


func test_describe_groups() -> void:
	var slice_variant := Variants.slice_sudoku(3)
	for group_id in slice_variant.groups.size():
		assert_eq(HintFinder.describe_group(slice_variant, group_id)["shape"], "slice")
	var part := HintFinder.describe_group(slice_variant, 1)
	var coord := slice_variant.coord_of(slice_variant.groups[1][0])
	assert_eq(coord[part["axis"]], part["layer"])
	var line_variant := Variants.latin_cube(3)
	for group_id in line_variant.groups.size():
		var line := HintFinder.describe_group(line_variant, group_id)
		assert_eq(line["shape"], "line")
		var a := line_variant.coord_of(line_variant.groups[group_id][0])
		var b := line_variant.coord_of(line_variant.groups[group_id][1])
		assert_true(a[line["axis"]] != b[line["axis"]], "a line runs along its axis")


func test_solved_board_has_no_hint() -> void:
	var board := _board()
	board.values = board.solution.duplicate()
	assert_eq(HintFinder.find(board), {})
