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
## True while the CS-02 landing beat holds the control lock. If the session is torn down
## mid-beat (e.g. the player takes the spawn-adjacent return portal within the 3s hold),
## the awaiting coroutine never resumes — _exit_tree() must release the lock instead.
var _cs02_lock_held := false


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
	if _loader==null or not _loader.layout_ready:
		SaveManager.unregister_world()
		SaveManager._reject_layout("Grove profile did not finish construction")
		return
	if _loader != null and _player != null and respawn != null:
		SaveManager.register_world(_loader, _player, respawn)

	# A return portal near the grove spawn — always OPEN (the way back to the home island).
	_spawn_return_portal()

	# (EXL1-2) Once the grove is cleared (세계수 정화), the two L1 확장 SUB-zone 연결점이 열린다:
	# 화원(북 오솔길) + 심장(세계수 하강). Spawned as open zone portals only when SaveManager.cleared.
	_spawn_zone_portals()

	# (v1.1.0 GP-4 §1) 시들지 않는 노목 QuestNPC near the grove spawn (reachable, off the portal apron).
	if _loader != null and _loader.spawn_cell != Vector2i(-1, -1):
		QuestNPC.spawn(self, _loader, _loader.anchor_cells("oak_npc",[_loader.spawn_cell + Vector2i(3, 1)])[0], "oak", "시들지 않는 노목",
			"…고맙구나. 색이란 걸, 다시 봤어.", "res://assets/objects/young_tree.png")

	# Apply a pending "이어하기" load into this live scene.
	SaveManager.game_loaded.connect(_ensure_landmarks_clear)
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_game()
	# (v1.3.1 BUG B) In-run RE-ENTRY (portal travel, no 이어하기): restore this world's snapshot so
	# a watered bush / gathered tiles / placed objects the player left behind come back instead of
	# rebuilding fresh. Only when a snapshot already exists (a revisit, not the first entry).
	elif SaveManager.has_world_snapshot(WorldContext.current_scene):
		SaveManager.restore_registered_world()
	_ensure_landmarks_clear()
	# Additive story anchors are built AFTER saved player objects and respawn indexing.
	var story = preload("res://scripts/world/l1_home_story_controller.gd").new()
	story.name = "L1HomeStory"
	add_child(story)
	story.setup(_loader)
	# (v1.3.1 BUG A) Self-heal the portal line from the progression flags every boot so a stale
	# snapshot can never leave a purified world's home portal re-locked.
	GameState.reconcile_portal_line()

	# Wire clear → CS-04 (handled by ClearSequence) → auto-return + CS-05 ignition.
	var clear := get_node_or_null(clear_sequence_path) as ClearSequence
	if clear != null:
		clear.cleared.connect(_on_cleared)
		if SaveManager.pending_l1_clear.size() == 2 and not SaveManager.cleared:
			clear._on_planted(Vector2i(SaveManager.pending_l1_clear[0], SaveManager.pending_l1_clear[1]))

	# (v0.4.0-C) Kick off the day/night soundscape (BGM + ambience) for this run.
	if AudioManager != null:
		AudioManager.start_world_audio()
		AudioManager.set_home_ambience(false)  # full BGM in the grove (Layer 1)

	# (CQ-3 G6) CS-02 「첫 입장」 landing beat: on the FIRST portal arrival into the grove (not a
	# load, grove not yet cleared), lock control for 3s and loop the SAME birdsong twice — the
	# world is beautiful yet "wrong": 같은 새가, 같은 노래를, 같은 자리에서.
	if WorldContext.arrival_mode == "portal_arrival" and not WorldContext.cs02_landing_seen \
			and not (SaveManager != null and SaveManager.cleared):
		WorldContext.cs02_landing_seen = true
		_play_cs02_landing()


## CS-02 landing lock: freeze control ~3s (world time keeps running so BGM/day-night flow), and
## play the same bird chirp twice at the SAME pitch (a broken record). Best-effort, headless-safe.
func _play_cs02_landing() -> void:
	if GameState == null:
		return
	if Codex != null and Codex.has_method("mark_cutscene_seen"):
		Codex.mark_cutscene_seen("CS-02")
	GameState.set_control_lock(true)
	_cs02_lock_held = true
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("bird")
	await get_tree().create_timer(1.5, true, false, true).timeout
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("bird")   # 같은 새소리, 같은 자리 — the loop that shouldn't be
	await get_tree().create_timer(1.5, true, false, true).timeout
	_cs02_lock_held = false
	if GameState != null:
		GameState.set_control_lock(false)


## (v1.3.0 sweep fix) If the grove is torn down while the CS-02 landing beat still holds the
## control lock (pre-clear return portal is right at the spawn — reachable within the 3s hold),
## the beat's awaited timers die with the scene and would leave the lock wedged forever.
## Restore it on the way out.
func _exit_tree() -> void:
	if _cs02_lock_held:
		_cs02_lock_held = false
		if GameState != null:
			GameState.set_control_lock(false)


## (v0.6.0 rework) Build the return portal near the grove spawn using the shared
## ReturnPortalController, so it matches the home gates EXACTLY: real monumental Portal (state
## OPEN), generous front entry apron, "E 홈으로 돌아가기" prompt, keyboard-E + click-walk-then-enter,
## state glow. Placed prominently just south/beside the spawn so it's visible on arrival.
func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	# Keep the return landmark visible but off the spawn/cauldron/stump knot. The old `(0,+2)`
	# landing merged portal + `E 조합` + player; the west pad keeps the way home visible while the
	# east/south dirt first-loop leads to the first flower and relocated cauldron.
	var candidates := [
		_loader.spawn_cell + Vector2i(-4, 0),
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, -2),
	]
	_return_portal.setup(_loader, _player, _loader.anchor_cells("return_portal",candidates), "E 홈으로 돌아가기")
	_return_portal.entered.connect(_on_return_portal)


## New authored landmarks yield to restored player objects, never move/refund save data.
## Recomputed after each restore; no schema migration or guessed placement backfill.
func _ensure_landmarks_clear() -> void:
	if _loader == null or not is_instance_valid(_return_portal):
		return
	var pot: Cauldron = null
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Cauldron and get_parent().is_ancestor_of(node):
			pot = node as Cauldron
			break
	if pot != null and not _landmark_cell_clear(_loader.cauldron_cell, pot):
		var cell := _find_landmark_cell(pot, _loader.anchor_cells("cauldron_fallback",[Vector2i(13, 32)]), false)
		if cell != Vector2i(-1, -1):
			pot.global_position = _loader.cell_center_world(cell)
			_loader.cauldron_cell = cell
	var portal := _return_portal.portal
	if portal != null:
		var base := _loader.world_to_cell(portal.global_position)
		var stand := _loader.world_to_cell(portal.entry_stand_point())
		if not _landmark_cell_clear(base, portal) or not _landmark_cell_clear(stand, portal):
			var cell := _find_landmark_cell(portal, _loader.anchor_cells("return_fallback",[Vector2i(8, 30), Vector2i(12, 34)]), true)
			if cell != Vector2i(-1, -1):
				portal.global_position = _loader.cell_center_world(cell)


func _landmark_cell_clear(cell: Vector2i, except_node: Node2D) -> bool:
	if not _loader.is_cell_walkable(cell):
		return false
	for group in ["placed_object", "gatherable"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == except_node or not node is Node2D or not get_parent().is_ancestor_of(node):
				continue
			if _loader.world_to_cell((node as Node2D).global_position) == cell:
				return false
	return true


func _find_landmark_cell(node: Node2D, preferred: Array, needs_apron: bool) -> Vector2i:
	var candidates := preferred.duplicate()
	var origin := _loader.world_to_cell(node.global_position)
	for radius in range(1, 7):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) == radius:
					candidates.append(origin + Vector2i(dx, dy))
	for candidate: Vector2i in candidates:
		if not _landmark_cell_clear(candidate, node):
			continue
		if needs_apron:
			var stand := _loader.world_to_cell(_loader.cell_center_world(candidate) + Vector2(0, Portal.ENTRY_FORWARD))
			if not _landmark_cell_clear(stand, node):
				continue
		return candidate
	push_warning("GroveSession: no unoccupied landmark fallback; preserved all player placements")
	return Vector2i(-1, -1)


func _on_return_portal() -> void:
	_return_home(false)


## (EXL1-2) Spawn the two L1 확장 SUB-zone 연결점 (화원·심장) — ONLY after the grove is cleared
## (세계수 정화 = 북쪽 길 개방 신호). Each is a real Portal with a custom travel handler. Placed on
## walkable cells NORTH of spawn (화원 = 오솔길, 심장 = 세계수 하강). Idempotent-ish (guarded by a flag).
var _zone_portals_spawned := false

func _spawn_zone_portals() -> void:
	if _zone_portals_spawned:
		return
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	if not (typeof(SaveManager) != TYPE_NIL and SaveManager.cleared):
		return  # locked until the grove is cleared
	_zone_portals_spawned = true
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	# 화원 연결점: a walkable cell to the NW of spawn (오솔길로 북상). 심장: to the NE (세계수 하강).
	_spawn_zone_portal(ys, _loader.anchor_cells("garden_portal",[_loader.spawn_cell + Vector2i(-4, -3), _loader.spawn_cell + Vector2i(-3, -2),
		_loader.spawn_cell + Vector2i(-5, 0)]), "E 고요의 화원으로", WorldContext.SCENE_GARDEN)
	_spawn_zone_portal(ys, _loader.anchor_cells("heart_portal",[_loader.spawn_cell + Vector2i(4, -3), _loader.spawn_cell + Vector2i(3, -2),
		_loader.spawn_cell + Vector2i(5, 0)]), "E 생명의 심장으로", WorldContext.SCENE_HEART)


func _spawn_zone_portal(ys: Node2D, cell_candidates: Array, prompt: String, scene_id: String) -> void:
	var cell := Vector2i(-1, -1)
	for c in cell_candidates:
		if c is Vector2i and _loader.is_cell_walkable(c):
			cell = c
			break
	if cell == Vector2i(-1, -1):
		return
	# Reuse the ReturnPortalController (real Portal, OPEN "return" state → violet vortex glow, apron
	# prompt, E + click-walk-then-enter). The zone identity is carried by the travel handler, not the
	# portal layer key — the controller keeps the portal OPEN via its "return" key.
	var ctrl := ReturnPortalController.new()
	add_child(ctrl)
	ctrl.setup(_loader, _player, [cell], prompt)
	ctrl.entered.connect(func(): _travel_to_zone(scene_id))


## Travel from the grove into a SUB-zone (화원/심장). Snapshots the grove so返回 restores it.
func _travel_to_zone(scene_id: String) -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = scene_id
	get_tree().change_scene_to_file(WorldContext.scene_path(scene_id))


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
