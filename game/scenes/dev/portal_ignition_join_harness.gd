extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
var joined:=0
var finish_count:=0
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func _ready() -> void: call_deferred("run")
func join_ignition(portal: PortalCutscene) -> void:
	await portal.play_return_ignition()
	joined+=1
func run() -> void:
	if not GUARD.require_isolated_user_data("portal_ignition_join"):
		get_tree().quit(86);return
	for skip_early in [true, false]:
		SaveManager.new_game()
		var portal:=PortalCutscene.new();add_child(portal)
		joined=0;finish_count=0
		portal.finished.connect(func():finish_count+=1)
		join_ignition(portal)
		join_ignition(portal)
		await get_tree().process_frame
		check("both concurrent ignition callers wait before completion skip=%s" % skip_early,joined==0)
		check("one active cinematic lease",GameState.control_locked() and not GameState.time_running)
		if skip_early:
			portal.skip();portal.skip()
		else:
			await get_tree().create_timer(8.0).timeout
		check("both callers resume exactly once skip=%s" % skip_early,joined==2)
		check("finalizer completes once skip=%s" % skip_early,finish_count==1 and not portal.is_active())
		check("all callers observe committed portals and quest",GameState.portal_state("nature")=="open" and GameState.portal_state("science")=="flickering" and QuestManager.active_id=="P2")
		check("own time/input lease released",GameState.time_running and not GameState.control_locked())
		join_ignition(portal)
		check("completed ignition is immediately idempotent",joined==3 and finish_count==1)
		portal.queue_free();await get_tree().process_frame
	print("IGNITION_JOIN failures=",failures)
	get_tree().quit(1 if failures else 0)
