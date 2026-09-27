extends Node3D
## One cube cell. Its whole look comes from a single state dictionary
## (see cell_states.gd), applied in apply_state().

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")
const CellMaterials := preload("res://scripts/board/cell_materials.gd")

## Gap kept between the digit and the cell surface so they never z-fight.
const LABEL_MARGIN := 0.03
const MARK_SIZE := 0.16
const POP_SCALE := 1.18
const SHAKE_DISTANCE := 0.06
const SHAKE_STEPS := 4
## Same width as a digit in a tabular font, so note columns line up.
const FIGURE_SPACE := "\u2007"

var index: int = -1
var home_position := Vector3.ZERO
var state: Dictionary = {}
var reduced_motion := false

var _visual: Node3D
var _body: MeshInstance3D
var _outline: MeshInstance3D
var _mark: MeshInstance3D
var _label: Label3D
var _notes: Label3D
var _digit_count := 9
var _notes_per_row := 3
var _target_scale := 1.0
var _font_entry: Font
var _font_given: Font
var _scale_tween: Tween
var _shake_tween: Tween


## fonts may hold "entry" and "given"; missing ones use Godot's default.
func setup(cell_index: int, body_mesh: Mesh, fonts: Dictionary, digit_count: int = 9, notes_per_row: int = 3) -> void:
	index = cell_index
	_digit_count = digit_count
	_notes_per_row = notes_per_row
	_visual = Node3D.new()
	add_child(_visual)

	_body = MeshInstance3D.new()
	_body.mesh = body_mesh
	_visual.add_child(_body)

	_outline = MeshInstance3D.new()
	_outline.mesh = body_mesh
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	_visual.add_child(_outline)

	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3.ONE * MARK_SIZE
	_mark = MeshInstance3D.new()
	_mark.mesh = mark_mesh
	# Sits on the top front corner, where the bevel leaves room for it.
	_mark.position = Vector3.ONE * (ThemeTokens.CELL_SIZE * 0.5 - ThemeTokens.CELL_BEVEL)
	_mark.visible = false
	_visual.add_child(_mark)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = ThemeTokens.DIGIT_FONT_SIZE
	_label.pixel_size = ThemeTokens.DIGIT_PIXEL_SIZE
	_label.double_sided = true
	_label.shaded = false
	_font_entry = fonts.get("entry")
	_font_given = fonts.get("given", _font_entry)
	if _font_entry != null:
		_label.font = _font_entry
	add_child(_label)

	_notes = Label3D.new()
	_notes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_notes.font_size = ThemeTokens.NOTE_FONT_SIZE
	_notes.pixel_size = ThemeTokens.DIGIT_PIXEL_SIZE
	_notes.line_spacing = ThemeTokens.NOTE_LINE_SPACING
	_notes.double_sided = true
	_notes.shaded = false
	_notes.outline_size = 0
	if _font_entry != null:
		_notes.font = _font_entry
	add_child(_notes)


func apply_state(new_state: Dictionary, materials: CellMaterials) -> void:
	state = new_state
	var dimmed: bool = state["is_dimmed"]
	var conflict: bool = state["is_conflict"]
	var selected: bool = state["is_selected"]
	var peer: bool = state["is_peer"]
	var given: bool = state["is_given"]
	var digit: int = state["digit"]

	if dimmed:
		_body.material_override = materials.body_dimmed
	elif conflict:
		_body.material_override = materials.body_conflict
	elif selected:
		_body.material_override = materials.body_selected
	elif bool(state["is_same_digit"]):
		_body.material_override = materials.body_same
	elif peer:
		_body.material_override = materials.body_peer
	elif given:
		_body.material_override = materials.body_given
	else:
		_body.material_override = materials.body

	var focus_axis: int = state.get("focus_axis", -1)
	_outline.visible = not dimmed and (selected or peer or focus_axis >= 0)
	if _outline.visible:
		if selected:
			_outline.material_override = materials.outline_selected
		elif focus_axis >= 0:
			# Cells in the focused slice share the axis color of its button.
			_outline.material_override = materials.outline_axis[focus_axis]
		else:
			_outline.material_override = materials.outline_peer
		var outline_scale := ThemeTokens.OUTLINE_SELECTED if selected else ThemeTokens.OUTLINE_PEER
		_outline.scale = Vector3.ONE * outline_scale

	_mark.visible = conflict and not dimmed
	_mark.material_override = materials.mark_conflict

	_label.text = str(digit) if digit != 0 else ""
	var color := materials.digit_entry
	if conflict:
		color = materials.digit_conflict
	elif given:
		color = materials.digit_given
	if dimmed:
		color.a = ThemeTokens.DIMMED_ALPHA
	_label.modulate = color
	if _font_given != null:
		_label.font = _font_given if given else _font_entry
	# An outline in the digit's own color makes matching digits heavier.
	var bold := not dimmed and bool(state["is_same_digit"])
	if _font_given == null:
		bold = bold or (given and not dimmed)
	_label.outline_size = ThemeTokens.DIGIT_BOLD_OUTLINE if bold else 0
	_label.outline_modulate = color

	var note_mask: int = state.get("notes", 0)
	_notes.visible = note_mask != 0 and not dimmed
	if _notes.visible:
		_notes.text = notes_text(note_mask, _digit_count, _notes_per_row)
		_notes.modulate = materials.digit_note

	var scale_goal := 1.0
	if dimmed:
		scale_goal = ThemeTokens.DIMMED_SCALE
	elif selected:
		scale_goal = ThemeTokens.SELECTED_SCALE
	_animate_scale(scale_goal)


func set_solved_look(materials: CellMaterials) -> void:
	_body.material_override = materials.body_solved
	_outline.visible = false
	_mark.visible = false


func is_animating() -> bool:
	return _scale_tween != null and _scale_tween.is_running()


func is_pickable() -> bool:
	return not state.get("is_dimmed", false)


## Axis-aligned box of the cell body in board space, for tap picking.
func pick_box() -> AABB:
	var half := ThemeTokens.CELL_SIZE * 0.5 * maxf(_target_scale, 1.0)
	return AABB(position - Vector3.ONE * half, Vector3.ONE * half * 2.0)


## Places the billboard digit on the camera side of the body. The digit sits
## on the plane that touches the box's nearest point, so the cell never
## covers its own digit while nearer cells still hide it.
func face_direction(direction: Vector3) -> void:
	var half := ThemeTokens.CELL_SIZE * 0.5 * _visual.scale.x
	var support := half * (absf(direction.x) + absf(direction.y) + absf(direction.z))
	_label.position = direction * (support + LABEL_MARGIN)
	_notes.position = _label.position


## Pencil marks laid out in a grid, with gaps where a digit isn't noted,
## so each digit always sits in the same spot.
static func notes_text(mask: int, digit_count: int, per_row: int) -> String:
	var rows := PackedStringArray()
	var row := PackedStringArray()
	for digit in range(1, digit_count + 1):
		row.append(str(digit) if mask & (1 << digit) != 0 else FIGURE_SPACE)
		if row.size() == per_row or digit == digit_count:
			rows.append(" ".join(row))
			row = PackedStringArray()
	return "\n".join(rows)


## Grows the cell in from nothing after a delay, for the start animation.
func assemble(delay: float) -> void:
	if reduced_motion or not is_inside_tree():
		return
	_kill(_scale_tween)
	var label_alpha := _label.modulate.a
	_visual.scale = Vector3.ONE * 0.01
	_label.modulate.a = 0.0
	_scale_tween = create_tween().set_parallel()
	_scale_tween.tween_property(_visual, "scale", Vector3.ONE * _target_scale, ThemeTokens.ASSEMBLE_DURATION) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_label, "modulate:a", label_alpha, ThemeTokens.MOTION_BASE) \
		.set_delay(delay + ThemeTokens.ASSEMBLE_DURATION * 0.5)


func pop() -> void:
	if reduced_motion:
		return
	_kill(_scale_tween)
	_visual.scale = Vector3.ONE * _target_scale * POP_SCALE
	_scale_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_visual, "scale", Vector3.ONE * _target_scale, ThemeTokens.MOTION_FAST * 2.0)


func shake() -> void:
	if reduced_motion:
		return
	_kill(_shake_tween)
	_shake_tween = create_tween()
	var step := ThemeTokens.MOTION_FAST / SHAKE_STEPS
	for i in SHAKE_STEPS:
		var side := 1.0 if i % 2 == 0 else -1.0
		_shake_tween.tween_property(_visual, "position:x", side * SHAKE_DISTANCE, step)
	_shake_tween.tween_property(_visual, "position:x", 0.0, step)


func _animate_scale(goal: float) -> void:
	if is_equal_approx(goal, _target_scale) and _visual.scale.is_equal_approx(Vector3.ONE * goal):
		return
	_target_scale = goal
	_kill(_scale_tween)
	if not is_inside_tree():
		_visual.scale = Vector3.ONE * goal
		return
	_scale_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_visual, "scale", Vector3.ONE * goal, ThemeTokens.motion(ThemeTokens.MOTION_BASE, reduced_motion))


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
