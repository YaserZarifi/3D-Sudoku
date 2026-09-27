extends RefCounted
## Turns board data into one visual state per cell. Board3D only renders what
## this returns, so every highlight rule lives in one place.

const Board := preload("res://scripts/sudoku/board.gd")
const Validator := preload("res://scripts/sudoku/validator.gd")

const NO_FOCUS := -1


## focus_axis is 0, 1 or 2 for x, y or z, or NO_FOCUS. Cells outside the
## focused layer are dimmed.
## notes holds a pencil-mark bitmask per cell, or is empty.
static func compute(board: Board, selected: int, focus_axis: int = NO_FOCUS, focus_layer: int = 0, notes: PackedInt32Array = PackedInt32Array()) -> Array[Dictionary]:
	var variant := board.variant
	var conflicts := {}
	for index in Validator.conflicts(board):
		conflicts[index] = true
	var peers := {}
	var selected_digit := 0
	if variant.is_valid_index(selected):
		selected_digit = board.get_value(selected)
		for peer in variant.peers[selected]:
			peers[peer] = true

	var states: Array[Dictionary] = []
	for index in variant.cell_count:
		var digit := board.get_value(index)
		var dimmed := false
		if focus_axis != NO_FOCUS:
			dimmed = variant.coord_of(index)[focus_axis] != focus_layer
		states.append({
			"digit": digit,
			"is_given": board.is_given(index),
			"is_selected": index == selected,
			"is_peer": peers.has(index),
			"is_same_digit": selected_digit != 0 and digit == selected_digit and index != selected,
			"is_conflict": conflicts.has(index),
			"is_dimmed": dimmed,
			"notes": notes[index] if digit == 0 and index < notes.size() else 0,
		})
	return states
