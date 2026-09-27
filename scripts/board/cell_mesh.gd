extends RefCounted
## Builds a box with chamfered edges and corners, so cells read as soft
## tactile blocks instead of sharp cubes. Flat-shaded.


static func beveled_box(size: float, bevel: float) -> ArrayMesh:
	var h := size * 0.5
	var i := h - clampf(bevel, 0.0, h)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Six faces.
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var quad: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				quad.append(_point(axis, side * h, corner.x * i, corner.y * i))
			_polygon(tool, quad)

	# Twelve edge strips, one per pair of axes and pair of signs.
	for a in 3:
		for b in range(a + 1, 3):
			var along := 3 - a - b
			for sa: float in [-1.0, 1.0]:
				for sb: float in [-1.0, 1.0]:
					var strip: Array[Vector3] = []
					for t: float in [-i, i]:
						var p := Vector3.ZERO
						p[along] = t
						var q := p
						p[a] = sa * h
						p[b] = sb * i
						q[a] = sa * i
						q[b] = sb * h
						strip.append(p)
						strip.append(q)
					_polygon(tool, [strip[0], strip[1], strip[3], strip[2]])

	# Eight corner triangles.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_polygon(tool, [
					Vector3(sx * h, sy * i, sz * i),
					Vector3(sx * i, sy * h, sz * i),
					Vector3(sx * i, sy * i, sz * h),
				])

	return tool.commit()


static func _point(axis: int, value: float, u: float, v: float) -> Vector3:
	var p := Vector3.ZERO
	p[axis] = value
	p[(axis + 1) % 3] = u
	p[(axis + 2) % 3] = v
	return p


## Adds a convex polygon as a fan, wound so it faces away from the center.
## Godot treats clockwise triangles as front-facing.
static func _polygon(tool: SurfaceTool, points: Array) -> void:
	var center := Vector3.ZERO
	for p: Vector3 in points:
		center += p
	center /= points.size()
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var ordered := points.duplicate()
	if normal.dot(center) > 0.0:
		ordered.reverse()
		normal = -normal
	for k in range(1, ordered.size() - 1):
		for p: Vector3 in [ordered[0], ordered[k], ordered[k + 1]]:
			tool.set_normal(-normal)
			tool.add_vertex(p)
