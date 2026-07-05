extends Camera2D
## v0.5: grove camera. Default zoom 1.5 so the new CC0 pixel + elevation detail READS
## larger; mouse wheel adjusts zoom within [MIN_ZOOM, MAX_ZOOM]. Zoom is suppressed while
## a modal UI has captured input (so scrolling a panel doesn't zoom the world).
##
## (v0.5 phase B) The camera CLAMPS to the map's iso bounds via limit_* so it never
## reveals the void beyond the island edge; position_smoothing (set in the scene) keeps
## the follow smooth. Limits are computed from the MapLoader's iso extents once the map
## is built, with a small margin so the cliff-skirt border stays on-screen.

const DEFAULT_ZOOM := 1.5
const MIN_ZOOM := 1.0
const MAX_ZOOM := 2.2
const ZOOM_STEP := 0.1
## Extra world-space margin (px) added around the map bounds so the diorama edge/cliff
## skirt is visible rather than clipped hard at the outermost tile.
const BOUND_MARGIN := 220.0

func _ready() -> void:
	zoom = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)
	# Clamp the camera to the map bounds after the loader has laid its tiles.
	call_deferred("_apply_bounds")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-ZOOM_STEP)

func _apply_zoom(delta: float) -> void:
	var z: float = clampf(zoom.x + delta, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)

## Set the camera limits from the map's iso extents so it never scrolls past the island.
func _apply_bounds() -> void:
	var loader := _find_loader()
	if loader == null or loader.width <= 0 or loader.height <= 0:
		return
	# Iso screen extremes (global): top vertex of (0,0), bottom of (w-1,h-1), left of
	# (0,h-1), right of (w-1,0). Add a margin so the cliff border reads.
	var half_w: float = loader.TILE_HALF_W
	var half_h: float = loader.TILE_HALF_H
	var top: float = loader.cell_center_world(Vector2i(0, 0)).y - half_h
	var bottom: float = loader.cell_center_world(Vector2i(loader.width - 1, loader.height - 1)).y + half_h
	var left: float = loader.cell_center_world(Vector2i(0, loader.height - 1)).x - half_w
	var right: float = loader.cell_center_world(Vector2i(loader.width - 1, 0)).x + half_w
	limit_left = int(left - BOUND_MARGIN)
	limit_right = int(right + BOUND_MARGIN)
	limit_top = int(top - BOUND_MARGIN)
	limit_bottom = int(bottom + BOUND_MARGIN)

## Walk up to the scene root to find the Ground MapLoader (the camera is a deep child of
## Player, so we search rather than hard-code the path).
func _find_loader() -> MapLoader:
	var n: Node = self
	while n != null:
		var g := n.get_node_or_null("Ground")
		if g is MapLoader:
			return g
		n = n.get_parent()
	return null
