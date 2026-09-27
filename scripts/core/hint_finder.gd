extends RefCounted
## Finds the next step a player could reason out, and says why, so a hint
## teaches instead of just filling a cell. Checked in this order:
## a wrong entry, a cell with one candidate (naked single), a digit with one
## spot left in a group (hidden single), then a plain reveal.

const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const Solver := preload("res://scripts/sudoku/solver.gd")

const KIND_WRONG := "wrong"
const KIND_NAKED := "naked"
const KIND_HIDDEN := "hidden"
const KIND_REVEAL := "reveal"
const AXIS_NAMES: PackedStringArray = ["X", "Y", "Z"]


## Returns {} when the board is solved or has no stored solution. Otherwise
## {"kind", "index", "digit", "group"} where group is -1 unless the reason
## is a single group. Steps in the selected cell win ties.
static func find(board: Board, selected: int = -1) -> Dictionary:
	var variant := board.variant
	if board.solution.size() != variant.cell_count:
		return {}

	var wrong := _pick(board, selected, func(i: int) -> bool:
		return not board.is_given(i) and board.values[i] != 0 and board.values[i] != board.solution[i])
	if wrong != -1:
		return _hint(KIND_WRONG, wrong, board.values[wrong], -1)

	# Reason only from digits that are known to be right.
	var clean := board.values.duplicate()
	var empty := PackedInt32Array()
	for index in variant.cell_count:
		if clean[index] != 0 and clean[index] != board.solution[index]:
			clean[index] = 0
		if clean[index] == 0:
			empty.append(index)
	if empty.is_empty():
		return {}

	var cands := {}
	for index in empty:
		cands[index] = Solver.candidates_for(clean, variant, index)

	var naked := _pick_from(empty, selected, func(i: int) -> bool:
		var mask: int = cands[i]
		return mask != 0 and mask & (mask - 1) == 0)
	if naked != -1:
		return _hint(KIND_NAKED, naked, board.solution[naked], -1)

	var hidden := {}
	for group_id in variant.groups.size():
		var group := variant.groups[group_id]
		if group.size() != variant.digit_count:
			continue
		for digit in range(1, variant.digit_count + 1):
			var spot := -1
			var spots := 0
			var placed := false
			for index in group:
				if clean[index] == digit:
					placed = true
					break
				if clean[index] == 0 and int(cands[index]) & (1 << digit) != 0:
					spot = index
					spots += 1
			if not placed and spots == 1 and board.solution[spot] == digit:
				if hidden.is_empty() or spot == selected:
					hidden = _hint(KIND_HIDDEN, spot, digit, group_id)
				if spot == selected:
					return hidden
	if not hidden.is_empty():
		return hidden

	var reveal := selected if empty.has(selected) else empty[0]
	return _hint(KIND_REVEAL, reveal, board.solution[reveal], -1)


## Which part of the cube a group is: {"shape": "slice" or "line",
## "axis": int, "layer": int}. A slice keeps one coordinate fixed ("axis",
## at "layer"); a line runs along "axis".
static func describe_group(variant: SudokuVariant, group_id: int) -> Dictionary:
	var group := variant.groups[group_id]
	var first := variant.coord_of(group[0])
	var fixed: Array[int] = []
	for axis in 3:
		var same := true
		for index in group:
			if variant.coord_of(index)[axis] != first[axis]:
				same = false
				break
		if same:
			fixed.append(axis)
	if fixed.size() == 1:
		return {"shape": "slice", "axis": fixed[0], "layer": first[fixed[0]]}
	var along := 3 - fixed[0] - fixed[1] if fixed.size() == 2 else 0
	return {"shape": "line", "axis": along, "layer": -1}


static func explain(hint: Dictionary, variant: SudokuVariant) -> String:
	var digit: int = hint.get("digit", 0)
	match hint.get("kind", ""):
		KIND_WRONG:
			return "This %d doesn't match the solution. Erase it or try another digit." % digit
		KIND_NAKED:
			var shape: String = describe_group(variant, variant.cell_groups[hint["index"]][0])["shape"]
			return "Only %d fits here. Every other digit is already in one of its %ss." % [digit, shape]
		KIND_HIDDEN:
			var part := describe_group(variant, hint["group"])
			if part["shape"] == "slice":
				return "%d has only one spot left in this %s slice." % [digit, AXIS_NAMES[part["axis"]]]
			return "%d has only one spot left on this line along %s." % [digit, AXIS_NAMES[part["axis"]]]
		KIND_REVEAL:
			return "No simple step here. This cell is a %d." % digit
	return ""


static func _hint(kind: String, index: int, digit: int, group_id: int) -> Dictionary:
	return {"kind": kind, "index": index, "digit": digit, "group": group_id}


static func _pick(board: Board, selected: int, matches: Callable) -> int:
	var all := PackedInt32Array()
	for index in board.variant.cell_count:
		all.append(index)
	return _pick_from(all, selected, matches)


## The selected cell if it matches, else the first cell that does.
static func _pick_from(cells: PackedInt32Array, selected: int, matches: Callable) -> int:
	if cells.has(selected) and matches.call(selected):
		return selected
	for index in cells:
		if matches.call(index):
			return index
	return -1
