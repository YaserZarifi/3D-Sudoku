extends Control
## First-launch intro: a few swipeable cards that explain the cube, then
## an offer to play the guided practice cube.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const IntroArt := preload("res://scripts/ui/intro_art.gd")

const SLIDES: Array[Dictionary] = [
	{"title": "Sudoku, in 3D", "art": IntroArt.Art.CUBE,
		"body": "The grid is a cube of 27 cells. Turn it, look inside and fill it in."},
	{"title": "One simple rule", "art": IntroArt.Art.SLICES,
		"body": "Every flat slice of the cube holds 1 to 9 exactly once. Slices run three ways: X, Y and Z."},
	{"title": "Turn and tap", "art": IntroArt.Art.TAP,
		"body": "Drag to turn the cube. Tap a cell to select it, then tap a number to fill it in."},
	{"title": "See inside", "art": IntroArt.Art.INSIDE,
		"body": "Tap X, Y or Z to show one slice at a time. Stuck? Hint explains the next step."},
]
## Horizontal drag, in canvas pixels, that turns the page.
const SWIPE_DISTANCE := 120.0

## practice is true when the player chose to try the guided cube.
signal finished(practice: bool)

var _page := 0
var _margin: MarginContainer
var _art: IntroArt
var _title: Label
var _body: Label
var _dots: HBoxContainer
var _next: Button
var _back: Button
var _content: VBoxContainer
var _swipe_start := Vector2.INF


func _ready() -> void:
	# The parent is a plain Node, so size comes from the anchors and offsets.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	ThemeManager.theme_changed.connect(_apply_theme)
	get_viewport().size_changed.connect(_update_safe_area)
	_apply_theme()
	_update_safe_area()
	_show_page(0, false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_swipe_start = touch.position
		elif _swipe_start != Vector2.INF:
			var moved := touch.position.x - _swipe_start.x
			_swipe_start = Vector2.INF
			if moved < -SWIPE_DISTANCE:
				_go(1)
			elif moved > SWIPE_DISTANCE:
				_go(-1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if _page > 0:
			_go(-1)
		else:
			finished.emit(false)


func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var skip := UiKit.button("Skip", "GhostButton")
	skip.pressed.connect(func() -> void: finished.emit(false))
	top.add_child(skip)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", ThemeTokens.space(4))
	column.add_child(_content)
	_art = IntroArt.new()
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.custom_minimum_size = Vector2(0, ThemeTokens.dp(200))
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_art)
	_title = UiKit.label("", "TitleLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_title)
	_body = UiKit.label("", "MutedLabel")
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", ThemeTokens.font_size("lg"))
	_body.custom_minimum_size = Vector2(0, ThemeTokens.dp(80))
	_content.add_child(_body)

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_dots)
	for i in SLIDES.size():
		var dot := TextureRect.new()
		dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_dots.add_child(dot)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_back = UiKit.button("Back", "GhostButton")
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect(_go.bind(-1))
	buttons.add_child(_back)
	_next = UiKit.button("Next", "AccentButton")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.size_flags_stretch_ratio = 2.0
	_next.pressed.connect(_on_next)
	buttons.add_child(_next)


func _on_next() -> void:
	if _page == SLIDES.size() - 1:
		finished.emit(true)
	else:
		_go(1)


func _go(step: int) -> void:
	var target := clampi(_page + step, 0, SLIDES.size() - 1)
	if target != _page:
		_show_page(target, true)


func _show_page(page: int, animate: bool) -> void:
	_page = page
	var slide: Dictionary = SLIDES[page]
	_art.art = slide["art"]
	_title.text = slide["title"]
	_body.text = slide["body"]
	_back.modulate.a = 0.0 if page == 0 else 1.0
	_back.disabled = page == 0
	_next.text = "Try a practice cube" if page == SLIDES.size() - 1 else "Next"
	_paint_dots()
	if animate:
		UiKit.fade_in(_content, ThemeManager.reduced_motion())


func _paint_dots() -> void:
	var size := ThemeTokens.dp(ThemeTokens.AXIS_DOT_DP)
	for i in _dots.get_child_count():
		var color := ThemeManager.color("accent") if i == _page else ThemeManager.color("hairline").lerp(ThemeManager.color("ink_muted"), 0.5)
		(_dots.get_child(i) as TextureRect).texture = UiKit.dot_icon(color, size)


func _apply_theme() -> void:
	theme = ThemeManager.theme
	(get_node("Background") as ColorRect).color = ThemeManager.color("bg")
	_art.palette = ThemeManager.palette
	_paint_dots()


func _update_safe_area() -> void:
	var margins := UiKit.safe_margins(get_viewport())
	var gutter := ThemeTokens.space(5)
	_margin.add_theme_constant_override("margin_left", int(margins.position.x) + gutter)
	_margin.add_theme_constant_override("margin_top", int(margins.position.y) + gutter)
	_margin.add_theme_constant_override("margin_right", int(margins.size.x) + gutter)
	_margin.add_theme_constant_override("margin_bottom", int(margins.size.y) + gutter)
