extends Node2D
class_name TouchController
## M6a tap / click-to-move + tap-to-interact (mobile prep; also works with mouse).
##
## Responsibilities:
##   - Maintain a height-aware AStar2D over walkable terrain minus live semantic
##     object blockers. Rebuild when tiles/gates change or a blocking Gatherable is
##     gathered/respawned, so tap routes agree with CharacterBody physics.
##   - On a tap/click:
##       * a gatherable / cauldron / stump object → if the player is already
##         adjacent, interact now; otherwise path to the nearest walkable cell
##         beside it and auto-interact on arrival.
##       * a held-item-valid target tile (water for D14, VOID for D22) or a
##         gatherable ground tile → walk adjacent (or act now if adjacent).
##       * a plain walkable tile → path there.
##   - Keyboard movement still works (Player cancels the path on key input).
##
## Pure addition: the existing InteractionController keyboard/`interact` flow is
## untouched; this node just calls its new public entrypoints after arrival.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var interaction_path: NodePath

var _loader: MapLoader
var _player: Player
var _interaction: InteractionController
## (v0.5 phase B) Height-aware graph: an AStar2D over walkable cells, connecting only
## 4-neighbours the player can actually traverse (same height, or via a ramp). Replaces
## the flat AStarGrid2D so paths never route across a cliff ledge. `_pid(cell)` maps a
## cell to its point id; solid/blocked cells simply have no point.
var _astar: AStar2D
var _region: Rect2i
## Instance ids of blocking Gatherables belonging to this controller's world. The set lets
## node_removed trigger a refresh after the node has already lost its parent/group.
var _blocking_gatherable_ids: Dictionary = {}
var _grid_refresh_queued: bool = false

## Pending auto-interaction to run when the player finishes the queued path.
## {"kind": "object"|"cell", "object": Node, "cell": Vector2i} or empty.
var _pending: Dictionary = {}

## How close (px) to an object counts as "adjacent" (mirrors interaction reach).
const ADJACENT_REACH := 150.0


func _ready() -> void:
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Player
	_interaction = get_node_or_null(interaction_path) as InteractionController
	if _loader == null:
		return
	# Track dynamic blockers. Initial objects already exist, so seed the id set as well as
	# listening for later ObjectRespawn additions/removals.
	get_tree().node_added.connect(_on_tree_node_added)
	get_tree().node_removed.connect(_on_tree_node_removed)
	_sync_blocking_gatherable_ids()
	# Build after the loader has laid tiles/objects.
	call_deferred("_build_grid")
	if _player != null:
		_player.path_finished.connect(_on_path_finished)
	# Rebuild walkability when gates change the passable set.
	# Defensive autoload guard (ready-time): a missing GameState would null-deref
	# .stepping_stone_placed during the grove flush in a release template.
	if GameState == null:
		push_warning("TouchController: GameState singleton missing; grid static")
		return
	GameState.stepping_stone_placed.connect(func(_c): _rebuild_solids())
	GameState.item_used_on_object.connect(func(_i, _o): call_deferred("_rebuild_solids"))
	GameState.day_phase_changed.connect(func(_p): call_deferred("_rebuild_solids"))
	# (v0.3.1 Fix 4) Gathering an interior tile turns it into a walkable HOLLOW — rebuild
	# so tap-to-move can cross the emptied spot (previously stayed solid to AStar).
	GameState.tile_walkable_changed.connect(func(_c): _rebuild_solids())
	# (v0.5.1 BUG2b) When the world input-lock toggles (a modal window opens OR a cutscene
	# starts/ends via time_running being driven through push/pop), drop any queued path +
	# pending auto-interact so the player never auto-walks a stale target after unlock.
	GameState.ui_modal_changed.connect(func(_open): _clear_pending_path())
	GameState.control_lock_changed.connect(func(_locked): _clear_pending_path())
	GameState.time_requested_changed.connect(func(_running): _clear_pending_path())


# ---- dynamic object blockers ---------------------------------------------

func _belongs_to_current_world(node: Node) -> bool:
	return is_instance_valid(_loader) and _loader.is_inside_tree() and _loader.get_parent() != null \
		and _loader.get_parent().is_ancestor_of(node)


func _is_blocking_gatherable(node: Node) -> bool:
	return node is Gatherable and (node as Gatherable).blocks_movement \
		and _belongs_to_current_world(node)


func _sync_blocking_gatherable_ids() -> void:
	_blocking_gatherable_ids.clear()
	if not is_inside_tree() or not is_instance_valid(_loader):
		return
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if _is_blocking_gatherable(node) and not node.is_queued_for_deletion():
			_blocking_gatherable_ids[node.get_instance_id()] = true


func _on_tree_node_added(node: Node) -> void:
	if _is_blocking_gatherable(node):
		_blocking_gatherable_ids[node.get_instance_id()] = true
		_queue_grid_refresh()


func _on_tree_node_removed(node: Node) -> void:
	var id := node.get_instance_id()
	if _blocking_gatherable_ids.erase(id):
		_queue_grid_refresh()


func _queue_grid_refresh() -> void:
	if _grid_refresh_queued or not is_inside_tree():
		return
	_grid_refresh_queued = true
	call_deferred("_flush_grid_refresh")


func _flush_grid_refresh() -> void:
	_grid_refresh_queued = false
	_rebuild_solids()
	_cancel_obstructed_path()


## Graph refresh cannot retroactively change the world-space route held by Player.
## Sweep that remaining route after dynamic blockers change; cancel only an unsafe
## route (including its auto-interaction). A fresh tap can request a detour. Never
## resume a canceled keyboard/modal path or fire path_finished for this cancellation.
func _cancel_obstructed_path() -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var transform := _player.global_transform
	for waypoint in _player._path:
		if _player.test_move(transform, waypoint - transform.origin):
			_clear_pending_path()
			return
		transform.origin = waypoint


func _blocking_object_cells() -> Dictionary:
	var cells := {}
	if not is_inside_tree() or not is_instance_valid(_loader):
		return cells
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not _is_blocking_gatherable(node) or node.is_queued_for_deletion():
			continue
		cells[_loader.world_to_cell(node.target_point())] = true
	return cells


# ---- AStar graph (height-aware) ------------------------------------------

## Stable point id for a cell (row-major). Cells never move, so the id is fixed even
## as walkability toggles — we add/remove the point and its edges instead.
func _pid(cell: Vector2i) -> int:
	return cell.y * _region.size.x + cell.x


func _build_grid() -> void:
	_astar = AStar2D.new()
	_region = Rect2i(0, 0, _loader.width, _loader.height)
	_rebuild_solids()


## Rebuild the walkable graph from live tile data + height. A cell is a point iff it is
## walkable; an edge connects two 4-adjacent walkable cells iff the loader says the
## player can traverse the height step between them (same level, or one side a ramp).
## Called on build and whenever a gate / gather changes the passable set.
func _rebuild_solids() -> void:
	if _astar == null or not is_inside_tree() or not is_instance_valid(_loader):
		return
	_astar.clear()
	var w := _loader.width
	var h := _loader.height
	var object_solids := _blocking_object_cells()
	_sync_blocking_gatherable_ids()
	# 1. Points for terrain-walkable cells not occupied by a live semantic blocker.
	for r in range(h):
		for c in range(w):
			var cell := Vector2i(c, r)
			if _loader.is_cell_walkable(cell) and not object_solids.has(cell):
				_astar.add_point(_pid(cell), Vector2(c, r))
	# 2. edges between traversable 4-neighbours (check +col / +row once per pair).
	for r in range(h):
		for c in range(w):
			var cell := Vector2i(c, r)
			if not _astar.has_point(_pid(cell)):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb := _loader.terrain_neighbor(cell, d)
				if not _region.has_point(nb):
					continue
				if not _astar.has_point(_pid(nb)):
					continue
				if _height_traversable(cell, nb):
					_astar.connect_points(_pid(cell), _pid(nb), true)


## Height-aware traversability wrapper — defers to the loader when it supports heights,
## otherwise everything is traversable (flat map / home island without a height file).
func _height_traversable(a: Vector2i, b: Vector2i) -> bool:
	if _loader.has_method("can_traverse"):
		return _loader.can_traverse(a, b)
	return true


## Public: recompute the grid now (e.g. after a scripted world change / tests).
func refresh_grid() -> void:
	_rebuild_solids()


# ---- input ---------------------------------------------------------------

## (v0.5.1 BUG2b) The world is "locked" for click-to-move whenever a modal window is open OR
## a cutscene is running (cutscenes pause GameState.time_running). No new path may be queued
## while locked; existing paths are cleared on the lock transition + on scene exit.
func _world_locked() -> bool:
	if GameState == null:
		return false
	return GameState.ui_modal_open() or not GameState.time_running or GameState.control_locked()


## Drop any queued path + pending auto-interact (used on lock, cutscene start, scene exit).
func _clear_pending_path() -> void:
	_pending = {}
	if _player != null and is_instance_valid(_player):
		_player.clear_path()


func _notification(what: int) -> void:
	# Scene teardown: never leave a queued path/pending interact dangling into the next scene.
	if what == NOTIFICATION_EXIT_TREE:
		_clear_pending_path()


func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	# (v0.4.0-B B3.1 / v0.5.1 BUG2b) Click-to-move is disabled while a window is open OR a
	# cutscene is playing. The window's own controls still receive their clicks (they sit on
	# higher CanvasLayers and consume the event before it reaches this world _unhandled_input).
	if _world_locked():
		return
	var world_pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		world_pos = _to_world(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		world_pos = _to_world(event.position)
	if world_pos == Vector2.INF:
		return
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()
	handle_tap(world_pos)


## Convert a screen/viewport position to world space via the active camera.
func _to_world(screen_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var xform := cam.get_canvas_transform()
		return xform.affine_inverse() * screen_pos
	return screen_pos


# ---- tap handling (public: also the harness entrypoint) ------------------

## Resolve a world-space tap: interact with an object/tile if targeted, else move.
func handle_tap(world_pos: Vector2) -> void:
	if _loader == null or _player == null:
		return
	# (v0.4.0-B B3.1 / v0.5.1 BUG2b) No world taps while a modal window is open or a cutscene
	# is running — refuse the path outright (also the harness entrypoint, so it's asserted).
	if _world_locked():
		return
	# An explicit Build tap on empty ground wins over a neighbouring sprite's
	# generous pick radius, using the same rule as the keyboard hover preview.
	var cell := _loader.world_to_cell(world_pos)
	if _interaction != null and _interaction.prefers_held_ground(cell):
		_interaction.cancel_harvest_except(null)
		_target_placement(cell)
		return
	# 1. Object hit? (nearest gatherable/cauldron/stump within a tile of the tap)
	var obj := _object_near(world_pos)
	if _interaction != null: _interaction.cancel_harvest_except(obj)
	if obj != null:
		_target_object(obj)
		return
	# 2. Tile hit.
	if cell.x < 0 or cell.y < 0 or cell.x >= _loader.width or cell.y >= _loader.height:
		return
	_target_cell(cell)


## Public convenience (tests / UI): move the player to a cell by pathfinding.
## (v0.5.1 BUG2b) Honors the world lock exactly like handle_tap — no new path may be queued
## while a modal window is open or a cutscene is running.
func move_to(cell: Vector2i) -> bool:
	if _world_locked():
		return false
	if _interaction != null: _interaction.cancel_harvest_except(null)
	_pending = {}
	return _path_to_cell(cell)


func _object_near(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_d := 72.0  # within ~half a tile of the tap
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not node.has_method("target_point"):
			continue
		var visual: Vector2 = node.visual_target_point() if node.has_method("visual_target_point") else node.target_point()
		var d: float = visual.distance_to(world_pos)
		if d <= best_d:
			best_d = d
			best = node
	return best


## Tap on an object: act now if adjacent, else walk to a cell beside it + act.
func _target_object(obj: Node) -> void:
	# (v0.5.1 BUG3) A Portal is entered via its front-apron entry zone, NOT via an adjacent
	# gather cell (its interactable anchor sat inside/above the gate collision). Path to the
	# apron stand-point and enter on arrival — walk-then-enter for click / tap.
	if obj is Portal:
		var gate := obj as Portal
		if gate.is_player_in_entry_zone():
			_player.clear_path()
			gate.on_interact()
			return
		var stand_cell := _loader.world_to_cell(gate.entry_stand_point())
		var stand_p := stand_cell
		if not _loader.is_cell_walkable(stand_p):
			stand_p = _nearest_walkable_adjacent(stand_cell)
		if stand_p == Vector2i(-1, -1):
			return
		if _path_to_cell(stand_p):
			_pending = {"kind": "portal", "object": gate}
		return
	if _is_adjacent_to(obj.target_point()):
		_player.clear_path()
		_interact_object(obj)
		return
	var obj_cell := _loader.world_to_cell(obj.target_point())
	var stand := _nearest_walkable_adjacent(obj_cell)
	if stand == Vector2i(-1, -1):
		return
	if _path_to_cell(stand):
		_pending = {"kind": "object", "object": obj}


## Tap on a tile: held-item placement/use or a gatherable ground tile → walk
## adjacent then act; a plain walkable tile → just move there.
func _target_placement(cell: Vector2i) -> void:
	var held := _interaction.get_held_item()
	if _is_adjacent_to_cell(cell):
		_player.clear_path()
		_pending = {}
		_interaction.interact_with_cell(cell)
		return
	var stand := _nearest_walkable_adjacent(cell)
	if stand != Vector2i(-1,-1) and _path_to_cell(stand):
		_pending = {"kind":"held_placement","cell":cell,"item":held}


func _target_cell(cell: Vector2i) -> void:
	var acts := _cell_is_actionable(cell)
	if acts:
		if _is_adjacent_to_cell(cell):
			_player.clear_path()
			_interaction.interact_with_cell(cell)
			return
		var stand := _nearest_walkable_adjacent(cell)
		if stand == Vector2i(-1, -1):
			return
		if _path_to_cell(stand):
			_pending = {"kind": "cell", "cell": cell}
		return
	# Plain move: only to a walkable destination.
	if _loader.is_cell_walkable(cell):
		_path_to_cell(cell)
	elif _loader.is_protected_stream(cell):
		_interaction.show_stream_hint(cell)


## Whether tapping this cell should trigger an interaction rather than a plain
## move. Only a valid held-item placement target counts (water for D14, VOID for
## D22, …). Gathering ground tiles stays a deliberate object/interact-button act,
## so a plain tap on walkable ground always means "walk there".
func _cell_is_actionable(cell: Vector2i) -> bool:
	var held := _interaction.get_held_item()
	if held == "":
		return false
	var tile_id := _interaction._logical_tile_id(cell)
	return tile_id != "" and _interaction.can_place_on_cell(cell,held)


# ---- pathfinding ---------------------------------------------------------

func _waypoint_world(cell: Vector2i) -> Vector2:
	var point := _loader.cell_center_world(cell)
	if not _loader.uses_grove_topology():
		point.y += _loader.height_offset(cell)
	return point


## A compact body does not occupy its whole tile. A player can legitimately stand
## beside it inside the omitted graph cell. Join only a directly collision-free
## neighbour; never synthesize an edge through the obstacle or a terrain ledge.
func _path_ids_from_player(dest: Vector2i) -> PackedInt64Array:
	var empty := PackedInt64Array()
	if _astar == null or _player == null:
		return empty
	var start := _loader.world_to_cell(_player.global_position)
	if not _region.has_point(start) or not _region.has_point(dest):
		return empty
	if not _astar.has_point(_pid(dest)):
		return empty
	if _astar.has_point(_pid(start)):
		return _astar.get_id_path(_pid(start), _pid(dest))
	if not _loader.is_cell_walkable(start) or not _blocking_object_cells().has(start):
		return empty
	var best := empty
	var best_cost := INF
	for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		var neighbour := _loader.terrain_neighbor(start, direction)
		if not _region.has_point(neighbour) or not _astar.has_point(_pid(neighbour)):
			continue
		if not _height_traversable(start, neighbour):
			continue
		var motion := _waypoint_world(neighbour) - _player.global_position
		if _player.test_move(_player.global_transform, motion):
			continue
		var route := _astar.get_id_path(_pid(neighbour), _pid(dest))
		var cost := motion.length() + route.size() * 64.0
		if not route.is_empty() and cost < best_cost:
			best = route
			best_cost = cost
	return best


func _path_to_cell(dest: Vector2i) -> bool:
	var ids := _path_ids_from_player(dest)
	if ids.is_empty():
		return false
	var pts: Array[Vector2] = []
	for pid in ids:
		var gp := _astar.get_point_position(pid)
		var cell := Vector2i(int(gp.x), int(gp.y))
		pts.append(_waypoint_world(cell))
	_player.set_path(pts)
	return true


## Shortest path-reachable 4-neighbour of `cell` (where the player can stand to act).
## Query the live graph, not terrain alone: another tree/rock may occupy an adjacent tile.
func _nearest_walkable_adjacent(cell: Vector2i) -> Vector2i:
	if _astar == null or _player == null:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_len := 1 << 30
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = _loader.terrain_neighbor(cell, d)
		if not _region.has_point(n) or not _astar.has_point(_pid(n)):
			continue
		var ids := _path_ids_from_player(n)
		if not ids.is_empty() and ids.size() < best_len:
			best = n
			best_len = ids.size()
	return best


func _is_adjacent_to(world_point: Vector2) -> bool:
	return _player.global_position.distance_to(world_point) <= ADJACENT_REACH


func _is_adjacent_to_cell(cell: Vector2i) -> bool:
	var pcell := _loader.world_to_cell(_player.global_position)
	var dc: Vector2i = cell - pcell
	return absi(dc.x) + absi(dc.y) <= 1


# ---- arrival -------------------------------------------------------------

func _on_path_finished() -> void:
	if _pending.is_empty():
		return
	var pend := _pending
	_pending = {}
	match pend.get("kind", ""):
		"held_placement":
			# This is the original placement request, not permission to gather or
			# use the player's later selection. Revalidate after the whole walk.
			if _world_locked() or _interaction == null: return
			var cell: Vector2i = pend["cell"]
			if _interaction.get_held_item() != pend["item"]: return
			if not _interaction.prefers_held_ground(cell): return
			if not _interaction._cell_adjacent(cell,_loader.world_to_cell(_player.global_position)): return
			_interaction.interact_with_cell(cell)
		"object":
			var obj = pend.get("object", null)
			if obj != null and is_instance_valid(obj):
				_interact_object(obj)
		"cell":
			_interaction.interact_with_cell(pend.get("cell", Vector2i.ZERO))
		"portal":
			# (v0.5.1 BUG3) Arrived at a gate's entry apron → enter it. on_interact routes to
			# HomeSession (travel if enterable, locked whisper if dormant).
			var gate = pend.get("object", null)
			if gate != null and is_instance_valid(gate) and gate.has_method("on_interact"):
				gate.on_interact()


func _interact_object(obj: Node) -> void:
	if _interaction != null:
		_interaction.interact_with_object(obj)
