extends Node
## Autoload. Holds the active palette and builds the UI Theme from tokens.
## Dark mode is just the second token set.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")

signal theme_changed

var palette: Dictionary = ThemeTokens.LIGHT
var theme: Theme
var dark := false


func _ready() -> void:
	SaveManager.settings_changed.connect(_refresh)
	_refresh(true)


func color(token: String) -> Color:
	return palette[token]


func reduced_motion() -> bool:
	return SaveManager.get_setting("reduced_motion")


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
	built.default_font_size = ThemeTokens.font_size("lg")

	var ink: Color = palette["ink"]
	var surface: Color = palette["surface"]
	var accent: Color = palette["accent"]

	_button_type(built, "Button", surface, palette["surface_pressed"], ink)
	_button_type(built, "AccentButton", accent, accent.darkened(0.15), palette["accent_ink"])
	_button_type(built, "GhostButton", Color(surface, 0.0), Color(palette["surface_pressed"], 0.8), ink)
	_button_type(built, "PadButton", surface, palette["surface_pressed"], accent)
	built.set_font_size("font_size", "PadButton", ThemeTokens.font_size("xl"))
	_button_type(built, "ToggleButton", surface, accent, ink)
	built.set_color("font_pressed_color", "ToggleButton", palette["accent_ink"])
	built.set_color("font_hover_pressed_color", "ToggleButton", palette["accent_ink"])
	built.set_stylebox("hover_pressed", "ToggleButton", _box(accent, ThemeTokens.RADIUS_BUTTON))

	built.set_color("font_color", "Label", ink)
	built.set_type_variation("MutedLabel", "Label")
	built.set_color("font_color", "MutedLabel", palette["ink_muted"])
	built.set_font_size("font_size", "MutedLabel", ThemeTokens.font_size("md"))
	built.set_type_variation("TitleLabel", "Label")
	built.set_font_size("font_size", "TitleLabel", ThemeTokens.font_size("xxl"))
	built.set_type_variation("HeadingLabel", "Label")
	built.set_font_size("font_size", "HeadingLabel", ThemeTokens.font_size("xl"))

	var panel := _box(surface, ThemeTokens.RADIUS_PANEL)
	panel.shadow_color = Color(0, 0, 0, 0.12)
	panel.shadow_size = ThemeTokens.dp(8)
	var padding := ThemeTokens.space(4)
	panel.content_margin_left = padding
	panel.content_margin_right = padding
	panel.content_margin_top = padding
	panel.content_margin_bottom = padding
	built.set_stylebox("panel", "PanelContainer", panel)
	built.set_type_variation("Scrim", "PanelContainer")
	built.set_stylebox("panel", "Scrim", _box(palette["scrim"], 0))

	built.set_constant("separation", "VBoxContainer", ThemeTokens.space(2))
	built.set_constant("separation", "HBoxContainer", ThemeTokens.space(2))
	built.set_constant("h_separation", "GridContainer", ThemeTokens.space(2))
	built.set_constant("v_separation", "GridContainer", ThemeTokens.space(2))
	return built


func _button_type(built: Theme, type_name: String, fill: Color, pressed_fill: Color, text: Color) -> void:
	if type_name != "Button":
		built.set_type_variation(type_name, "Button")
	var normal := _box(fill, ThemeTokens.RADIUS_BUTTON)
	var pressed := _box(pressed_fill, ThemeTokens.RADIUS_BUTTON)
	var disabled := _box(Color(fill, fill.a * 0.5), ThemeTokens.RADIUS_BUTTON)
	built.set_stylebox("normal", type_name, normal)
	built.set_stylebox("hover", type_name, normal)
	built.set_stylebox("pressed", type_name, pressed)
	built.set_stylebox("hover_pressed", type_name, pressed)
	built.set_stylebox("disabled", type_name, disabled)
	built.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		built.set_color(state, type_name, text)
	built.set_color("font_disabled_color", type_name, Color(text, 0.4))


func _box(fill: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(ThemeTokens.dp(radius))
	var padding := ThemeTokens.space(2)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
