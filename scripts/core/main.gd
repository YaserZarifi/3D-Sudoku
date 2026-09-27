extends Node
## Entry point. Swaps between the menu and the game scene.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const MenuScene := preload("res://scenes/menu/menu.tscn")
const GameScene := preload("res://scenes/game/game.tscn")

## Above every screen, so the fade covers the swap.
const FADE_LAYER := 100

var _screen: Node
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_fade.color = ThemeManager.color("bg")
	show_menu()
	_fade_to(0.0)


func show_menu() -> void:
	if _screen != null:
		if _busy:
			return
		_busy = true
		await _fade_to(1.0)
	var menu := MenuScene.instantiate()
	menu.new_game_requested.connect(_start_game)
	menu.resume_requested.connect(_resume_game)
	menu.daily_requested.connect(_open_and.bind("start_daily"))
	menu.tutorial_requested.connect(_open_and.bind("start_tutorial"))
	_swap(menu)
	if _busy:
		_busy = false
		_fade_to(0.0)


func _start_game(variant_id: String, difficulty: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	var game := _open_game()
	game.start_new(variant_id, difficulty)
	_busy = false
	_fade_to(0.0)


## Fades to a fresh game scene and calls one of its start methods.
func _open_and(start_method: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	var game := _open_game()
	game.call(start_method)
	_busy = false
	_fade_to(0.0)


func _resume_game() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	var game := _open_game()
	var restored: bool = game.resume(SaveManager.get_game())
	_busy = false
	if restored:
		_fade_to(0.0)
	else:
		show_menu()


func _open_game() -> Node:
	var game := GameScene.instantiate()
	game.menu_requested.connect(show_menu)
	_swap(game)
	return game


func _swap(next: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = next
	add_child(next)


## Fades the cover over the screen (1.0) or away (0.0). Input is blocked
## while covered so a double tap can't start two games.
func _fade_to(alpha: float) -> Signal:
	_fade.color = Color(ThemeManager.color("bg"), _fade.color.a)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "color:a", alpha, ThemeTokens.motion(ThemeTokens.MOTION_BASE, ThemeManager.reduced_motion()))
	return tween.finished


func _notification(what: int) -> void:
	# Back on the menu leaves the app. In the game, the game scene pauses instead.
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _screen == null or not _screen.has_signal("resume_requested"):
		return
	var menu: Node = _screen.get_node_or_null("UI/Menu")
	if menu != null and menu.has_open_sheet():
		return
	get_tree().quit()
