extends Sprite2D
class_name Gatherable
## A world object that yields an item when gathered (tree, rock, flower, stone,
## grass tuft, …). Attach to a Sprite2D; it self-registers into the `gatherable`
## group so the interaction system can find nearby targets without a hardcoded
## list.
##
## `unique` objects (world-tree O0 / I9) stay in the world after the first gather
## and cannot be re-gathered — the spec's "world-tree exception hook". Non-unique
## objects free themselves after gathering.
##
## `object_id` lets the placement/use framework target this node with `usable_on`
## items (e.g. pour I7 water on a `bush_dry`). Gathering and use are independent:
## a node can be gatherable, usable, or both.

const GROUP := "gatherable"

## Item id granted on gather. Empty = not gatherable (use-only object).
@export var item_id: String = ""
## How many of `item_id` to grant per gather.
@export var amount: int = 1
## Unique objects persist after first gather (cannot re-gather).
@export var unique: bool = false
## Stable id for `usable_on` targeting (e.g. "bush_dry"). Optional.
@export var object_id: String = ""

## Set true once a unique object has been gathered.
var _spent: bool = false


func _ready() -> void:
	add_to_group(GROUP)


## True if this object can still be gathered right now.
func can_gather() -> bool:
	return item_id != "" and not (unique and _spent)


## Perform the gather: grant the item and (if not unique) remove the object.
## Returns the granted item id, or "" if nothing was gathered.
func gather() -> String:
	if not can_gather():
		return ""
	var granted := item_id
	Inventory.add(granted, amount)
	GameState.item_gathered.emit(granted)
	if unique:
		_spent = true  # world-tree stays in world, flagged spent
	else:
		queue_free()
	return granted


## World point used for highlight / distance checks (base of the sprite).
func target_point() -> Vector2:
	return global_position
