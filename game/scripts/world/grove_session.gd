extends Node
class_name GroveSession
## Glue node inside starting_grove.tscn. On ready it:
##   - registers the live world (MapLoader, Player, ObjectRespawn) with SaveManager
##   - if SaveManager.pending_load, loads the save into the freshly-built scene
##     (map diff + objects + gates + player pos + time + held item)
##   - wires the ClearSequence so clearing marks the run cleared + autosaves
##
## Kept separate from MapLoader so the map builder stays purely data-driven and
## the M4 harness (which instances the scene without a save) is unaffected.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath
@export var clear_sequence_path: NodePath


func _ready() -> void:
	# Wait one frame so MapLoader._ready() has built tiles + spawned objects and
	# ObjectRespawn has indexed them.
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	var loader := get_node_or_null(map_loader_path) as MapLoader
	var player := get_node_or_null(player_path) as Node2D
	var respawn := get_node_or_null(respawn_path) as ObjectRespawn
	if loader != null and player != null and respawn != null:
		SaveManager.register_world(loader, player, respawn)

	# Apply a pending "이어하기" load into this live scene.
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_game()

	# Wire clear → mark cleared + autosave (spec: autosave after clear sequence).
	var clear := get_node_or_null(clear_sequence_path) as ClearSequence
	if clear != null:
		clear.cleared.connect(_on_cleared)


func _on_cleared() -> void:
	SaveManager.mark_cleared()
	SaveManager.save_game()
