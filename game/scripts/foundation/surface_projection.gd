extends RefCounted
## One presentation adapter: logical positions in, sampled visible positions out.
## Never use this output for collision, target distance, navigation or save cells.
static func point(map: MapLoader, logical: Vector2) -> Vector2:
	if not is_instance_valid(map): return logical
	return logical + Vector2(0,map.visual_height_offset(logical))

static func outline(map: MapLoader, logical: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	# Sample just inside the selected tile: border ownership must not switch to an
	# unrelated adjacent plateau at an exact diamond corner.
	for corner in [Vector2(0,-32),Vector2(64,0),Vector2(0,32),Vector2(-64,0),Vector2(0,-32)]:
		out.append(point(map,logical+corner*0.999))
	return out
