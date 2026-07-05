extends Node2D
class_name InteractionController
## M2 interaction hub: targeting + highlight + gather + place/use.
##
## Each frame it picks a target — a nearby `Gatherable` object if one is close
## enough, otherwise the tile the player faces — and shows the violet diamond
## highlight over it. On the `interact` action it does one of:
##   1. If a held item is selected AND the target is a valid placement/use target
##      for that item -> place or use (consume item, apply effect).
##   2. Else if the target object is gatherable -> gather it.
##   3. Else if the target tile has custom-data `gatherable` -> gather the tile,
##      grant its `item_id`, and replace the tile with T0 VOID.
##
## Data-driven: valid tiles/objects come from ItemDB (placeable_on / usable_on)
## and TileSet custom data, never hardcoded item switches. The *placement effect*
## (what happens after a valid placement) is a small named-effect registry keyed
## by item id, because an effect is executable code, not data.

## Source id used for the empty VOID result after gathering a tile.
const VOID_SOURCE := 0
## Source id reused visually for a stepping stone on water (T1 dirt) — TODO:
## dedicated "stone on water" art in a later art batch.
const STEPPING_STONE_SOURCE := 1
const ATLAS := Vector2i(0, 0)

## How close (px) a gatherable object must be to take priority over the faced tile.
const OBJECT_REACH := 140.0

@export var player_path: NodePath
@export var tilemap_path: NodePath
@export var highlight_path: NodePath
@export var feedback_layer_path: NodePath  ## where floating labels spawn (world space)
@export var slot_hint_path: NodePath  ## optional SteppingSlotHint for D14 guidance

var _player: Player
var _tilemap: TileMapLayer
var _highlight: TileHighlight
var _feedback_layer: Node
var _slot_hint: SteppingSlotHint

## Currently held item id (from inventory selection), or "" for none.
var _held_item: String = ""

## Current frame's resolved target. Any node in the `gatherable` group that
## implements the target_point()/can_gather()/gather() interface (Gatherable, or
## a duck-typed object like Cauldron). Typed as Node2D so non-Gatherable
## interactables (Cauldron) are supported.
var _target_object: Node = null
var _target_cell: Vector2i = Vector2i.ZERO
var _has_tile_target: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_tilemap = get_node_or_null(tilemap_path) as TileMapLayer
	_highlight = get_node_or_null(highlight_path) as TileHighlight
	_feedback_layer = get_node_or_null(feedback_layer_path)
	if _feedback_layer == null:
		_feedback_layer = self
	_slot_hint = get_node_or_null(slot_hint_path) as SteppingSlotHint


func set_held_item(item_id: String) -> void:
	_held_item = item_id


func get_held_item() -> String:
	return _held_item


func _process(_delta: float) -> void:
	_resolve_target()
	_update_highlight()
	_update_slot_hint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_do_interact()
		get_viewport().set_input_as_handled()


# ---- targeting -----------------------------------------------------------

func _resolve_target() -> void:
	_target_object = null
	_has_tile_target = false
	if _player == null or _tilemap == null:
		return

	# Prefer the nearest in-reach interactable object (Gatherable or Cauldron).
	var best: Node = null
	var best_d := OBJECT_REACH
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not node.has_method("target_point"):
			continue
		var d: float = node.target_point().distance_to(_player.global_position)
		if d <= best_d:
			best_d = d
			best = node
	if best != null:
		_target_object = best
		return

	# Otherwise the facing-adjacent tile.
	var player_cell := _tilemap.local_to_map(_tilemap.to_local(_player.global_position))
	_target_cell = player_cell + _player.facing_cell_step()
	_has_tile_target = _tilemap.get_cell_source_id(_target_cell) != -1


func _update_highlight() -> void:
	if _highlight == null:
		return
	if _target_object != null:
		var oc := _tilemap.local_to_map(_tilemap.to_local(_target_object.target_point()))
		_highlight.show_cell(_cell_center_world(oc))
	elif _has_tile_target:
		_highlight.show_cell(_cell_center_world(_target_cell))
	else:
		_highlight.hide_highlight()


func _cell_center_world(cell: Vector2i) -> Vector2:
	return _tilemap.to_global(_tilemap.map_to_local(cell))


## G1 guidance: while D14 is held, pulse a diamond over every stepping-slot cell
## that is still water (un-filled). No-op unless a SteppingSlotHint is wired and the
## tilemap exposes `stepping_slot_cells` (the real grove; test_map has neither).
func _update_slot_hint() -> void:
	if _slot_hint == null:
		return
	if _held_item != "D14" or _tilemap == null or not ("stepping_slot_cells" in _tilemap):
		_slot_hint.hide_all()
		return
	var centers := PackedVector2Array()
	for cell in _tilemap.stepping_slot_cells:
		if _is_water_cell(cell):
			centers.append(_cell_center_world(cell))
	_slot_hint.show_cells(centers)


## Source ids that are still water (un-filled stepping slot). T5A/T5B/T5M.
func _is_water_cell(cell: Vector2i) -> bool:
	var src := _tilemap.get_cell_source_id(cell)
	return src == 8 or src == 9 or src == 10


# ---- interaction ---------------------------------------------------------

func _do_interact() -> void:
	var obj := _target_object as Gatherable
	# 1. Held item: try placement (tile) or use (object) first.
	if _held_item != "":
		if obj != null and _try_use_on_object(obj):
			return
		if _has_tile_target and _try_place_on_tile(_target_cell):
			return

	# 2. Gather a targeted object.
	if _target_object != null and _target_object.can_gather():
		var granted: String = _target_object.gather()
		if granted != "":
			_spawn_feedback(_target_object.target_point(), granted)
		return

	# 3. Non-gather interactable (e.g. Cauldron opens the Fusion UI).
	if _target_object != null and _target_object.has_method("on_interact"):
		_target_object.on_interact()
		return

	# 4. Gather a tile.
	if _has_tile_target:
		_try_gather_tile(_target_cell)


# ---- public tap/click entrypoints (M6a touch) ----------------------------

## Interact with a specific object (gather / use held item / on_interact). Used by
## the touch controller once the player has reached / is adjacent to a tapped
## object, bypassing the per-frame facing resolution.
func interact_with_object(obj: Node) -> void:
	if obj == null:
		return
	var g := obj as Gatherable
	if _held_item != "" and g != null and _try_use_on_object(g):
		return
	if obj.has_method("can_gather") and obj.can_gather():
		var granted: String = obj.gather()
		if granted != "":
			_spawn_feedback(obj.target_point(), granted)
		return
	if obj.has_method("on_interact"):
		obj.on_interact()


## Interact with a specific tile cell (place held item / gather tile). Used by the
## touch controller for tapped tiles (water for D14, VOID for D22, gatherable
## ground). Returns nothing; no-op if neither placement nor gather applies.
func interact_with_cell(cell: Vector2i) -> void:
	if _tilemap.get_cell_source_id(cell) == -1:
		return
	if _held_item != "" and _try_place_on_tile(cell):
		return
	_try_gather_tile(cell)


func _try_gather_tile(cell: Vector2i) -> void:
	var data := _tilemap.get_cell_tile_data(cell)
	if data == null:
		return
	if not bool(data.get_custom_data("gatherable")):
		return
	var item_id := String(data.get_custom_data("item_id"))
	if item_id == "":
		return
	Inventory.add(item_id, 1)
	GameState.item_gathered.emit(item_id)
	_spawn_feedback(_cell_center_world(cell), item_id)
	# Replace with VOID (the emptied hole).
	_tilemap.set_cell(cell, VOID_SOURCE, ATLAS)


# ---- placement / use framework ------------------------------------------

## Try to place the held item on the target tile. Returns true if placement
## happened (item consumed). Validity comes from ItemDB.placeable_on vs the
## target tile's logical id.
func _try_place_on_tile(cell: Vector2i) -> bool:
	var tile_id := _logical_tile_id(cell)
	if tile_id == "":
		return false
	if not ItemDB.can_place_on_tile(_held_item, tile_id):
		return false
	# Apply the effect keyed by item id (named-effect registry).
	var applied := _apply_placement_effect(_held_item, cell)
	if not applied:
		return false
	Inventory.remove(_held_item, 1)
	if Inventory.count(_held_item) == 0:
		set_held_item("")
	return true


## Named placement effects. Returns true if the effect was applied.
func _apply_placement_effect(item_id: String, cell: Vector2i) -> bool:
	match item_id:
		"D14":  # 디딤돌 — stepping stone: make the water tile walkable.
			_place_stepping_stone(cell)
			return true
		"D22":  # 어린 세계수 — plant on VOID: clear condition.
			GameState.world_tree_planted.emit(cell)
			return true
	# Unknown placeable item with no registered effect: refuse (don't consume).
	push_warning("InteractionController: no placement effect for '%s'" % item_id)
	return false


## Swap a water cell to a walkable stepping-stone state. Reuses T1 dirt art for
## now (TODO: dedicated on-water stone sprite). The swapped tile's TileSet data
## (walkable=true, no collision) makes it crossable.
func _place_stepping_stone(cell: Vector2i) -> void:
	_tilemap.set_cell(cell, STEPPING_STONE_SOURCE, ATLAS)
	GameState.stepping_stone_placed.emit(cell)
	# G1 guidance: if the crossing this cell belongs to still has un-filled (water)
	# slots, tell the player more stones are needed (a 3-deep stream can't be crossed
	# with one stone — the #1 first-user drop-off risk).
	if _crossing_still_has_water(cell):
		FloatingLabel.spawn(_feedback_layer, _cell_center_world(cell) - Vector2(0, 40),
			"아직 물이 깊다… 발판이 더 필요해")


## True if any stepping-slot cell in the same crossing as `placed` is still water.
## "Same crossing" = the connected group of stepping_slot_cells (4-neighbour flood)
## containing `placed`, so multiple independent crossings never cross-trigger.
func _crossing_still_has_water(placed: Vector2i) -> bool:
	if _tilemap == null or not ("stepping_slot_cells" in _tilemap):
		return false
	var slots: Array = _tilemap.stepping_slot_cells
	var slot_set := {}
	for c in slots:
		slot_set[c] = true
	# Flood-fill the crossing group from `placed` over 4-connected slot cells.
	var group := {}
	var stack: Array = [placed]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		if group.has(cur):
			continue
		group[cur] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if slot_set.has(nb) and not group.has(nb):
				stack.append(nb)
	for c in group:
		if _is_water_cell(c):
			return true
	return false


## Try to use the held item on the target object. Returns true if consumed.
func _try_use_on_object(obj: Gatherable) -> bool:
	if obj.object_id == "":
		return false
	if not ItemDB.can_use_on_object(_held_item, obj.object_id):
		return false
	var used_id := _held_item
	Inventory.remove(used_id, 1)
	if Inventory.count(used_id) == 0:
		set_held_item("")
	GameState.item_used_on_object.emit(used_id, obj)
	return true


# ---- helpers -------------------------------------------------------------

## Map a cell's source id back to its logical tile id (T0, T1, T2A, T4, T5A…).
## Data-driven: source ids equal tile ids per the tileset convention.
const SOURCE_TO_TILE_ID := {
	0: "T0", 1: "T1", 2: "T2A", 3: "T2B", 4: "T2C", 5: "T2D",
	7: "T4", 8: "T5A", 9: "T5B", 10: "T5M",
}

func _logical_tile_id(cell: Vector2i) -> String:
	var src := _tilemap.get_cell_source_id(cell)
	return SOURCE_TO_TILE_ID.get(src, "")


func _spawn_feedback(world_pos: Vector2, item_id: String) -> void:
	var msg := "+1 %s" % ItemDB.item_name(item_id)
	FloatingLabel.spawn(_feedback_layer, world_pos - Vector2(0, 40), msg)
