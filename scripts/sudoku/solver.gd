extends RefCounted
## Deterministic solver: constraint propagation (naked and hidden singles)
## plus backtracking on the cell with the fewest candidates.
## Candidates are bitmasks where bit d means digit d is still possible.

const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Board := preload("res://scripts/sudoku/board.gd")

var variant: SudokuVariant
## Filled in by solve() and count_solutions().
var naked_singles: int = 0
var hidden_singles: int = 0
var guesses: int = 0
var max_depth: int = 0

## Order in which digits are tried when guessing. Ascending by default.
## The generator swaps in a seeded order to build random solved boards.
var digit_order: PackedByteArray
## Tie-break rank per cell when picking where to guess. Lower goes first.
## Identity by default; the generator shuffles it for structural variety.
var cell_rank: PackedInt32Array

var _limit: int = 1
var _found: int = 0
var _first_solution: PackedByteArray


func _init(solver_variant: SudokuVariant) -> void:
	variant = solver_variant
	for digit in range(1, variant.digit_count + 1):
		digit_order.append(digit)
	for index in variant.cell_count:
		cell_rank.append(index)


## Returns the first solution in search order, or an empty array.
func solve(board: Board) -> PackedByteArray:
	_run(board.values, 1)
	return _first_solution


## Counts completions, stopping early once `limit` is reached.
## Uniqueness is checked with limit = 2.
func count_solutions(board: Board, limit: int = 2) -> int:
	_run(board.values, limit)
	return _found


func has_unique_solution(board: Board) -> bool:
	return count_solutions(board, 2) == 1


## Solver stats as a dictionary, used by the difficulty rater.
func stats() -> Dictionary:
	return {
		"naked_singles": naked_singles,
		"hidden_singles": hidden_singles,
		"guesses": guesses,
		"max_depth": max_depth,
	}


## Candidate mask for one empty cell, from the digits its peers hold.
static func candidates_for(values: PackedByteArray, target_variant: SudokuVariant, index: int) -> int:
	if values[index] != 0:
		return 0
	var used := 0
	for peer in target_variant.peers[index]:
		used |= 1 << values[peer]
	return target_variant.all_digits_mask() & ~used


func _run(start_values: PackedByteArray, limit: int) -> void:
	naked_singles = 0
	hidden_singles = 0
	guesses = 0
	max_depth = 0
	_limit = maxi(limit, 1)
	_found = 0
	_first_solution = PackedByteArray()

	var values := start_values.duplicate()
	if values.size() != variant.cell_count or _has_clash(values):
		return
	var cands := PackedInt32Array()
	cands.resize(variant.cell_count)
	for index in variant.cell_count:
		cands[index] = candidates_for(values, variant, index)
	_search(values, cands, 0)


func _has_clash(values: PackedByteArray) -> bool:
	for index in variant.cell_count:
		var digit := values[index]
		if digit == 0:
			continue
		if digit > variant.digit_count:
			return true
		for peer in variant.peers[index]:
			if values[peer] == digit:
				return true
	return false


func _search(values: PackedByteArray, cands: PackedInt32Array, depth: int) -> void:
	max_depth = maxi(max_depth, depth)
	if not _propagate(values, cands):
		return

	var best := -1
	var best_count := variant.digit_count + 1
	for index in variant.cell_count:
		if values[index] == 0:
			var count := _bit_count(cands[index])
			if count < best_count or (count == best_count and cell_rank[index] < cell_rank[best]):
				best = index
				best_count = count
	if best == -1:
		_found += 1
		if _found == 1:
			_first_solution = values.duplicate()
		return

	for digit in digit_order:
		if cands[best] & (1 << digit) == 0:
			continue
		guesses += 1
		var next_values := values.duplicate()
		var next_cands := cands.duplicate()
		if _assign(next_values, next_cands, best, digit):
			_search(next_values, next_cands, depth + 1)
		if _found >= _limit:
			return


## Applies singles until nothing changes. Returns false on a contradiction.
func _propagate(values: PackedByteArray, cands: PackedInt32Array) -> bool:
	var progress := true
	while progress:
		progress = false
		for index in variant.cell_count:
			if values[index] != 0:
				continue
			var mask := cands[index]
			if mask == 0:
				return false
			if mask & (mask - 1) == 0:
				if not _assign(values, cands, index, _lowest_digit(mask)):
					return false
				naked_singles += 1
				progress = true
		if progress:
			continue

		for group in variant.groups:
			# Hidden singles only hold when the group must contain every digit.
			if group.size() != variant.digit_count:
				continue
			for digit in range(1, variant.digit_count + 1):
				var bit := 1 << digit
				var spot := -1
				var spots := 0
				var placed := false
				for index in group:
					if values[index] == digit:
						placed = true
						break
					if values[index] == 0 and cands[index] & bit != 0:
						spot = index
						spots += 1
				if placed:
					continue
				if spots == 0:
					return false
				if spots == 1:
					if not _assign(values, cands, spot, digit):
						return false
					hidden_singles += 1
					progress = true
	return true


func _assign(values: PackedByteArray, cands: PackedInt32Array, index: int, digit: int) -> bool:
	values[index] = digit
	cands[index] = 0
	var bit := 1 << digit
	for peer in variant.peers[index]:
		if values[peer] == digit:
			return false
		if values[peer] == 0 and cands[peer] & bit != 0:
			cands[peer] &= ~bit
			if cands[peer] == 0:
				return false
	return true


static func _bit_count(mask: int) -> int:
	var count := 0
	while mask != 0:
		mask &= mask - 1
		count += 1
	return count


static func _lowest_digit(mask: int) -> int:
	var digit := 0
	while mask & (1 << digit) == 0:
		digit += 1
	return digit
