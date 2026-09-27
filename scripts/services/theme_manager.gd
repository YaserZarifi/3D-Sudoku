extends Node
## Autoload. Holds the active palette and fonts, and builds the UI Theme
## from tokens. Dark mode is just the second token set.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")

signal theme_changed

var palette: Dictionary = ThemeTokens.LIGHT
var theme: Theme
var dark := false
## Tabular figures keep timers and digits from jumping around.
var font_regular: Font
var font_semibold: Font
var font_bold: Font
## Outfit at three weights, for display text and the cube's digits.
var display_medium: Font
var display_semibold: Font
var display_bold: Font
## Small uppercase section labels.
var font_overline: Font


func _ready() -> void:
	font_regular = _font(ThemeTokens.FONT_REGULAR)
	font_semibold = _font(ThemeTokens.FONT_SEMIBOLD)
	font_bold = _font(ThemeTokens.FONT_BOLD)
	display_medium = _display(ThemeTokens.DISPLAY_WEIGHT_MEDIUM, 0)
	display_semibold = _display(ThemeTokens.DISPLAY_WEIGHT_SEMIBOLD, ThemeTokens.TRACKING_DISPLAY)
	display_bold = _display(ThemeTokens.DISPLAY_WEIGHT_BOLD, ThemeTokens.TRACKING_DISPLAY)
	font_overline = _font(ThemeTokens.FONT_SEMIBOLD)
	(font_overline as FontVariation).spacing_glyph = ThemeTokens.TRACKING_OVERLINE
	SaveManager.settings_changed.connect(_refresh)
	_refresh(true)


func color(token: String) -> Color:
	return palette[token]


func reduced_motion() -> bool:
	return SaveManager.get_setting("reduced_motion")


func _font(path: String) -> Font:
	var variation := FontVariation.new()
	variation.base_font = load(path)
	var tabular := TextServerManager.get_primary_interface().name_to_tag("tnum")
	variation.opentype_features = {tabular: 1}
	return variation


func _display(weight: int, tracking: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = load(ThemeTokens.FONT_DISPLAY)
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	variation.spacing_glyph = tracking
	return variation


func _refresh(force: bool = false) -> void:
	var want_dark: bool = SaveManager.get_setting("dark_mode")
	if want_dark == dark and not force:
		return
	dark = want_dark
	palette = ThemeTokens.palette(dark)
	theme = _build_theme()
	RenderingServer.set_default_clear_color(palette["bg"])
	theme_changed.emit()


func _build_theme() -> Theme:
	var built := Theme.new()
	built.default_font = font_regular
	built.default_font_size = ThemeTokens.font_size("lg")

	var ink: Color = palette["ink"]
	var surface: Color = palette["surface"]
	var accent: Color = palette["accent"]
	var hairline: Color = palette["hairline"]

	_button_type(built, "Button", surface, palette["surface_pressed"], ink, hairline)
	_button_type(built, "AccentButton", accent, accent.darkened(0.12), palette["accent_ink"], Color.TRANSPARENT)
	_button_type(built, "GhostButton", Color(surface, 0.0), Color(palette["surface_pressed"], 0.8), ink, Color.TRANSPARENT)
	_button_type(built, "PadButton", surface, palette["surface_pressed"], accent, hairline)
	built.set_font_size("font_size", "PadButton", ThemeTokens.font_size("xl"))
	_button_type(built, "PadButtonActive", accent, accent.darkened(0.12), palette["accent_ink"], Color.TRANSPARENT)
	built.set_font_size("font_size", "PadButtonActive", ThemeTokens.font_size("xl"))
	_button_type(built, "PadButtonNotes", surface, palette["surface_pressed"], palette["ink_muted"], hairline)
	built.set_font_size("font_size", "PadButtonNotes", ThemeTokens.font_size("lg"))
	_button_type(built, "ToggleButton", surface, accent, ink, hairline)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		built.set_color(state, "ToggleButton", palette["accent_ink"])
	built.set_stylebox("hover_pressed", "ToggleButton", _box(accent, ThemeTokens.RADIUS_BUTTON, Color.TRANSPARENT))
	for type_name in ["Button", "GhostButton", "ToggleButton"]:
		built.set_font(&"font", type_name, font_semibold)
	for type_name in ["AccentButton", "PadButton", "PadButtonActive", "PadButtonNotes"]:
		built.set_font(&"font", type_name, display_semibold)

	built.set_color("font_color", "Label", ink)
	built.set_type_variation("MutedLabel", "Label")
	built.set_color("font_color", "MutedLabel", palette["ink_muted"])
	built.set_font_size("font_size", "MutedLabel", ThemeTokens.font_size("md"))
	built.set_type_variation("TitleLabel", "Label")
	built.set_font_size("font_size", "TitleLabel", ThemeTokens.font_size("xxl"))
	built.set_font("font", "TitleLabel", display_bold)
	built.set_type_variation("HeadingLabel", "Label")
	built.set_font_size("font_size", "HeadingLabel", ThemeTokens.font_size("xl"))
	built.set_font("font", "HeadingLabel", display_semibold)
	built.set_type_variation("DisplayLabel", "Label")
	built.set_font("font", "DisplayLabel", display_semibold)
	built.set_font_size("font_size", "DisplayLabel", ThemeTokens.font_size("hero"))
	built.set_type_variation("OverlineLabel", "Label")
	built.set_font("font", "OverlineLabel", font_overline)
	built.set_font_size("font_size", "OverlineLabel", ThemeTokens.font_size("xs"))
	built.set_color("font_color", "OverlineLabel", palette["ink_muted"])
	built.set_type_variation("TimerLabel", "Label")
	built.set_font("font", "TimerLabel", font_semibold)
	built.set_type_variation("CaptionLabel", "Label")
	built.set_color("font_color", "CaptionLabel", palette["ink_muted"])
	built.set_font_size("font_size", "CaptionLabel", ThemeTokens.font_size("sm"))
	built.set_font("font", "CaptionLabel", font_semibold)

	var panel := _box(surface, ThemeTokens.RADIUS_PANEL, hairline)
	panel.shadow_color = palette["shadow"]
	panel.shadow_size = ThemeTokens.dp(ThemeTokens.SHADOW_DP)
	panel.shadow_offset = Vector2(0, ThemeTokens.dp(4))
	var padding := ThemeTokens.space(5)
	panel.content_margin_left = padding
	panel.content_margin_right = padding
	panel.content_margin_top = padding
	panel.content_margin_bottom = padding
	built.set_stylebox("panel", "PanelContainer", panel)
	built.set_type_variation("Scrim", "PanelContainer")
	built.set_stylebox("panel", "Scrim", _box(palette["scrim"], 0, Color.TRANSPARENT))
	built.set_type_variation("CardPanel", "PanelContainer")
	var card := _box(surface, ThemeTokens.RADIUS_BUTTON, hairline)
	card.content_margin_left = ThemeTokens.space(4)
	card.content_margin_right = ThemeTokens.space(4)
	built.set_stylebox("panel", "CardPanel", card)
	built.set_type_variation("StatCard", "PanelContainer")
	var stat := _box(surface, ThemeTokens.RADIUS_PANEL, hairline)
	stat.shadow_color = Color(palette["shadow"], palette["shadow"].a * 0.6)
	stat.shadow_size = ThemeTokens.dp(8)
	stat.shadow_offset = Vector2(0, ThemeTokens.dp(2))
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		stat.set_content_margin(side, ThemeTokens.space(4))
	built.set_stylebox("panel", "StatCard", stat)
	built.set_type_variation("HeroCard", "PanelContainer")
	var hero := stat.duplicate() as StyleBoxFlat
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		hero.set_content_margin(side, ThemeTokens.space(1))
	built.set_stylebox("panel", "HeroCard", hero)

	var track := _box(palette["surface_pressed"], 99, Color.TRANSPARENT)
	var fill := _box(accent, 99, Color.TRANSPARENT)
	for bar_box in [track, fill]:
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			bar_box.set_content_margin(side, 0)
	built.set_stylebox("background", "ProgressBar", track)
	built.set_stylebox("fill", "ProgressBar", fill)
	built.set_font_size("font_size", "ProgressBar", 1)
	var grabber := _box(Color(palette["ink_muted"], 0.35), 99, Color.TRANSPARENT)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		grabber.set_content_margin(side, ThemeTokens.dp(2))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		built.set_stylebox(state, "VScrollBar", grabber)
	built.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	built.set_constant("separation", "VBoxContainer", ThemeTokens.space(2))
	built.set_constant("separation", "HBoxContainer", ThemeTokens.space(2))
	built.set_constant("h_separation", "GridContainer", ThemeTokens.space(2))
	built.set_constant("v_separation", "GridContainer", ThemeTokens.space(2))
	return built


func _button_type(built: Theme, type_name: String, fill: Color, pressed_fill: Color, text: Color, border: Color) -> void:
	if type_name != "Button":
		built.set_type_variation(type_name, "Button")
	var normal := _box(fill, ThemeTokens.RADIUS_BUTTON, border)
	var pressed := _box(pressed_fill, ThemeTokens.RADIUS_BUTTON, border)
	var disabled := _box(Color(fill, fill.a * 0.5), ThemeTokens.RADIUS_BUTTON, border)
	built.set_stylebox("normal", type_name, normal)
	built.set_stylebox("hover", type_name, normal)
	built.set_stylebox("pressed", type_name, pressed)
	built.set_stylebox("hover_pressed", type_name, pressed)
	built.set_stylebox("disabled", type_name, disabled)
	built.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		built.set_color(state, type_name, text)
	built.set_color("font_disabled_color", type_name, Color(text, 0.4))


func _box(fill: Color, radius: int, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(ThemeTokens.dp(radius))
	box.corner_detail = 12
	box.anti_aliasing = true
	if border.a > 0.0:
		box.set_border_width_all(maxi(ThemeTokens.dp(ThemeTokens.HAIRLINE_DP), 1))
		box.border_color = border
	var padding := ThemeTokens.space(2)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
