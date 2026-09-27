extends Control
## Isometric drawings of the cube for the intro slides. Drawn in code, so
## they follow the palette and stay sharp at any size.

enum Art { CUBE, SLICES, TAP, INSIDE }

const CELL_GAP := 0.14
const SHADE_RIGHT := 0.12
const SHADE_LEFT := 0.24
const COS30 := 0.8660254
const CUBE_WIDTH := 5.6
const CUBE_HEIGHT := 6.6

var art: Art = Art.CUBE:
	set(value):
		art = value
		queue_redraw()
var palette: Dictionary = {}:
	set(value):
		palette = value
		queue_redraw()


func _draw() -> void:
	if palette.is_empty():
		return
	match art:
		Art.CUBE:
			_draw_cube(size * 0.5, _unit(1.0), func(_c: Vector3i) -> Color: return palette["cell"])
		Art.SLICES:
			var tokens := ["axis_x", "axis_y", "axis_z"]
			var unit := _unit(3.3)
			for axis in 3:
				var center := Vector2(size.x * (0.18 + 0.32 * axis), size.y * 0.5)
				var tint: Color = palette[tokens[axis]]
				_draw_cube(center, unit, func(c: Vector3i) -> Color:
					return palette["cell"].lerp(tint, 0.8) if c[axis] == 2 else palette["cell"])
		Art.TAP:
			var center := size * Vector2(0.44, 0.5)
			var unit := _unit(1.3)
			_draw_cube(center, unit, func(c: Vector3i) -> Color:
				return palette["accent"] if c == Vector3i(2, 2, 1) else palette["cell"])
			_draw_finger(center + Vector2(unit * 1.9, unit * 0.9), unit)
		Art.INSIDE:
			_draw_cube(size * 0.5, _unit(1.0), func(c: Vector3i) -> Color:
				if c.y == 1:
					return palette["cell"].lerp(palette["axis_y"], 0.75)
				return Color(palette["cell"], 0.16))


## Size of one cell so cubes fit. A drawn cube spans about 5.6 cells
## across and 6.4 down; cubes_across makes room for several side by side.
func _unit(cubes_across: float) -> float:
	return minf(size.x / (CUBE_WIDTH * cubes_across), size.y / CUBE_HEIGHT)


## Draws a 3 x 3 x 3 cube. color_of returns the fill for each cell.
## Cells are painted back to front, so nearer ones cover farther ones.
func _draw_cube(center: Vector2, unit: float, color_of: Callable) -> void:
	var order: Array[Vector3i] = []
	for x in 3:
		for y in 3:
			for z in 3:
				order.append(Vector3i(x, y, z))
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x + a.y + a.z < b.x + b.y + b.z)
	var half := 0.5 - CELL_GAP * 0.5
	for cell in order:
		var fill: Color = color_of.call(cell)
		var c := Vector3(cell) - Vector3.ONE
		# Top (+y), right (+x) and left (+z) faces are the ones facing the viewer.
		_face(center, unit, c, [Vector3(-half, half, -half), Vector3(half, half, -half), Vector3(half, half, half), Vector3(-half, half, half)], fill)
		_face(center, unit, c, [Vector3(half, half, -half), Vector3(half, half, half), Vector3(half, -half, half), Vector3(half, -half, -half)], fill.darkened(SHADE_RIGHT))
		_face(center, unit, c, [Vector3(-half, half, half), Vector3(half, half, half), Vector3(half, -half, half), Vector3(-half, -half, half)], fill.darkened(SHADE_LEFT))


func _face(center: Vector2, unit: float, cell: Vector3, corners: Array, fill: Color) -> void:
	var points := PackedVector2Array()
	for corner: Vector3 in corners:
		points.append(center + _project(cell + corner) * unit)
	draw_colored_polygon(points, fill)


func _project(p: Vector3) -> Vector2:
	return Vector2((p.x - p.z) * COS30, (p.x + p.z) * 0.5 - p.y)


## A fingertip with a curved arrow, hinting at drag to turn.
func _draw_finger(tip: Vector2, unit: float) -> void:
	var ink: Color = palette["ink"]
	var radius := unit * 0.32
	draw_circle(tip, radius, Color(ink, 0.18))
	draw_circle(tip, radius * 0.55, Color(ink, 0.55))
	var arc_center := size * Vector2(0.44, 0.5)
	var arc_radius := unit * 2.7
	draw_arc(arc_center, arc_radius, deg_to_rad(20), deg_to_rad(70), 24, palette["accent"], unit * 0.09, true)
	var end := arc_center + Vector2.from_angle(deg_to_rad(70)) * arc_radius
	var along := Vector2.from_angle(deg_to_rad(160))
	var side := along.orthogonal()
	var head := unit * 0.28
	draw_colored_polygon(PackedVector2Array([end + along * head, end + side * head * 0.6, end - side * head * 0.6]), palette["accent"])
