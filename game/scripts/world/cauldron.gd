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


func _ready() -> void:
	add_to_group(GROUP)


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
