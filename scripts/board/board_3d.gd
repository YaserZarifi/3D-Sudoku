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
## Digits only need to move when the eye moves relative to the board or a
## cell changes size, so most frames skip the update entirely.
var _labels_dirty := true
var _last_eye := Vector3.INF
var _spacing_tween: Tween
var _body_mesh: Mesh
var _axis_labels: Array[Label3D] = []
var _confetti: CPUParticles3D
var _palette: Dictionary = {}


## fonts: {"entry": Font, "given": Font}, both optional.
func build(board_variant: SudokuVariant, palette: Dictionary, fonts: Dictionary = {}) -> void:
	for cell in cells:
		cell.queue_free()
	cells.clear()
	variant = board_variant
	_palette = palette
	materials = CellMaterials.new(palette)
	_body_mesh = CellMesh.beveled_box(ThemeTokens.CELL_SIZE, ThemeTokens.CELL_BEVEL)

	for index in variant.cell_count:
		var cell := Cell3D.new()
		cell.name = "Cell%d" % index
		cell.setup(index, _body_mesh, fonts, variant.digit_count, variant.size)
		cell.reduced_motion = reduced_motion
		add_child(cell)
		cells.append(cell)
	_layout()


func set_palette(palette: Dictionary) -> void:
	_palette = palette
	materials = CellMaterials.new(palette)
	_color_axis_labels()


## Letters X, Y and Z just outside the cube, in the colors of the slice
## buttons, so it's clear which way each slice runs.
func show_axes(font: Font) -> void:
	for label in _axis_labels:
		label.queue_free()
	_axis_labels.clear()
	for axis in 3:
		var label := Label3D.new()
		label.text = ["X", "Y", "Z"][axis]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = ThemeTokens.AXIS_LABEL_FONT_SIZE
		label.pixel_size = ThemeTokens.DIGIT_PIXEL_SIZE
		label.outline_size = 0
		label.shaded = false
		if font != null:
			label.font = font
		add_child(label)
		_axis_labels.append(label)
	_color_axis_labels()
	_layout()


## Scales every cell in from nothing, center first, when a puzzle starts.
func play_assemble() -> void:
	if reduced_motion:
		return
	for cell in cells:
		cell.assemble(cell.position.length() * ThemeTokens.ASSEMBLE_STEP * 10.0)
	_labels_dirty = true


## A short burst of confetti around the cube.
func play_confetti() -> void:
	if reduced_motion:
		return
	if _confetti == null:
		_confetti = CPUParticles3D.new()
		_confetti.one_shot = true
		_confetti.emitting = false
		_confetti.amount = ThemeTokens.CONFETTI_AMOUNT
		_confetti.lifetime = ThemeTokens.CONFETTI_LIFETIME
		_confetti.explosiveness = 0.95
		_confetti.direction = Vector3.UP
		_confetti.spread = 75.0
		_confetti.initial_velocity_min = 4.0
		_confetti.initial_velocity_max = 7.5
		_confetti.gravity = Vector3(0, -7.0, 0)
		_confetti.angular_velocity_min = -360.0
		_confetti.angular_velocity_max = 360.0
		_confetti.scale_amount_min = 0.7
		_confetti.scale_amount_max = 1.3
		var quad := QuadMesh.new()
		quad.size = Vector2(0.12, 0.08)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = material
		_confetti.mesh = quad
		add_child(_confetti)
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	colors.colors = PackedColorArray([_palette.get("accent", Color.BLUE), _palette.get("gold", Color.GOLD),
		_palette.get("success", Color.GREEN), _palette.get("axis_x", Color.RED), _palette.get("axis_z", Color.PURPLE)])
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_confetti.color_initial_ramp = colors
	_confetti.position = Vector3(0, -extent() * 0.5, 0)
	_confetti.restart()


func _color_axis_labels() -> void:
	for axis in _axis_labels.size():
		_axis_labels[axis].modulate = _palette.get(["axis_x", "axis_y", "axis_z"][axis], Color.WHITE)


func apply_states(states: Array[Dictionary]) -> void:
	for index in cells.size():
		cells[index].apply_state(states[index], materials)
	_labels_dirty = true


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
	var animating := false
	for cell in cells:
		if cell.is_animating():
			animating = true
			break
	if not _labels_dirty and not animating and eye.is_equal_approx(_last_eye):
		return
	_labels_dirty = false
	_last_eye = eye
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
	var edge := center * _spacing
	var reach := edge + ThemeTokens.CELL_SIZE * 0.5 + ThemeTokens.AXIS_LABEL_GAP
	# Each letter sits past the end of a front edge running along its axis,
	# clear of the digits: X bottom right, Y top left, Z bottom left front.
	var anchors := [Vector3(reach, -edge, edge), Vector3(-edge, reach, edge), Vector3(-edge, -edge, reach)]
	for axis in _axis_labels.size():
		_axis_labels[axis].position = anchors[axis]
	_labels_dirty = true
