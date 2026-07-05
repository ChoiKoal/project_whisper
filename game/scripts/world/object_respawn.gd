extends Node
class_name ObjectRespawn
## Respawns ordinary gatherable objects (T/F/R/s) one full game day after they
## are gathered. Tile gathers (grass/dirt/mud/water → VOID) are NEVER respawned —
## VOID is permanent (테마 핵심). The World Tree (unique) never respawns either
## (it stays in the world via Gatherable's unique/_spent, so it never frees).
##
## The MapLoader hands us its `object_spawns` list (cell + symbol + the initial
## instance). We watch each instance; when a non-unique one frees itself on
## gather, we schedule a respawn at GameState.game_time + DAY_LENGTH and rebuild
## the same object at the same cell then.

@export var map_loader_path: NodePath
@export var ysort_layer_path: NodePath

var _loader: MapLoader
var _ysort: Node2D

## Each entry: {cell, symbol, node, respawn_at (float or -1)}.
var _tracked: Array = []
## cell -> tracked entry, for O(1) lookups (save/load with a dense object map).
var _by_cell: Dictionary = {}


func _ready() -> void:
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_ysort = get_node_or_null(ysort_layer_path) as Node2D
	if _loader == null:
		return
	# Give the loader a frame to spawn objects.
	call_deferred("_index")


func _index() -> void:
	# Build a position→node map once (O(children)) so indexing the (now dense, M6a)
	# spawn list stays linear instead of O(objects × children).
	var by_pos: Dictionary = {}
	if _ysort != null:
		for ch in _ysort.get_children():
			if ch is Gatherable:
				by_pos[(ch as Node2D).position.round()] = ch
	# Rebuild the tracked list from the loader's spawn record + live children.
	for entry in _loader.object_spawns:
		var cell: Vector2i = entry["cell"]
		var node = by_pos.get(_loader.cell_center_world(cell).round(), null)
		var te := {"cell": cell, "symbol": entry["symbol"], "node": node, "respawn_at": -1.0}
		_tracked.append(te)
		_by_cell[cell] = te


## O(1) tracked-entry lookup by cell (used by SaveManager on load).
func entry_for_cell(cell: Vector2i):
	return _by_cell.get(cell, null)


func _find_object_at(cell: Vector2i) -> Node:
	if _ysort == null:
		return null
	var target := _loader.cell_center_world(cell)
	for ch in _ysort.get_children():
		if ch is Gatherable and (ch as Node2D).position.distance_to(target) < 4.0:
			return ch
	return null


func _process(_delta: float) -> void:
	var now := GameState.game_time
	for entry in _tracked:
		var node = entry["node"]
		# Detect a fresh gather: node freed, no respawn scheduled yet.
		if (node == null or not is_instance_valid(node)) and entry["respawn_at"] < 0.0:
			entry["respawn_at"] = now + GameState.DAY_LENGTH
			entry["node"] = null
		# Time to respawn?
		elif entry["respawn_at"] >= 0.0 and now >= entry["respawn_at"]:
			_respawn(entry)


func _respawn(entry: Dictionary) -> void:
	if _loader == null or _ysort == null:
		entry["respawn_at"] = -1.0
		return
	# Only respawn if the tile beneath is still its original ground; if the player
	# gathered the tile too (→ VOID 0 or HOLLOW 11 빈 자국), skip (theme: the emptied
	# mark persists — v0.3.1 makes it walkable but it's still "emptied").
	var cell: Vector2i = entry["cell"]
	var src := _loader.get_cell_source_id(cell)
	if src == 0 or src == 11:
		entry["respawn_at"] = -1.0
		return
	# Deterministic rebuild (same texture variant as the initial spawn) so save /
	# respawn state matches. All symbol/texture logic lives on the MapLoader.
	var node := _loader.rebuild_gatherable(entry["symbol"], cell)
	if node != null:
		node.position = _loader.cell_center_world(cell)
		node.y_sort_enabled = true
		_ysort.add_child(node)
		# (v0.5 phase C PRE-FIX) a respawned object on a raised cell must get the same
		# height lift as the initial spawn, or it would sit at the un-lifted cell centre
		# (embedded in the plateau's cliff face). Single shared code path.
		_loader.apply_height_lift(node)
	entry["node"] = node
	entry["respawn_at"] = -1.0


## Test helper: force any pending respawns whose time has come.
func force_tick() -> void:
	_process(0.0)
