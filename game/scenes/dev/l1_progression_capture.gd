extends "res://scenes/dev/l1_gameplay_capture.gd"
## Normal-root progression automation: NO teleports, inventory injection, direct
## quest advance, gate flags, time jumps or planted/clear signals. Opening uses its
## real skip handler; Fusion UI callbacks are driven after physically reaching pot.
var ground: MapLoader
var player: Player
var touch: TouchController
var interaction: InteractionController
var gathered_tiles: Array[Vector2i] = []
func require(ok: bool, label: String) -> bool:
	if ok: print("[PASS] ",label)
	else: _fail(label)
	return ok
func bind_world() -> void:
	var world := _tree.current_scene
	ground = world.get_node("Ground")
	player = world.get_node("YSortLayer/Player")
	touch = world.get_node("TouchController")
	interaction = world.get_node("Interaction")
func _run() -> void:
	if not await play():
		_failed = true
		await _capture("failure.png","failure_not_completion")
	_finish()
func play() -> bool:
	_tree.root.focus_exited.connect(func(): print("ROOT_FOCUS_EXIT at=",Time.get_ticks_msec()))
	_tree.root.focus_entered.connect(func(): print("ROOT_FOCUS_ENTER at=",Time.get_ticks_msec()))
	GameState.control_lock_changed.connect(func(value): print("CONTROL_TRANSITION ",value," at=",Time.get_ticks_msec()))
	SaveManager.delete_save();SaveManager.new_game()
	_tree.change_scene_to_file(TITLE)
	if not await _wait_scene_seconds("Title",5): return require(false,"title boot")
	await _tree.create_timer(1.5).timeout
	await _click_control(_find_button(_tree.current_scene,"새로 시작"))
	if not await _wait_scene_seconds("Opening",5): return require(false,"new game opening")
	if OS.get_environment("FDN_LAYOUT_REVISION")=="l1-v2":
		if not require(SaveManager.new_game_for_layout("l1-v2"),"explicit staged v2 new run before Home/Grove instantiation"):return false
	var skip := InputEventAction.new();skip.action="ui_cancel";skip.pressed=true
	_tree.current_scene.call("_unhandled_input",skip)
	if not await _wait_scene_seconds("HomeIsland",10): return require(false,"new game Home")
	await _tree.create_timer(5).timeout
	bind_world()
	if not await enter_nature(): return false
	await _tree.create_timer(3.8).timeout
	bind_world()
	if not require(QuestManager.active_id=="Q1","normal Home walk/portal starts Q1"): return false
	await _capture("01-l1-arrival.png","normal_title_home_walk_nature_arrival")
	# Every unit comes from an actual reachable object or a locally gathered tile.
	for pair in [["I2",2],["I4",2],["I6",6],["I8",3]]:
		if ground.layout_revision=="l1-v2" and pair[0]=="I2":
			if not await gather_tiles("I2",pair[1]):return false
		elif not await gather_objects(pair[0],pair[1]): return false
	if not await gather_tiles("I1",5): return false
	if not await gather_tiles("I7",2): return false
	if not require(QuestManager.active_id=="Q2","gathering naturally advances Q1"): return false
	var pot := find_object("cauldron")
	if not await tap_object(pot): return false
	if not require(GameState.ui_modal_open(),"reachable cauldron opens actual Fusion UI"): return false
	if not await craft("I2","I2","D09"): return false
	if not await craft("D09","I4","D10"): return false
	for i in range(3):
		if not await craft("I6","I8","D61"): return false
		if not await craft("I1","I6","D52"): return false
		if not await craft("D61","D52","D14"): return false
	if not await craft("I1","I4","D04"): return false
	_tree.current_scene.get_node("FusionUI").close()
	await _frames(3)
	if not require(QuestManager.active_id=="Q3","real Fusion UI transactions advance Q2"): return false
	var experiment:Vector2i=ground.anchor_cells("experiment_cells",[Vector2i(23,34),Vector2i(23,35),Vector2i(24,35)])[1]
	if not await walk(experiment): return false
	interaction.set_held_item("D10")
	await point_interact(ground.cell_center_world(experiment))
	interaction.set_held_item("")
	if not require(GameState.story_episode().active_outcome=="nest","gathered/crafted nest placement triggers episode"): return false
	await _capture("02-nest-response.png","normal_materials_nest_response")
	# Approach each G1 slot in southern-to-northern order; no remote placement.
	for index in range(ground.stepping_slot_cells.size()-1,-1,-1):
		var slot: Vector2i = ground.stepping_slot_cells[index]
		var stand := touch._nearest_walkable_adjacent(slot)
		if not await walk(stand): return false
		interaction.set_held_item("D14")
		await point_interact(ground.cell_center_world(slot))
		if not require(ground.get_cell_source_id(slot)==1,"crafted G1 stone placed from actual approach "+str(slot)): return false
	interaction.set_held_item("")
	if not require(QuestManager.active_id=="Q4","three real G1 placements advance Q3"): return false
	var story := _tree.current_scene.get_node("GroveSession/L1HomeStory")
	if not await walk(ground.world_to_cell(story.cairn.global_position)): return false
	await point_interact(story.cairn.visual_target_point())
	if not require(GameState.story_episode().cairn_seen.get("nest",false),"normal G1 crossing and ramp climb reaches cairn inspection"): return false
	await _capture("03-cairn-normal.png","normal_gather_craft_G1_cairn")
	# The lower terrace has a substantial tree on its eastern exit. Harvesting
	# this real obstacle opens the route onward; no graph/body disabling shortcut.
	if ground.layout_revision=="l1-v1":
		var respawn: ObjectRespawn = _tree.current_scene.get_node("ObjectRespawn")
		var frontier: Node = respawn.entry_for_cell(Vector2i(20,22)).node
		var wood_before := Inventory.count("I4")
		if not await tap_object(frontier): return false
		if not require(Inventory.count("I4")==wood_before+1,"real terrace tree harvest opens G2 approach"): return false
	# Water the real dry bush after walking to its accessible southern neighbour.
	var bush := find_object("bush_dry")
	interaction.set_held_item("I7")
	if not await tap_object(bush): return false
	interaction.set_held_item("")
	if not require(bush.is_bloomed() and QuestManager.active_id=="Q5","actual water use opens G2 and advances Q4"): return false
	await _capture("04-g2-bloomed.png","normal_water_use_G2")
	# Rest is a real gameplay action. It skips to evening, then the game clock
	# must naturally reach night; the harness never sets time or speed.
	if not await tap_object(find_object("rest_stump")): return false
	var night_deadline := Time.get_ticks_msec()+150000
	while QuestManager.active_id=="Q5" and Time.get_ticks_msec()<night_deadline:
		await _tree.create_timer(0.5).timeout
	if not require(QuestManager.active_id=="Q6","rest and natural night transition advance Q5"): return false
	var tree := find_object("world_tree")
	# Use a clear outer approach within normal interaction reach, not the graph's
	# closest cell under the large trunk (whose collision appears during CS-03).
	var near_tree := Vector2i(-1,-1)
	var route_length := 99999
	for pid in touch._astar.get_point_ids():
		var candidate := Vector2i(touch._astar.get_point_position(pid))
		var point := touch._waypoint_world(candidate)
		var distance: float = point.distance_to(tree.target_point())
		if distance < 80 or distance > 120: continue
		var arrival_center: Vector2 = _tree.current_scene.get_node("QuestAreaWatcher")._center
		if point.distance_to(arrival_center) > 130: continue
		var probe := player.global_transform;probe.origin=point
		if player.test_move(probe,Vector2.ZERO,null,0.08,true): continue
		var size := touch._path_ids_from_player(candidate).size()
		if size>0 and size<route_length: near_tree=candidate;route_length=size
	print("WORLD_TREE_APPROACH ",near_tree," root=",tree.target_point())
	if not await walk(near_tree): return false
	var encounter_deadline := Time.get_ticks_msec()+12000
	while GameState.control_locked() and Time.get_ticks_msec()<encounter_deadline: await _frames(1)
	if not require(QuestManager.active_id=="Q7","actual night passage and world-tree approach advance Q6"): return false
	if not await tap_object(tree): return false
	if not require(Inventory.count("I9")==1 and QuestManager.active_id=="Q8","real unique world-tree gather advances Q7"): return false
	await _capture("05-world-tree-gathered.png","normal_G3_I9_gather")
	if not await tap_object(find_object("cauldron")): return false
	if not await craft("I9","I7","D19"): return false
	if not await craft("D19","D04","D20"): return false
	if not await craft("D20","I1","D22"): return false
	_tree.current_scene.get_node("FusionUI").close();await _frames(3)
	if not require(QuestManager.active_id=="Q9","real I9-D19-D20-D22 chain advances Q8"): return false
	var hollow := gathered_tiles[0]
	if not await walk(hollow): return false
	interaction.set_held_item("D22")
	# Hollow has no ground-gather hover. Use the supported tap placement entrypoint
	# from the player's physically reached hollow, not a remote effect call.
	touch.handle_tap(ground.cell_center_world(hollow))
	await _frames(4)
	if not require(Inventory.count("D22")==0 and QuestManager.is_done("Q9"),"actual hollow tap consumes crafted D22 and completes Q9"): return false
	if not await _wait_scene_seconds("HomeIsland",35): return require(false,"normal planted hollow clear returns Home")
	var ignition_deadline := Time.get_ticks_msec()+30000
	while SaveManager.pending_return_ignition and Time.get_ticks_msec()<ignition_deadline: await _frames(1)
	if not require(SaveManager.cleared and QuestManager.active_id=="P2" and not GameState.control_locked(),"normal CS04/CS05 completion reaches Home P2 unlocked"): return false
	await _capture("06-home-natural-clear.png","normal_full_quest_clear_Home")
	if not require(_tree.current_scene.find_children("L1H01ReturnTrace","",true,false).size()==1,"normal clear produces exactly one Home trace"): return false
	bind_world()
	if not await enter_nature(): return false
	await _tree.create_timer(1).timeout;bind_world()
	if not await walk(experiment): return false
	story = _tree.current_scene.get_node("GroveSession/L1HomeStory")
	if not require(story.response_count==0 and GameState.story_episode().active_outcome=="nest" and SaveManager.cleared,"normal revisit restores nest without replaying response/clear"): return false
	await point_interact(story.perch.visual_target_point())
	await _capture("07-revisit.png","normal_saved_revisit")
	return true
func enter_nature() -> bool:
	var nature: Portal
	for node in _tree.get_nodes_in_group("gatherable"):
		if node is Portal and node.layer=="nature" and _tree.current_scene.is_ancestor_of(node): nature=node
	if not require(nature!=null,"nature portal exists"): return false
	if not await walk(ground.world_to_cell(nature.entry_stand_point())): return false
	await _frames(6)
	if not require(nature.is_player_in_entry_zone(),"actual Home walk reaches nature entry apron"): return false
	await _action("interact")
	return require(await _wait_scene_seconds("StartingGrove",12),"real nature interaction travels to L1")
func walk(cell: Vector2i) -> bool:
	if not require(touch.move_to(cell),"path accepted "+str(cell)): return false
	var target := touch._waypoint_world(cell)
	var deadline := Time.get_ticks_msec()+24000
	while player.global_position.distance_to(target)>8 and Time.get_ticks_msec()<deadline:
		await _physics_frames(1)
		if GameState.control_locked():
			# CS-03 intentionally cancels navigation on first tree approach. Wait
			# for the owned lock to end, then issue a NEW user movement request.
			while GameState.control_locked() and Time.get_ticks_msec()<deadline: await _physics_frames(1)
			if not GameState.control_locked():
				print("NORMAL_INPUT_REISSUE_AFTER_CUTSCENE ",cell)
				if not touch.move_to(cell): break
	player.release_move_and_path()
	return require(player.global_position.distance_to(target)<9,"actual walk arrives "+str(cell)+" actual="+str(player.global_position))
func find_object(id: String) -> Node:
	for node in _tree.get_nodes_in_group("gatherable"):
		if _tree.current_scene.is_ancestor_of(node) and ((node is RestStump and id=="rest_stump") or node.get("object_id")==id): return node
	return null
func tap_object(node: Node) -> bool:
	if not require(is_instance_valid(node),"interaction target exists"): return false
	var target: Vector2 = node.target_point()
	var pick: Vector2 = node.visual_target_point() if node.has_method("visual_target_point") else target
	print("TAP_REQUEST ",JSON.stringify({"target":str(node),"point":str(target),"pick":str(pick),"picked":str(touch._object_near(pick)),"stand":str(touch._nearest_walkable_adjacent(ground.world_to_cell(target)))}))
	touch.handle_tap(pick)
	print("TAP_QUEUED ",player._path," pending=",touch._pending)
	var deadline := Time.get_ticks_msec()+45000
	var retries := 0
	while Time.get_ticks_msec()<deadline:
		while player.is_pathing() and Time.get_ticks_msec()<deadline: await _physics_frames(1)
		await _frames(4)
		var observed_lock := touch._world_locked()
		if observed_lock and player.global_position.distance_to(target)>151:
			print("ROUTE_INTERRUPTION ",JSON.stringify({"cinematic":GameState._cinematic_keys,"modal":GameState._modal_keys,"legacy":GameState._control_locked,"target":str(target)}))
			await _handle_route_interruption(deadline)
			if touch._world_locked(): break
		if player.global_position.distance_to(target)<=151: break
		if player.is_pathing() or retries>=2: break
		if touch._pending.is_empty() and not observed_lock: break
		# A witnessed modal/cinematic owns cancellation. Read/wait via normal
		# input, then issue a NEW request; never revive private canceled state.
		retries += 1
		print("INPUT_INTERRUPTED_NEW_TAP ",JSON.stringify({"position":str(player.global_position),"pending":str(touch._pending),"target":str(target),"retry":retries}))
		while touch._world_locked() and Time.get_ticks_msec()<deadline: await _frames(1)
		touch.handle_tap(pick)
	print("TAP_END ",JSON.stringify({"target":str(target),"actual":str(player.global_position),"pathing":player.is_pathing(),"distance":player.global_position.distance_to(target),"pending":str(touch._pending),"locked":touch._world_locked()}))
	return require(not player.is_pathing() and player.global_position.distance_to(target)<=151,"actual tap approaches/interacts at "+str(target))
func _handle_route_interruption(deadline: int) -> void:
	while touch._world_locked() and Time.get_ticks_msec()<deadline: await _frames(1)
func gather_objects(item: String,count: int) -> bool:
	while Inventory.count(item)<count:
		var best: Node
		var best_len := 99999
		for node in _tree.get_nodes_in_group("gatherable"):
			if not node is Gatherable or node.item_id!=item or not node.can_gather() or node.is_queued_for_deletion(): continue
			var stand := touch._nearest_walkable_adjacent(ground.world_to_cell(node.target_point()))
			if stand==Vector2i(-1,-1): continue
			var size := touch._path_ids_from_player(stand).size()
			if size>0 and size<best_len: best=node;best_len=size
		if not require(best!=null,"reachable source for "+item): return false
		var before := Inventory.count(item)
		if not await tap_object(best): return false
		if not require(Inventory.count(item)>before,"actual object gather yields "+item): return false
	return true
func gather_tiles(item: String,count: int) -> bool:
	while Inventory.count(item)<count:
		var best := Vector2i(-1,-1)
		var best_stand := best
		var best_len := 99999
		for cell in ground.get_used_cells():
			if cell in ground.stepping_slot_cells: continue
			var data := ground.get_cell_tile_data(cell)
			if data==null or not ground.can_gather_cell(cell) or str(data.get_custom_data("item_id"))!=item: continue
			if touch._object_near(ground.cell_center_world(cell)) != null: continue
			var stand := touch._nearest_walkable_adjacent(cell)
			if stand==Vector2i(-1,-1): continue
			# Direct-E prioritizes any adjacent world object over a ground gather.
			# Pick a genuinely clear work spot rather than asserting the wrong target.
			var clear_spot := true
			for object in _tree.get_nodes_in_group("gatherable"):
				if object.is_queued_for_deletion() or not object.has_method("target_point"): continue
				var occupied := ground.world_to_cell(object.target_point())
				if absi(occupied.x-stand.x)<=1 and absi(occupied.y-stand.y)<=1: clear_spot=false;break
			if not clear_spot: continue
			var size := touch._path_ids_from_player(stand).size()
			if size>0 and size<best_len: best=cell;best_stand=stand;best_len=size
		if not require(best!=Vector2i(-1,-1),"reachable tile for "+item): return false
		if not await walk(best_stand): return false
		var before := Inventory.count(item)
		await point_interact(ground.cell_center_world(best))
		if not require(Inventory.count(item)==before+1,"actual local keyboard tile gather "+item+str(best)): return false
		gathered_tiles.append(best)
	return true
func point_interact(point: Vector2) -> void:
	# Camera smoothing must settle before projecting a stationary mouse click.
	await _tree.create_timer(0.65).timeout
	var screen := _tree.root.get_camera_2d().get_canvas_transform()*point
	_tree.root.warp_mouse(screen)
	var motion := InputEventMouseMotion.new();motion.position=screen
	Input.parse_input_event(motion);await _frames(5)
	print("INPUT_PROBE ", JSON.stringify({"wanted":str(ground.world_to_cell(point)),"screen":str(screen),"mouse":str(_tree.root.get_mouse_position()),"player_cell":str(ground.world_to_cell(player.global_position)),"hover_cell":str(interaction._hover_cell),"has_hover":interaction._has_hover_cell,"hover_object":str(interaction._hover_object),"target_cell":str(interaction._target_cell),"target_object":str(interaction._target_object),"lock":touch._world_locked()}))
	await _action("interact");await _frames(4)
func craft(a: String,b: String,output: String) -> bool:
	var ui := _tree.current_scene.get_node("FusionUI")
	if not require(GameState.ui_modal_open(),"Fusion modal open for "+output): return false
	var before := Inventory.count(output)
	ui._clear_inputs();ui._on_strip_pressed(a);ui._on_strip_pressed(b);ui._on_fuse_pressed()
	var deadline := Time.get_ticks_msec()+4000
	while ui._animating and Time.get_ticks_msec()<deadline: await _frames(1)
	return require(Inventory.count(output)==before+1,"Fusion UI consumes gathered materials: "+a+"+"+b+"->"+output)
func _finish() -> void:
	var manifest := {"capture_kind":"normal_root_automated_progression_no_inventory_or_clear_injection", "expected_viewport":[TARGET_SIZE.x,TARGET_SIZE.y], "records":_records, "failed":_failed, "scope":"Nest branch; H0 and other authored/generic branches remain separate. Automatic input, not human/manual QA; no item/quest/gate/clear/time injection. Fusion UI callbacks and public TouchController requests are automation seams."}
	var path := _out_dir.path_join("normal-l1-runtime-state.json")
	var encoded := JSON.stringify(manifest,"\t")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		_failed = true
	else:
		file.store_string(encoded)
		if file.get_error()!=OK: _failed=true
		file.close()
		if FileAccess.get_file_as_string(path)!=encoded: _failed=true
	print("NORMAL_PROGRESSION_DONE failed=",_failed," manifest=",path)
	_tree.quit(1 if _failed else 0)
func _runtime_record(phase: String) -> Dictionary:
	var result := super._runtime_record(phase)
	result["capture_kind"]="normal_root_automated_progression_no_inventory_or_clear_injection"
	result["test_state_injection"]="Only Opening real skip handler called directly. No teleports, ingredient/recipe injection, quest/clear signals or time edits. Real TouchController movement/tap, keyboard gather/place; Fusion UI callbacks after physical cauldron arrival. Automated input, not human/manual QA."
	result["quest"] = QuestManager.active_id
	result["story_state"] = GameState.story_state.duplicate(true)
	result["game_time"] = GameState.game_time
	result["day_phase"] = GameState.phase()
	var gates:Array=[]
	for node in _tree.get_nodes_in_group("night_gate"):
		if not _tree.current_scene.is_ancestor_of(node):continue
		var gate:=node as NightGate
		var sprite:=gate._sprite
		var rect:=sprite.get_rect()
		var screen_rect:=Rect2(sprite.get_global_transform_with_canvas()*rect.position,rect.size*sprite.global_scale)
		gates.append({"node":str(gate.get_path()),"cell":str(ground.world_to_cell(gate.global_position)),"root":str(gate.global_position),"open":gate.is_open(),"texture":sprite.texture.resource_path,"offset":str(sprite.offset),"scale":str(sprite.global_scale),"screen_rect":str(screen_rect),"body_layer":gate._body.collision_layer,"shape_disabled":gate._body.get_child(0).disabled})
	result["night_gate_bindings"] = gates
	return result
