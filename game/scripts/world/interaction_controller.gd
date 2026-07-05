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
## (v0.3.1 Fix 4) Source id of the walkable "빈 자국(hollow)" left after gathering an
## interior tile. Unlike border VOID (source 0, walkable=false, physics wall), the
## hollow is walkable (custom-data walkable=true, no physics) and its logical tile id
## stays "T0" (see SOURCE_TO_TILE_ID) so the D22 어린 세계수 plant-on-T0 chain is
## untouched — the world remembers being emptied but you can still walk over it.
const HOLLOW_SOURCE := 11
## Source id reused visually for a stepping stone on water (T1 dirt) — TODO:
## dedicated "stone on water" art in a later art batch.
const STEPPING_STONE_SOURCE := 1
const ATLAS := Vector2i(0, 0)

## How close (px) a gatherable object must be to take priority over the faced tile.
## v0.3.1 R3: raised from 140 so objects one iso-cell away in ANY direction — including
## the NE/NW cells "above" the player (lower y-sort, ~1 tile diagonal ≈ 143px) that felt
## unreachable — are targetable. One iso tile is 128×64, so a diagonal neighbour centre is
## ~√(64²+32²)≈72px away at the tile grid, but object target_points sit at sprite base with
## art offsets, so 180 covers the adjacent ring generously without reaching two cells out.
const OBJECT_REACH := 180.0

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

## Floating "E …" prompt shown above the current target (world space). Created lazily.
var _prompt: Label = null

## Currently held item id (from inventory selection), or "" for none.
var _held_item: String = ""

## Current frame's resolved target. Any node in the `gatherable` group that
## implements the target_point()/can_gather()/gather() interface (Gatherable, or
## a duck-typed object like Cauldron). Typed as Node2D so non-Gatherable
## interactables (Cauldron) are supported.
var _target_object: Node = null
var _target_cell: Vector2i = Vector2i.ZERO
var _has_tile_target: bool = false

## ---- v0.3.1 Fix 3: movement-aware + hover highlight ----------------------
## Mouse-hover target (desktop): a gatherable object or gatherable tile under the
## cursor. Shown regardless of movement (aids tap-to-move users); a click still
## walk-then-interacts (handled by the TouchController). Resolved each frame from the
## viewport mouse position; null when the mouse is off a gatherable target or on touch.
var _hover_object: Node = null
var _hover_cell: Vector2i = Vector2i.ZERO
var _has_hover_cell: bool = false
## Whether the last-seen input was touch (hover highlight is a desktop-only aid).
var _touch_mode: bool = false


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


## Context hint for the held-item HUD: if the held item can act on the current
## frame's resolved target, return a short prompt ("E: 사용" for a usable object,
## "E: 배치" for a placeable tile), else "". Read by InventoryUI each frame.
func held_action_hint() -> String:
	if _held_item == "":
		return ""
	var obj := _target_object as Gatherable
	if obj != null and obj.object_id != "" and ItemDB.can_use_on_object(_held_item, obj.object_id):
		return "E: 사용"
	if _has_tile_target and ItemDB.can_place_on_tile(_held_item, _logical_tile_id(_target_cell)):
		return "E: 배치"
	return ""


func _process(_delta: float) -> void:
	_resolve_target()
	_resolve_hover()
	_update_highlight()
	_update_slot_hint()
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	# Track input mode so the desktop-only hover highlight doesn't linger on touch.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_mode = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_touch_mode = false
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


## (v0.3.1 Fix 3) Desktop mouse-hover targeting: find a gatherable object or gatherable
## tile under the cursor. Independent of the facing/nearest target so it works while the
## player is moving (aids tap-to-move users). No-op on touch input.
func _resolve_hover() -> void:
	_hover_object = null
	_has_hover_cell = false
	if _touch_mode or _player == null or _tilemap == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var mouse_screen := get_viewport().get_mouse_position()
	var world: Vector2 = cam.get_canvas_transform().affine_inverse() * mouse_screen
	# Nearest gatherable object within ~half a tile of the cursor.
	var best: Node = null
	var best_d := 72.0
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not node.has_method("target_point"):
			continue
		var d: float = node.target_point().distance_to(world)
		if d <= best_d:
			best_d = d
			best = node
	if best != null:
		_hover_object = best
		return
	# Else a gatherable ground tile under the cursor.
	var cell := _tilemap.local_to_map(_tilemap.to_local(world))
	if _tilemap.get_cell_source_id(cell) == -1:
		return
	var data := _tilemap.get_cell_tile_data(cell)
	if data != null and bool(data.get_custom_data("gatherable")):
		_hover_cell = cell
		_has_hover_cell = true


## True if the current facing tile is worth highlighting when IDLE: it is gatherable,
## OR the held item can be placed on it (D14 water / D22 hollow). A plain walkable tile
## the player merely faces gets no highlight — that was the "jumps around" annoyance.
func _idle_tile_worth_showing() -> bool:
	if not _has_tile_target:
		return false
	var data := _tilemap.get_cell_tile_data(_target_cell)
	if data != null and bool(data.get_custom_data("gatherable")):
		return true
	if _held_item != "" and ItemDB.can_place_on_tile(_held_item, _logical_tile_id(_target_cell)):
		return true
	return false


## v0.3.1 Fix 3 display rule:
##   - Mouse hover over a gatherable object/tile → hover highlight (even while moving).
##   - Else while MOVING → no highlight (stop the per-frame jitter).
##   - Else (IDLE) → subtle highlight on the nearest interactable object, or the facing
##     tile only if it is gatherable / a valid held-item placement target.
func _update_highlight() -> void:
	if _highlight == null:
		return
	# 1. Hover (desktop) wins and ignores movement.
	if _hover_object != null:
		var hc := _tilemap.local_to_map(_tilemap.to_local(_hover_object.target_point()))
		_highlight.show_cell(_cell_center_world(hc), true)
		return
	if _has_hover_cell:
		_highlight.show_cell(_cell_center_world(_hover_cell), true)
		return
	# 2. Moving with no hover → hide entirely.
	if _player != null and _player.is_moving():
		_highlight.hide_highlight()
		return
	# 3. Idle: show subtle highlight on a real interactable only.
	if _target_object != null:
		var oc := _tilemap.local_to_map(_tilemap.to_local(_target_object.target_point()))
		_highlight.show_cell(_cell_center_world(oc), false)
	elif _idle_tile_worth_showing():
		_highlight.show_cell(_cell_center_world(_target_cell), false)
	else:
		_highlight.hide_highlight()


func _cell_center_world(cell: Vector2i) -> Vector2:
	return _tilemap.to_global(_tilemap.map_to_local(cell))


## Floating "E …" hint above the current target. Small dark pill, cream text
## (art guide §7). Text depends on what the `interact` action would do this frame.
func _update_prompt() -> void:
	# v0.3.1 Fix 3: hide the E-prompt entirely while the player is MOVING — it only
	# appears when IDLE next to something you can act on.
	if _player != null and _player.is_moving():
		_hide_prompt()
		return
	var text := _prompt_text()
	if text == "":
		_hide_prompt()
		return
	if _prompt == null:
		_prompt = _make_prompt()
	# Slight fade-in when the prompt (re)appears (tone pass §5).
	if not _prompt.visible:
		_prompt.visible = true
		_prompt.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_prompt, "modulate:a", 1.0, 0.18)
	_prompt.text = text
	# Anchor above the target point, centered.
	var world: Vector2 = _target_object.target_point() if _target_object != null else _cell_center_world(_target_cell)
	_prompt.size = _prompt.get_minimum_size()
	_prompt.global_position = world - Vector2(_prompt.size.x * 0.5, 64)


func _hide_prompt() -> void:
	if _prompt != null:
		_prompt.visible = false


func _prompt_text() -> String:
	# Held item that can act on the target takes priority (matches _do_interact order).
	if _held_item != "":
		var obj := _target_object as Gatherable
		if obj != null and obj.object_id != "" and ItemDB.can_use_on_object(_held_item, obj.object_id):
			return "E 사용"
		if _has_tile_target and ItemDB.can_place_on_tile(_held_item, _logical_tile_id(_target_cell)):
			return "E 배치"
	# Object interactions.
	if _target_object != null:
		if _target_object.has_method("can_gather") and _target_object.can_gather():
			return "E 채집"
		if _target_object.has_method("on_interact"):
			return "E 조합"
	# Gatherable ground tile.
	if _has_tile_target:
		var data := _tilemap.get_cell_tile_data(_target_cell)
		if data != null and bool(data.get_custom_data("gatherable")):
			return "E 채집"
	return ""


func _make_prompt() -> Label:
	# v0.3.1 tone pass §5: a smaller, softer pill positioned consistently above the
	# target, with a slight fade-in (handled in _update_prompt).
	var l := Label.new()
	l.add_theme_color_override("font_color", Color("#faf5e6"))
	l.add_theme_font_size_override("font_size", 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.11, 0.82)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.set_border_width_all(1)
	sb.border_color = Color(0.62, 0.48, 0.85, 0.75)  # violet, slightly soft
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	l.add_theme_stylebox_override("normal", sb)
	l.z_index = 100
	_feedback_layer.add_child(l)
	return l


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
	# v0.3.1 R3: when the mouse is hovering a gatherable object/tile, that target wins over
	# the facing/nearest one — you act on what you point at. Falls back to the facing target
	# (keyboard play / touch) when there is no hover.
	var act_object: Node = _hover_object if _hover_object != null else _target_object
	var act_has_tile := _has_hover_cell or _has_tile_target
	var act_cell := _hover_cell if _has_hover_cell else _target_cell
	var obj := act_object as Gatherable
	# 1. Held item: try placement (tile) or use (object) first.
	if _held_item != "":
		if obj != null and _try_use_on_object(obj):
			return
		if act_has_tile and _try_place_on_tile(act_cell):
			return

	# 2. Gather a targeted object.
	if act_object != null and act_object.has_method("can_gather") and act_object.can_gather():
		var granted: String = act_object.gather()
		if granted != "":
			_spawn_feedback(act_object.target_point(), granted)
		return

	# 3. Non-gather interactable (e.g. Cauldron opens the Fusion UI).
	if act_object != null and act_object.has_method("on_interact"):
		act_object.on_interact()
		return

	# 4. Gather a tile.
	if act_has_tile:
		_try_gather_tile(act_cell)


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
	# Replace with the walkable HOLLOW (빈 자국) — the emptied spot stays crossable.
	# Its logical id remains "T0" so D22 plant-on-VOID still targets it; the AStar grid
	# is rebuilt (via the stepping_stone_placed → _rebuild_solids listener) so tap-to-move
	# crosses it. No physics collision is added (the tile has no physics polygon).
	_tilemap.set_cell(cell, HOLLOW_SOURCE, ATLAS)
	_notify_walkable_changed(cell)


## Tell the pathfinding grid a cell's walkability changed (gather → hollow). Guarded so
## a missing GameState (release template edge case) degrades to no rebuild, not a crash.
func _notify_walkable_changed(cell: Vector2i) -> void:
	if GameState != null:
		GameState.tile_walkable_changed.emit(cell)


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
	11: "T0",  # HOLLOW (빈 자국): logical id stays T0 so D22 plant-on-T0 still works.
}

func _logical_tile_id(cell: Vector2i) -> String:
	var src := _tilemap.get_cell_source_id(cell)
	return SOURCE_TO_TILE_ID.get(src, "")


func _spawn_feedback(world_pos: Vector2, item_id: String) -> void:
	var msg := "+1 %s" % ItemDB.item_name(item_id)
	FloatingLabel.spawn(_feedback_layer, world_pos - Vector2(0, 40), msg)


## (v0.3.1 R4) Float an arbitrary hint message above the player (e.g. the first-time
## "이건 조합 재료야…" affordance nudge). No-op if the player isn't wired.
func spawn_player_hint(msg: String) -> void:
	if _player == null:
		return
	FloatingLabel.spawn(_feedback_layer, _player.global_position - Vector2(0, 72), msg)
