extends Node2D
class_name SteppingSlotHint
## G1 guidance (M6c): while the player holds a D14 디딤돌, pulse a violet diamond
## over every stepping-slot cell that is still water (un-filled), so it's obvious
## the crossing needs a stone on EACH slot — not just one. Reuses the tile-highlight
## visual (pulsing violet #9e7ad9 diamond, 128×64 iso footprint).
##
## Driven by InteractionController._update_slot_hint() via show_cells()/hide_all():
## it recomputes the un-filled slots each frame the player holds D14. Cheap: a
## handful of cells, one custom _draw.

const OUTLINE_COLOR := Color("#9e7ad9")  # same violet as TileHighlight
const TILE_HALF := Vector2(64, 32)       # half of 128x64
const PULSE_SPEED := 4.0
const OUTLINE_WIDTH := 3.0

## World-space centers of the slot cells to highlight this frame.
var _centers: PackedVector2Array = PackedVector2Array()
var _pulse: float = 0.0


func _process(delta: float) -> void:
	if _centers.is_empty():
		return
	_pulse += delta * PULSE_SPEED
	queue_redraw()


## Highlight the given world-space cell centers (empty clears the hint).
func show_cells(centers: PackedVector2Array) -> void:
	_centers = centers
	visible = not centers.is_empty()
	queue_redraw()


func hide_all() -> void:
	if _centers.is_empty():
		return
	_centers = PackedVector2Array()
	visible = false
	queue_redraw()


## Number of diamonds currently drawn (for harness assertions).
func get_highlight_count() -> int:
	return _centers.size()


func _draw() -> void:
	if _centers.is_empty():
		return
	var alpha: float = 0.45 + 0.35 * (0.5 + 0.5 * sin(_pulse))
	var col := OUTLINE_COLOR
	col.a = alpha
	for center in _centers:
		var pts := PackedVector2Array([
			center + Vector2(0, -TILE_HALF.y),
			center + Vector2(TILE_HALF.x, 0),
			center + Vector2(0, TILE_HALF.y),
			center + Vector2(-TILE_HALF.x, 0),
			center + Vector2(0, -TILE_HALF.y),
		])
		draw_polyline(pts, col, OUTLINE_WIDTH, true)
