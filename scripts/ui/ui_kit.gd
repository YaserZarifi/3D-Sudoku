extends RefCounted
## Small helpers so screens build controls the same way.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")


static func button(text: String, variation: String = "Button") -> Button:
	var result := Button.new()
	result.text = text
	result.theme_type_variation = variation
	result.custom_minimum_size = Vector2(ThemeTokens.dp(ThemeTokens.MIN_BUTTON_DP), ThemeTokens.dp(ThemeTokens.MIN_BUTTON_DP))
	result.focus_mode = Control.FOCUS_NONE
	add_press_feedback(result)
	return result


## Shrinks a button slightly while it's held, so every press feels physical.
static func add_press_feedback(target: BaseButton) -> void:
	var center := func() -> void: target.pivot_offset = target.size * 0.5
	target.resized.connect(center)
	target.button_down.connect(func() -> void: _press_to(target, ThemeTokens.PRESS_SCALE))
	target.button_up.connect(func() -> void: _press_to(target, 1.0))


static func _press_to(target: Control, goal: float) -> void:
	if not target.is_inside_tree():
		return
	var tween := target.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE * goal, ThemeTokens.MOTION_FAST)


static func label(text: String, variation: String = "") -> Label:
	var result := Label.new()
	result.text = text
	if variation != "":
		result.theme_type_variation = variation
	return result


## Safe-area insets in canvas pixels: position holds left/top,
## size holds right/bottom.
static func safe_margins(viewport: Viewport) -> Rect2:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0.0 or safe.size.x <= 0.0:
		return Rect2()
	# The safe area is reported in screen pixels; the UI works in canvas pixels.
	var scale := viewport.get_visible_rect().size / window_size
	var left := maxf(safe.position.x, 0.0)
	var top := maxf(safe.position.y, 0.0)
	var right := maxf(window_size.x - safe.end.x, 0.0)
	var bottom := maxf(window_size.y - safe.end.y, 0.0)
	# On desktop the "safe area" is the whole monitor, which says nothing useful.
	if not OS.has_feature("mobile"):
		return Rect2()
	return Rect2(left * scale.x, top * scale.y, right * scale.x, bottom * scale.y)


static func fade_in(control: Control, reduced_motion: bool) -> void:
	control.modulate.a = 0.0
	var tween := control.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, ThemeTokens.motion(ThemeTokens.MOTION_SLOW, reduced_motion))
