extends Node
## Synthetic timing diagnostic. A deliberate main-thread stall models missed render frames.
## No production state bypass: held selection and mouse input remain public APIs.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
var receipts:Array=[]
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func _ready()->void:call_deferred("run")
func physics(n:int)->void:
	for i in range(n):await get_tree().physics_frame
func receipt(ic:InteractionController,target:Vector2i,start:int,phase:String)->Dictionary:
	return {"phase":phase,"process_frames_since_select":Engine.get_process_frames()-start,"held":ic.get_held_item(),"count":Inventory.count("D10"),"valid":ic.prefers_held_ground(target),"pointed":str(ic._tilemap.local_to_map(ic._tilemap.to_local(get_viewport().get_camera_2d().get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()))),"hover":str(ic._hover_cell),"hover_placement":ic._hover_placement,"ghost":ic._ghost.is_active(),"touch":ic._touch_mode,"modal":GameState.ui_modal_open()}
func run()->void:
	if not GUARD.require_isolated_user_data("hover_timing_probe"):
		get_tree().quit(86);return
	SaveManager.new_game_for_layout("l1-v2")
	var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
	await physics(12)
	var ground:MapLoader=scene.get_node("Ground")
	var player:Player=scene.get_node("YSortLayer/Player")
	var ic:InteractionController=scene.get_node("Interaction")
	player.global_position=ground.cell_center_world(Vector2i(23,35))
	await get_tree().create_timer(1.5).timeout
	Inventory.add("D10",1)
	var target:=Vector2i(20,31)
	for stall in [0,140,220]:
		ic.set_held_item("")
		var screen:=get_viewport().get_camera_2d().get_canvas_transform()*ground.cell_center_world(target)
		get_viewport().warp_mouse(screen)
		var motion:=InputEventMouseMotion.new();motion.position=screen;Input.parse_input_event(motion)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		ic.set_held_item("D10")
		var start:=Engine.get_process_frames()
		if stall:OS.delay_msec(stall)
		await physics(5)
		var early:=receipt(ic,target,start,"physics5_stall"+str(stall));receipts.append(early);print("HOVER_TIMING ",JSON.stringify(early))
		check("diagnostic selection/stock/pointed target intact "+str(stall),early.valid and early.held=="D10" and early.pointed==str(target) and not early.touch and not early.modal)
		# Wait for actual presentation processing, not for the desired outcome.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var late:=receipt(ic,target,start,"rendered_stall"+str(stall));receipts.append(late);print("HOVER_TIMING ",JSON.stringify(late))
		check("rendered far ghost matches unchanged click destination "+str(stall),ic._ghost.is_active() and ic._ghost.global_position.distance_to(ground.cell_center_world(target))<1)
	var file:=FileAccess.open(OS.get_environment("FDN_EVIDENCE")+"/timing.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipts,"\t"));file.close()
	SaveManager.unregister_world();scene.queue_free();await physics(4)
	print("HOVER_TIMING_DONE failures=",failures)
	get_tree().quit(1 if failures else 0)
