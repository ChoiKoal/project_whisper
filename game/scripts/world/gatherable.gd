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
##
## v0.3.1 R3 (non-blocking gatherables): only large obstacles (trees) physically block
## the player. Small scatter — rocks, stones, flowers, grass tufts, green bushes — set
## `blocks_movement = false` so the player walks OVER them (they stay gatherable). Trees
## set `blocks_movement = true` and get a small trunk StaticBody so you can't pass through
## them. When a tree is gathered it queue_free()s, taking its collision with it.

const GROUP := "gatherable"

## Item id granted on gather. Empty = not gatherable (use-only object).
@export var item_id: String = ""
## How many of `item_id` to grant per gather.
@export var amount: int = 1
## Unique objects persist after first gather (cannot re-gather).
@export var unique: bool = false
## Stable id for `usable_on` targeting (e.g. "bush_dry"). Optional.
@export var object_id: String = ""
## v0.3.1 R3: whether this object physically blocks movement (trees). Small gatherables
## leave this false so the player crosses over them. A trunk collision body is created in
## _ready() only when true.
@export var blocks_movement: bool = false
## Radius (px) of the trunk collision circle when `blocks_movement` is true.
const TRUNK_RADIUS := 20.0

## Set true once a unique object has been gathered.
var _spent: bool = false

## ---- v0.4.0 A2: target-brighten (replaces the floor diamond) ---------------
## When the interaction system marks this object as the current target (the adjacent
## gatherable you'd interact with, or the one under the mouse cursor), the sprite
## self-brightens with a gentle modulate pulse + a faint violet rim so the OBJECT
## itself reads as "you can act on this" — no floor cursor. Driven each frame by
## InteractionController via set_targeted(); the pulse animates in _process.
const BRIGHT_PEAK := 1.25          ## self_modulate value multiplier at pulse peak
const BRIGHT_BASE := 1.08          ## floor brightness while targeted (always >1)
const BRIGHT_PULSE_SPEED := 3.4
const RIM_COLOR := Color("#9e7ad9") ## subtle violet rim tint mixed into the lift
var _targeted: bool = false
var _bright_pulse: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	if blocks_movement:
		_add_trunk_collision()
	set_process(false)


## (v0.4.0 A2) Mark/unmark this object as the interaction target. While targeted the
## sprite pulses brighter (self_modulate) with a faint violet lift; clearing restores
## the plain WHITE self_modulate so day/night CanvasModulate still tints it normally.
func set_targeted(on: bool) -> void:
	if on == _targeted:
		return
	_targeted = on
	set_process(on)
	if not on:
		_bright_pulse = 0.0
		self_modulate = Color.WHITE


func is_targeted() -> bool:
	return _targeted


func _process(delta: float) -> void:
	if not _targeted:
		return
	_bright_pulse += delta * BRIGHT_PULSE_SPEED
	# Brightness lerps between BASE and PEAK on a sine; a hair of violet is mixed into
	# the channels so the lift reads as a soft mystic rim rather than a flat white flash.
	var t: float = 0.5 + 0.5 * sin(_bright_pulse)
	var b: float = lerp(BRIGHT_BASE, BRIGHT_PEAK, t)
	# Violet-biased brightening: scale each channel by b, then nudge toward the rim hue.
	var c := Color(b, b, b, 1.0)
	c = c.lerp(Color(RIM_COLOR.r * b, RIM_COLOR.g * b, RIM_COLOR.b * b, 1.0), 0.12 * t)
	self_modulate = c


## Small circular StaticBody at the sprite base so the player can't walk through a tree
## trunk. Placed at local (0,0) — the Gatherable's origin sits at the tile centre (the art
## `offset` lifts the canopy up), which is where the trunk visually meets the ground.
func _add_trunk_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # same layer the player's move collision masks
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = TRUNK_RADIUS
	col.shape = shape
	body.add_child(col)
	add_child(body)


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
