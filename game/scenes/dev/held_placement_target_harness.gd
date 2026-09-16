extends Node
## Focused input fixture, NOT normal progression: isolated v2, setup position and D10.
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label:String,ok:bool)->void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok:failures+=1
func frames(count:int)->void:
	for i in range(count):await get_tree().process_frame
func _ready()->void:call_deferred("run")
func run()->void:
	if not GUARD.require_isolated_user_data("held_placement"):
		get_tree().quit(86);return
	for scenario in [["D10","keyboard",Vector2i(23,35),Vector2i(23,35)],["D10","tap",Vector2i(23,35),Vector2i(23,35)],["D14","keyboard",Vector2i(22,30),Vector2i(22,31)],["D14","tap",Vector2i(22,30),Vector2i(22,31)]]:
		var item:String=scenario[0]
		var mode:String=scenario[1]
		var label:=item+" "+mode
		SaveManager.new_game_for_layout("l1-v2")
		var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate()
		add_child(scene)
		await frames(20)
		var ground:MapLoader=scene.get_node("Ground")
		var player:Player=scene.get_node("YSortLayer/Player")
		var interaction:InteractionController=scene.get_node("Interaction")
		var touch:TouchController=scene.get_node("TouchController")
		var cell:Vector2i=scenario[2]
		player.global_position=ground.cell_center_world(scenario[3])
		player.release_move_and_path()
		await get_tree().create_timer(1.5).timeout
		Inventory.add(item,1)
		interaction.set_held_item(item)
		var before_stone:=Inventory.count("I2")
		var picked:Node=touch._object_near(ground.cell_center_world(cell))
		print("PICK_FIXTURE scenario=",label," cell=",cell," held=",interaction.get_held_item()," inventory=",Inventory.count(item)," valid=",interaction.can_place_on_cell(cell,item)," picked=",picked," point=",picked.target_point() if picked!=null else Vector2.INF)
		check(label+" fixture valid unoccupied target",interaction.can_place_on_cell(cell,item) and interaction._placed_object_at(cell)==null)
		if mode=="keyboard":
			var screen:=get_viewport().get_camera_2d().get_canvas_transform()*ground.cell_center_world(cell)
			get_viewport().warp_mouse(screen)
			var motion:=InputEventMouseMotion.new();motion.position=screen
			Input.parse_input_event(motion)
			await frames(6)
			print("KEYBOARD_RESOLVED hover=",interaction._hover_object," tile=",interaction._hover_cell," has_tile=",interaction._has_hover_cell," target=",interaction._target_object)
			if item=="D14":
				check("functional placement highlight matches K not gather glow",interaction._highlight.is_active() and interaction._highlight.global_position.distance_to(ground.cell_center_world(cell))<1)
			var event:=InputEventAction.new();event.action="interact";event.pressed=true
			get_viewport().push_input(event,true)
			await frames(1)
			event.pressed=false;get_viewport().push_input(event,true)
		else:touch.handle_tap(ground.cell_center_world(cell))
		var deadline:=Time.get_ticks_msec()+5000
		while player.is_pathing() and Time.get_ticks_msec()<deadline:await frames(1)
		await frames(8)
		check(label+" explicit placement consumes exactly one item",Inventory.count(item)==0)
		check(label+" placement does not gather neighboring rock",Inventory.count("I2")==before_stone)
		if item=="D10":
			check(label+" real placement triggers optional nest episode",GameState.story_episode().active_outcome=="nest" and interaction._placed_object_at(cell)!=null)
		else:
			check(label+" actual protected G1 slot becomes walkable",ground.get_cell_source_id(cell)==1)
		SaveManager.unregister_world();scene.queue_free();await frames(4)
	get_tree().quit(1 if failures else 0)
