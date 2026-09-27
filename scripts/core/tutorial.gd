extends RefCounted
## The guided first game. A list of steps, each finished by one player
## event. Pure logic: the game screen feeds it events and shows its text.

const STEPS: Array[Dictionary] = [
	{"id": "turn", "until": "orbit",
		"text": "Drag the cube to turn it and look around."},
	{"id": "select", "until": "select",
		"text": "Tap a cell to select it. The outlined cells share a line with it."},
	{"id": "place", "until": "place_ok",
		"text": "Every line of three holds 1, 2 and 3 once. Enter the digit that fits.",
		"retry": "That digit is already in one of its lines. Try another one."},
	{"id": "slice", "until": "slice",
		"text": "Cells inside are hard to see. Tap X, Y or Z to show one layer at a time."},
	{"id": "notes", "until": "notes_on",
		"text": "Not sure yet? Turn on Notes to jot down candidates."},
	{"id": "finish", "until": "solved",
		"text": "Now fill the whole cube. Hint fills a cell if you get stuck."},
]

var step := 0
var _retry := false


## Starts at a named step, used when a saved tutorial is resumed.
func jump_to(step_id: String) -> void:
	for i in STEPS.size():
		if STEPS[i]["id"] == step_id:
			step = i
			_retry = false
			return


func is_finished() -> bool:
	return step >= STEPS.size()


func step_id() -> String:
	return "" if is_finished() else STEPS[step]["id"]


func text() -> String:
	if is_finished():
		return ""
	var current: Dictionary = STEPS[step]
	return current.get("retry", current["text"]) if _retry else current["text"]


func step_count() -> int:
	return STEPS.size()


## Returns whether the shown text changed.
func handle(event: String) -> bool:
	if is_finished():
		return false
	var current: Dictionary = STEPS[step]
	if event == current["until"]:
		step += 1
		_retry = false
		return true
	if event == "place_conflict" and current.has("retry") and not _retry:
		_retry = true
		return true
	return false
