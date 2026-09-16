extends "res://scenes/dev/l1_gameplay_capture.gd"
## Real normal root, no L1 setup teleport. Test-shortened respawn deadline is disclosed.
func _capture(filename: String,phase: String) -> void:
	await super._capture(filename,phase)
	if phase!="l1_after_real_movement": return
	var world:=_tree.current_scene
	var ground: MapLoader=world.get_node("Ground")
	var player: Player=world.get_node("YSortLayer/Player")
	var touch: TouchController=world.get_node("TouchController")
	var respawn: ObjectRespawn=world.get_node("ObjectRespawn")
	var origin_cell:=ground.world_to_cell(player.global_position)
	var rock_cell:=Vector2i(22,37)
	var entry: Dictionary=respawn.entry_for_cell(rock_cell)
	var rock:=entry.node as Gatherable
	var stand:=touch._nearest_walkable_adjacent(rock_cell)
	if stand==Vector2i(-1,-1) or not await walk(touch,player,ground,stand): return
	await _tree.create_timer(0.6,true,false,true).timeout
	await super._capture("normal-rock-approach.png","boulder_after_actual_walk_from_spawn")
	var root:=rock.target_point()
	var direction: Vector2=(root-player.global_position).normalized()
	var ax: String="move_right" if direction.x>=0 else "move_left"
	var ay: String="move_down" if direction.y>=0 else "move_up"
	Input.action_press(ax,absf(direction.x));Input.action_press(ay,absf(direction.y)*2)
	await _physics_frames(45)
	Input.action_release(ax);Input.action_release(ay)
	player.release_move_and_path()
	var separation:=player.global_position.distance_to(root)
	print("ROOT_ROCK_KEYBOARD separation=",separation," expected=44 cell=",rock_cell)
	if separation<42 or separation>47:
		_fail("root keyboard footprint mismatch "+str(separation));return
	print("[PASS] normal-root actual keyboard stops at boulder foot")
	await _tree.create_timer(0.6,true,false,true).timeout
	await super._capture("normal-rock-blocked.png","actual_keyboard_blocked_by_boulder")
	var before:=Inventory.count("I6")
	touch.handle_tap(rock.visual_target_point())
	await _physics_frames(5)
	if Inventory.count("I6")!=before+1 or is_instance_valid(rock):
		_fail("actual root rock tap gather failed");return
	print("[PASS] normal-root tap gathers boulder and yields I6")
	if not await walk(touch,player,ground,rock_cell): return
	await super._capture("normal-rock-gathered-through.png","actual_walk_through_freed_rock_cell")
	if not await walk(touch,player,ground,stand): return
	entry.respawn_at=GameState.game_time
	respawn.force_tick();await _physics_frames(5)
	rock=entry.node as Gatherable
	if rock==null or not rock.blocks_movement or touch._astar.has_point(touch._pid(rock_cell)):
		_fail("root respawn collision/path missing");return
	print("[PASS] root respawn restores collider and automatic path blocker; deadline fixture")
	await super._capture("normal-rock-respawned.png","actual_respawn_with_disclosed_due_time_fixture")
	await walk(touch,player,ground,origin_cell)
func _action(action_name: String) -> void:
	if _tree.current_scene.name=="HomeIsland" and action_name=="interact":
		var session:=_tree.current_scene.get_node("HomeSession")
		var deadline:=Time.get_ticks_msec()+2000
		while session.get("_active_portal")==null and Time.get_ticks_msec()<deadline: await _tree.process_frame
	await super._action(action_name)
func walk(touch: TouchController,player: Player,ground: MapLoader,cell: Vector2i) -> bool:
	if not touch.move_to(cell):
		_fail("rock path rejected "+str(cell));return false
	var target:=ground.cell_center_world(cell)
	var deadline:=Time.get_ticks_msec()+20000
	while player.global_position.distance_to(target)>7 and Time.get_ticks_msec()<deadline: await _physics_frames(1)
	player.release_move_and_path()
	if player.global_position.distance_to(target)>9:
		_fail("rock path physically blocked target=%s actual=%s" % [cell,player.global_position]);return false
	print("[PASS] root rock actual walk ",cell)
	return true
func _runtime_record(phase: String) -> Dictionary:
	var record:=super._runtime_record(phase)
	record["rock_provenance"]="Normal title/new-game; Opening handler shortcut; Home apron setup teleport inherited. NO L1 teleport. Real walk to authored R(22,37), keyboard block, tap gather, walk through, deadline-shortened ObjectRespawn, return. Not all gates completion."
	return record
