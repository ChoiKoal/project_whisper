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
## (v0.6.0) The reworked return portal (entry-zone prompt + E + click-walk-then-enter). Replaces
## the old bare Portal that only connected portal_interacted (the "weak interaction" owner report).
var _return_portal: ReturnPortalController = null


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

	# (v1.1.0 GP-4 §1) 시들지 않는 노목 QuestNPC near the grove spawn (reachable, off the portal apron).
	if _loader != null and _loader.spawn_cell != Vector2i(-1, -1):
		QuestNPC.spawn(self, _loader, _loader.spawn_cell + Vector2i(3, 1), "oak", "시들지 않는 노목",
			"…고맙구나. 색이란 걸, 다시 봤어.", "res://assets/objects/young_tree.png")

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


## (v0.6.0 rework) Build the return portal near the grove spawn using the shared
## ReturnPortalController, so it matches the home gates EXACTLY: real monumental Portal (state
## OPEN), generous front entry apron, "E 홈으로 돌아가기" prompt, keyboard-E + click-walk-then-enter,
## state glow. Placed prominently just south/beside the spawn so it's visible on arrival.
func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	# Prominent, walkable cell near the spawn; the controller picks the first walkable candidate.
	# Prefer just SOUTH of spawn (in front of the player on arrival), then west, then north.
	var candidates := [
		_loader.spawn_cell + Vector2i(0, 2),
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, -2),
	]
	_return_portal.setup(_loader, _player, candidates, "E 홈으로 돌아가기")
	_return_portal.entered.connect(_on_return_portal)


func _on_return_portal() -> void:
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
