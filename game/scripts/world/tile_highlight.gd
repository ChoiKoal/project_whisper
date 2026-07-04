extends Node2D
class_name TileHighlight
## Draws a pulsing violet diamond outline over the currently targeted tile.
## Driven by the interaction system via `show_cell()` / `hide_highlight()`.
## The diamond matches the 128x64 iso tile footprint.

const OUTLINE_COLOR := Color("#9e7ad9")  # violet pulse per spec
const TILE_HALF := Vector2(64, 32)       # half of 128x64
const PULSE_SPEED := 4.0
const OUTLINE_WIDTH := 3.0

var _active: bool = false
var _pulse: float = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta * PULSE_SPEED
	queue_redraw()


## Position the highlight over a tile whose center is at `world_center`.
func show_cell(world_center: Vector2) -> void:
	global_position = world_center
	_active = true
	visible = true
	queue_redraw()


func hide_highlight() -> void:
	if not _active:
		return
	_active = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	# Diamond corners (top, right, bottom, left) around local origin.
	var pts := PackedVector2Array([
		Vector2(0, -TILE_HALF.y),
		Vector2(TILE_HALF.x, 0),
		Vector2(0, TILE_HALF.y),
		Vector2(-TILE_HALF.x, 0),
		Vector2(0, -TILE_HALF.y),
	])
	var alpha: float = 0.45 + 0.35 * (0.5 + 0.5 * sin(_pulse))
	var col := OUTLINE_COLOR
	col.a = alpha
	draw_polyline(pts, col, OUTLINE_WIDTH, true)
