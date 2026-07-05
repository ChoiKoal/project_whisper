extends Node2D
class_name TileGlow
## (v0.4.0 A2) Soft radial glow decal for a TILE-gather target (a dirt/water/grass cell
## with a gatherable item_id and no object on it). Replaces the hard violet diamond for
## tile gathering: a low-alpha soft radial bloom sits on the cell so it reads as "you can
## gather here" without the cursor-y diamond ("커서 너무 마음에 안들어").
##
## Driven by InteractionController._update_targeting() via show_cell()/hide_glow(). Object
## gather uses the object-brighten path instead; the violet diamond survives only for
## held-item PLACEMENT targeting (TileHighlight) + D14 slot hints (SteppingSlotHint).

## Violet bloom tint (art guide §3 mystic violet), kept low-alpha + soft.
const GLOW_COLOR := Color("#9e7ad9")
## Radius of the soft radial falloff, in px. ~half a tile so it hugs the diamond.
const GLOW_RADIUS := 46.0
## Peak center alpha (very subtle per spec: "soft radial, low alpha").
const ALPHA_BASE := 0.16
const ALPHA_PULSE := 0.10   ## breathes up to ~0.26
const PULSE_SPEED := 2.6
## Number of concentric bands used to fake a radial gradient with draw_circle.
const BANDS := 7

var _active: bool = false
var _pulse: float = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta * PULSE_SPEED
	queue_redraw()


## Show the glow centered on a tile whose center is at `world_center`.
func show_cell(world_center: Vector2) -> void:
	global_position = world_center
	_active = true
	visible = true
	queue_redraw()


func hide_glow() -> void:
	if not _active:
		return
	_active = false
	visible = false
	queue_redraw()


## Public (harness): is the glow currently shown?
func is_active() -> bool:
	return _active


func _draw() -> void:
	if not _active:
		return
	var peak: float = ALPHA_BASE + ALPHA_PULSE * (0.5 + 0.5 * sin(_pulse))
	# Concentric filled circles, alpha falling off toward the edge → soft radial bloom.
	# The 2:1 iso squash is applied via draw_set_transform so the bloom is a flat ellipse
	# hugging the diamond rather than a screen-round dot.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for i in range(BANDS):
		var t: float = float(i) / float(BANDS - 1)   # 0 center → 1 edge
		var r: float = GLOW_RADIUS * (0.28 + 0.72 * t)
		var a: float = peak * (1.0 - t) * (1.0 - t)  # quadratic falloff
		var col := GLOW_COLOR
		col.a = a
		draw_circle(Vector2.ZERO, r, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
