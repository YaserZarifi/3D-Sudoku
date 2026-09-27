extends Node3D
## Builds and renders the cube from a Variant. Knows nothing about game
## rules: it receives cell states and reports which cell a ray hits.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const SudokuVariant := preload("res://scripts/sudoku/variant.gd")
const Cell3D := preload("res://scripts/board/cell_3d.gd")
const CellMaterials := preload("res://scripts/board/cell_materials.gd")
const CellMesh := preload("res://scripts/board/cell_mesh.gd")

const NO_CELL := -1

var variant: SudokuVariant
var cells: Array[Cell3D] = []
var materials: CellMaterials
var reduced_motion := false:
	set(value):
		reduced_motion = value
		for cell in cells:
			cell.reduced_motion = value

var _spacing := ThemeTokens.CELL_SPACING
var _spacing_tween: Tween
var _body_mesh: Mesh


func build(board_variant: SudokuVariant, palette: Dictionary, font: Font = null) -> void:
	for cell in cells:
		cell.queue_free()
	cells.clear()
	variant = board_variant
	materials = CellMaterials.new(palette)
	_body_mesh = CellMesh.beveled_box(ThemeTokens.CELL_SIZE, ThemeTokens.CELL_BEVEL)

	for index in variant.cell_count:
		var cell := Cell3D.new()
		cell.name = "Cell%d" % index
		cell.setup(index, _body_mesh, font)
		cell.reduced_motion = reduced_motion
		add_child(cell)
		cells.append(cell)
	_layout()


func set_palette(palette: Dictionary) -> void:
	materials = CellMaterials.new(palette)


func apply_states(states: Array[Dictionary]) -> void:
	for index in cells.size():
		cells[index].apply_state(states[index], materials)


func show_solved() -> void:
	for cell in cells:
		cell.set_solved_look(materials)


## Pops every cell in a wave from one corner and turns it the success color.
## Awaitable; returns once the last cell has started its pop.
func play_solved_wave(step_seconds: float) -> void:
	var order := cells.duplicate()
	var corner := Vector3.ONE * -INF
	for cell in cells:
		corner = corner.max(cell.position)
	order.sort_custom(func(a: Cell3D, b: Cell3D) -> bool:
		return a.position.distance_to(corner) < b.position.distance_to(corner))
	for cell: Cell3D in order:
		cell.set_solved_look(materials)
		cell.pop()
		if not reduced_motion:
			await get_tree().create_timer(step_seconds).timeout


func pop_cell(index: int) -> void:
	if index >= 0 and index < cells.size():
		cells[index].pop()


func shake_cell(index: int) -> void:
	if index >= 0 and index < cells.size():
		cells[index].shake()


## Spreads cells apart while the player is dragging, to show the inside.
func set_exploded(exploded: bool) -> void:
	var goal := ThemeTokens.CELL_SPACING_DRAG if exploded else ThemeTokens.CELL_SPACING
	if _spacing_tween != null and _spacing_tween.is_valid():
		_spacing_tween.kill()
	if reduced_motion:
		_set_spacing(goal)
		return
	_spacing_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_spacing_tween.tween_method(_set_spacing, _spacing, goal, ThemeTokens.MOTION_SLOW)


## Nearest pickable cell hit by a ray given in world space, or NO_CELL.
func pick(ray_origin: Vector3, ray_direction: Vector3) -> int:
	var to_local_space := global_transform.affine_inverse()
	var origin := to_local_space * ray_origin
	var direction := (to_local_space.basis * ray_direction).normalized()
	var best := NO_CELL
	var best_distance := INF
	for cell in cells:
		if not cell.is_pickable():
			continue
		var hit: Variant = cell.pick_box().intersects_ray(origin, direction)
		if hit == null:
			continue
		var distance := origin.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			best = cell.index
	return best


## Half the cube's width in world units, used to frame the camera.
func extent() -> float:
	if variant == null:
		return 0.0
	return (variant.size - 1) * 0.5 * ThemeTokens.CELL_SPACING + ThemeTokens.CELL_SIZE * 0.5


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or cells.is_empty():
		return
	var eye := to_local(camera.global_position)
	for cell in cells:
		cell.face_direction((eye - cell.position).normalized())


func _set_spacing(value: float) -> void:
	_spacing = value
	_layout()


func _layout() -> void:
	if variant == null:
		return
	var center := (variant.size - 1) * 0.5
	for cell in cells:
		var coord := variant.coord_of(cell.index)
		cell.position = (Vector3(coord) - Vector3.ONE * center) * _spacing
