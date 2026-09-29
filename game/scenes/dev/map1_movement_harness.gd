extends "res://scenes/dev/l1_gameplay_capture.gd"
## Focused MAP1-v2 physical/input fixtures. Initial positions, day/night and I7
## are injected ONLY for diagnostic cases; normal quest routes are separate.
var ground: MapLoader
var player: Player
var touch: TouchController
var interaction: InteractionController
var failures:=0
var movements:Array=[]
var post_draw_state:Dictionary={}
var contact_active:=false
var drawn_contact_errors:=0
var drawn_contact_samples:=0
func capture_contact_timing()->void:
	if not is_instance_valid(player) or not is_instance_valid(ground):return
	var expected:Vector2=player._base_anim_position+Vector2(0,ground.visual_height_offset(player.global_position))
	post_draw_state={"expected":str(expected),"actual":str(player._anim.position),"position":str(player.global_position),"error":player._anim.position.distance_to(expected)}
	if contact_active:
		drawn_contact_samples+=1
		if post_draw_state.error>0.1:drawn_contact_errors+=1
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func bind_world()->void:
	ground=_tree.current_scene.get_node("Ground")
	player=_tree.current_scene.get_node("YSortLayer/Player")
	touch=_tree.current_scene.get_node("TouchController")
	interaction=_tree.current_scene.get_node("Interaction")
func _runtime_record(phase:String)->Dictionary:
	var r:=super._runtime_record(phase)
	r["capture_kind"]="diagnostic actual-root input/physics after explicit starting fixtures"
	r["test_state_injection"]="new v2 direct scene, endpoint positions, phase time and I7 water only; continuous motion uses Input actions or public Touch.move_to; no movement teleports"
	r["layout_revision"]="l1-v2"
	r["game_time"]=GameState.game_time
	return r
func wait_lock()->void:
	var deadline:=Time.get_ticks_msec()+18000
	while GameState.control_locked() and Time.get_ticks_msec()<deadline:await _physics_frames(1)
	check("owned cinematic finishes without unlock override",not GameState.control_locked())
func reset_at(pos:Vector2)->void:
	player.release_move_and_path()
	for action in Player.MOVE_ACTIONS:Input.action_release(action)
	player.global_position=pos
	player.get_node("Camera2D").reset_smoothing()
	await _physics_frames(5)
func cross(label:String,start:Vector2,target:Vector2,mode:String,passage:bool,visit:Vector2i=Vector2i(-1,-1))->void:
	await wait_lock()
	await reset_at(start)
	drawn_contact_errors=0;drawn_contact_samples=0;contact_active=true
	var accepted:=true
	if mode=="tap":accepted=touch.move_to(ground.world_to_cell(target))
	if mode=="tap":
		# Gates use physical blockers; the existing graph admits a request that
		# stops at them. Raw V must be rejected, open routes must be admitted.
		check(label+" path admission contract",accepted if passage else (not accepted if ground._sym_at(ground.world_to_cell(target))=="V" else true))
		var legal:=true
		for point:Vector2 in player._path:legal=legal and ground._sym_at(ground.world_to_cell(point))!="V"
		check(label+" queued waypoints never cross V",legal)
	var trail:Array=[];var void_hits:=0;var visit_hit:=false;var contact_errors:=0
	var deadline:=Time.get_ticks_msec()+4500
	var frame:=0;var interruption:=false
	while Time.get_ticks_msec()<deadline:
		if GameState.control_locked():
			interruption=true
			await wait_lock()
			deadline=Time.get_ticks_msec()+4500
			if mode=="tap" and passage:touch.move_to(ground.world_to_cell(target))
		if mode=="keyboard":
			var delta:=target-player.global_position
			for action in Player.MOVE_ACTIONS:Input.action_release(action)
			if absf(delta.x)>2.5:Input.action_press("move_right" if delta.x>0 else "move_left")
			if absf(delta.y)>2.5:Input.action_press("move_down" if delta.y>0 else "move_up")
		await _physics_frames(1)
		var cell:=ground.world_to_cell(player.global_position)
		if ground._sym_at(cell)=="V":void_hits+=1
		visit_hit=visit_hit or cell==visit
		trail.append({"position":[player.global_position.x,player.global_position.y],"cell":[cell.x,cell.y],"height":ground.visual_height_offset(player.global_position)})
		if frame in [6,20,40]:
			await _capture(label+"-%02d.png"%frame,"movement_"+label)
			# The timing receipt proved the coroutine resumes after a NEW physics
			# tick. Compare root and sprite within the SAME frame_post_draw event.
		frame+=1
		if player.global_position.distance_to(target)<8:break
		if not passage and frame>=65:break
	player.release_move_and_path()
	contact_active=false
	contact_errors=drawn_contact_errors
	for action in Player.MOVE_ACTIONS:Input.action_release(action)
	var arrived:=player.global_position.distance_to(target)<10
	check(label+" actual "+("passage" if passage else "blocked"),arrived==passage)
	check(label+" never crosses authored V",void_hits==0)
	check(label+" rendered foot projection retained",drawn_contact_samples>0 and contact_errors==0)
	if visit!=Vector2i(-1,-1) and passage:check(label+" visits intended cell "+str(visit),visit_hit)
	var row:={"label":label,"mode":mode,"expected_passage":passage,"accepted":accepted,"start":[start.x,start.y],"target":[target.x,target.y],"end":[player.global_position.x,player.global_position.y],"arrived":arrived,"void_hits":void_hits,"visit":str(visit),"visited":visit_hit,"contact_errors":contact_errors,"cinematic_interruption":interruption,"trail":trail}
	row["drawn_contact_samples"]=drawn_contact_samples
	movements.append(row)
	print("MAP1_MOVE ",JSON.stringify({"label":label,"end":row.end,"arrived":arrived,"void_hits":void_hits,"contact_errors":contact_errors}))
func _run()->void:
	SaveManager.new_game_for_layout("l1-v2")
	_tree.change_scene_to_file("res://scenes/world/starting_grove.tscn")
	if not await _wait_scene_seconds("StartingGrove",10):check("scene ready",false);finish_moves();return
	await _tree.create_timer(4).timeout
	bind_world()
	RenderingServer.frame_post_draw.connect(capture_contact_timing)
	# Do not pause game time: time_running=false is an intentional input lock.
	# Phase fixtures jump once; time and input run normally during each crossing.
	var gates:Array=[];var bush:BushDry
	for node in _tree.get_nodes_in_group("night_gate"):
		if _tree.current_scene.is_ancestor_of(node):gates.append(node)
	for node in _tree.get_nodes_in_group("gatherable"):
		if node is BushDry and _tree.current_scene.is_ancestor_of(node):bush=node
	check("two NightGates and bush",gates.size()==2 and bush!=null)
	for is_open in [false,true]:
		GameState.set_game_time(GameState.DAY_LENGTH*(0.8 if is_open else 0.3))
		await _physics_frames(4);touch.refresh_grid()
		for i in range(gates.size()):
			var gate:NightGate=gates[i]
			var cell:Vector2i=ground.night_gate_cells[i]
			var logical:=ground.cell_center_world(cell)
			check("NightGate fixture uses authored cell, not lifted art root",absf(gate.global_position.x-logical.x)<0.1)
			for mode in ["keyboard","tap"]:
				var tag:="night-%d-%s-%s"%[i,"open" if is_open else "closed",mode]
				await cross(tag,logical+Vector2(0,64),logical-Vector2(0,64),mode,is_open,cell)
				if is_open:await cross(tag+"-reverse",logical-Vector2(0,64),logical+Vector2(0,64),mode,true,cell)
	GameState.set_game_time(GameState.DAY_LENGTH*0.3);await _physics_frames(4)
	var root:=bush.global_position
	for mode in ["keyboard","tap"]:await cross("bush-closed-"+mode,root+Vector2(0,64),root-Vector2(0,64),mode,false)
	await reset_at(root+Vector2(0,64))
	Inventory.add("I7",1);interaction.set_held_item("I7")
	touch.handle_tap(bush.visual_target_point())
	var deadline:=Time.get_ticks_msec()+5000
	while not bush.is_bloomed() and Time.get_ticks_msec()<deadline:await _physics_frames(1)
	interaction.set_held_item("")
	check("real water tap consumes injected fixture water and blooms bush",bush.is_bloomed() and Inventory.count("I7")==0)
	touch.refresh_grid()
	for mode in ["keyboard","tap"]:
		await cross("bush-open-"+mode,root+Vector2(0,64),root-Vector2(0,64),mode,true,ground.world_to_cell(root))
		await cross("bush-open-"+mode+"-reverse",root-Vector2(0,64),root+Vector2(0,64),mode,true,ground.world_to_cell(root))
	for cell in [Vector2i(19,8),Vector2i(19,14),Vector2i(15,14),Vector2i(33,14)]:
		for mode in ["keyboard","tap"]:
			var target:=ground.cell_center_world(cell)
			await cross("void-%d-%d-%s"%[cell.x,cell.y,mode],target+Vector2(0,80),target,mode,false)
	# First and last cells of the v2 ascent. Real endpoint steering, both modes/directions.
	for ramp in [Vector2i(19,16),Vector2i(22,22)]:
		var pair:Array[Vector2i]=[]
		for d in [Vector2i(1,0),Vector2i(0,1)]:
			var a:=ground.terrain_neighbor(ramp,d);var b:=ground.terrain_neighbor(ramp,-d)
			if ground.can_traverse(a,ramp) and ground.can_traverse(ramp,b) and ground.is_cell_walkable(a) and ground.is_cell_walkable(b):
				pair.assign([a,b]);break
		check("two traversable ramp-end neighbors %s"%ramp,pair.size()==2)
		if pair.size()!=2:continue
		for reverse in [false,true]:
			for mode in ["keyboard","tap"]:
				await cross("ramp-%d-%d-%s-%s"%[ramp.x,ramp.y,reverse,mode],ground.cell_center_world(pair[1] if reverse else pair[0]),ground.cell_center_world(pair[0] if reverse else pair[1]),mode,true,ramp)
	var count:=ground.get_node("InternalTrenches").get_child_count()
	var colliders:=ground.ledge_collider_count
	var position_saved:=player.global_position
	check("isolated save succeeds",SaveManager.save_game())
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	for i in range(2):
		ground._build_elevation();await _physics_frames(3)
		check("rebuild one bank set and same ledges %d"%i,ground.get_node("InternalTrenches").get_child_count()==count and ground.ledge_collider_count==colliders)
	SaveManager.unregister_world();SaveManager.pending_load=true
	_tree.reload_current_scene()
	await _tree.create_timer(2).timeout;bind_world()
	check("saved reentry retains logical position",player.global_position.distance_to(position_saved)<0.1)
	check("saved reentry has exactly one bank set",ground.get_node("InternalTrenches").get_child_count()==count and _tree.current_scene.find_children("InternalTrenches","",true,false).size()==1)
	check("saved reentry resave",SaveManager.save_game())
	var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	for key in ["objects","placed_objects","void_cells","stepping_stones","gates","layout_revision"]:
		check("saved state unchanged "+key,JSON.stringify(saved.worlds.grove[key])==JSON.stringify(after.worlds.grove[key]))
	finish_moves()
func finish_moves()->void:
	var data:={"kind":"injected starting fixtures, real continuous keyboard/tap physics; not normal progression","failures":failures,"movements":movements,"captures":_records}
	var file:=FileAccess.open(_out_dir.path_join("movement-receipt.json"),FileAccess.WRITE)
	if file==null:failures+=1
	else:file.store_string(JSON.stringify(data,"\t"));file.close()
	print("MAP1_MOVEMENT_DONE failures=",failures)
	_tree.quit(1 if failures or _failed else 0)
