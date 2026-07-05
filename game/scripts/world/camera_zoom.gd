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

## True while the awakening reveal tween is running (suppresses manual zoom input then).
var _revealing: bool = false

func _ready() -> void:
	zoom = Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM)
	# Clamp the camera to the map bounds after the loader has laid its tiles.
	call_deferred("_apply_bounds")


## (v0.5d) The new-game awakening beat: start slightly zoomed IN on the dais (the player
## spawns there) with a small upward drift toward the portal arc, then ease OUT to the default
## framing so the ring of gates is revealed. Called by HomeSession on a fresh awakening only.
func play_awakening_reveal() -> void:
	_revealing = true
	# Start tight on the dais, nudged up toward the northern arc so the reveal pans across it.
	zoom = Vector2(2.4, 2.4)
	offset = Vector2(0, -70)
	var prev_smooth := position_smoothing_enabled
	position_smoothing_enabled = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "zoom", Vector2(DEFAULT_ZOOM, DEFAULT_ZOOM), 3.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.9)
	tw.tween_property(self, "offset", Vector2.ZERO, 3.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.9)
	tw.chain().tween_callback(func():
		_revealing = false
		position_smoothing_enabled = prev_smooth)

func _unhandled_input(event: InputEvent) -> void:
	if _revealing:
		return
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
