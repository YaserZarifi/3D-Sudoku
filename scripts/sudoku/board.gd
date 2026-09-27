extends RefCounted
## Mutable state of one puzzle. Invalid input is rejected before anything
## is written, so a board is never left half updated.

const SudokuVariant := preload("res://scripts/sudoku/variant.gd")

var variant: SudokuVariant
## One byte per cell, 0 means empty.
var values: PackedByteArray
## 1 where the cell is a given.
var givens: PackedByteArray
## The unique completion, stored with the puzzle. Empty when unknown.
var solution: PackedByteArray


func _init(board_variant: SudokuVariant) -> void:
	variant = board_variant
	values.resize(variant.cell_count)
	givens.resize(variant.cell_count)


## Builds a board whose non-zero values are all givens.
static func from_givens(board_variant: SudokuVariant, clue_values: PackedByteArray, solved: PackedByteArray = PackedByteArray()) -> RefCounted:
	var board := new(board_variant)
	if clue_values.size() != board_variant.cell_count:
		return board
	for index in board_variant.cell_count:
		var digit := clue_values[index]
		if board_variant.is_valid_digit(digit):
			board.values[index] = digit
			board.givens[index] = 1
	board.solution = solved.duplicate()
	return board


func get_value(index: int) -> int:
	return values[index] if variant.is_valid_index(index) else 0


func is_given(index: int) -> bool:
	return variant.is_valid_index(index) and givens[index] == 1


func is_empty(index: int) -> bool:
	return get_value(index) == 0


## Returns whether the board changed. Digit 0 clears the cell.
func set_value(index: int, digit: int) -> bool:
	if not variant.is_valid_index(index) or givens[index] == 1:
		return false
	if digit != 0 and not variant.is_valid_digit(digit):
		return false
	if values[index] == digit:
		return false
	values[index] = digit
	return true


func clear_value(index: int) -> bool:
	return set_value(index, 0)


## Removes every entry, keeping the givens.
func clear_entries() -> void:
	for index in variant.cell_count:
		if givens[index] == 0:
			values[index] = 0


func count_digit(digit: int) -> int:
	var count := 0
	for value in values:
		if value == digit:
			count += 1
	return count


func duplicate_board() -> RefCounted:
	var copy := new(variant)
	copy.values = values.duplicate()
	copy.givens = givens.duplicate()
	copy.solution = solution.duplicate()
	return copy
