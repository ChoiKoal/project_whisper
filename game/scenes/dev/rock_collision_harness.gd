extends Node
## Focused RED/GREEN harness for semantic L1 rock collision.
## Run only with an isolated HOME/WHISPER_TEST_HOME; this harness mutates only
## isolated autoload state and never writes the production project or a real save.

const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const GROVE := "res://scenes/world/starting_grove.tscn"
const ROCK_ITEM := "I6"
const STONE_ITEM := "I8"
const ROCK_RADIUS := 24.0
const PLAYER_RADIUS := 20.0

class Fixture extends MapLoader:
	func _ready() -> void:
		pass

var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if ok else "FAIL", label,
		("  (%s)" % detail) if detail != "" else ""])
	if not ok:
		failures += 1


func _ready() -> void:
	if not GUARD.require_isolated_user_data("rock_collision"):
		get_tree().quit(86)
		return
	call_deferred("run")


func frames(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame


func run() -> void:
	print("=== ROCK COLLISION RED/GREEN HARNESS ===")
	Inventory.clear()
	GameState.time_running = true
	SaveManager.pending_load = false
	var packed := load(GROVE) as PackedScene
	var world := packed.instantiate()
	add_child(world)
	await frames(6)

	var loader := world.get_node("Ground") as MapLoader
	var player := world.get_node("YSortLayer/Player") as Player
	var touch := world.get_node("TouchController") as TouchController
	var respawn := world.get_node("ObjectRespawn") as ObjectRespawn
	touch.refresh_grid()

	_test_catalog_and_metadata(loader, respawn)
	_test_initial_nodes_and_height_contract(loader, touch, respawn)
	await _test_walk_approach_gather_respawn(loader, player, touch, respawn)

	world.queue_free()
	await frames(3)
	await _test_exact_physics_at_all_heights()

	print("ROCK_COLLISION_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func _test_catalog_and_metadata(loader: MapLoader, respawn: ObjectRespawn) -> void:
	check("L1 gatherable catalog remains 165 entries",
		loader.object_spawns.size() == 165 and respawn._tracked.size() == 165,
		"spawns=%d tracked=%d" % [loader.object_spawns.size(), respawn._tracked.size()])
	var objects: Dictionary = loader._legend.get("objects", {})
	var rock_spec: Dictionary = objects.get("R", {})
	var stone_spec: Dictionary = objects.get("s", {})
	var tree_spec: Dictionary = objects.get("T", {})
	check("R metadata explicitly means substantial blocking footprint",
		bool(rock_spec.get("blocks", false))
			and is_equal_approx(float(rock_spec.get("block_radius", -1.0)), ROCK_RADIUS))
	check("s metadata explicitly remains walkover",
		stone_spec.has("blocks") and not bool(stone_spec.get("blocks", true)))
	check("tree metadata preserves the existing blocking contract",
		bool(tree_spec.get("blocks", false))
			and is_equal_approx(float(tree_spec.get("block_radius", -1.0)), 20.0))
	check("item/catalog identity is unchanged",
		String(rock_spec.get("gatherable", {}).get("item_id", "")) == ROCK_ITEM
			and String(stone_spec.get("gatherable", {}).get("item_id", "")) == STONE_ITEM)


func _test_initial_nodes_and_height_contract(
		loader: MapLoader, touch: TouchController, respawn: ObjectRespawn) -> void:
	var rock_levels := {}
	var rock_count := 0
	var stone_count := 0
	for raw_entry in respawn._tracked:
		var entry: Dictionary = raw_entry
		var node := entry.get("node", null) as Gatherable
		if node == null or not is_instance_valid(node):
			continue
		var cell: Vector2i = entry["cell"]
		if entry["symbol"] == "R":
			rock_count += 1
			rock_levels[loader.height_at(cell)] = true
			check("initial R is blocking at %s" % cell, node.blocks_movement)
			check("initial R radius matches metadata at %s" % cell,
				is_equal_approx(_radius(node), ROCK_RADIUS), str(_radius(node)))
			check("initial R owns one centred circular footprint at %s" % cell,
				_has_circle(node, ROCK_RADIUS)
					and _body_global_position(node).is_equal_approx(loader.cell_center_world(cell)))
			check("R logical root and projected foot agree at height %d" % loader.height_at(cell),
				node.target_point().is_equal_approx(loader.cell_center_world(cell))
					and node.visual_target_point().is_equal_approx(
						loader.cell_center_world(cell) + Vector2(0, loader.height_offset(cell))))
			check("AStar omits initial blocking R cell %s" % cell,
				not touch._astar.has_point(touch._pid(cell)))
		elif entry["symbol"] == "s":
			stone_count += 1
			check("initial s remains nonblocking at %s" % cell,
				not node.blocks_movement and not _has_static_body(node))
			check("AStar retains walkover s cell %s" % cell,
				touch._astar.has_point(touch._pid(cell)))
	check("authored/scattered R and s sources still exist", rock_count > 0 and stone_count > 0,
		"R=%d s=%d" % [rock_count, stone_count])
	check("real R fixtures cover logical heights 0/1/2",
		rock_levels.has(0) and rock_levels.has(1) and rock_levels.has(2), str(rock_levels))


func _test_walk_approach_gather_respawn(
		loader: MapLoader, player: Player, touch: TouchController,
		respawn: ObjectRespawn) -> void:
	var choice := _choose_reachable_rock(loader, touch, respawn)
	check("found a path-reachable R with an adjacent stand cell", not choice.is_empty())
	if choice.is_empty():
		return
	var entry: Dictionary = choice["entry"]
	var rock := entry["node"] as Gatherable
	var rock_cell: Vector2i = entry["cell"]
	var start: Vector2i = choice["start"]
	player.release_move_and_path()
	player.global_position = loader.cell_center_world(start)
	await frames(2)
	var before := Inventory.count(ROCK_ITEM)
	touch.handle_tap(rock.visual_target_point())
	check("tap approach queues an object interaction", touch._pending.get("kind", "") == "object")
	var queued_avoids_rock := true
	for waypoint in player._path:
		if loader.world_to_cell(waypoint) == rock_cell:
			queued_avoids_rock = false
	check("tap/AStar route approaches without entering R cell", queued_avoids_rock)
	for _i in range(900):
		await get_tree().physics_frame
		if not is_instance_valid(rock) or rock.is_queued_for_deletion():
			break
	check("approach reaches and gathers R through the real interaction path",
		Inventory.count(ROCK_ITEM) == before + 1
			and (not is_instance_valid(rock) or rock.is_queued_for_deletion()))
	await frames(3)
	respawn.force_tick()
	await frames(2)
	check("gather removes physics obstacle and restores R cell to AStar",
		touch._astar.has_point(touch._pid(rock_cell)) and not _static_body_at(loader, rock_cell))

	entry["respawn_at"] = GameState.game_time
	respawn.force_tick()
	await frames(3)
	var rebuilt := entry.get("node", null) as Gatherable
	check("ObjectRespawn rebuilt the same R semantic",
		rebuilt != null and is_instance_valid(rebuilt)
			and rebuilt.blocks_movement
			and is_equal_approx(_radius(rebuilt), ROCK_RADIUS)
			and _has_circle(rebuilt, ROCK_RADIUS))
	check("respawn restores physics and removes R cell from AStar",
		rebuilt != null and _static_body_at(loader, rock_cell)
			and not touch._astar.has_point(touch._pid(rock_cell)))
	if rebuilt != null:
		check("respawn preserves logical/projected height contract",
			rebuilt.target_point().is_equal_approx(loader.cell_center_world(rock_cell))
				and rebuilt.visual_target_point().is_equal_approx(
					loader.cell_center_world(rock_cell)
					+ Vector2(0, loader.height_offset(rock_cell))))


func _choose_reachable_rock(
		loader: MapLoader, touch: TouchController, respawn: ObjectRespawn) -> Dictionary:
	for raw_entry in respawn._tracked:
		var entry: Dictionary = raw_entry
		if entry["symbol"] != "R" or not is_instance_valid(entry.get("node", null)):
			continue
		var rock_cell: Vector2i = entry["cell"]
		var stand := touch._nearest_walkable_adjacent(rock_cell)
		if stand == Vector2i(-1, -1) or not touch._astar.has_point(touch._pid(stand)):
			continue
		for r in range(loader.height - 1, -1, -1):
			for c in range(loader.width):
				var start := Vector2i(c, r)
				if not touch._astar.has_point(touch._pid(start)):
					continue
				if loader.cell_center_world(start).distance_to(loader.cell_center_world(rock_cell)) <= 180.0:
					continue
				var ids := touch._astar.get_id_path(touch._pid(start), touch._pid(stand))
				if not ids.is_empty():
					return {"entry": entry, "start": start, "stand": stand}
	return {}


func _test_exact_physics_at_all_heights() -> void:
	var template: Node = load(GROVE).instantiate()
	var tiles: TileSet = template.get_node("Ground").tile_set
	template.free()
	var legend_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_legend.json"))
	for level in [0, 1, 2]:
		var fixture_root := Node2D.new()
		add_child(fixture_root)
		var loader := Fixture.new()
		loader.tile_set = tiles
		loader.width = 15
		loader.height = 15
		loader._legend = legend_raw
		fixture_root.add_child(loader)
		for y in range(loader.height):
			for x in range(loader.width):
				loader.set_cell(Vector2i(x, y), 2, Vector2i.ZERO)
		var cell := Vector2i(7, 7)
		loader.elevation[cell] = level
		var origin := loader.cell_center_world(cell)
		var rock := loader.rebuild_gatherable("R", cell)
		rock.position = origin
		fixture_root.add_child(rock)
		loader.apply_height_lift(rock)
		check("fixture R radius is 24 at height %d" % level,
			rock.blocks_movement and _has_circle(rock, ROCK_RADIUS))
		check("fixture R collision stays at logical ground footprint height %d" % level,
			_body_global_position(rock).is_equal_approx(origin)
				and rock.target_point().is_equal_approx(origin)
				and rock.visual_target_point().is_equal_approx(
					origin + Vector2(0, loader.height_offset(cell))))

		var player := Player.new()
		player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		player._tilemap = loader
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = PLAYER_RADIUS
		collision.shape = shape
		player.add_child(collision)
		fixture_root.add_child(player)
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			player.release_move_and_path()
			player.position = origin + direction * 100.0
			await frames(2)
			var action: String = "move_left" if direction == Vector2.RIGHT else "move_right" if direction == Vector2.LEFT else "move_down" if direction == Vector2.UP else "move_up"
			Input.action_press(action)
			await frames(45)
			Input.action_release(action)
			var distance := player.position.distance_to(origin)
			check("R stops actual keyboard Player at footprint height%d direction%s" % [level, direction],
				distance >= ROCK_RADIUS + PLAYER_RADIUS - 2.0
					and distance <= ROCK_RADIUS + PLAYER_RADIUS + 2.0,
				"distance=%.3f" % distance)

		rock.queue_free()
		await frames(3)
		var stone := loader.rebuild_gatherable("s", cell)
		stone.position = origin
		fixture_root.add_child(stone)
		loader.apply_height_lift(stone)
		check("s has no physics footprint at height %d" % level,
			not stone.blocks_movement and not _has_static_body(stone))
		player.release_move_and_path()
		player.position = origin + Vector2.RIGHT * 100.0
		await frames(2)
		player.set_path([origin])
		await frames(45)
		check("real Player walks over s at height %d" % level,
			player.position.distance_to(origin) < 8.0,
			"distance=%.3f" % player.position.distance_to(origin))
		player.release_move_and_path()
		fixture_root.queue_free()
		await frames(3)


func _radius(node: Node) -> float:
	var value = node.get("block_radius")
	return float(value) if value != null else -1.0


func _has_static_body(node: Node) -> bool:
	for child in node.get_children():
		if child is StaticBody2D:
			return true
	return false


func _has_circle(node: Node, radius: float) -> bool:
	for child in node.get_children():
		if child is StaticBody2D:
			for grandchild in child.get_children():
				if grandchild is CollisionShape2D:
					var circle := (grandchild as CollisionShape2D).shape as CircleShape2D
					if circle != null and is_equal_approx(circle.radius, radius):
						return true
	return false


func _body_global_position(node: Node) -> Vector2:
	for child in node.get_children():
		if child is StaticBody2D:
			return (child as StaticBody2D).global_position
	return Vector2.INF


func _static_body_at(loader: MapLoader, cell: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not (node is Gatherable) or node.is_queued_for_deletion():
			continue
		if loader.get_parent().is_ancestor_of(node) \
				and loader.world_to_cell(node.target_point()) == cell \
				and _has_static_body(node):
			return true
	return false
