extends Node
## Entry point. Swaps between the menu and the game scene.

const MenuScene := preload("res://scenes/menu/menu.tscn")
const GameScene := preload("res://scenes/game/game.tscn")

var _screen: Node


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	var menu := MenuScene.instantiate()
	menu.new_game_requested.connect(_start_game)
	menu.resume_requested.connect(_resume_game)
	_swap(menu)


func _start_game(variant_id: String, difficulty: String) -> void:
	var game := _open_game()
	game.start_new(variant_id, difficulty)


func _resume_game() -> void:
	var game := _open_game()
	if not game.resume(SaveManager.get_game()):
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


func _notification(what: int) -> void:
	# Back on the menu leaves the app. In the game, the game scene pauses instead.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _screen != null and _screen.has_signal("resume_requested"):
		get_tree().quit()
