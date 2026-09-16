extends Node
## Counterfactual topology diagnosis on isolated runtime state only.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok: failures += 1
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("cairn_route"):
		get_tree().quit(86);return
	SaveManager.new_game()
	var scene: Node = load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene)
	for i in range(8): await get_tree().physics_frame
	var ground: MapLoader = scene.get_node("Ground")
	var touch: TouchController = scene.get_node("TouchController")
	var interaction: InteractionController = scene.get_node("Interaction")
	Inventory.add("D14",ground.stepping_slot_cells.size()) # disclosed gate fixture
	for c in ground.stepping_slot_cells:
		interaction.set_held_item("D14"); interaction._try_place_on_tile(c)
	interaction.set_held_item("")
	for i in range(3): await get_tree().physics_frame
	var start := ground.spawn_cell
	var target := Vector2i(19,20)
	var actual := reachable(ground,touch,start,false,false)
	var ignore_objects := reachable(ground,touch,start,false,true)
	var ignore_heights := reachable(ground,touch,start,true,false)
	var ignore_both := reachable(ground,touch,start,true,true)
	var observations := {}
	for label in ["actual","ignore_objects","ignore_heights","ignore_both"]:
		var set: Dictionary = {"actual":actual,"ignore_objects":ignore_objects,"ignore_heights":ignore_heights,"ignore_both":ignore_both}[label]
		var nearest := INF
		for c: Vector2i in set:
			nearest = minf(nearest, ground.cell_center_world(c).distance_to(ground.cell_center_world(target)))
		observations[label] = {"cells":set.size(),"cairn":set.has(target),"nearest_distance":nearest,"bridge_north":set.has(Vector2i(16,23)),"lower_hill":set.has(Vector2i(16,22))}
	print("CAIRN_DIAGNOSIS ", JSON.stringify(observations))
	print("RAMPS ",ground.ramp_cells," CAIRN_HEIGHT ",ground.height_at(target))
	check("G1-open actual route reaches cairn", actual.has(target))
	check("G1-open actual route reaches lower hill",actual.has(Vector2i(16,22)))
	var player: Player = scene.get_node("YSortLayer/Player")
	# Actual normal spawn-to-cairn motion after the disclosed gate-only setup.
	var accepted := touch.move_to(target)
	for i in range(900):
		await get_tree().physics_frame
		if not player.is_pathing(): break
	check("real Player reaches cairn after G1 fixture",accepted and player.global_position.distance_to(ground.cell_center_world(target))<9)
	# Solid authored tree on the narrow lower terrace is a gatherable obstruction,
	# not an extra terrain gate. Remove it through real tap approach, not a flag.
	var respawn: ObjectRespawn = scene.get_node("ObjectRespawn")
	var frontier: Gatherable = respawn.entry_for_cell(Vector2i(20,22)).node
	var wood_before := Inventory.count("I4")
	touch.handle_tap(frontier.visual_target_point())
	for i in range(600):
		await get_tree().physics_frame
		if not is_instance_valid(frontier): break
	check("actual tap harvest clears terrace tree frontier",not is_instance_valid(frontier) and Inventory.count("I4")==wood_before+1)
	var bush: Vector2i = ground.bush_cell
	var adjacent := touch._nearest_walkable_adjacent(bush)
	var detail := []
	for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		var n := ground.terrain_neighbor(bush,d)
		detail.append({"cell":str(n),"height":ground.height_at(n),"ramp":ground.is_ramp(n),"walk":ground.is_cell_walkable(n),"path_size":touch._path_ids_from_player(n).size()})
	print("BUSH_APPROACH_DIAG ",JSON.stringify({"bush":str(bush),"stand":str(adjacent),"neighbours":detail}))
	check("cairn route can approach G2 bush",adjacent!=Vector2i(-1,-1))
	SaveManager.unregister_world();scene.queue_free();await get_tree().process_frame
	print("CAIRN_ROUTE failures=",failures)
	get_tree().quit(1 if failures else 0)
func reachable(ground: MapLoader,touch: TouchController,start: Vector2i,ignore_height: bool,ignore_objects: bool) -> Dictionary:
	var visited := {start:true}
	var queue: Array[Vector2i] = [start]
	var blocked := {} if ignore_objects else touch._blocking_object_cells()
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n: Vector2i = ground.terrain_neighbor(cell,d)
			if visited.has(n) or not touch._region.has_point(n) or not ground.is_cell_walkable(n) or blocked.has(n): continue
			if not ignore_height and not ground.can_traverse(cell,n): continue
			visited[n]=true;queue.append(n)
	return visited
