extends Node2D
class_name TouchController
## M6a tap / click-to-move + tap-to-interact (mobile prep; also works with mouse).
##
## Responsibilities:
##   - Maintain an AStarGrid2D over the MapLoader's walkable grid. Rebuild the
##     solid mask whenever walkability changes (D14 stepping stone placed, bush
##     gate bloomed, night gate day/night toggle).
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
var _astar: AStarGrid2D

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
	# Build after the loader has laid tiles/objects.
	call_deferred("_build_grid")
	if _player != null:
		_player.path_finished.connect(_on_path_finished)
	# Rebuild walkability when gates change the passable set.
	GameState.stepping_stone_placed.connect(func(_c): _rebuild_solids())
	GameState.item_used_on_object.connect(func(_i, _o): call_deferred("_rebuild_solids"))
	GameState.day_phase_changed.connect(func(_p): call_deferred("_rebuild_solids"))


# ---- AStar grid ----------------------------------------------------------

func _build_grid() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, _loader.width, _loader.height)
	_astar.cell_size = Vector2(1, 1)
	# 4-connected iso grid (diagonal moves would cut across non-adjacent diamonds).
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	_rebuild_solids()


## Recompute which cells are solid (non-walkable) from live tile data. Called on
## build and whenever a gate changes the passable set.
func _rebuild_solids() -> void:
	if _astar == null:
		return
	for r in range(_loader.height):
		for c in range(_loader.width):
			var cell := Vector2i(c, r)
			_astar.set_point_solid(cell, not _loader.is_cell_walkable(cell))


## Public: recompute the grid now (e.g. after a scripted world change / tests).
func refresh_grid() -> void:
	_rebuild_solids()


# ---- input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var world_pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		world_pos = _to_world(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		world_pos = _to_world(event.position)
	if world_pos == Vector2.INF:
		return
	get_viewport().set_input_as_handled()
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
	# 1. Object hit? (nearest gatherable/cauldron/stump within a tile of the tap)
	var obj := _object_near(world_pos)
	if obj != null:
		_target_object(obj)
		return
	# 2. Tile hit.
	var cell := _loader.world_to_cell(world_pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= _loader.width or cell.y >= _loader.height:
		return
	_target_cell(cell)


## Public convenience (tests / UI): move the player to a cell by pathfinding.
func move_to(cell: Vector2i) -> bool:
	_pending = {}
	return _path_to_cell(cell)


func _object_near(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_d := 72.0  # within ~half a tile of the tap
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not node.has_method("target_point"):
			continue
		var d: float = node.target_point().distance_to(world_pos)
		if d <= best_d:
			best_d = d
			best = node
	return best


## Tap on an object: act now if adjacent, else walk to a cell beside it + act.
func _target_object(obj: Node) -> void:
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


## Whether tapping this cell should trigger an interaction rather than a plain
## move. Only a valid held-item placement target counts (water for D14, VOID for
## D22, …). Gathering ground tiles stays a deliberate object/interact-button act,
## so a plain tap on walkable ground always means "walk there".
func _cell_is_actionable(cell: Vector2i) -> bool:
	var held := _interaction.get_held_item()
	if held == "":
		return false
	var tile_id := _interaction._logical_tile_id(cell)
	return tile_id != "" and ItemDB.can_place_on_tile(held, tile_id)


# ---- pathfinding ---------------------------------------------------------

func _path_to_cell(dest: Vector2i) -> bool:
	if _astar == null:
		return false
	var start := _loader.world_to_cell(_player.global_position)
	if not _astar.region.has_point(start) or not _astar.region.has_point(dest):
		return false
	if _astar.is_point_solid(dest):
		return false
	var cells := _astar.get_id_path(start, dest)
	if cells.is_empty():
		return false
	var pts: Array[Vector2] = []
	for cid in cells:
		pts.append(_loader.cell_center_world(cid))
	_player.set_path(pts)
	return true


## Nearest 4-neighbour walkable cell to `cell` (where the player can stand to act).
func _nearest_walkable_adjacent(cell: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if _loader.is_cell_walkable(n):
			return n
	return Vector2i(-1, -1)


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
		"object":
			var obj = pend.get("object", null)
			if obj != null and is_instance_valid(obj):
				_interact_object(obj)
		"cell":
			_interaction.interact_with_cell(pend.get("cell", Vector2i.ZERO))


func _interact_object(obj: Node) -> void:
	if _interaction != null:
		_interaction.interact_with_object(obj)
