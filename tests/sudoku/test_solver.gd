extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")
const Solver := preload("res://scripts/sudoku/solver.gd")


## The construction from game-rules.md: triple (s, t) gets digit 3s + t + 1.
func _constructed_slice_solution() -> Board:
	var variant := Variants.slice_sudoku(3)
	var board := Board.new(variant)
	for s in 3:
		for t in 3:
			for i in 3:
				board.set_value(variant.index_of(i, (i + s) % 3, (i + t) % 3), s * 3 + t + 1)
	return board


func test_constructed_solution_is_valid() -> void:
	assert_true(Validator.is_solved(_constructed_slice_solution()))


func test_solves_full_board_from_partial() -> void:
	var solved := _constructed_slice_solution()
	var puzzle := solved.duplicate_board()
	for index in [0, 5, 13, 20, 26]:
		puzzle.clear_value(index)
	var solver := Solver.new(puzzle.variant)
	assert_eq(solver.solve(puzzle), solved.values)
	assert_eq(solver.count_solutions(puzzle, 2), 1)


func test_empty_board_has_many_solutions() -> void:
	for variant in [Variants.latin_cube(3), Variants.slice_sudoku(3)]:
		var board := Board.new(variant)
		var solver := Solver.new(variant)
		var solution := solver.solve(board)
		assert_eq(solution.size(), variant.cell_count)
		var check := Board.from_givens(variant, solution)
		assert_true(Validator.is_solved(check), variant.id)
		assert_eq(solver.count_solutions(board, 2), 2)


func test_no_solution_when_givens_clash() -> void:
	var variant := Variants.latin_cube(3)
	var board := Board.new(variant)
	board.set_value(0, 1)
	board.set_value(1, 1)
	var solver := Solver.new(variant)
	assert_eq(solver.solve(board).size(), 0)
	assert_eq(solver.count_solutions(board, 2), 0)


func test_no_solution_without_direct_clash() -> void:
	# Row (y=0, z=0) holds 1 and 2, so cell 2 must be 3, but its y-line already has 3.
	var variant := Variants.latin_cube(3)
	var board := Board.new(variant)
	board.set_value(variant.index_of(0, 0, 0), 1)
	board.set_value(variant.index_of(1, 0, 0), 2)
	board.set_value(variant.index_of(2, 1, 0), 3)
	var solver := Solver.new(variant)
	assert_eq(solver.count_solutions(board, 2), 0)


func test_solver_is_deterministic() -> void:
	var variant := Variants.slice_sudoku(3)
	var first := Solver.new(variant).solve(Board.new(variant))
	var second := Solver.new(variant).solve(Board.new(variant))
	assert_eq(first, second)


func test_stats_report_singles_without_guessing() -> void:
	var solved := _constructed_slice_solution()
	var puzzle := solved.duplicate_board()
	puzzle.clear_value(13)
	var solver := Solver.new(puzzle.variant)
	solver.solve(puzzle)
	assert_eq(solver.guesses, 0)
	assert_eq(solver.naked_singles + solver.hidden_singles, 1)


func test_candidates() -> void:
	var variant := Variants.latin_cube(3)
	var board := Board.new(variant)
	board.set_value(1, 2)
	var mask := Solver.candidates_for(board.values, variant, 0)
	assert_eq(mask, (1 << 1) | (1 << 3))
	assert_eq(Solver.candidates_for(board.values, variant, 1), 0)
