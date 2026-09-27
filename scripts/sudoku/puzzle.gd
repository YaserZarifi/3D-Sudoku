extends RefCounted
## A generated puzzle: givens, the unique solution and how hard it rated.

const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Board := preload("res://scripts/sudoku/board.gd")

var variant: SudokuVariant
var givens: PackedByteArray
var solution: PackedByteArray
var difficulty: String = ""
var rating: String = ""
var seed: int = 0
var stats: Dictionary = {}


func clue_count() -> int:
	var count := 0
	for value in givens:
		if value != 0:
			count += 1
	return count


func to_board() -> Board:
	return Board.from_givens(variant, givens, solution)
