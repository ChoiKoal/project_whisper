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
## Movement collision is semantic object data, not inferred from artwork or filenames.
## `blocks_movement` and `block_radius` describe a compact ground footprint. Trees and
## substantial R rocks block; small s stones, flowers, tufts, and low decals remain walkover.
## A non-unique blocker frees its StaticBody with the object when gathered.

const GROUP := "gatherable"

## Item id granted on gather. Empty = not gatherable (use-only object).
@export var item_id: String = ""
## How many of `item_id` to grant per gather.
@export var amount: int = 1
## Unique objects persist after first gather (cannot re-gather).
@export var unique: bool = false
## Stable id for `usable_on` targeting (e.g. "bush_dry"). Optional.
@export var object_id: String = ""
## Whether this object physically blocks movement at its logical ground anchor.
@export var blocks_movement: bool = false
## Radius (px) of the circular ground footprint. This is object metadata and must describe
## the contact footprint, never the full height/width of tall sprite ink.
@export_range(1.0, 64.0, 1.0) var block_radius: float = 20.0

## Finalized before any synchronous inventory/gameplay signals, for ALL objects.
var _spent: bool = false
var _gathered_at := -1.0
var last_granted_amount := 0
var _harvest_owner := 0

func reserve_harvest(owner_id: int) -> bool:
	if not can_gather() or _harvest_owner != 0: return false
	_harvest_owner = owner_id
	return true

func release_harvest(owner_id: int) -> void:
	if _harvest_owner == owner_id: _harvest_owner = 0

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
		_add_footprint_collision()
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


## Compact circular StaticBody at the sprite base. It stays at local (0,0): the Gatherable
## origin is the logical tile centre while sprite `offset` carries projected/tall artwork.
func _add_footprint_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # same layer the player's move collision masks
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = block_radius
	col.shape = shape
	body.add_child(col)
	add_child(body)


## True if this object can still be gathered right now.
func can_gather() -> bool:
	return item_id != "" and not _spent and not is_queued_for_deletion()


## Perform the gather: grant the item and (if not unique) remove the object.
## Returns the granted item id, or "" if nothing was gathered.
func gather() -> String:
	if not can_gather() or _harvest_owner != 0:
		return ""
	var granted := item_id
	SaveManager.begin_reward(get_instance_id())
	# Inventory.add emits item_added synchronously. Guard and removal intent must
	# already be final when a listener reenters gather or snapshots this world.
	_spent = true
	_gathered_at = GameState.game_time
	if not unique:
		queue_free()
	last_granted_amount = Inventory.add(granted, amount)
	GameState.item_gathered.emit(granted)
	_after_gather()
	SaveManager.end_reward(get_instance_id())
	return granted

## Subclass side effects belong to the same save boundary as the inventory grant.
func _after_gather() -> void:
	pass


## World point used for highlight / distance checks (base of the sprite).
func target_point() -> Vector2:
	return global_position

## Picking/prompts use the projected foot; gameplay reach and cells use target_point.
func visual_target_point() -> Vector2:
	if get_meta("_logical_height_lift",false):
		return global_position+Vector2(0,float(get_meta("_lift_offset",0.0)))
	return global_position
