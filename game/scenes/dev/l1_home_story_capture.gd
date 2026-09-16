extends "res://scenes/dev/l1_gameplay_capture.gd"
## BEFORE is obtained before episode implementation. Same live walk/camera for AFTER.
func _capture(filename: String, phase: String) -> void:
	await super._capture(filename, phase)
	if phase != "l1_after_real_movement": return
	var grove := _tree.current_scene
	var ground: MapLoader = grove.get_node("Ground")
	var player: Player = grove.get_node("YSortLayer/Player")
	var touch: TouchController = grove.get_node("TouchController")
	var start := ground.world_to_cell(player.global_position)
	if not await walk(touch, player, ground, Vector2i(23,35)): return
	await _tree.create_timer(0.8,true,false,true).timeout
	await super._capture("normal-story-east.png", "story_east_actual_walk")
	var interaction: InteractionController=grove.get_node("Interaction")
	var story:=grove.get_node("GroveSession/L1HomeStory")
	# Fixture supplies raw materials only; recipes execute their real consume/discover transaction.
	Inventory.add("I2",2);Inventory.add("I4",1)
	if Fusion.fuse("I2","I2").output!="D09" or Fusion.fuse("D09","I4").output!="D10":
		_fail("root real R24/R25 transaction failed");return
	interaction.set_held_item("D10")
	await keyboard_place(ground.cell_center_world(Vector2i(23,35)))
	await _tree.create_timer(0.6,true,false,true).timeout
	if GameState.story_episode().active_outcome!="nest" or Inventory.count("D10")!=0:
		_fail("root keyboard did not place crafted nest");return
	print("[PASS] root keyboard consumed crafted nest and caused first local response")
	await super._capture("normal-story-nest-response.png","actual_keyboard_nest_response_fixture_materials")
	await _tree.create_timer(4.8,true,false,true).timeout
	await super._capture("normal-story-nest-settled.png","actual_keyboard_nest_persistent")
	if OS.get_environment("STORY_CAIRN_PROBE")!="1":
		# Keep the separately reproduced G1/cairn path blocker explicit, not a forced teleport.
		print("UNVERIFIED_CAIRN_WALK see final-root2 log; main root checks nest/Home handoff only")
		await walk(touch,player,ground,start)
		return
	# Disclosed G1 fixture: real placement transactions but supplied D14 and remote API calls.
	# The following route itself uses actual Player/TouchController physics, never L1 teleport.
	Inventory.add("D14",ground.stepping_slot_cells.size())
	for slot in ground.stepping_slot_cells:
		interaction.set_held_item("D14")
		if not interaction._try_place_on_tile(slot): _fail("G1 fixture stone rejected")
	interaction.set_held_item("")
	var cairn_cell:=ground.world_to_cell(story.cairn.global_position)
	var approach:=Vector2i(-1,-1)
	var origin:=ground.world_to_cell(player.global_position)
	for candidate in [cairn_cell,cairn_cell+Vector2i(1,0),cairn_cell+Vector2i(-1,0),cairn_cell+Vector2i(0,1),cairn_cell+Vector2i(0,-1)]:
		if touch._astar.has_point(touch._pid(candidate)) and not touch._astar.get_id_path(touch._pid(origin),touch._pid(candidate)).is_empty():
			approach=candidate;break
	if approach==Vector2i(-1,-1):
		_fail("no real G1-open path to live cairn "+str(cairn_cell));return
	if not await walk(touch,player,ground,approach): return
	await _tree.create_timer(0.8,true,false,true).timeout
	await keyboard_place(story.cairn.visual_target_point())
	await _tree.create_timer(0.4,true,false,true).timeout
	if not GameState.story_episode().cairn_seen.get("nest",false):
		_fail("actual keyboard cairn inspection failed");return
	print("[PASS] actual walk through fixture-opened G1 and keyboard cairn inspection")
	await super._capture("normal-story-cairn.png","actual_walk_cairn_after_disclosed_G1_fixture")
	await walk(touch, player, ground, start)
func _action(action_name: String) -> void:
	# Physics overlap can become true before HomeSession._process observes it.
	# Wait for the actual prompt target; never substitute its handler or force the portal state.
	if _tree.current_scene.name=="HomeIsland" and action_name=="interact":
		var home:=_tree.current_scene.get_node("HomeSession")
		var deadline:=Time.get_ticks_msec()+2000
		while home.get("_active_portal")==null and Time.get_ticks_msec()<deadline:
			await _tree.process_frame
		if home.get("_active_portal")==null:
			_fail("real Home entry prompt did not settle")
			return
	await super._action(action_name)
func keyboard_place(point: Vector2) -> void:
	var screen:=_tree.root.get_camera_2d().get_canvas_transform()*point
	_tree.root.warp_mouse(screen)
	var motion:=InputEventMouseMotion.new()
	motion.position=screen
	Input.parse_input_event(motion)
	await _frames(5)
	await _action("interact")

func _runtime_record(phase: String) -> Dictionary:
	var result:=super._runtime_record(phase)
	result["story_state"]=GameState.story_state.duplicate(true)
	result["test_shortcuts"]="Opening handler shortcut; Home portal apron setup teleport; raw I2/I4 fixture for real R24/R25; later clear fixture supplies D22 and HOLLOW at spawn, skips CS04. NOT full Q1-Q9 playthrough. Real root input/scene travel, no L1 teleport."
	result["cairn_probe_enabled"]=OS.get_environment("STORY_CAIRN_PROBE")=="1"
	result["cairn_probe_shortcut"]="Only if enabled: supplied D14 and remote placement API open G1 before attempted real cairn walk. Current path blocker remains."
	return result

func _finish() -> void:
	if _failed:
		super._finish();return
	# Real Home portal return above saved the placed nest. Reenter to exercise snapshot restoration.
	var home:=_tree.current_scene
	var player: Player=home.get_node("YSortLayer/Player")
	var nature: Portal
	for node in _tree.get_nodes_in_group("gatherable"):
		if node is Portal and node.layer=="nature" and home.is_ancestor_of(node): nature=node
	if nature==null:
		_fail("Home nature missing for revisit");super._finish();return
	player.global_position=nature.entry_stand_point()
	await _physics_frames(6)
	await _action("interact")
	if not await _wait_scene_seconds("StartingGrove",10.0):
		_fail("story revisit scene missing");super._finish();return
	await _tree.create_timer(1.0,true,false,true).timeout
	var grove:=_tree.current_scene
	var story:=grove.get_node("GroveSession/L1HomeStory")
	if story.response_count!=0 or GameState.story_episode().active_outcome!="nest":
		_fail("revisit repeated/lost outcome");super._finish();return
	print("[PASS] actual portal revisit reconstructs saved nest without response replay")
	# Disclosed dependency shortcut: test the clear/Home handoff, not all main quest gates.
	var ground: MapLoader=grove.get_node("Ground")
	var interaction: InteractionController=grove.get_node("Interaction")
	player=grove.get_node("YSortLayer/Player")
	var cell:=ground.world_to_cell(player.global_position)
	ground.set_cell(cell,11,Vector2i.ZERO)
	Inventory.add("D22",1);interaction.set_held_item("D22")
	if not interaction._try_place_on_tile(cell):
		_fail("clear fixture placement failed");super._finish();return
	await _tree.create_timer(0.3,true,false,true).timeout
	await _action("ui_cancel")
	if not await _wait_scene_seconds("HomeIsland",10.0):
		_fail("CS04 skip failed real auto-return");super._finish();return
	# Scene identity precedes deferred Home setup. Wait on completion, not a timer that can
	# elapse during expensive first-frame map construction before the timeline even starts.
	var ignition_deadline:=Time.get_ticks_msec()+30000
	while SaveManager.pending_return_ignition and Time.get_ticks_msec()<ignition_deadline:
		await _tree.process_frame
	home=_tree.current_scene
	if not SaveManager.cleared or SaveManager.pending_return_ignition or QuestManager.active_id!="P2" or GameState.control_locked():
		_fail("CS05 handoff/pending/P2/lock failed");super._finish();return
	var traces:=home.find_children("L1H01ReturnTrace","",true,false)
	if traces.size()!=1:
		_fail("Home trace not exactly one");super._finish();return
	print("[PASS] actual CS04 skip -> Home -> full CS05 -> single nest trace/P2/unlocked")
	await super._capture("normal-home-story-returned.png","actual_clear_handoff_with_disclosed_D22_fixture")
	# Real touch walking to the nature door improves trace inspection without changing camera zoom.
	player=home.get_node("YSortLayer/Player")
	ground=home.get_node("Ground")
	for node in _tree.get_nodes_in_group("gatherable"):
		if node is Portal and node.layer=="nature" and home.is_ancestor_of(node): nature=node
	if await walk(home.get_node("TouchController"),player,ground,ground.world_to_cell(nature.entry_stand_point())):
		await _tree.create_timer(0.8,true,false,true).timeout
		await super._capture("normal-home-nest-trace.png","home_trace_after_actual_walk")
	super._finish()

func walk(touch: TouchController, player: Player, ground: MapLoader, cell: Vector2i) -> bool:
	if not touch.move_to(cell):
		_fail("story path rejected %s" % cell)
		return false
	var target := ground.to_global(ground.map_to_local(cell))
	var deadline := Time.get_ticks_msec()+16000
	while player.global_position.distance_to(target)>7 and Time.get_ticks_msec()<deadline:
		await _physics_frames(1)
	player.release_move_and_path()
	if player.global_position.distance_to(target)>9:
		_fail("story actual walk blocked %s actual=%s" % [cell, player.global_position])
		return false
	print("[PASS] story actual walk ", cell)
	return true
