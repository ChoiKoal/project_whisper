extends Node
class_name GroveSession
## Glue node inside starting_grove.tscn (Layer 1). On ready it:
##   - registers the live world (MapLoader, Player, ObjectRespawn) with SaveManager under
##     the "grove" scene id
##   - if SaveManager.pending_load, loads the save into the freshly-built scene
##   - spawns a RETURN PORTAL near the grove spawn (always open once arrived — the way home)
##   - if the player arrived via a portal, lands them at the pond/spawn arrival point
##   - wires the ClearSequence so clearing → CS-04 purification → auto-return to the home
##     island with the CS-05 ignition pending
##
## Kept separate from MapLoader so the map builder stays purely data-driven and the M4
## harness (which instances the scene without a save) is unaffected.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath
@export var clear_sequence_path: NodePath

var _loader: MapLoader
var _player: Node2D


func _ready() -> void:
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	# Wait one frame so MapLoader._ready() has built tiles + spawned objects and
	# ObjectRespawn has indexed them.
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	var respawn := get_node_or_null(respawn_path) as ObjectRespawn
	if _loader != null and _player != null and respawn != null:
		SaveManager.register_world(_loader, _player, respawn)

	# A return portal near the grove spawn — always OPEN (the way back to the home island).
	_spawn_return_portal()

	# Apply a pending "이어하기" load into this live scene.
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_game()

	# Wire clear → CS-04 (handled by ClearSequence) → auto-return + CS-05 ignition.
	var clear := get_node_or_null(clear_sequence_path) as ClearSequence
	if clear != null:
		clear.cleared.connect(_on_cleared)

	# (v0.4.0-C) Kick off the day/night soundscape (BGM + ambience) for this run.
	if AudioManager != null:
		AudioManager.start_world_audio()
		AudioManager.set_home_ambience(false)  # full BGM in the grove (Layer 1)


## Build a return portal (always open) a couple cells from the grove spawn, wired to travel
## back to the home island. Uses the same Portal node; its layer is "return".
func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	var ysort := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ysort == null:
		return
	# A walkable cell near the spawn to stand the arch on (prefer just west of spawn).
	var cell := _loader.spawn_cell + Vector2i(-2, 0)
	if not _loader.is_cell_walkable(cell):
		cell = _loader.spawn_cell + Vector2i(0, -2)
	var scr := load("res://scripts/world/portal.gd")
	if scr == null:
		return
	# Force it OPEN before add_child so Portal._ready adopts the OPEN state on build (the
	# state must exist before the node reads GameState.portal_state("return") in its _ready).
	GameState.set_portal_state("return", GameState.PORTAL_OPEN)
	var p: Node2D = scr.new()
	if p == null:
		return
	p.set("layer", "return")
	p.set("object_id", "portal_return")
	p.position = _loader.cell_center_world(cell)
	p.y_sort_enabled = true
	ysort.add_child(p)
	if p.has_signal("portal_interacted"):
		p.connect("portal_interacted", _on_return_portal)


func _on_return_portal(_portal) -> void:
	_return_home(false)


func _on_cleared() -> void:
	# CS-04 purification has played (ClearSequence). Mark cleared, then auto-return to the
	# home island with the CS-05 ignition queued.
	SaveManager.mark_cleared()
	SaveManager.save_game()
	_return_home(true)


## Travel back to the home island. `ignition` = queue the CS-05 return-ignition cutscene.
func _return_home(ignition: bool) -> void:
	WorldContext.arrival_mode = "portal_arrival"
	if ignition:
		SaveManager.queue_return_ignition()
	# Snapshot the grove world so re-entry restores it.
	SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_HOME))
