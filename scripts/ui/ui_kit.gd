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


## A dimmed full-screen layer with a centered panel. Returns
## {"root": the layer, "box": column for content, "title": heading label}.
## Hidden until the caller shows it.
static func sheet(parent: Control, title: String) -> Dictionary:
	var scrim := PanelContainer.new()
	scrim.theme_type_variation = "Scrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.visible = false
	parent.add_child(scrim)
	var center := CenterContainer.new()
	scrim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ThemeTokens.dp(300), 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ThemeTokens.space(3))
	panel.add_child(box)
	var heading := label(title, "HeadingLabel")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	return {"root": scrim, "box": box, "title": heading}


## Shows or hides a sheet from sheet(), with a short fade and lift.
static func show_sheet(root: Control, visible_now: bool, reduced_motion: bool) -> void:
	root.visible = visible_now
	if not visible_now:
		return
	fade_in(root, reduced_motion)
	if reduced_motion:
		return
	var panel := root.get_child(0).get_child(0) as Control
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.96
	var tween := panel.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, ThemeTokens.MOTION_SLOW)


## A filled circle, used as a color key next to labels such as X, Y and Z.
static func dot_icon(color: Color, diameter: int) -> ImageTexture:
	var size := maxi(diameter, 4)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius := size * 0.5
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(radius, radius))
			# One pixel of soft edge keeps the dot round at small sizes.
			var alpha := clampf(radius - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(color, color.a * alpha))
	return ImageTexture.create_from_image(image)
