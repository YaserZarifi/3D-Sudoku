extends RefCounted
## Shared materials for every cell, rebuilt when the palette changes.
## Cells pick from these instead of owning their own.

const ThemeTokens := preload("res://scripts/ui/theme_tokens.gd")

var body: StandardMaterial3D
var body_given: StandardMaterial3D
var body_selected: StandardMaterial3D
var body_peer: StandardMaterial3D
var body_conflict: StandardMaterial3D
var body_solved: StandardMaterial3D
var body_dimmed: StandardMaterial3D
var outline_selected: StandardMaterial3D
var outline_peer: StandardMaterial3D
var mark_conflict: StandardMaterial3D
var digit_entry: Color
var digit_given: Color
var digit_conflict: Color
var digit_note: Color


func _init(palette: Dictionary) -> void:
	var cell: Color = palette["cell"]
	var accent: Color = palette["accent"]
	var peer_tint: Color = cell.lerp(Color(accent, 1.0), palette["peer"].a)
	body = _lit(cell)
	body_given = _lit(palette["cell_given"])
	body_selected = _lit(cell.lerp(accent, 0.3))
	body_peer = _lit(peer_tint)
	body_conflict = _lit(cell.lerp(palette["conflict"], 0.35))
	body_solved = _lit(cell.lerp(palette["success"], 0.35))
	body_dimmed = _lit(Color(cell, ThemeTokens.DIMMED_ALPHA))
	body_dimmed.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_selected = _outline(accent)
	outline_peer = _outline(Color(accent, 0.55))
	mark_conflict = _unlit(palette["conflict"])
	digit_entry = accent
	digit_given = palette["ink"]
	digit_conflict = palette["conflict"]
	digit_note = palette["ink_muted"]


func _lit(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = ThemeTokens.CELL_ROUGHNESS
	return material


func _unlit(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Inverted hull: a slightly bigger box drawn from the inside only.
func _outline(color: Color) -> StandardMaterial3D:
	var material := _unlit(color)
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
