extends RefCounted
## One puzzle tier: cube size, digit range and constraint groups.
## Built once by a factory in variants.gd, then treated as read-only.
## This is the only place that converts between cell indices and coordinates.

var id: String
var display_name: String
var size: int
var digit_count: int
var cell_count: int
## Cell indices of each constraint group.
var groups: Array[PackedInt32Array] = []
## For each cell, every other cell sharing a group with it.
var peers: Array[PackedInt32Array] = []
## For each cell, the ids of the groups it belongs to.
var cell_groups: Array[PackedInt32Array] = []
## Number of givens the generator aims for, keyed by difficulty name.
var clue_targets: Dictionary = {}


func _init(variant_id: String, variant_name: String, cube_size: int, digits: int) -> void:
	id = variant_id
	display_name = variant_name
	size = cube_size
	digit_count = digits
	cell_count = cube_size * cube_size * cube_size


## Called once by the factory. Stores the groups and precomputes lookups.
func set_groups(group_list: Array[PackedInt32Array]) -> void:
	groups = group_list
	cell_groups.clear()
	peers.clear()
	for index in cell_count:
		cell_groups.append(PackedInt32Array())
	for group_id in groups.size():
		for index in groups[group_id]:
			cell_groups[index].append(group_id)

	for index in cell_count:
		var seen := {}
		var cell_peers := PackedInt32Array()
		for group_id in cell_groups[index]:
			for other in groups[group_id]:
				if other != index and not seen.has(other):
					seen[other] = true
					cell_peers.append(other)
		cell_peers.sort()
		peers.append(cell_peers)


func index_of(x: int, y: int, z: int) -> int:
	return x + y * size + z * size * size


func index_of_coord(coord: Vector3i) -> int:
	return index_of(coord.x, coord.y, coord.z)


func coord_of(index: int) -> Vector3i:
	return Vector3i(index % size, (index / size) % size, index / (size * size))


func is_valid_coord(coord: Vector3i) -> bool:
	return coord.x >= 0 and coord.x < size \
		and coord.y >= 0 and coord.y < size \
		and coord.z >= 0 and coord.z < size


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < cell_count


func is_valid_digit(digit: int) -> bool:
	return digit >= 1 and digit <= digit_count


## Bitmask with bits 1..digit_count set.
func all_digits_mask() -> int:
	return ((1 << digit_count) - 1) << 1


## How many times each digit appears in a solved board.
func copies_per_digit() -> int:
	return cell_count / digit_count
