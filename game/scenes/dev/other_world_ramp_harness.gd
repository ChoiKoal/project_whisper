extends Node
## Local ramp traversal QA, not normal multi-world quest completion.
## Each route begins from a disclosed setup position next to an authored ramp.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
class BeforeDynamicCancel extends TouchController:
	func _cancel_obstructed_path() -> void:
		pass # Exact pre-10 behavior: graph refresh without route validation.
var failures := 0
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("other_world_ramps"):
		get_tree().quit(86); return
	for world in ["terminal_station","clockwork_city","mage_tower","cathedral"]:
		SaveManager.new_game()
		var scene: Node = load("res://scenes/world/"+world+".tscn").instantiate()
		if OS.get_environment("RAMP_PRE10_BASELINE") == "1":
			var original: Node = scene.get_node("TouchController")
			var wiring := {}
			for key in ["map_loader_path","player_path","interaction_path"]: wiring[key] = original.get(key)
			original.set_script(BeforeDynamicCancel)
			for key in wiring: original.set(key,wiring[key])
			print("PRE10_BASELINE_CANCEL_DISABLED ",world)
		add_child(scene)
		await frames(8)
		var ground: MapLoader = scene.get_node("Ground")
		var player: Player = scene.get_node("YSortLayer/Player")
		var touch: TouchController = scene.get_node("TouchController")
		var choice: Array[Vector2i] = []
		for ramp: Vector2i in ground.ramp_cells:
			if not touch._astar.has_point(touch._pid(ramp)): continue
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var n: Vector2i = ground.terrain_neighbor(ramp,d)
				if ground.height_at(n) > 0 and touch._astar.has_point(touch._pid(n)) and touch._astar.are_points_connected(touch._pid(ramp),touch._pid(n)):
					choice = [ramp,n]; break
			if not choice.is_empty(): break
		check(world+" authored ramp-to-raised graph edge exists",not choice.is_empty())
		if not choice.is_empty():
			player.global_position = touch._waypoint_world(choice[0])
			await frames(2)
			var accepted := touch.move_to(choice[1])
			for i in range(180):
				await get_tree().physics_frame
				if not player.is_pathing(): break
			var distance := player.global_position.distance_to(touch._waypoint_world(choice[1]))
			print("RAMP_OBSERVATION ",JSON.stringify({"world":world,"start":str(choice[0]),"end":str(choice[1]),"start_height":ground.height_at(choice[0]),"end_height":ground.height_at(choice[1]),"accepted":accepted,"end_distance":distance,"player":str(player.global_position),"pathing":player.is_pathing()}))
			check(world+" actual tap ramp traversal reaches raised waypoint",accepted and distance < 8)
		player.release_move_and_path()
		SaveManager.unregister_world(); scene.queue_free(); await frames(4)
	print("OTHER_WORLD_RAMPS failures=",failures)
	get_tree().quit(1 if failures else 0)
