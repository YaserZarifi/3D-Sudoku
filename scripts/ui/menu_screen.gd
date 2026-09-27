extends Control
## Start screen: continue, a new game by tier and level, the daily puzzle,
## how to play, statistics and settings.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const SaveData := preload("res://scripts/core/save_data.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const GameUi := preload("res://scripts/ui/game_ui.gd")

const TIER_RULES := {
	"latin_cube_3": "Every line holds 1, 2 and 3 once.",
	"slice_sudoku_3": "Every slice holds 1 to 9 once.",
}
const SETTINGS: Array[Array] = [
	["sound", "Sound"],
	["haptics", "Haptics"],
	["reduced_motion", "Reduced motion"],
	["dark_mode", "Dark mode"],
]
const STATS_COLUMNS: PackedStringArray = ["", "Played", "Solved", "Best", "Average"]

signal new_game_requested(variant_id: String, difficulty: String)
signal resume_requested
signal daily_requested
signal tutorial_requested
## The empty part of the screen where the decorative cube can sit.
signal open_area_changed(area: Rect2)

var _variant_id: String
var _difficulty: String
var _margin: MarginContainer
var _rules: Label
var _resume: Button
var _resume_detail: Label
var _new_game: Button
var _daily: Button
var _tutorial: Button
var _record: Label
var _tier_buttons: Dictionary = {}
var _level_buttons: Dictionary = {}
var _setting_buttons: Dictionary = {}
var _settings_sheet: Dictionary
var _stats_sheet: Dictionary
var _stats_body: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_variant_id = SaveManager.get_setting("last_variant")
	if Variants.by_id(_variant_id) == null:
		_variant_id = Variants.SLICE_SUDOKU_ID
	_difficulty = SaveManager.get_setting("last_difficulty")
	if not Generator.DIFFICULTIES.has(_difficulty):
		_difficulty = "easy"
	_build()
	ThemeManager.theme_changed.connect(_apply_theme)
	SaveManager.settings_changed.connect(_refresh)
	get_viewport().size_changed.connect(_update_safe_area)
	_apply_theme()
	_update_safe_area()
	_refresh()


func _notification(what: int) -> void:
	# The back button closes an open sheet before it leaves the app.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _close_sheets():
		get_viewport().set_input_as_handled()


func has_open_sheet() -> bool:
	return _settings_sheet["root"].visible or _stats_sheet["root"].visible


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	_margin.add_child(column)

	var title := UiKit.label("3D Sudoku", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_rules = UiKit.label("", "MutedLabel")
	_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rules)

	# Keeps the upper part of the screen free for the turning cube.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.resized.connect(func() -> void: open_area_changed.emit(spacer.get_global_rect()))
	column.add_child(spacer)

	_resume = UiKit.button("Continue", "AccentButton")
	_resume.pressed.connect(resume_requested.emit)
	column.add_child(_resume)
	_resume_detail = UiKit.label("", "CaptionLabel")
	_resume_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_resume_detail)

	column.add_child(_segmented(Variants.all_ids(), _tier_buttons, _pick_tier, func(id: String) -> String: return Variants.by_id(id).display_name))
	column.add_child(_segmented(Generator.DIFFICULTIES, _level_buttons, _pick_level, func(level: String) -> String: return level.capitalize()))

	_new_game = UiKit.button("New Game", "AccentButton")
	_new_game.pressed.connect(func() -> void: new_game_requested.emit(_variant_id, _difficulty))
	column.add_child(_new_game)
	_record = UiKit.label("", "CaptionLabel")
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_record)

	var extras := GridContainer.new()
	extras.columns = 2
	column.add_child(extras)
	_daily = _grid_button(extras, "Daily", daily_requested.emit)
	_grid_button(extras, "Stats", _open_stats)
	_tutorial = _grid_button(extras, "How to play", tutorial_requested.emit)
	_grid_button(extras, "Settings", _open_settings)

	_settings_sheet = UiKit.sheet(self, "Settings")
	var settings_box: VBoxContainer = _settings_sheet["box"]
	for entry in SETTINGS:
		var toggle := UiKit.button(entry[1], "ToggleButton")
		toggle.toggle_mode = true
		var key: String = entry[0]
		toggle.toggled.connect(func(on: bool) -> void: SaveManager.set_setting(key, on))
		settings_box.add_child(toggle)
		_setting_buttons[key] = toggle
	settings_box.add_child(_close_button(_settings_sheet))

	_stats_sheet = UiKit.sheet(self, "Statistics")
	_stats_body = VBoxContainer.new()
	_stats_sheet["box"].add_child(_stats_body)
	_stats_sheet["box"].add_child(_close_button(_stats_sheet))


func _segmented(keys: PackedStringArray, store: Dictionary, on_pick: Callable, caption: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ThemeTokens.space(1))
	for key in keys:
		var option := UiKit.button(caption.call(key), "ToggleButton")
		option.toggle_mode = true
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.pressed.connect(on_pick.bind(key))
		row.add_child(option)
		store[key] = option
	return row


func _grid_button(grid: GridContainer, text: String, action: Callable) -> Button:
	var button := UiKit.button(text, "Button")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	grid.add_child(button)
	return button


func _close_button(sheet: Dictionary) -> Button:
	var close := UiKit.button("Close", "GhostButton")
	close.pressed.connect(func() -> void: UiKit.show_sheet(sheet["root"], false, true))
	return close


func _close_sheets() -> bool:
	var closed := false
	for sheet: Dictionary in [_settings_sheet, _stats_sheet]:
		if sheet["root"].visible:
			UiKit.show_sheet(sheet["root"], false, true)
			closed = true
	return closed


func _open_settings() -> void:
	UiKit.show_sheet(_settings_sheet["root"], true, ThemeManager.reduced_motion())


func _open_stats() -> void:
	_fill_stats()
	UiKit.show_sheet(_stats_sheet["root"], true, ThemeManager.reduced_motion())


func _pick_tier(variant_id: String) -> void:
	_variant_id = variant_id
	_refresh()


func _pick_level(difficulty: String) -> void:
	_difficulty = difficulty
	_refresh()


func _refresh() -> void:
	var has_game := SaveManager.has_game()
	_resume.visible = has_game
	_resume_detail.visible = has_game
	if has_game:
		_resume_detail.text = _describe_saved(SaveManager.get_game())
	# One primary action at a time: Continue when there's a game to go back to.
	_new_game.theme_type_variation = "Button" if has_game else "AccentButton"
	var first_time: bool = not SaveManager.get_setting("tutorial_done")
	_tutorial.theme_type_variation = "AccentButton" if first_time and not has_game else "Button"

	for variant_id: String in _tier_buttons:
		(_tier_buttons[variant_id] as Button).set_pressed_no_signal(variant_id == _variant_id)
	for difficulty: String in _level_buttons:
		(_level_buttons[difficulty] as Button).set_pressed_no_signal(difficulty == _difficulty)
	for key: String in _setting_buttons:
		(_setting_buttons[key] as Button).set_pressed_no_signal(SaveManager.get_setting(key))
	_rules.text = TIER_RULES.get(_variant_id, "")

	var entry: Dictionary = SaveManager.stats().get("%s/%s" % [_variant_id, _difficulty], {})
	var solved: int = entry.get("solved", 0)
	var best: float = entry.get("best_time", 0.0)
	_record.text = "Solved %d" % solved
	if best > 0.0:
		_record.text += " · Best %s" % GameUi.format_time(best)

	var today := SaveData.today()
	var daily := SaveManager.daily()
	var streak := SaveData.current_streak(daily, today)
	var done := SaveData.solved_today(daily, today)
	_daily.disabled = done
	_daily.text = "Daily done" if done else "Daily"
	if streak > 0:
		_daily.text += " · %d" % streak


func _describe_saved(game: Dictionary) -> String:
	var variant := Variants.by_id(str(game.get("variant", "")))
	var name := variant.display_name if variant != null else ""
	var mode := str(game.get("mode", "classic"))
	if mode == "daily":
		name = "Daily"
	elif mode == "tutorial":
		name = "How to play"
	else:
		name += " · %s" % str(game.get("difficulty", "")).capitalize()
	var elapsed := float(game.get("elapsed", 0.0)) if game.get("elapsed") is float or game.get("elapsed") is int else 0.0
	return "%s · %s" % [name, GameUi.format_time(elapsed)]


func _fill_stats() -> void:
	for child in _stats_body.get_children():
		child.queue_free()
	var stats := SaveManager.stats()
	for variant_id in Variants.all_ids():
		var heading := UiKit.label(Variants.by_id(variant_id).display_name, "HeadingLabel")
		heading.add_theme_font_size_override("font_size", ThemeTokens.font_size("lg"))
		_stats_body.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = STATS_COLUMNS.size()
		grid.add_theme_constant_override("h_separation", ThemeTokens.space(3))
		_stats_body.add_child(grid)
		for column in STATS_COLUMNS:
			grid.add_child(_cell(column, true, column != ""))
		for difficulty in Generator.DIFFICULTIES:
			var entry: Dictionary = stats.get("%s/%s" % [variant_id, difficulty], {})
			grid.add_child(_cell(difficulty.capitalize(), true, false))
			_add_entry_cells(grid, entry)

	var daily_heading := UiKit.label("Daily", "HeadingLabel")
	daily_heading.add_theme_font_size_override("font_size", ThemeTokens.font_size("lg"))
	_stats_body.add_child(daily_heading)
	var daily := SaveManager.daily()
	var daily_entry: Dictionary = stats.get(SaveData.DAILY_KEY, {})
	var line := UiKit.label("Streak %d · Longest %d · Solved %d" % [
		SaveData.current_streak(daily, SaveData.today()),
		int(daily.get("best_streak", 0)),
		int(daily_entry.get("solved", 0)),
	], "MutedLabel")
	_stats_body.add_child(line)


func _add_entry_cells(grid: GridContainer, entry: Dictionary) -> void:
	var best: float = entry.get("best_time", 0.0)
	var average := SaveData.average_time(entry)
	grid.add_child(_cell(str(entry.get("played", 0))))
	grid.add_child(_cell(str(entry.get("solved", 0))))
	grid.add_child(_cell(GameUi.format_time(best) if best > 0.0 else "-"))
	grid.add_child(_cell(GameUi.format_time(average) if average > 0.0 else "-"))


func _cell(text: String, header: bool = false, align_right: bool = true) -> Label:
	var cell := UiKit.label(text, "CaptionLabel" if header else "")
	if not header:
		cell.add_theme_font_size_override("font_size", ThemeTokens.font_size("md"))
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if align_right else HORIZONTAL_ALIGNMENT_LEFT
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cell


func _apply_theme() -> void:
	theme = ThemeManager.theme


func _update_safe_area() -> void:
	var margins := UiKit.safe_margins(get_viewport())
	var gutter := ThemeTokens.space(5)
	_margin.add_theme_constant_override("margin_left", int(margins.position.x) + gutter)
	_margin.add_theme_constant_override("margin_top", int(margins.position.y) + gutter)
	_margin.add_theme_constant_override("margin_right", int(margins.size.x) + gutter)
	_margin.add_theme_constant_override("margin_bottom", int(margins.size.y) + gutter)
