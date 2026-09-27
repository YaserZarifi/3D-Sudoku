extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")
const Solver := preload("res://scripts/sudoku/solver.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")


func test_puzzles_are_valid_and_unique() -> void:
	for variant_id in Variants.all_ids():
		var variant := Variants.by_id(variant_id)
		for difficulty in Generator.DIFFICULTIES:
			for puzzle_seed in [1, 42, 9001]:
				var puzzle := Generator.generate(variant, difficulty, puzzle_seed)
				var label := "%s %s %d" % [variant_id, difficulty, puzzle_seed]
				var board := puzzle.to_board()
				assert_true(Validator.conflicts(board).is_empty(), label)
				assert_eq(Solver.new(variant).count_solutions(board, 2), 1, label)
				assert_true(Validator.is_solved(Board.from_givens(variant, puzzle.solution)), label)
				assert_eq(Solver.new(variant).solve(board), puzzle.solution, label)
				_assert_givens_match_solution(puzzle.givens, puzzle.solution, label)


func test_same_seed_same_puzzle() -> void:
	var variant := Variants.slice_sudoku(3)
	var first := Generator.generate(variant, "medium", 1234)
	var second := Generator.generate(variant, "medium", 1234)
	assert_eq(first.givens, second.givens)
	assert_eq(first.solution, second.solution)


func test_different_seeds_differ() -> void:
	var variant := Variants.slice_sudoku(3)
	var seen := {}
	for puzzle_seed in 8:
		seen[Generator.generate(variant, "medium", puzzle_seed).solution] = true
	assert_true(seen.size() > 1, "generator should vary with the seed")


func test_easier_levels_need_no_guessing() -> void:
	for variant_id in Variants.all_ids():
		var variant := Variants.by_id(variant_id)
		for difficulty in ["easy", "medium"]:
			for puzzle_seed in 5:
				var puzzle := Generator.generate(variant, difficulty, puzzle_seed)
				assert_true(puzzle.rating != "expert", "%s %s %d" % [variant_id, difficulty, puzzle_seed])


func test_clue_count_respects_target() -> void:
	var variant := Variants.slice_sudoku(3)
	var puzzle := Generator.generate(variant, "easy", 7)
	assert_true(puzzle.clue_count() >= variant.clue_targets["easy"])


func _assert_givens_match_solution(givens: PackedByteArray, solution: PackedByteArray, label: String) -> void:
	for index in givens.size():
		if givens[index] != 0 and givens[index] != solution[index]:
			fail("%s: given at %d differs from solution" % [label, index])
			return


func test_hard_slice_puzzles_need_hidden_singles() -> void:
	var variant := Variants.slice_sudoku(3)
	for puzzle_seed in 5:
		assert_eq(Generator.generate(variant, "hard", puzzle_seed).rating, "medium")


func test_rating_from_stats() -> void:
	assert_eq(Generator.rate({"guesses": 1, "hidden_singles": 3}), "expert")
	assert_eq(Generator.rate({"guesses": 0, "hidden_singles": 0}), "easy")
	assert_eq(Generator.rate({"guesses": 0, "hidden_singles": 2}), "medium")
