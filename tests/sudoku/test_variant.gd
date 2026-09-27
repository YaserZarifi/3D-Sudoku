extends "res://tests/test_case.gd"

const Variants := preload("res://scripts/sudoku/variants.gd")


func test_index_round_trip() -> void:
	var variant := Variants.slice_sudoku(3)
	for index in variant.cell_count:
		var coord := variant.coord_of(index)
		assert_true(variant.is_valid_coord(coord))
		assert_eq(variant.index_of_coord(coord), index)


func test_index_layout() -> void:
	var variant := Variants.latin_cube(3)
	assert_eq(variant.index_of(1, 0, 0), 1)
	assert_eq(variant.index_of(0, 1, 0), 3)
	assert_eq(variant.index_of(0, 0, 1), 9)
	assert_eq(variant.coord_of(26), Vector3i(2, 2, 2))


func test_invalid_coords() -> void:
	var variant := Variants.latin_cube(3)
	assert_false(variant.is_valid_coord(Vector3i(-1, 0, 0)))
	assert_false(variant.is_valid_coord(Vector3i(0, 3, 0)))
	assert_false(variant.is_valid_index(27))


func test_latin_cube_groups_and_peers() -> void:
	var variant := Variants.latin_cube(3)
	assert_eq(variant.digit_count, 3)
	assert_eq(variant.groups.size(), 27)
	for group in variant.groups:
		assert_eq(group.size(), 3)
	for index in variant.cell_count:
		assert_eq(variant.peers[index].size(), 6, "peers of %d" % index)
		assert_eq(variant.cell_groups[index].size(), 3)


func test_slice_sudoku_groups_and_peers() -> void:
	var variant := Variants.slice_sudoku(3)
	assert_eq(variant.digit_count, 9)
	assert_eq(variant.groups.size(), 9)
	for group in variant.groups:
		assert_eq(group.size(), 9)
	for index in variant.cell_count:
		assert_eq(variant.peers[index].size(), 18, "peers of %d" % index)
		assert_eq(variant.cell_groups[index].size(), 3)


func test_slice_peers_share_a_coordinate() -> void:
	var variant := Variants.slice_sudoku(3)
	var center := variant.index_of(1, 1, 1)
	for peer in variant.peers[center]:
		var coord := variant.coord_of(peer)
		assert_true(coord.x == 1 or coord.y == 1 or coord.z == 1)
	assert_false(variant.peers[center].has(center))


func test_by_id() -> void:
	for variant_id in Variants.all_ids():
		assert_eq(Variants.by_id(variant_id).id, variant_id)
	assert_true(Variants.by_id("nope") == null)
