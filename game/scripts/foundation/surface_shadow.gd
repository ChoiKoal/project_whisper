extends Node2D
## Ground-contact treatment, separately projected from the body atlas.
## Engineering shadow only; not final character/effects craft approval.
const PROJECTION = preload("res://scripts/foundation/surface_projection.gd")
var _points := PackedVector2Array()
func _ready() -> void:
	z_as_relative=false
	z_index=4
	process_priority=100
func _process(_delta: float) -> void:
	var player:=get_parent() as Player
	if player==null or not is_instance_valid(player._tilemap): return
	var map:=player._tilemap as MapLoader
	_points.clear()
	for p in [Vector2(-20,0),Vector2(-10,-4),Vector2(10,-4),Vector2(20,0),Vector2(12,4),Vector2(-12,4)]:
		_points.append(to_local(PROJECTION.point(map,player.global_position+p)))
	queue_redraw()
func surface_polygon() -> PackedVector2Array:
	return _points.duplicate()
func _draw() -> void:
	if _points.size()>2: draw_colored_polygon(_points,Color(0.10,0.12,0.12,0.35))
