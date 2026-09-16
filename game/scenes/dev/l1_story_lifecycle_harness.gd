extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
var callbacks:=0
func check(label: String,ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("l1_story_lifecycle"):
		get_tree().quit(86);return
	check("owned cinematic API exists",GameState.has_method("begin_cinematic"))
	var clear:=ClearSequence.new();add_child(clear)
	check("CS04 exposes skip",clear.has_method("skip"))
	var portal:=PortalCutscene.new();add_child(portal)
	check("travel/CS05 exposes skip",portal.has_method("skip"))
	if failures:
		clear.queue_free();portal.queue_free();get_tree().quit(1);return
	GameState.time_running=false
	GameState.set_control_lock(true)
	GameState.push_modal("other-owner")
	clear.cleared.connect(func():callbacks+=1)
	clear.play();clear.call("skip");clear.call("skip")
	check("CS04 double skip emits once",callbacks==1)
	check("CS04 preserves prior time/control/modal",not GameState.time_running and GameState.control_locked() and GameState._modal_keys.has("other-owner"))
	GameState.set_control_lock(false);GameState.time_running=true
	GameState.call("begin_cinematic","test-other")
	callbacks=0
	portal.play_travel(func():callbacks+=1)
	portal.play_travel(func():callbacks+=100)
	portal.call("skip");portal.call("skip")
	check("duplicate travel entry never executes extra callback",callbacks==1)
	check("travel leaves other cinematic owner intact",not GameState.time_running and GameState.control_locked())
	GameState.call("end_cinematic","test-other")
	check("last lease releases only cinematic time/control",GameState.time_running and not GameState.control_locked() and GameState.ui_modal_open())
	GameState.pop_modal("other-owner")
	portal.play_travel(func():callbacks+=1000)
	GameState.time_running=false
	GameState.set_control_lock(true)
	portal.call("skip")
	check("locks acquired mid-cutscene survive finish",not GameState.time_running and GameState.control_locked())
	GameState.time_running=true;GameState.set_control_lock(false)
	portal.play_return_ignition()
	portal.call("skip")
	check("CS05 skip commits existing portal line and P2",GameState.portal_state("nature")=="open" and GameState.portal_state("science")=="flickering" and QuestManager.to_dict().get("active_id")=="P2")
	portal.queue_free();clear.queue_free()
	await get_tree().process_frame
	check("free after finish leaves no cinematic lock",GameState.time_running and not GameState.control_locked())
	var abort:=PortalCutscene.new();add_child(abort)
	callbacks=0
	abort.play_travel(func():callbacks+=1)
	abort.queue_free()
	await get_tree().process_frame
	check("scene exit cancels travel callback and releases own lock",callbacks==0 and GameState.time_running and not GameState.control_locked())
	await get_tree().create_timer(1.8).timeout
	check("cancelled tween cannot invoke stale callback",callbacks==0)
	# Actual D22 consumption followed by disk save/teardown must preserve a resumable clear.
	SaveManager.new_game()
	var grove: Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(grove)
	for i in range(12): await get_tree().process_frame
	var ground: MapLoader=grove.get_node("Ground")
	ground.set_cell(Vector2i(23,35),11,Vector2i.ZERO)
	Inventory.add("D22",1)
	var interact: InteractionController=grove.get_node("Interaction")
	interact.set_held_item("D22")
	check("D22 actual transaction consumed once",interact._try_place_on_tile(Vector2i(23,35)) and Inventory.count("D22")==0)
	SaveManager.save_game()
	var data:=SaveManager.build_save_dict()
	check("unfinished CS04 persisted",data.get("pending_l1_clear")==[23,35])
	SaveManager.unregister_world();grove.queue_free()
	await get_tree().process_frame
	SaveManager.load_game()
	SaveManager.pending_load=true
	grove=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(grove)
	for i in range(12): await get_tree().process_frame
	var resumed: ClearSequence=grove.get_node("ClearSequence")
	check("disk reload resumes clear without another D22",resumed.is_active() and Inventory.count("D22")==0)
	# Avoid real scene handoff in this unit; completion inspected by later root capture.
	resumed.cleared.disconnect(Callable(grove.get_node("GroveSession"),"_on_cleared"))
	resumed.skip()
	SaveManager.unregister_world();grove.queue_free();await get_tree().process_frame
	# Pending CS05 must remain durable until finalizer/caller completes, including load arrival_mode empty.
	SaveManager.mark_cleared();SaveManager.queue_return_ignition()
	WorldContext.current_scene="home";WorldContext.arrival_mode=""
	SaveManager.save_game()
	SaveManager.pending_load=true
	var home: Node=load("res://scenes/world/home_island.tscn").instantiate();add_child(home)
	for i in range(12): await get_tree().process_frame
	var ignition: PortalCutscene=home.get_node("PortalCutscene")
	check("pending CS05 replays on load without arrival_mode",ignition.is_active())
	check("pending CS05 not consumed while running",SaveManager.pending_return_ignition)
	ignition.skip()
	check("CS05 caller clears pending only after commit",not SaveManager.pending_return_ignition and QuestManager.active_id=="P2")
	var camera: Camera2D=home.get_node("YSortLayer/Player/Camera2D")
	await get_tree().create_timer(3.8).timeout
	check("CS05 skip cancels delayed camera pan",camera.offset==Vector2.ZERO)
	SaveManager.unregister_world();home.queue_free();await get_tree().process_frame
	# Replay must use current outcome but never modify story/inventory/quests/portals.
	Codex.mark_cutscene_seen("EP-L1H-01")
	GameState.story_record_experiment("D10")
	var before_story:=GameState.story_episode()
	var before_quests:=QuestManager.to_dict()
	var before_portals:=GameState.portal_states.duplicate(true)
	GameState.time_running=false;GameState.set_control_lock(true)
	GameState.push_modal("codex")
	var replay:=CutsceneReplay.new();add_child(replay)
	replay.play("EP-L1H-01")
	check("episode replay has current branch cards",replay.has_method("episode_cards"))
	if replay.has_method("episode_cards"):
		check("nest replay reads saved outcome",str(replay.call("episode_cards")).contains("집부터 만들었네"))
	replay.skip();replay.skip()
	check("replay preserves previous pause/control/modal",not GameState.time_running and GameState.control_locked() and GameState._modal_keys.has("codex"))
	check("replay side effects absent",GameState.story_episode()==before_story and QuestManager.to_dict()==before_quests and GameState.portal_states==before_portals)
	GameState.time_running=true;GameState.set_control_lock(false);GameState.pop_modal("codex")
	await get_tree().process_frame
	print("STORY_LIFECYCLE failures=",failures)
	get_tree().quit(1 if failures else 0)
