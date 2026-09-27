extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const GameState := preload("res://scripts/core/game_state.gd")


func _state() -> GameState:
	return GameState.from_puzzle(Generator.generate(Variants.slice_sudoku(3), "easy", 5))


func _first_empty(state: GameState) -> int:
	for index in state.board.variant.cell_count:
		if state.board.is_empty(index):
			return index
	return -1


func test_place_and_undo() -> void:
	var state := _state()
	var index := _first_empty(state)
	assert_true(state.place(index, 3))
	assert_true(state.place(index, 4))
	assert_eq(state.undo(), index)
	assert_eq(state.board.get_value(index), 3)
	assert_eq(state.undo(), index)
	assert_true(state.board.is_empty(index))
	assert_eq(state.undo(), GameState.NO_SELECTION)


func test_undo_restores_erase() -> void:
	var state := _state()
	var index := _first_empty(state)
	state.place(index, 5)
	state.place(index, 0)
	state.undo()
	assert_eq(state.board.get_value(index), 5)


func test_givens_are_locked() -> void:
	var state := _state()
	for index in state.board.variant.cell_count:
		if state.board.is_given(index):
			assert_false(state.place(index, 1))
			assert_true(state.undo_stack.is_empty())
			return


func test_conflict_counts_mistake() -> void:
	var state := _state()
	var variant := state.board.variant
	var given := -1
	for index in variant.cell_count:
		if state.board.is_given(index):
			given = index
			break
	for peer in variant.peers[given]:
		if state.board.is_empty(peer):
			state.place(peer, state.board.get_value(given))
			break
	assert_eq(state.mistakes, 1)


func test_filling_solution_solves() -> void:
	var state := _state()
	for index in state.board.variant.cell_count:
		if state.board.is_empty(index):
			state.place(index, state.board.solution[index])
	assert_true(state.solved)
	assert_false(state.place(_first_empty(state), 1), "no moves after solving")


func test_hint_fills_selected_cell() -> void:
	var state := _state()
	var index := _first_empty(state)
	state.selected = index
	assert_eq(state.hint(), index)
	assert_eq(state.board.get_value(index), state.board.solution[index])
	assert_eq(state.hints_used, 1)


func test_restart_clears_entries() -> void:
	var state := _state()
	var index := _first_empty(state)
	state.place(index, 2)
	state.elapsed = 30.0
	state.restart()
	assert_true(state.board.is_empty(index))
	assert_true(state.undo_stack.is_empty())
	assert_eq(state.elapsed, 0.0)


func test_save_round_trip() -> void:
	var state := _state()
	var index := _first_empty(state)
	state.place(index, 7)
	state.elapsed = 42.5
	# Going through JSON turns every number into a float, like a real save.
	var text := JSON.stringify(state.to_dict())
	var restored: GameState = GameState.from_dict(JSON.parse_string(text))
	assert_true(restored != null)
	assert_eq(restored.board.values, state.board.values)
	assert_eq(restored.board.givens, state.board.givens)
	assert_eq(restored.board.solution, state.board.solution)
	assert_eq(restored.undo_stack.size(), 1)
	assert_eq(restored.elapsed, 42.5)
	assert_eq(restored.difficulty, "easy")
	assert_eq(restored.undo(), index)


func test_rejects_corrupt_saves() -> void:
	var good := _state().to_dict()
	assert_true(GameState.from_dict({}) == null)
	var cases := [
		{"variant": "missing"},
		{"version": 99},
		{"values": [1, 2, 3]},
		{"solution": good["givens"]},
		{"values": _changed_given(good)},
		{"givens": "nonsense"},
	]
	for change: Dictionary in cases:
		var broken := good.duplicate(true)
		broken.merge(change, true)
		assert_true(GameState.from_dict(broken) == null, "should reject %s" % str(change.keys()))


func _changed_given(save: Dictionary) -> Array:
	var values: Array = save["values"].duplicate()
	for index in values.size():
		if save["givens"][index] != 0:
			values[index] = 0
			break
	return values
