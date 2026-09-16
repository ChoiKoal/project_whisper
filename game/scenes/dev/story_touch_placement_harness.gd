extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
func check(label: String,ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("story_touch"):
		get_tree().quit(86);return
	SaveManager.new_game()
	var scene: Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
	for i in range(16): await get_tree().process_frame
	var ground: MapLoader=scene.get_node("Ground")
	var player: Player=scene.get_node("YSortLayer/Player")
	var interaction: InteractionController=scene.get_node("Interaction")
	var touch: TouchController=scene.get_node("TouchController")
	var cell:=Vector2i(23,35)
	player.global_position=ground.cell_center_world(cell)
	for i in range(3): await get_tree().physics_frame
	Inventory.add("I2",2);Inventory.add("I4",1)
	check("real raw-material nest recipe chain",Fusion.fuse("I2","I2").output=="D09" and Fusion.fuse("D09","I4").output=="D10")
	interaction.set_held_item("D10")
	check("expanded decor target actionable by touch",touch._cell_is_actionable(cell))
	touch.handle_tap(ground.cell_center_world(cell))
	for i in range(5): await get_tree().physics_frame
	check("touch alone consumes crafted nest and causes response",Inventory.count("D10")==0 and GameState.story_episode().active_outcome=="nest" and interaction._placed_object_at(cell)!=null)
	SaveManager.unregister_world();scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
