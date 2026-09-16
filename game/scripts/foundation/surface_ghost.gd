extends "res://scripts/world/placement_ghost.gd"
const PROJECTION = preload("res://scripts/foundation/surface_projection.gd")
func show_ghost(item_id: String, logical: Vector2, valid: bool) -> void:
	var map := get_parent().get_node_or_null("Ground") as MapLoader
	super.show_ghost(item_id,PROJECTION.point(map,logical),valid)
