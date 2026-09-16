extends Node
## Actual authored L1 ramps, physical keyboard and TouchController movement.
## Each case starts with an explicit setup teleport; the crossing itself is real physics.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const SIDES := [TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("terrain_live"):
		get_tree().quit(86)
		return
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func run() -> void:
	SaveManager.new_game()
	WorldContext.arrival_mode = ""
	var scene: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	for i in range(12): await get_tree().process_frame
	GameState.time_running = true
	var ground: MapLoader = scene.get_node("Ground")
	var player: Player = scene.get_node("YSortLayer/Player")
	var touch: TouchController = scene.get_node("TouchController")
	var false_walkable := 0
	for y in range(ground.height):
		for x in range(ground.width):
			if ground._layout[y][x]=="V" and touch._astar.has_point(touch._pid(Vector2i(x,y))): false_walkable += 1
	check("click graph excludes authored VOID physics walls",false_walkable==0,"bad_nodes=%d" % false_walkable)
	# These ramps meet progression gates, not free ground: preserve that contract.
	var interaction: InteractionController = scene.get_node("Interaction")
	for cell in ground.stepping_slot_cells:
		check("G1 water slot blocked before D14 %s" % cell,not ground.is_cell_walkable(cell))
	Inventory.add("D14",3)
	interaction.set_held_item("D14")
	for cell in ground.stepping_slot_cells:
		check("G1 real D14 placement %s" % cell,interaction._try_place_on_tile(cell))
	check("G1 consumes exactly three supplied stones",Inventory.count("D14")==0)
	interaction.set_held_item("")
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is BushDry:
			check("G2 dry gate initially closed",not node.is_bloomed())
			# Gate-state fixture through the actual bloom method; not claimed as a
			# gathered/crafted-water playthrough. Collider must really disappear.
			node.bloom()
			check("G2 bloom opens its collider",node.is_bloomed() and node._body==null)
	await frames(5)
	touch.refresh_grid()
	var tried := 0
	var available: Array[Vector2i] = []
	for ramp in ground.ramp_cells:
		var pairs: Array = []
		for side in SIDES:
			var nb := ground.get_neighbor_cell(ramp,side)
			print("LIVE_RAMP cell=%s nb=%s level=%d walkable=%s" % [ramp,nb,ground.height_at(nb),ground.is_cell_walkable(nb)])
			if ground.height_at(nb)>0 and ground.is_cell_walkable(nb):
				var opposite := ground.get_neighbor_cell(ramp,SIDES[(SIDES.find(side)+2)%4])
				if ground.is_cell_walkable(opposite) and ground.height_at(opposite)==0:
					pairs.append([opposite,nb])
		if pairs.is_empty():
			check("shore ramp remains water-gated %s" % ramp,ramp in [Vector2i(14,23),Vector2i(15,23)])
			continue
		available.append(ramp)
		var pair: Array = pairs[0]
		for reverse in [false,true]:
			var start: Vector2i = pair[1] if reverse else pair[0]
			var end: Vector2i = pair[0] if reverse else pair[1]
			var target := ground.map_to_local(end)
			for mode in ["tap","keyboard"]:
				player.release_move_and_path()
				player.position = ground.map_to_local(start)
				await frames(4)
				if mode=="tap":
					check("actual ramp tap route %s reverse%s" % [ramp,reverse],touch.move_to(end))
				else:
					var delta := target-player.position
					if absf(delta.x)>1: Input.action_press("move_right" if delta.x>0 else "move_left")
					if absf(delta.y)>1: Input.action_press("move_down" if delta.y>0 else "move_up")
				for i in range(100):
					await frames(1)
					if player.position.distance_to(target)<7: break
				player.release_move_and_path()
				check("actual ramp crossing %s %s reverse%s" % [ramp,mode,reverse],player.position.distance_to(target)<9,"position=%s target=%s cell=%s" % [player.position,target,ground.world_to_cell(player.position)])
				tried += 1
	var expected: Array[Vector2i] = [Vector2i(15,23),Vector2i(16,23),Vector2i(18,17)]
	available.sort()
	expected.sort()
	check("all gate-connected ramps exercised both ways and both controls",available==expected and tried==expected.size()*4,"crossings=%d available=%s" % [tried,available])
	# Long routes across the actual G1 bridge and G2 single-cell corridor, not a
	# caller-injected straight path and not merely AStar returning a nonempty list.
	for route in [[Vector2i(16,27),Vector2i(16,22)],[Vector2i(18,18),Vector2i(18,13)]]:
		player.release_move_and_path()
		player.position = ground.map_to_local(route[0])
		await frames(3)
		check("progression path resolves %s" % [route],touch.move_to(route[1]))
		var target := ground.map_to_local(route[1])
		for i in range(360):
			await frames(1)
			if player.position.distance_to(target)<7: break
		player.release_move_and_path()
		check("real progression path arrives %s" % [route],player.position.distance_to(target)<9,"position=%s target=%s" % [player.position,target])
	SaveManager.unregister_world()
	scene.queue_free()
	await get_tree().process_frame
	print("LIVE_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
