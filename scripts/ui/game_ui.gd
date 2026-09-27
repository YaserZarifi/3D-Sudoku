extends Control
## Portrait game layout: HUD, board area, slice bar and number pad, plus the
## tip banner and the pause and solved sheets. Emits intents and never
## touches the board.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const InputManager := preload("res://scripts/input/input_manager.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")

const AXIS_NAMES: PackedStringArray = ["X", "Y", "Z"]
const AXIS_TOKENS: PackedStringArray = ["axis_x", "axis_y", "axis_z"]
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
## The button on the tip banner (Skip, Fill in and so on) was pressed.
signal banner_action

var board_input: InputManager

var _safe_margin: MarginContainer
var _title: Label
var _title_base := ""
var _timer: Label
var _undo: Button
var _slice_buttons: Array[Button] = []
var _pad: GridContainer
var _pad_buttons: Dictionary = {}
var _pad_counts: Dictionary = {}
var _notes_button: Button
var _pause_overlay: Control
var _solved_overlay: Control
var _solved_title: Label
var _solved_time: Label
var _solved_badge: Label
var _solved_details: GridContainer
var _shown_seconds := -1
var _banner: PanelContainer
var _banner_text: Label
var _banner_caption: Label
var _banner_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()


func setup(digit_count: int, title: String) -> void:
	_title_base = title
	set_mistakes(0)
	for child in _pad.get_children():
		child.queue_free()
	_pad_buttons.clear()
	_pad_counts.clear()
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
		# How many of this digit are still missing, in the corner.
		var count := UiKit.label("", "CaptionLabel")
		count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.position -= Vector2(ThemeTokens.space(2), ThemeTokens.space(1))
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count)
		_pad.add_child(button)
		_pad_buttons[digit] = button
		_pad_counts[digit] = count
	show_pause(false)
	show_solved(false)


## Cheap to call every frame: the label only changes once a second.
func set_time(seconds: float) -> void:
	var whole := int(seconds)
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_timer.text = format_time(seconds)


func set_mistakes(count: int) -> void:
	_title.text = _title_base
	if count > 0:
		_title.text += " · %d %s" % [count, "mistake" if count == 1 else "mistakes"]


func set_undo_enabled(enabled: bool) -> void:
	_undo.disabled = not enabled


## Marks pad digits that match the selection: the selected cell's entry, or
## its pencil marks in notes mode. Notes mode also restyles the whole pad.
func set_pad_highlight(active_digits: PackedInt32Array, notes_mode: bool) -> void:
	_notes_button.set_pressed_no_signal(notes_mode)
	for digit: int in _pad_buttons:
		var button: Button = _pad_buttons[digit]
		if active_digits.has(digit):
			button.theme_type_variation = "PadButtonActive"
		else:
			button.theme_type_variation = "PadButtonNotes" if notes_mode else "PadButton"


## remaining is how many more of this digit a solved board needs.
func set_digit_remaining(digit: int, remaining: int) -> void:
	if not _pad_buttons.has(digit):
		return
	(_pad_buttons[digit] as Button).modulate.a = DONE_DIGIT_ALPHA if remaining <= 0 else 1.0
	(_pad_counts[digit] as Label).text = str(remaining) if remaining > 0 else ""


## Tip card over the top of the board, used by the tutorial and by hints.
## Empty text hides it. action is the button label, empty for none.
func show_banner(text: String, caption: String = "", action: String = "") -> void:
	var was_visible := _banner.visible
	_banner.visible = text != ""
	_banner_text.text = text
	_banner_caption.text = caption
	_banner_caption.visible = caption != ""
	_banner_button.text = action
	_banner_button.visible = action != ""
	if _banner.visible and not was_visible:
		UiKit.fade_in(_banner, ThemeManager.reduced_motion())


## axis is -1 when no slice is focused.
func set_slice(axis: int, layer: int, size: int) -> void:
	for i in _slice_buttons.size():
		var button := _slice_buttons[i]
		button.set_pressed_no_signal(i == axis)
		button.text = "%s %d/%d" % [AXIS_NAMES[i], layer + 1, size] if i == axis else AXIS_NAMES[i]


func show_pause(visible_now: bool) -> void:
	UiKit.show_sheet(_pause_overlay, visible_now, ThemeManager.reduced_motion())


## info: {"title", "time", "record": bool, "details": [[label, value], ...]}
func show_solved(visible_now: bool, info: Dictionary = {}) -> void:
	if visible_now:
		_solved_title.text = info.get("title", "Solved!")
		_solved_time.text = info.get("time", "")
		_solved_badge.visible = info.get("record", false)
		for child in _solved_details.get_children():
			child.queue_free()
		for row: Array in info.get("details", []):
			var name := UiKit.label(str(row[0]), "MutedLabel")
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_solved_details.add_child(name)
			var value := UiKit.label(str(row[1]), "TimerLabel")
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_solved_details.add_child(value)
	UiKit.show_sheet(_solved_overlay, visible_now, ThemeManager.reduced_motion())


## Screen area the cube should fit in: the board region minus the tip
## banner when it's showing.
func board_area() -> Rect2:
	var area := board_input.get_global_rect()
	if _banner != null and _banner.visible:
		var cut := _banner.size.y + ThemeTokens.space(2)
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
	var pause := UiKit.button("Pause", "GhostButton")
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
	_build_banner()

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

	var pause_sheet := UiKit.sheet(self, "Paused")
	_pause_overlay = pause_sheet["root"]
	_add_actions(pause_sheet["box"], [
		["Resume", "AccentButton", resume_pressed],
		["Restart", "Button", restart_pressed],
		["New puzzle", "Button", new_game_pressed],
		["Main menu", "GhostButton", menu_pressed],
	])

	var solved_sheet := UiKit.sheet(self, "Solved!")
	_solved_overlay = solved_sheet["root"]
	_solved_title = solved_sheet["title"]
	var box: VBoxContainer = solved_sheet["box"]
	_solved_time = UiKit.label("", "DisplayLabel")
	_solved_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_solved_time)
	_solved_badge = UiKit.label("NEW BEST TIME", "OverlineLabel")
	_solved_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_solved_badge)
	_solved_details = GridContainer.new()
	_solved_details.columns = 2
	box.add_child(_solved_details)
	_add_actions(box, [
		["Next puzzle", "AccentButton", new_game_pressed],
		["Main menu", "GhostButton", menu_pressed],
	])


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.theme_type_variation = "CardPanel"
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.visible = false
	var report := func() -> void: board_area_changed.emit(board_area())
	_banner.resized.connect(report)
	_banner.visibility_changed.connect(report)
	board_input.add_child(_banner)
	var row := HBoxContainer.new()
	_banner.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	_banner_caption = UiKit.label("", "CaptionLabel")
	texts.add_child(_banner_caption)
	_banner_text = UiKit.label("")
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.add_theme_font_size_override("font_size", ThemeTokens.font_size("md"))
	texts.add_child(_banner_text)
	_banner_button = UiKit.button("", "GhostButton")
	_banner_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_banner_button.pressed.connect(banner_action.emit)
	row.add_child(_banner_button)


func _add_actions(box: VBoxContainer, actions: Array) -> void:
	for action: Array in actions:
		var button := UiKit.button(action[0], action[1])
		var action_signal: Signal = action[2]
		button.pressed.connect(action_signal.emit)
		box.add_child(button)


func _apply_theme() -> void:
	theme = ThemeManager.theme
	for axis in _slice_buttons.size():
		_slice_buttons[axis].icon = UiKit.dot_icon(ThemeManager.color(AXIS_TOKENS[axis]), ThemeTokens.dp(ThemeTokens.AXIS_DOT_DP))
	if _solved_badge != null:
		_solved_badge.add_theme_color_override("font_color", ThemeManager.color("accent"))


func _update_safe_area() -> void:
	var margins := UiKit.safe_margins(get_viewport())
	var gutter := ThemeTokens.space(3)
	_safe_margin.add_theme_constant_override("margin_left", int(margins.position.x) + gutter)
	_safe_margin.add_theme_constant_override("margin_top", int(margins.position.y) + gutter)
	_safe_margin.add_theme_constant_override("margin_right", int(margins.size.x) + gutter)
	_safe_margin.add_theme_constant_override("margin_bottom", int(margins.size.y) + gutter)
