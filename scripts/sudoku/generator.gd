extends RefCounted
## Seeded puzzle generator. The same variant, difficulty and seed always give
## the same puzzle. Every puzzle is proven unique by the solver.

const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Solver := preload("res://scripts/sudoku/solver.gd")
const Puzzle := preload("res://scripts/sudoku/puzzle.gd")

const DIFFICULTIES: PackedStringArray = ["easy", "medium", "hard"]
## Every level must be solvable by singles alone, and Hard must need hidden
## singles. Retry this many times before accepting the closest result.
const MAX_ATTEMPTS := 12


static func generate(variant: SudokuVariant, difficulty: String, puzzle_seed: int) -> Puzzle:
	var rng := RandomNumberGenerator.new()
	rng.seed = puzzle_seed
	var target: int = variant.clue_targets.get(difficulty, variant.clue_targets.get("medium", 0))

	var best: Puzzle = null
	for attempt in MAX_ATTEMPTS:
		var puzzle := _attempt(variant, target, rng)
		puzzle.difficulty = difficulty
		puzzle.seed = puzzle_seed
		if best == null or _fits(puzzle, difficulty):
			best = puzzle
		if _fits(puzzle, difficulty):
			break
	return best


## Rates a board from the stats of a fresh solve.
static func rate(stats: Dictionary) -> String:
	if stats.get("guesses", 0) > 0:
		return "expert"
	if stats.get("hidden_singles", 0) == 0:
		return "easy"
	return "medium"


static func _fits(puzzle: Puzzle, difficulty: String) -> bool:
	match difficulty:
		"easy", "medium":
			return puzzle.rating != "expert"
		"hard":
			return puzzle.rating == "medium"
	return true


static func _attempt(variant: SudokuVariant, target: int, rng: RandomNumberGenerator) -> Puzzle:
	var solved := _random_solution(variant, rng)
	var board: Board = Board.from_givens(variant, solved, solved)
	var checker := Solver.new(variant)

	var order := _shuffled_indices(variant.cell_count, rng)
	var clues := variant.cell_count
	for index in order:
		if clues <= target:
			break
		var digit: int = board.values[index]
		board.values[index] = 0
		if checker.count_solutions(board, 2) == 1:
			clues -= 1
		else:
			board.values[index] = digit

	var puzzle := Puzzle.new()
	puzzle.variant = variant
	puzzle.givens = board.values.duplicate()
	puzzle.solution = solved
	checker.solve(board)
	puzzle.stats = checker.stats()
	puzzle.rating = rate(puzzle.stats)
	return puzzle


static func _random_solution(variant: SudokuVariant, rng: RandomNumberGenerator) -> PackedByteArray:
	var solver := Solver.new(variant)
	var digits := _shuffled_indices(variant.digit_count, rng)
	solver.digit_order = PackedByteArray()
	for position in digits:
		solver.digit_order.append(position + 1)
	solver.cell_rank = _shuffled_indices(variant.cell_count, rng)
	return solver.solve(Board.new(variant))


static func _shuffled_indices(count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in count:
		result.append(index)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := result[i]
		result[i] = result[j]
		result[j] = swap
	return result
