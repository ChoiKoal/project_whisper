extends Node
class_name QuestAreaWatcher
## v0.4.0-C — emits GameState.player_entered_area("world_tree") the first time the player
## walks within `enter_radius` of the world-tree cell(s). Q6 ("위로… 빛나는 곳으로 와.")
## listens for this. Kept as a tiny polling node (rather than an Area2D wired into the
## data-driven map builder) because the world tree is spawned procedurally from the layout,
## so there is no authored scene node to attach a static Area2D to.
##
## Fires ONCE per scene lifetime. Re-entering does not re-fire (the quest has advanced).

## Area id emitted with the signal. Default = grove world-tree (Q6). The home island sets
## this to "dais_edge" (P0) with mode "leave_spawn".
@export var area_id: String = "world_tree"
## Watch mode: "world_tree" fires when the player ARRIVES near the world tree; "leave_spawn"
## fires when the player has moved AWAY from the spawn/dais by LEAVE_RADIUS (P0: reach the
## dais edge / look around).
@export var mode: String = "world_tree"
## Pixel radius around the world-tree centre that counts as "arrived".
const ENTER_RADIUS := 140.0
## Pixel distance from the spawn that counts as "left the dais" (P0).
const LEAVE_RADIUS := 96.0

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _center := Vector2.ZERO
var _has_center := false
var _leave_mode := false
var _fired := false


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader == null:
		return
	if mode == "leave_spawn":
		_leave_mode = true
		if _loader.spawn_cell != Vector2i(-1, -1):
			_center = _loader.cell_center_world(_loader.spawn_cell)
			_has_center = true
	elif not _loader.world_tree_cells.is_empty():
		# Average the world-tree cells to a single arrival point.
		var acc := Vector2.ZERO
		for cell in _loader.world_tree_cells:
			acc += _loader.cell_center_world(cell)
		_center = acc / float(_loader.world_tree_cells.size())
		_has_center = true


func _process(_delta: float) -> void:
	if _fired or not _has_center or _player == null:
		return
	var d := _player.global_position.distance_to(_center)
	var hit := (d >= LEAVE_RADIUS) if _leave_mode else (d <= ENTER_RADIUS)
	if hit:
		_fired = true
		GameState.player_entered_area.emit(area_id)
