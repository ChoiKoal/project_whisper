extends Sprite2D
class_name Cauldron
## 솥단지 — the fusion cauldron world object (M3).
##
## Placed on the map near the pond. It registers into the `gatherable` group so
## the existing InteractionController targets/highlights it, but it is neither
## gatherable nor use-target: instead, interacting with it emits `interacted`,
## which the Fusion UI listens to in order to open.
##
## Interaction hook: the controller, after finding no gather/use action, calls
## `on_interact()` on a targeted object if it has that method (duck-typed). This
## keeps M2's controller mostly untouched.

const GROUP := "gatherable"

## Stable id (parity with Gatherable.object_id for targeting/debug).
@export var object_id: String = "cauldron"

## Emitted when the player interacts with the cauldron.
signal interacted

## v0.2.1: subtle bubbling — alternate between two brew-surface frames on a slow
## timer + a faint scale pulse. Purely cosmetic (world-cauldron polish, 조합 쾌감 §5).
const TEX_CALM := "res://assets/objects/cauldron.png"
const TEX_BUBBLE := "res://assets/objects/cauldron_bubble.png"
const BUBBLE_PERIOD := 0.55  ## seconds per brew frame

var _tex_calm: Texture2D
var _tex_bubble: Texture2D
var _bubble_t: float = 0.0
var _bubble_on: bool = false
var _pulse_t: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_tex_calm = load(TEX_CALM)
	_tex_bubble = load(TEX_BUBBLE)
	# Cache the base texture actually assigned by the loader as the "calm" frame in
	# case art paths change; only animate if both frames resolved.
	if texture != null:
		_tex_calm = texture


func _process(delta: float) -> void:
	if _tex_bubble == null or _tex_calm == null:
		return
	_bubble_t += delta
	if _bubble_t >= BUBBLE_PERIOD:
		_bubble_t -= BUBBLE_PERIOD
		_bubble_on = not _bubble_on
		texture = _tex_bubble if _bubble_on else _tex_calm
	# Very subtle breathing pulse so the whole pot reads as alive (kept tiny so the
	# base footprint / Y-sort origin doesn't visibly shift).
	_pulse_t += delta * 2.2
	var s := 1.0 + sin(_pulse_t) * 0.02
	scale = Vector2(s, s)


# ---- Gatherable-compatible interface (so the controller can target it) ----

## Not gatherable — interacting opens fusion instead.
func can_gather() -> bool:
	return false


func gather() -> String:
	return ""


## World point for highlight / distance checks (base of the sprite).
func target_point() -> Vector2:
	return global_position


## Called by InteractionController when the player interacts with this object and
## no gather/use action applied. Opens the Fusion UI via the signal.
func on_interact() -> void:
	interacted.emit()
