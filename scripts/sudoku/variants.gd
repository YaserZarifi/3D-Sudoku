extends RefCounted
## Factories for every playable tier. The only code that knows what a line
## or a slice is. Rules for each tier are in docs/game-rules.md.

const SudokuVariant := preload("res://scripts/sudoku/variant.gd")

const LATIN_CUBE_ID := "latin_cube_3"
const SLICE_SUDOKU_ID := "slice_sudoku_3"


static func by_id(variant_id: String) -> SudokuVariant:
	match variant_id:
		LATIN_CUBE_ID:
			return latin_cube(3)
		SLICE_SUDOKU_ID:
			return slice_sudoku(3)
	return null


static func all_ids() -> PackedStringArray:
	return PackedStringArray([LATIN_CUBE_ID, SLICE_SUDOKU_ID])


## Tier 1: every line along x, y and z holds 1..N once.
static func latin_cube(n: int) -> SudokuVariant:
	var variant := SudokuVariant.new("latin_cube_%d" % n, "Latin Cube", n, n)
	var groups: Array[PackedInt32Array] = []
	for a in n:
		for b in n:
			var along_x := PackedInt32Array()
			var along_y := PackedInt32Array()
			var along_z := PackedInt32Array()
			for i in n:
				along_x.append(variant.index_of(i, a, b))
				along_y.append(variant.index_of(a, i, b))
				along_z.append(variant.index_of(a, b, i))
			groups.append(along_x)
			groups.append(along_y)
			groups.append(along_z)
	variant.set_groups(groups)
	# Tier 1 is the tutorial, so even Hard leaves plenty of clues.
	variant.clue_targets = {"easy": 14, "medium": 10, "hard": 6}
	return variant


## Tier 2: every slice along x, y and z holds 1..N*N once.
static func slice_sudoku(n: int) -> SudokuVariant:
	var variant := SudokuVariant.new("slice_sudoku_%d" % n, "Slice Sudoku", n, n * n)
	var groups: Array[PackedInt32Array] = []
	for s in n:
		var slice_x := PackedInt32Array()
		var slice_y := PackedInt32Array()
		var slice_z := PackedInt32Array()
		for a in n:
			for b in n:
				slice_x.append(variant.index_of(s, a, b))
				slice_y.append(variant.index_of(a, s, b))
				slice_z.append(variant.index_of(a, b, s))
		groups.append(slice_x)
		groups.append(slice_y)
		groups.append(slice_z)
	variant.set_groups(groups)
	variant.clue_targets = {"easy": 16, "medium": 13, "hard": 10}
	return variant
