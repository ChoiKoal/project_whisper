extends Node
## Synthetic spawn/ingredients; actual tap, lock APIs and subsequent public path execution.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func frames(n:int)->void:
	for i in range(n):await get_tree().physics_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not GUARD.require_isolated_user_data("pending_lock_safety"):
		get_tree().quit(86);return
	for mode in ["cinematic","legacy_control","time_pause","same_frame_time","nested_cinematic"]:
		SaveManager.new_game_for_layout("l1-v2")
		var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
		await frames(12)
		var ground:MapLoader=scene.get_node("Ground")
		var player:Player=scene.get_node("YSortLayer/Player")
		var ic:InteractionController=scene.get_node("Interaction")
		var touch:TouchController=scene.get_node("TouchController")
		player.global_position=ground.cell_center_world(Vector2i(23,35));await frames(4)
		Inventory.add("D10",1);ic.set_held_item("D10")
		var target:=Vector2i(-1,-1)
		for cell in ground.get_used_cells():
			if not ic.prefers_held_ground(cell):continue
			var distance:=ground.cell_center_world(cell).distance_to(player.global_position)
			if distance<300 or distance>500:continue
			if touch._path_ids_from_player(cell).size()>4:target=cell;break
		check(mode+" reachable placement fixture",target!=Vector2i(-1,-1))
		if target==Vector2i(-1,-1):get_tree().quit(2);return
		touch.handle_tap(ground.cell_center_world(target))
		check(mode+" actual tap queued",player.is_pathing() and not touch._pending.is_empty())
		match mode:
			"cinematic","nested_cinematic":GameState.begin_cinematic("pending-test")
			"legacy_control":GameState.set_control_lock(true)
			_:GameState.time_running=false
		check(mode+" lock synchronously clears pending and movement",touch._pending.is_empty() and not player.is_pathing())
		if mode!="same_frame_time":await frames(3)
		if mode=="nested_cinematic":GameState.begin_cinematic("other-owner")
		match mode:
			"cinematic","nested_cinematic":GameState.end_cinematic("pending-test")
			"legacy_control":GameState.set_control_lock(false)
			_:GameState.time_running=true
		if mode=="nested_cinematic":
			check("own cancel preserves foreign cinematic lease",GameState.control_locked() and not GameState.time_running)
			GameState.end_cinematic("other-owner")
		check(mode+" unlock cannot resurrect pending",touch._pending.is_empty() and not player.is_pathing())
		# Public Player route completion after cancel must not execute the old request.
		var stand:=touch._nearest_walkable_adjacent(target)
		check(mode+" fresh route accepted",touch._path_to_cell(stand))
		var deadline:=Time.get_ticks_msec()+12000
		while player.is_pathing() and Time.get_ticks_msec()<deadline:await frames(1)
		check(mode+" fresh route completed",not player.is_pathing())
		check(mode+" no stale action on later arrival",ic._placed_object_at(target)==null and Inventory.count("D10")==1)
		SaveManager.unregister_world();scene.queue_free();await frames(4)
	print("PENDING_LOCK_SAFETY_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
