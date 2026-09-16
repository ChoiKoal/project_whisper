extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("story_reachability_probe"):
		get_tree().quit(86);return
	SaveManager.new_game();WorldContext.arrival_mode=""
	var scene: Node=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
	for i in range(12): await get_tree().process_frame
	var ground: MapLoader=scene.get_node("Ground")
	var touch: TouchController=scene.get_node("TouchController")
	var interaction: InteractionController=scene.get_node("Interaction")
	Inventory.add("D14",ground.stepping_slot_cells.size())
	for cell in ground.stepping_slot_cells:
		interaction.set_held_item("D14");interaction._try_place_on_tile(cell)
	interaction.set_held_item("")
	var before:=reachable(touch)
	var story:=scene.get_node("GroveSession/L1HomeStory")
	story.perch.free();story.cairn.free();story.free()
	touch.refresh_grid()
	var without:=reachable(touch)
	print("REACHABILITY_COUNTERFACTUAL ",JSON.stringify({"with_episode":before,"without_episode":without,"g1_sources":ground.stepping_slot_cells.map(func(c):return ground.get_cell_source_id(c)),"interpretation":"NO CLAIM of G1/cairn completion; equal results isolate unchanged map graph from new story nodes"}))
	print("[PASS] episode removal does not change observed path result" if before==without else "[FAIL] episode nodes changed graph")
	SaveManager.unregister_world();scene.queue_free();await get_tree().process_frame
	get_tree().quit(0 if before==without else 1)
func reachable(touch: TouchController) -> Array:
	var out: Array=[]
	for c in [Vector2i(19,20),Vector2i(18,20),Vector2i(20,20),Vector2i(19,19),Vector2i(19,21)]:
		out.append({"cell":[c.x,c.y],"point":touch._astar.has_point(touch._pid(c)),"path":not touch._astar.get_id_path(touch._pid(Vector2i(23,35)),touch._pid(c)).is_empty() if touch._astar.has_point(touch._pid(c)) else false})
	return out
