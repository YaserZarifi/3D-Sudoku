extends "res://tests/test_case.gd"

const GameManager := preload("res://scripts/core/game_manager.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const HintFinder := preload("res://scripts/core/hint_finder.gd")


func _manager() -> GameManager:
	var manager := GameManager.new()
	manager.new_game(Variants.SLICE_SUDOKU_ID, "easy", 21)
	return manager


func test_hint_explains_then_fills() -> void:
	var manager := _manager()
	manager.hint()
	var hint := manager.pending_hint
	assert_false(hint.is_empty())
	assert_true(str(hint.get("text", "")) != "")
	assert_eq(manager.state.selected, hint["index"])
	assert_true(manager.state.board.is_empty(hint["index"]), "the first tap only explains")
	manager.hint()
	assert_eq(manager.state.board.get_value(hint["index"]), hint["digit"])
	assert_true(manager.pending_hint.is_empty())
	assert_eq(manager.state.hints_used, 1)
	manager.free()


func test_hint_erases_a_wrong_entry() -> void:
	var manager := _manager()
	var board := manager.state.board
	var index := -1
	for cell in board.variant.cell_count:
		if board.is_empty(cell):
			index = cell
			break
	manager.select_index(index)
	manager.enter_digit(board.solution[index] % board.variant.digit_count + 1)
	manager.hint()
	assert_eq(manager.pending_hint["kind"], HintFinder.KIND_WRONG)
	manager.hint()
	assert_true(board.is_empty(index))
	manager.free()


func test_selecting_another_cell_drops_the_hint() -> void:
	var manager := _manager()
	manager.hint()
	var index: int = manager.pending_hint["index"]
	manager.select_index((index + 1) % manager.state.board.variant.cell_count)
	assert_true(manager.pending_hint.is_empty())
	manager.free()
