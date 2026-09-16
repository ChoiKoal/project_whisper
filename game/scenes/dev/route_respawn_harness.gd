extends Node
## Isolated fixture: gather R, queue a real route through its free cell, then
## shorten only its respawn timer while the player is still approaching.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
var completions := 0
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func _ready() -> void: call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("route_respawn"):
		get_tree().quit(86); return
	SaveManager.new_game()
	var scene: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	await frames(8)
	var ground: MapLoader = scene.get_node("Ground")
	var player: Player = scene.get_node("YSortLayer/Player")
	var touch: TouchController = scene.get_node("TouchController")
	var respawn: ObjectRespawn = scene.get_node("ObjectRespawn")
	var cell := Vector2i(22,37)
	var entry: Dictionary = respawn.entry_for_cell(cell)
	var rock: Gatherable = entry.node
	rock.gather() # setup gather; no claim of normal acquisition here
	await frames(4)
	respawn.force_tick()
	var route: Array[Vector2i] = []
	for ay in range(34,40):
		for ax in range(19,26):
			var a := Vector2i(ax,ay)
			if not touch._astar.has_point(touch._pid(a)): continue
			if ground.cell_center_world(a).distance_to(ground.cell_center_world(cell)) < 200: continue
			for by in range(34,40):
				for bx in range(19,26):
					var b := Vector2i(bx,by)
					if b == cell or not touch._astar.has_point(touch._pid(b)): continue
					var ids := touch._astar.get_id_path(touch._pid(a),touch._pid(b))
					if ids.size() >= 4 and ids.has(touch._pid(cell)):
						route = [a,b]
						break
				if not route.is_empty(): break
			if not route.is_empty(): break
		if not route.is_empty(): break
	check("real free-cell graph provides a crossing route", not route.is_empty())
	if not route.is_empty():
		player.global_position = ground.cell_center_world(route[0]) # setup only
		await frames(2)
		check("crossing request accepted", touch.move_to(route[1]))
		player.path_finished.connect(func(): completions += 1)
		# Inject only the pending contract here, so cancellation must clear both
		# queued movement and its eventual auto-interaction without claiming arrival.
		touch._pending = {"kind":"cell", "cell":route[1]}
		await frames(2)
		check("player is approaching before respawn",player.is_pathing() and player.global_position.distance_to(ground.cell_center_world(cell)) > 150)
		entry.respawn_at = GameState.game_time
		respawn.force_tick()
		await frames(4)
		check("respawn removes cell from live graph", not touch._astar.has_point(touch._pid(cell)))
		check("invalid queued route is canceled instead of walking into respawn", not player.is_pathing() and touch._pending.is_empty())
		check("cancellation never reports arrival",completions == 0)
		var stopped := player.global_position
		await frames(8)
		check("canceled input remains stopped",not player.is_pathing() and player.global_position.distance_to(stopped) < 1)
		check("new user request replans around the respawn", touch.move_to(route[1]))
		var retained: Array[Vector2] = player._path.duplicate()
		touch._queue_grid_refresh()
		await frames(2)
		check("safe queued detour survives refresh",player.is_pathing() and not retained.is_empty())
		for i in range(480):
			await get_tree().physics_frame
			if not player.is_pathing(): break
		check("replanned route actually arrives without gathering rock",player.global_position.distance_to(ground.cell_center_world(route[1])) < 8 and is_instance_valid(entry.node))
	player.release_move_and_path()
	SaveManager.unregister_world()
	scene.queue_free()
	await frames(3)
	print("ROUTE_RESPAWN failures=",failures)
	get_tree().quit(1 if failures else 0)
