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

var _player: Player
var _tilemap: TileMapLayer
var _highlight: TileHighlight
var _feedback_layer: Node

## Currently held item id (from inventory selection), or "" for none.
var _held_item: String = ""

## Current frame's resolved target.
var _target_object: Gatherable = null
var _target_cell: Vector2i = Vector2i.ZERO
var _has_tile_target: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	_tilemap = get_node_or_null(tilemap_path) as TileMapLayer
	_highlight = get_node_or_null(highlight_path) as TileHighlight
	_feedback_layer = get_node_or_null(feedback_layer_path)
	if _feedback_layer == null:
		_feedback_layer = self


func set_held_item(item_id: String) -> void:
	_held_item = item_id


func get_held_item() -> String:
	return _held_item


func _process(_delta: float) -> void:
	_resolve_target()
	_update_highlight()


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

	# Prefer the nearest in-reach gatherable/usable object.
	var best: Gatherable = null
	var best_d := OBJECT_REACH
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		var g := node as Gatherable
		if g == null:
			continue
		var d := g.target_point().distance_to(_player.global_position)
		if d <= best_d:
			best_d = d
			best = g
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


# ---- interaction ---------------------------------------------------------

func _do_interact() -> void:
	# 1. Held item: try placement (tile) or use (object) first.
	if _held_item != "":
		if _target_object != null and _try_use_on_object(_target_object):
			return
		if _has_tile_target and _try_place_on_tile(_target_cell):
			return

	# 2. Gather a targeted object.
	if _target_object != null and _target_object.can_gather():
		var granted := _target_object.gather()
		if granted != "":
			_spawn_feedback(_target_object.target_point(), granted)
		return

	# 3. Gather a tile.
	if _has_tile_target:
		_try_gather_tile(_target_cell)


func _try_gather_tile(cell: Vector2i) -> void:
	var data := _tilemap.get_cell_tile_data(cell)
	if data == null:
		return
	if not bool(data.get_custom_data("gatherable")):
		return
	var item_id: String = data.get_custom_data("item_id")
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
	7: "T4", 8: "T5A", 9: "T5B",
}

func _logical_tile_id(cell: Vector2i) -> String:
	var src := _tilemap.get_cell_source_id(cell)
	return SOURCE_TO_TILE_ID.get(src, "")


func _spawn_feedback(world_pos: Vector2, item_id: String) -> void:
	var msg := "+1 %s" % ItemDB.item_name(item_id)
	FloatingLabel.spawn(_feedback_layer, world_pos - Vector2(0, 40), msg)
