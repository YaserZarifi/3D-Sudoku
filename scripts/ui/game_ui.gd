extends Control
## Portrait game layout: HUD, board area, slice bar and number pad, plus the
## pause and solved overlays. Emits intents and never touches the board.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const InputManager := preload("res://scripts/input/input_manager.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")

const AXIS_NAMES: PackedStringArray = ["X", "Y", "Z"]
## Faded look for digits that are all on the board. They stay usable.
const DONE_DIGIT_ALPHA := 0.35

signal digit_pressed(digit: int)
signal erase_pressed
signal undo_pressed
signal hint_pressed
signal notes_toggled(enabled: bool)
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal new_game_pressed
signal menu_pressed
signal reset_view_pressed
signal slice_pressed(axis: int)
signal board_area_changed(area: Rect2)
signal coach_skipped

var board_input: InputManager

var _safe_margin: MarginContainer
var _title: Label
var _timer: Label
var _undo: Button
var _slice_buttons: Array[Button] = []
var _pad: GridContainer
var _pad_buttons: Dictionary = {}
var _pause_overlay: Control
var _solved_overlay: Control
var _solved_summary: Label
var _solved_title: Label
var _shown_seconds := -1
var _notes_button: Button
var _coach: PanelContainer
var _coach_text: Label
var _coach_step: Label
var _notes_mode := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()


func setup(digit_count: int, title: String) -> void:
	_title.text = title
	for child in _pad.get_children():
		child.queue_free()
	_pad_buttons.clear()
	# Tier 1 has three digits, shown as one row of larger buttons.
	_pad.columns = mini(digit_count, 3)
	var height := ThemeTokens.dp(ThemeTokens.MIN_BUTTON_DP)
	if digit_count <= 3:
		height = int(height * 1.6)
	for digit in range(1, digit_count + 1):
		var button := UiKit.button(str(digit), "PadButton")
		button.custom_minimum_size = Vector2(0, height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.pressed.connect(digit_pressed.emit.bind(digit))
		_pad.add_child(button)
		_pad_buttons[digit] = button
	show_pause(false)
	show_solved(false)


## Cheap to call every frame: the label only changes once a second.
func set_time(seconds: float) -> void:
	var whole := int(seconds)
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_timer.text = format_time(seconds)


func set_undo_enabled(enabled: bool) -> void:
	_undo.disabled = not enabled


## Marks pad digits that match the selection: the selected cell's entry, or
## its pencil marks in notes mode. Notes mode also restyles the whole pad.
func set_pad_highlight(active_digits: PackedInt32Array, notes_mode: bool) -> void:
	_notes_mode = notes_mode
	_notes_button.set_pressed_no_signal(notes_mode)
	for digit: int in _pad_buttons:
		var button: Button = _pad_buttons[digit]
		if active_digits.has(digit):
			button.theme_type_variation = "PadButtonActive"
		else:
			button.theme_type_variation = "PadButtonNotes" if notes_mode else "PadButton"


## Tutorial card over the top of the board. Empty text hides it.
func show_coach(text: String, step: int = 0, total: int = 0) -> void:
	var was_visible := _coach.visible
	_coach.visible = text != ""
	_coach_text.text = text
	_coach_step.text = "%d of %d" % [step + 1, total] if total > 0 else ""
	if _coach.visible and (not was_visible or text != ""):
		UiKit.fade_in(_coach, ThemeManager.reduced_motion())


func set_digit_done(digit: int, done: bool) -> void:
	if _pad_buttons.has(digit):
		(_pad_buttons[digit] as Button).modulate.a = DONE_DIGIT_ALPHA if done else 1.0


## axis is -1 when no slice is focused.
func set_slice(axis: int, layer: int, size: int) -> void:
	for i in _slice_buttons.size():
		var button := _slice_buttons[i]
		button.set_pressed_no_signal(i == axis)
		button.text = "%s %d/%d" % [AXIS_NAMES[i], layer + 1, size] if i == axis else AXIS_NAMES[i]


func show_pause(visible_now: bool) -> void:
	UiKit.show_sheet(_pause_overlay, visible_now, ThemeManager.reduced_motion())


func show_solved(visible_now: bool, summary: String = "") -> void:
	_solved_summary.text = summary
	UiKit.show_sheet(_solved_overlay, visible_now, ThemeManager.reduced_motion())


## Screen area the cube should fit in: the board region minus the
## tutorial card when it's showing.
func board_area() -> Rect2:
	var area := board_input.get_global_rect()
	if _coach != null and _coach.visible:
		var cut := _coach.size.y + ThemeTokens.space(2)
		area.position.y += cut
		area.size.y = maxf(area.size.y - cut, 1.0)
	return area


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	if total >= 3600:
		return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
	return "%02d:%02d" % [total / 60, total % 60]


func _build() -> void:
	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_margin.add_child(column)

	var hud := HBoxContainer.new()
	column.add_child(hud)
	var pause := UiKit.button("Menu", "GhostButton")
	pause.pressed.connect(pause_pressed.emit)
	hud.add_child(pause)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	hud.add_child(info)
	_title = UiKit.label("", "MutedLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_title)
	_timer = UiKit.label("00:00", "TimerLabel")
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_timer)
	_undo = UiKit.button("Undo", "GhostButton")
	_undo.pressed.connect(undo_pressed.emit)
	hud.add_child(_undo)

	board_input = InputManager.new()
	board_input.name = "BoardInput"
	board_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_input.resized.connect(func() -> void: board_area_changed.emit(board_area()))
	column.add_child(board_input)
	_build_coach()

	var slice_bar := HBoxContainer.new()
	column.add_child(slice_bar)
	for axis in AXIS_NAMES.size():
		var toggle := UiKit.button(AXIS_NAMES[axis], "ToggleButton")
		toggle.toggle_mode = true
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.pressed.connect(slice_pressed.emit.bind(axis))
		slice_bar.add_child(toggle)
		_slice_buttons.append(toggle)
	var reset := UiKit.button("Reset view", "Button")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.size_flags_stretch_ratio = 1.6
	reset.pressed.connect(reset_view_pressed.emit)
	slice_bar.add_child(reset)

	var pad_row := HBoxContainer.new()
	column.add_child(pad_row)
	_pad = GridContainer.new()
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.size_flags_stretch_ratio = 3.0
	pad_row.add_child(_pad)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_row.add_child(side)
	var erase := UiKit.button("Erase", "Button")
	erase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	erase.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	erase.pressed.connect(erase_pressed.emit)
	side.add_child(erase)
	_notes_button = UiKit.button("Notes", "ToggleButton")
	_notes_button.toggle_mode = true
	_notes_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes_button.toggled.connect(notes_toggled.emit)
	side.add_child(_notes_button)
	var hint := UiKit.button("Hint", "Button")
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.pressed.connect(hint_pressed.emit)
	side.add_child(hint)

	_pause_overlay = _overlay("Paused", [
		["Resume", "AccentButton", resume_pressed],
		["Restart", "Button", restart_pressed],
		["New Game", "Button", new_game_pressed],
		["Main Menu", "Button", menu_pressed],
	])
	var solved_parts := _overlay_parts("Solved", [
		["New Game", "AccentButton", new_game_pressed],
		["Main Menu", "Button", menu_pressed],
	])
	_solved_overlay = solved_parts[0]
	_solved_title = solved_parts[1]
	_solved_summary = UiKit.label("", "MutedLabel")
	_solved_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box: VBoxContainer = solved_parts[2]
	box.add_child(_solved_summary)
	box.move_child(_solved_summary, 1)


func _build_coach() -> void:
	_coach = PanelContainer.new()
	_coach.theme_type_variation = "CardPanel"
	_coach.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	_coach.visible = false
	var report := func() -> void: board_area_changed.emit(board_area())
	_coach.resized.connect(report)
	_coach.visibility_changed.connect(report)
	board_input.add_child(_coach)
	var row := HBoxContainer.new()
	_coach.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	_coach_step = UiKit.label("", "CaptionLabel")
	texts.add_child(_coach_step)
	_coach_text = UiKit.label("")
	_coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_text.add_theme_font_size_override("font_size", ThemeTokens.font_size("md"))
	texts.add_child(_coach_text)
	var skip := UiKit.button("Skip", "GhostButton")
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(coach_skipped.emit)
	row.add_child(skip)


func _overlay(title: String, actions: Array) -> Control:
	return _overlay_parts(title, actions)[0]


## Returns [overlay, title label, button column].
func _overlay_parts(title: String, actions: Array) -> Array:
	var sheet := UiKit.sheet(self, title)
	var box: VBoxContainer = sheet["box"]
	for action: Array in actions:
		var button := UiKit.button(action[0], action[1])
		var action_signal: Signal = action[2]
		button.pressed.connect(action_signal.emit)
		box.add_child(button)
	return [sheet["root"], sheet["title"], box]


func _apply_theme() -> void:
	theme = ThemeManager.theme


func _update_safe_area() -> void:
	var margins := UiKit.safe_margins(get_viewport())
	var gutter := ThemeTokens.space(3)
	_safe_margin.add_theme_constant_override("margin_left", int(margins.position.x) + gutter)
	_safe_margin.add_theme_constant_override("margin_top", int(margins.position.y) + gutter)
	_safe_margin.add_theme_constant_override("margin_right", int(margins.size.x) + gutter)
	_safe_margin.add_theme_constant_override("margin_bottom", int(margins.size.y) + gutter)
