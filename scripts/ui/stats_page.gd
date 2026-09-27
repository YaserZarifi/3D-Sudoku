extends VBoxContainer
## Full-screen statistics: three headline numbers, then a card per tier with
## a tile per difficulty, then the daily streak.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const SaveData := preload("res://scripts/core/save_data.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const GameUi := preload("res://scripts/ui/game_ui.gd")

signal back_pressed

var _body: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", ThemeTokens.space(3))
	var header := HBoxContainer.new()
	add_child(header)
	var back := UiKit.button("Back", "GhostButton")
	back.pressed.connect(back_pressed.emit)
	header.add_child(back)
	var heading := UiKit.label("Statistics", "HeadingLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(heading)
	var balance := Control.new()
	balance.custom_minimum_size = back.get_combined_minimum_size()
	header.add_child(balance)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", ThemeTokens.space(4))
	scroll.add_child(_body)


## Rebuilds everything from the saved statistics.
func refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	var stats := SaveManager.stats()
	var daily := SaveManager.daily()
	var today := SaveData.today()

	var played := 0
	var solved := 0
	for key: String in stats:
		played += int(stats[key].get("played", 0))
		solved += int(stats[key].get("solved", 0))
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", ThemeTokens.space(2))
	_body.add_child(hero)
	hero.add_child(_hero_tile(str(solved), "SOLVED"))
	hero.add_child(_hero_tile(_percent(solved, played), "WIN RATE"))
	hero.add_child(_hero_tile(str(SaveData.current_streak(daily, today)), "STREAK"))

	for variant_id in Variants.all_ids():
		_body.add_child(_tier_card(variant_id, stats))
	_body.add_child(_daily_card(daily, stats.get(SaveData.DAILY_KEY, {}), today))


func _hero_tile(value: String, caption: String) -> PanelContainer:
	var tile := _card()
	# Narrower padding than other cards, so three fit side by side on a phone.
	tile.theme_type_variation = "HeroCard"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := _column(tile, 0)
	var number := UiKit.label(value, "DisplayLabel")
	number.add_theme_font_size_override("font_size", ThemeTokens.font_size("xxl"))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", ThemeManager.color("accent"))
	box.add_child(number)
	var label := UiKit.label(caption, "OverlineLabel")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return tile


func _tier_card(variant_id: String, stats: Dictionary) -> PanelContainer:
	var card := _card()
	var box := _column(card, ThemeTokens.space(3))
	box.add_child(UiKit.label(Variants.by_id(variant_id).display_name, "HeadingLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ThemeTokens.space(3))
	box.add_child(row)
	for difficulty in Generator.DIFFICULTIES:
		var entry: Dictionary = stats.get("%s/%s" % [variant_id, difficulty], {})
		row.add_child(_level_tile(difficulty, entry))
	return card


func _level_tile(difficulty: String, entry: Dictionary) -> VBoxContainer:
	var played: int = entry.get("played", 0)
	var solved: int = entry.get("solved", 0)
	var best: float = entry.get("best_time", 0.0)
	var average := SaveData.average_time(entry)
	var tile := VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", ThemeTokens.space(1))
	tile.add_child(UiKit.label(difficulty.to_upper(), "OverlineLabel"))
	var count := UiKit.label(str(solved), "HeadingLabel")
	tile.add_child(count)
	tile.add_child(UiKit.label("of %d played" % played, "CaptionLabel"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(played, 1)
	bar.value = solved
	bar.custom_minimum_size = Vector2(0, ThemeTokens.dp(6))
	tile.add_child(bar)
	tile.add_child(_stat_line("Best", GameUi.format_time(best) if best > 0.0 else "-"))
	tile.add_child(_stat_line("Avg", GameUi.format_time(average) if average > 0.0 else "-"))
	return tile


func _daily_card(daily: Dictionary, entry: Dictionary, today: String) -> PanelContainer:
	var card := _card()
	var box := _column(card, ThemeTokens.space(3))
	box.add_child(UiKit.label("Daily puzzle", "HeadingLabel"))
	var row := HBoxContainer.new()
	box.add_child(row)
	for pair: Array in [
		["STREAK", str(SaveData.current_streak(daily, today))],
		["LONGEST", str(int(daily.get("best_streak", 0)))],
		["SOLVED", str(int(entry.get("solved", 0)))],
	]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UiKit.label(pair[0], "OverlineLabel"))
		cell.add_child(UiKit.label(pair[1], "HeadingLabel"))
		row.add_child(cell)
	return card


func _stat_line(name: String, value: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	var label := UiKit.label(name, "CaptionLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var number := UiKit.label(value, "TimerLabel")
	number.add_theme_font_size_override("font_size", ThemeTokens.font_size("sm"))
	line.add_child(number)
	return line


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "StatCard"
	# Cards never force the page wider than the screen.
	card.custom_minimum_size.x = 0
	return card


func _column(parent: Control, separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


static func _percent(part: int, whole: int) -> String:
	return "-" if whole <= 0 else "%d%%" % int(round(100.0 * part / whole))
