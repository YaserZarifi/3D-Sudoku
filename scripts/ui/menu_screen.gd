extends Control
## Start screen with two pages. Home: one big Play (or Continue), the daily
## puzzle, and small links to How to play, Stats and Settings. Picker: choose
## a tier and a level, then Start.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const SaveData := preload("res://scripts/core/save_data.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const GameUi := preload("res://scripts/ui/game_ui.gd")

const TIERS := {
	"latin_cube_3": {
		"title": "Latin Cube",
		"body": "Digits 1 to 3. Every line through the cube holds each once. Quick and gentle.",
	},
	"slice_sudoku_3": {
		"title": "Slice Sudoku",
		"body": "Digits 1 to 9. Every slice of the cube holds each once. The main game.",
	},
}
const SETTINGS: Array[Array] = [
	["sound", "Sound"],
	["haptics", "Haptics"],
	["reduced_motion", "Reduced motion"],
	["dark_mode", "Dark mode"],
]
const STATS_COLUMNS: PackedStringArray = ["", "Played", "Solved", "Best", "Average"]
const TIER_CARD_DP := 96

signal new_game_requested(variant_id: String, difficulty: String)
signal resume_requested
signal daily_requested
signal tutorial_requested

var _variant_id: String
var _difficulty: String
var _margin: MarginContainer
var _home: VBoxContainer
var _picker: VBoxContainer
var _home_spacer: Control
var _picker_spacer: Control
var _play: Button
var _play_detail: Label
var _new_puzzle: Button
var _daily: Button
var _daily_detail: Label
var _record: Label
var _tier_cards: Dictionary = {}
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
	_show_page(_home)


func _notification(what: int) -> void:
	# Back closes a sheet, then the picker, before it leaves the app.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if not _close_sheets() and _picker.visible:
			_show_page(_home)


## True while back should stay inside the menu instead of quitting.
func has_open_sheet() -> bool:
	return _settings_sheet["root"].visible or _stats_sheet["root"].visible or _picker.visible


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var pages := Control.new()
	_margin.add_child(pages)
	_home = _page(pages)
	_picker = _page(pages)
	_build_home()
	_build_picker()

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


func _page(parent: Control) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", ThemeTokens.space(2))
	parent.add_child(page)
	return page


func _build_home() -> void:
	var title := UiKit.label("3D Sudoku", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(title)
	var tagline := UiKit.label("Sudoku on a cube you can turn.", "MutedLabel")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(tagline)
	_home_spacer = _open_area(_home)

	_play = UiKit.button("Play", "AccentButton")
	_play.custom_minimum_size.y = ThemeTokens.dp(ThemeTokens.MIN_BUTTON_DP * 1.3)
	_play.add_theme_font_size_override("font_size", ThemeTokens.font_size("xl"))
	_play.pressed.connect(_on_play)
	_home.add_child(_play)
	_play_detail = UiKit.label("", "CaptionLabel")
	_play_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(_play_detail)
	_new_puzzle = UiKit.button("New puzzle", "Button")
	_new_puzzle.pressed.connect(_show_page.bind(_picker))
	_home.add_child(_new_puzzle)

	var daily_card := _card_button("Daily puzzle", "", "Button")
	_daily = daily_card["button"]
	_daily_detail = daily_card["body"]
	_daily.pressed.connect(daily_requested.emit)
	_home.add_child(_daily)

	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", ThemeTokens.space(1))
	_home.add_child(links)
	for link: Array in [["How to play", tutorial_requested.emit], ["Stats", _open_stats], ["Settings", _open_settings]]:
		var button := UiKit.button(link[0], "GhostButton")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", ThemeTokens.font_size("md"))
		button.pressed.connect(link[1])
		links.add_child(button)


func _build_picker() -> void:
	var header := HBoxContainer.new()
	_picker.add_child(header)
	var back := UiKit.button("Back", "GhostButton")
	back.pressed.connect(_show_page.bind(_home))
	header.add_child(back)
	var heading := UiKit.label("Choose a puzzle", "HeadingLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(heading)
	# Balances the Back button so the heading stays centered.
	var balance := Control.new()
	balance.custom_minimum_size = back.get_combined_minimum_size()
	header.add_child(balance)
	_picker_spacer = _open_area(_picker)

	for variant_id in Variants.all_ids():
		var info: Dictionary = TIERS.get(variant_id, {"title": variant_id, "body": ""})
		var card := _card_button(info["title"], info["body"], "ToggleButton")
		var button: Button = card["button"]
		button.toggle_mode = true
		button.pressed.connect(_pick_tier.bind(variant_id))
		_picker.add_child(button)
		_tier_cards[variant_id] = card

	var level_caption := UiKit.label("Difficulty", "CaptionLabel")
	_picker.add_child(level_caption)
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", ThemeTokens.space(1))
	_picker.add_child(levels)
	for difficulty in Generator.DIFFICULTIES:
		var option := UiKit.button(difficulty.capitalize(), "ToggleButton")
		option.toggle_mode = true
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.pressed.connect(_pick_level.bind(difficulty))
		levels.add_child(option)
		_level_buttons[difficulty] = option

	_record = UiKit.label("", "CaptionLabel")
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker.add_child(_record)
	var start := UiKit.button("Start", "AccentButton")
	start.custom_minimum_size.y = ThemeTokens.dp(ThemeTokens.MIN_BUTTON_DP * 1.3)
	start.add_theme_font_size_override("font_size", ThemeTokens.font_size("xl"))
	start.pressed.connect(func() -> void: new_game_requested.emit(_variant_id, _difficulty))
	_picker.add_child(start)


func _open_area(page: VBoxContainer) -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)
	return spacer


## The empty part of the current page, where the decorative cube can sit.
func open_area() -> Rect2:
	return (_home_spacer if _home.visible else _picker_spacer).get_global_rect()


## A tall button with a title and a line of explanation under it.
## Returns {"button", "title", "body"}.
func _card_button(title: String, body: String, variation: String) -> Dictionary:
	var button := UiKit.button("", variation)
	button.custom_minimum_size.y = ThemeTokens.dp(TIER_CARD_DP)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ThemeTokens.space(4))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var title_label := UiKit.label(title, "")
	title_label.add_theme_font_override("font", ThemeManager.font_semibold)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_label)
	var body_label := UiKit.label(body, "CaptionLabel")
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(body_label)
	return {"button": button, "title": title_label, "body": body_label}


func _show_page(page: VBoxContainer) -> void:
	_home.visible = page == _home
	_picker.visible = page == _picker
	UiKit.fade_in(page, ThemeManager.reduced_motion())


func _on_play() -> void:
	if SaveManager.has_game():
		resume_requested.emit()
	else:
		_show_page(_picker)


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
	_play.text = "Continue" if has_game else "Play"
	_play_detail.visible = has_game
	_new_puzzle.visible = has_game
	if has_game:
		_play_detail.text = _describe_saved(SaveManager.get_game())

	var today := SaveData.today()
	var daily := SaveManager.daily()
	var streak := SaveData.current_streak(daily, today)
	var done := SaveData.solved_today(daily, today)
	_daily.disabled = done
	if done:
		_daily_detail.text = "Done for today. Streak %d, come back tomorrow." % streak
	elif streak > 0:
		_daily_detail.text = "Today's Slice Sudoku. Keep your %d day streak going." % streak
	else:
		_daily_detail.text = "One new Slice Sudoku every day."

	for variant_id: String in _tier_cards:
		var card: Dictionary = _tier_cards[variant_id]
		var chosen := variant_id == _variant_id
		(card["button"] as Button).set_pressed_no_signal(chosen)
		var ink := ThemeManager.color("accent_ink") if chosen else ThemeManager.color("ink")
		(card["title"] as Label).add_theme_color_override("font_color", ink)
		(card["body"] as Label).add_theme_color_override("font_color", Color(ink, 0.8) if chosen else ThemeManager.color("ink_muted"))
	for difficulty: String in _level_buttons:
		(_level_buttons[difficulty] as Button).set_pressed_no_signal(difficulty == _difficulty)
	for key: String in _setting_buttons:
		(_setting_buttons[key] as Button).set_pressed_no_signal(SaveManager.get_setting(key))

	var entry: Dictionary = SaveManager.stats().get("%s/%s" % [_variant_id, _difficulty], {})
	var solved: int = entry.get("solved", 0)
	var best: float = entry.get("best_time", 0.0)
	_record.text = "Solved %d" % solved
	if best > 0.0:
		_record.text += " · Best %s" % GameUi.format_time(best)


func _describe_saved(game: Dictionary) -> String:
	var variant := Variants.by_id(str(game.get("variant", "")))
	var name := variant.display_name if variant != null else ""
	var mode := str(game.get("mode", "classic"))
	if mode == "daily":
		name = "Daily puzzle"
	elif mode == "tutorial":
		name = "Practice cube"
	else:
		name += " · %s" % str(game.get("difficulty", "")).capitalize()
	var raw_elapsed: Variant = game.get("elapsed", 0.0)
	var elapsed := float(raw_elapsed) if raw_elapsed is float or raw_elapsed is int else 0.0
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
	_stats_body.add_child(UiKit.label("Streak %d · Longest %d · Solved %d" % [
		SaveData.current_streak(daily, SaveData.today()),
		int(daily.get("best_streak", 0)),
		int(daily_entry.get("solved", 0)),
	], "MutedLabel"))


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
	if not _tier_cards.is_empty():
		_refresh()


func _update_safe_area() -> void:
	var margins := UiKit.safe_margins(get_viewport())
	var gutter := ThemeTokens.space(5)
	_margin.add_theme_constant_override("margin_left", int(margins.position.x) + gutter)
	_margin.add_theme_constant_override("margin_top", int(margins.position.y) + gutter)
	_margin.add_theme_constant_override("margin_right", int(margins.size.x) + gutter)
	_margin.add_theme_constant_override("margin_bottom", int(margins.size.y) + gutter)
