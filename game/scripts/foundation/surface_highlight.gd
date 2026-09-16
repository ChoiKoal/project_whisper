extends "res://scripts/world/tile_highlight.gd"
const PROJECTION = preload("res://scripts/foundation/surface_projection.gd")
var _surface_points := PackedVector2Array()
func show_cell(logical: Vector2, hover: bool = false) -> void:
	var map := get_parent().get_node_or_null("Ground") as MapLoader
	super.show_cell(PROJECTION.point(map,logical),hover)
	_surface_points.clear()
	for p in PROJECTION.outline(map,logical): _surface_points.append(to_local(p))
	z_as_relative=false
	z_index=4  # surface treatment, below actors/vertical occluders
func surface_polygon() -> PackedVector2Array:
	return _surface_points.duplicate()
func _draw() -> void:
	if not _active or _surface_points.size()<5: return
	var color := OUTLINE_COLOR
	color.a = 0.6 if _hover else 0.4
	draw_polyline(_surface_points,color,2.0,false)
