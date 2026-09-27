extends Control
## Start screen: resume, pick a tier and level, settings and a stats line.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
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

signal new_game_requested(variant_id: String, difficulty: String)
signal resume_requested
## The empty part of the screen where the decorative cube can sit.
signal open_area_changed(area: Rect2)

var _variant_id: String
var _difficulty: String
var _resume: Button
var _rules: Label
var _stats: Label
var _tier_buttons: Dictionary = {}
var _level_buttons: Dictionary = {}
var _setting_buttons: Dictionary = {}
var _margin: MarginContainer


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


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	_margin.add_child(column)

	var title := UiKit.label("3D Sudoku", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_rules = UiKit.label("", "MutedLabel")
	_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rules)

	# Keeps the top of the screen free for the spinning cube behind the menu.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.resized.connect(func() -> void: open_area_changed.emit(spacer.get_global_rect()))
	column.add_child(spacer)

	_resume = UiKit.button("Resume", "AccentButton")
	_resume.pressed.connect(resume_requested.emit)
	column.add_child(_resume)

	var tiers := HBoxContainer.new()
	column.add_child(tiers)
	for variant_id in Variants.all_ids():
		var tier := UiKit.button(Variants.by_id(variant_id).display_name, "ToggleButton")
		tier.toggle_mode = true
		tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier.pressed.connect(_pick_tier.bind(variant_id))
		tiers.add_child(tier)
		_tier_buttons[variant_id] = tier

	var levels := HBoxContainer.new()
	column.add_child(levels)
	for difficulty in Generator.DIFFICULTIES:
		var level := UiKit.button(difficulty.capitalize(), "ToggleButton")
		level.toggle_mode = true
		level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level.pressed.connect(_pick_level.bind(difficulty))
		levels.add_child(level)
		_level_buttons[difficulty] = level

	var start := UiKit.button("New Game", "AccentButton")
	start.pressed.connect(func() -> void: new_game_requested.emit(_variant_id, _difficulty))
	column.add_child(start)

	_stats = UiKit.label("", "MutedLabel")
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats)

	var settings := GridContainer.new()
	settings.columns = 2
	column.add_child(settings)
	for entry in SETTINGS:
		var toggle := UiKit.button(entry[1], "ToggleButton")
		toggle.toggle_mode = true
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.add_theme_font_size_override("font_size", ThemeTokens.font_size("md"))
		var key: String = entry[0]
		toggle.toggled.connect(func(on: bool) -> void: SaveManager.set_setting(key, on))
		settings.add_child(toggle)
		_setting_buttons[key] = toggle


func _pick_tier(variant_id: String) -> void:
	_variant_id = variant_id
	_refresh()


func _pick_level(difficulty: String) -> void:
	_difficulty = difficulty
	_refresh()


func _refresh() -> void:
	_resume.visible = SaveManager.has_game()
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
	_stats.text = "Solved %d" % solved
	if best > 0.0:
		_stats.text += " · Best %s" % GameUi.format_time(best)


func _apply_theme() -> void:
	theme = ThemeManager.theme


func _update_safe_area() -> void:
	var margins := UiKit.safe_margins(get_viewport())
	var gutter := ThemeTokens.space(5)
	_margin.add_theme_constant_override("margin_left", int(margins.position.x) + gutter)
	_margin.add_theme_constant_override("margin_top", int(margins.position.y) + gutter)
	_margin.add_theme_constant_override("margin_right", int(margins.size.x) + gutter)
	_margin.add_theme_constant_override("margin_bottom", int(margins.size.y) + gutter)
