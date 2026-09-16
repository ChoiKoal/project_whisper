extends Node
## Presentation-only companion for newly placed AND save-restored structures.
## Keep logical root/collider/target/save cell unchanged, including spawn-pop scaling.
var map: MapLoader
var prop: PlacedObject
var _base_offset := Vector2.ZERO
var _glow_offset := Vector2.ZERO
func _ready() -> void:
	prop=get_parent() as PlacedObject
	if prop==null: return
	_base_offset=prop.offset
	if is_instance_valid(prop._glow) and prop._glow is Sprite2D:
		_glow_offset=(prop._glow as Sprite2D).offset
	prop.y_sort_enabled=false
	process_priority=100
	_process(0.0)
func _process(_delta: float) -> void:
	if not is_instance_valid(map) or not is_instance_valid(prop): return
	var lift:=map.visual_height_offset(prop.global_position)
	var local_lift:=prop.to_local(prop.global_position+Vector2(0,lift))
	prop.offset=_base_offset+local_lift
	if is_instance_valid(prop._glow) and prop._glow is Sprite2D:
		(prop._glow as Sprite2D).offset=_glow_offset+local_lift
