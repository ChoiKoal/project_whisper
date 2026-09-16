extends "res://scripts/world/tile_glow.gd"
const PROJECTION = preload("res://scripts/foundation/surface_projection.gd")
var _surface_points := PackedVector2Array()
func show_cell(logical: Vector2) -> void:
	var map := get_parent().get_node_or_null("Ground") as MapLoader
	super.show_cell(PROJECTION.point(map,logical))
	_surface_points.clear()
	for p in PROJECTION.outline(map,logical): _surface_points.append(to_local(p)*0.65)
	z_as_relative=false
	z_index=4
func _draw() -> void:
	if not _active or _surface_points.size()<5: return
	# Small surface-conforming treatment rather than a flat circular glow cutting
	# through the ramp. Final pixel material/UI styling remains a separate gate.
	var color := GLOW_COLOR
	color.a=0.13
	draw_colored_polygon(_surface_points.slice(0,4),color)
