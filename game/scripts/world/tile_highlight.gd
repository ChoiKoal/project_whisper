extends Node2D
class_name TileHighlight
## Draws a pulsing violet diamond outline over the currently targeted tile.
## Driven by the interaction system via `show_cell()` / `hide_highlight()`.
## The diamond matches the 128x64 iso tile footprint.
##
## v0.3.1 (Fix 3): subtler by default (thinner outline, lower peak alpha) since the
## highlight now only appears when IDLE near an interactable — it should read as a
## gentle "you can act here" hint, not a constantly-jumping cursor. A `hover` style
## (mouse hover over a gatherable) is a touch brighter so it reads under the pointer.

const OUTLINE_COLOR := Color("#9e7ad9")  # violet pulse per spec
const TILE_HALF := Vector2(64, 32)       # half of 128x64
const PULSE_SPEED := 3.2

## v0.3.1 subtler idle style: thinner line, ~0.55 peak alpha.
const IDLE_WIDTH := 2.0
const IDLE_ALPHA_BASE := 0.30
const IDLE_ALPHA_PULSE := 0.25   # peak ≈ 0.55
## Hover style (mouse over a gatherable): slightly brighter + a hair thicker.
const HOVER_WIDTH := 2.5
const HOVER_ALPHA_BASE := 0.40
const HOVER_ALPHA_PULSE := 0.28  # peak ≈ 0.68

var _active: bool = false
var _pulse: float = 0.0
var _hover: bool = false


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta * PULSE_SPEED
	queue_redraw()


## Position the highlight over a tile whose center is at `world_center`.
## `hover` selects the (slightly brighter) mouse-hover style.
func show_cell(world_center: Vector2, hover: bool = false) -> void:
	global_position = world_center
	_active = true
	_hover = hover
	visible = true
	queue_redraw()


func hide_highlight() -> void:
	if not _active:
		return
	_active = false
	_hover = false
	visible = false
	queue_redraw()


## Public (harness): is the highlight currently shown?
func is_active() -> bool:
	return _active


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
	var base := HOVER_ALPHA_BASE if _hover else IDLE_ALPHA_BASE
	var puls := HOVER_ALPHA_PULSE if _hover else IDLE_ALPHA_PULSE
	var width := HOVER_WIDTH if _hover else IDLE_WIDTH
	var alpha: float = base + puls * (0.5 + 0.5 * sin(_pulse))
	var col := OUTLINE_COLOR
	col.a = alpha
	draw_polyline(pts, col, width, true)
