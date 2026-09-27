extends RefCounted
## Rule checks. Conflicts are judged against the groups, never the solution.

const Board := preload("res://scripts/sudoku/board.gd")


## Entries that share a group with the same digit. Givens are never blamed,
## so a given clashing with an entry only marks the entry.
static func conflicts(board: Board) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in _clashing_cells(board):
		if not board.is_given(index):
			result.append(index)
	return result


static func is_conflict(board: Board, index: int) -> bool:
	var digit := board.get_value(index)
	if digit == 0 or board.is_given(index):
		return false
	for peer in board.variant.peers[index]:
		if board.values[peer] == digit:
			return true
	return false


static func is_complete(board: Board) -> bool:
	for value in board.values:
		if value == 0:
			return false
	return true


static func is_solved(board: Board) -> bool:
	return is_complete(board) and _clashing_cells(board).is_empty()


static func _clashing_cells(board: Board) -> PackedInt32Array:
	var result := PackedInt32Array()
	var variant := board.variant
	for index in variant.cell_count:
		var digit := board.values[index]
		if digit == 0:
			continue
		for peer in variant.peers[index]:
			if board.values[peer] == digit:
				result.append(index)
				break
	return result
