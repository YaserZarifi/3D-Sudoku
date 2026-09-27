extends Node3D
## Menu scene: a slowly turning solved cube behind the menu controls.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const Variants := preload("res://scripts/sudoku/variants.gd")
const Generator := preload("res://scripts/sudoku/generator.gd")
const Board := preload("res://scripts/sudoku/board.gd")
const CellStates := preload("res://scripts/board/cell_states.gd")

## Turns per second of the idle spin.
const SPIN_SPEED := 0.03
const DEMO_SEED := 7

signal new_game_requested(variant_id: String, difficulty: String)
signal resume_requested

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _camera_rig: Node3D = $CameraRig
@onready var _board: Node3D = $Board3D
@onready var _menu: Control = $UI/Menu

var _demo: Board


func _ready() -> void:
	_menu.new_game_requested.connect(new_game_requested.emit)
	_menu.resume_requested.connect(resume_requested.emit)
	_menu.open_area_changed.connect(_camera_rig.set_view_area)
	ThemeManager.theme_changed.connect(_apply_palette)
	var variant := Variants.slice_sudoku(3)
	var puzzle := Generator.generate(variant, "easy", DEMO_SEED)
	_board.build(variant, ThemeManager.palette, {"entry": ThemeManager.font_semibold, "given": ThemeManager.font_bold})
	_demo = Board.from_givens(variant, puzzle.solution)
	_apply_palette()
	_camera_rig.frame_board(_board.extent())


func _process(delta: float) -> void:
	if not ThemeManager.reduced_motion():
		_board.rotate_y(TAU * SPIN_SPEED * delta)


func _apply_palette() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = ThemeManager.color("bg")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = ThemeTokens.AMBIENT_ENERGY
	_environment.environment = environment
	_board.set_palette(ThemeManager.palette)
	_board.apply_states(CellStates.compute(_demo, -1))
