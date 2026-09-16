extends Node
## Synthetic isolated input/lifecycle fixtures, not normal acquisition/progression.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func frames(n:int)->void:
	for i in range(n):await get_tree().physics_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not GUARD.require_isolated_user_data("held_boundaries"):
		get_tree().quit(86);return
	for mode in ["preview","changed","spent","occupied","modal","success"]:
		SaveManager.new_game_for_layout("l1-v2")
		var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
		await frames(12)
		var ground:MapLoader=scene.get_node("Ground")
		var player:Player=scene.get_node("YSortLayer/Player")
		var ic:InteractionController=scene.get_node("Interaction")
		var touch:TouchController=scene.get_node("TouchController")
		player.global_position=ground.cell_center_world(Vector2i(23,35))
		await get_tree().create_timer(1.5).timeout
		Inventory.add("D10",1);ic.set_held_item("D10")
		var target:=Vector2i(-1,-1)
		for cell in ground.get_used_cells():
			if not ic.prefers_held_ground(cell):continue
			var distance:=ground.cell_center_world(cell).distance_to(player.global_position)
			if distance<300 or distance>500:continue
			var route:=touch._path_ids_from_player(cell)
			if route.size()>4:target=cell;break
		check(mode+" reachable far placement fixture",target!=Vector2i(-1,-1))
		if target==Vector2i(-1,-1):get_tree().quit(2);return
		print("BOUNDARY mode=",mode," target=",target)
		if mode=="preview":
			var screen:=get_viewport().get_camera_2d().get_canvas_transform()*ground.cell_center_world(target)
			get_viewport().warp_mouse(screen)
			var motion:=InputEventMouseMotion.new();motion.position=screen;Input.parse_input_event(motion)
			await frames(5)
			print("PREVIEW_RECEIPT ",JSON.stringify({"requested_screen":str(screen),"actual_mouse":str(get_viewport().get_mouse_position()),"hover":str(ic._hover_cell),"hover_placement":ic._hover_placement,"ghost":str(ic._ghost.global_position),"active":ic._ghost.is_active(),"wanted":str(ground.cell_center_world(target)),"player":str(player.global_position),"held":ic.get_held_item(),"count":Inventory.count("D10"),"touch_mode":ic._touch_mode,"has_hover":ic._has_hover_cell,"hover_object":str(ic._hover_object),"valid_now":ic.prefers_held_ground(target),"pointed_now":str(ground.world_to_cell(get_viewport().get_camera_2d().get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()))}))
			check("far decor ghost matches explicit click destination",ic._ghost.is_active() and ic._ghost.global_position.distance_to(ground.cell_center_world(target))<1)
			var event:=InputEventAction.new();event.action="interact";event.pressed=true
			get_viewport().push_input(event,true);await frames(1)
			event.pressed=false;get_viewport().push_input(event,true);await frames(3)
			check("far hover never grants remote E placement",ic._placed_object_at(target)==null)
		else:
			touch.handle_tap(ground.cell_center_world(target))
			check(mode+" real tap queues movement",player.is_pathing() and not touch._pending.is_empty())
			var source_before:=ground.get_cell_source_id(target)
			var stone_before:=Inventory.count("I2")
			var added:Gatherable
			match mode:
				"changed":Inventory.add("D04",1);ic.set_held_item("D04")
				"spent":Inventory.remove("D10",1)
				"occupied":
					added=Gatherable.new();added.item_id="I2"
					scene.get_node("YSortLayer").add_child(added)
					added.global_position=ground.cell_center_world(target)
				"modal":GameState.push_modal("held-boundary")
			var deadline:=Time.get_ticks_msec()+12000
			while player.is_pathing() and Time.get_ticks_msec()<deadline:await frames(1)
			await frames(5)
			if mode=="modal":GameState.pop_modal("held-boundary");await frames(3)
			if mode=="success":
				check("far unchanged tap places exactly once",ic._placed_object_at(target)!=null and Inventory.count("D10")==0)
			else:
				check(mode+" stale placement is canceled without substitute/gather",ic._placed_object_at(target)==null and ground.get_cell_source_id(target)==source_before)
				check(mode+" no unintended item consumption",Inventory.count("D10")== (0 if mode=="spent" else 1))
				if mode=="changed":check("new selection is not consumed by old tap",Inventory.count("D04")==1)
				if mode=="occupied":check("arrival does not harvest new occupant",is_instance_valid(added) and not added.is_queued_for_deletion() and Inventory.count("I2")==stone_before)
		SaveManager.unregister_world();scene.queue_free();await frames(4)
	get_tree().quit(1 if failures else 0)
