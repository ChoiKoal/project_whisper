extends Node
class_name QuestAreaWatcher
## v0.4.0-C — emits GameState.player_entered_area("world_tree") the first time the player
## walks within `enter_radius` of the world-tree cell(s). Q6 ("위로… 빛나는 곳으로 와.")
## listens for this. Kept as a tiny polling node (rather than an Area2D wired into the
## data-driven map builder) because the world tree is spawned procedurally from the layout,
## so there is no authored scene node to attach a static Area2D to.
##
## Fires ONCE per scene lifetime. Re-entering does not re-fire (the quest has advanced).

## Area id emitted with the signal (matches quests.json Q6 target).
const AREA_ID := "world_tree"
## Pixel radius around the world-tree centre that counts as "arrived".
const ENTER_RADIUS := 140.0

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _center := Vector2.ZERO
var _has_center := false
var _fired := false


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader != null and not _loader.world_tree_cells.is_empty():
		# Average the world-tree cells to a single arrival point.
		var acc := Vector2.ZERO
		for cell in _loader.world_tree_cells:
			acc += _loader.cell_center_world(cell)
		_center = acc / float(_loader.world_tree_cells.size())
		_has_center = true


func _process(_delta: float) -> void:
	if _fired or not _has_center or _player == null:
		return
	if _player.global_position.distance_to(_center) <= ENTER_RADIUS:
		_fired = true
		GameState.player_entered_area.emit(AREA_ID)
