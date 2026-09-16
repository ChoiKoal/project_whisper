extends Node
## Synthetic, isolated topology fixture using the shipped TileSet and real Player physics.
## Initial positioning is test setup, not normal-play evidence. No world save mutation.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const SIDES := [TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]
class Fixture extends MapLoader:
	func _ready() -> void:
		pass
var failures := 0
var checks := 0
func check(label: String, ok: bool, detail := "") -> void:
	checks += 1
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("terrain_topology"):
		get_tree().quit(86)
		return
	call_deferred("run")
func run() -> void:
	GameState.time_running = true
	var template: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	var tiles: TileSet = template.get_node("Ground").tile_set
	template.free()
	for row in [8, 9]:
		var ground := Fixture.new()
		ground.tile_set = tiles
		ground.width = 20
		ground.height = 20
		add_child(ground)
		ground.l2_cliff_palette = true
		check("terrain topology independent of palette row%d" % row,ground.terrain_neighbor(Vector2i(8,row),Vector2i(1,0))==ground.get_neighbor_cell(Vector2i(8,row),TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE))
		ground.l2_cliff_palette = false
		for y in range(20):
			for x in range(20): ground.set_cell(Vector2i(x,y), 2, Vector2i.ZERO)
		var high := Vector2i(8,row)
		ground.elevation[high] = 1
		ground.hill_cells[high] = 1
		ground._build_ledge_collision()
		var player := Player.new()
		player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		player._tilemap = ground
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 20.0
		shape.shape = circle
		player.add_child(shape)
		add_child(player)
		var touch := TouchController.new()
		add_child(touch)
		touch._loader = ground
		touch._player = player
		touch._build_grid()
		var actual: Array[Vector2i] = []
		for side in SIDES:
			var nb := ground.get_neighbor_cell(high, side)
			actual.append(nb)
			var delta := ground.map_to_local(nb)-ground.map_to_local(high)
			print("GEOMETRY row=%d side=%d cell=%s nb=%s delta=%s" % [row,side,high,nb,delta])
			player.release_move_and_path()
			player.position = ground.map_to_local(high)
			await physics_frames(3)
			var dest := ground.map_to_local(nb)
			player.set_path([dest])
			await physics_frames(45)
			check("non-ramp real physics blocks row%d side%d" % [row,side], ground.world_to_cell(player.global_position)==high,
				"pos=%s cell=%s target=%s" % [player.position,ground.world_to_cell(player.global_position),nb])
			player.release_move_and_path()
		# Real keyboard input, including the four diamond vertices, not just set_path.
		for input_dir in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1),Vector2i(1,-1)]:
			player.release_move_and_path()
			player.position = ground.map_to_local(high)
			await physics_frames(3)
			if input_dir.x: Input.action_press("move_right" if input_dir.x>0 else "move_left")
			if input_dir.y: Input.action_press("move_down" if input_dir.y>0 else "move_up")
			await physics_frames(35)
			player.release_move_and_path()
			check("keyboard stays behind ledge row%d input%s" % [row,input_dir],ground.world_to_cell(player.position)==high,"pos=%s" % player.position)
		# Flat graph must connect exactly shared sides, never jump over a corner.
		ground.elevation.clear()
		ground.hill_cells.clear()
		ground._ledge_body.queue_free()
		await physics_frames(2)
		touch.refresh_grid()
		var links: Array[Vector2i] = []
		for id in touch._astar.get_point_connections(touch._pid(high)):
			links.append(Vector2i(touch._astar.get_point_position(id)))
		var exact := links.size()==actual.size()
		for nb in actual: exact = exact and nb in links
		check("flat graph follows all actual TileSet sides row%d" % row, exact, "actual=%s graph=%s" % [actual,links])
		# Ramp fixture: adjacent low → ramp → high must be walkable in physical space.
		var ramp := high
		var plateau := ground.get_neighbor_cell(ramp, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE)
		var low := ground.get_neighbor_cell(ramp, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE)
		ground.ramp_cells[ramp] = true
		ground.elevation[plateau] = 1
		ground.hill_cells[plateau] = 1
		ground._build_ledge_collision()
		touch.refresh_grid()
		player.position = ground.map_to_local(low)
		await physics_frames(3)
		check("ramp route exists row%d" % row, touch.move_to(plateau))
		var target := ground.map_to_local(plateau)
		check("ramp target is flat logical centre row%d" % row,
			not player._path.is_empty() and player._path[-1].is_equal_approx(target), "path=%s expected=%s" % [player._path,target])
		await physics_frames(100)
		check("real Player reaches plateau through ramp row%d" % row, player.position.distance_to(target)<7,
			"pos=%s target=%s cell=%s" % [player.position,target,ground.world_to_cell(player.position)])
		player.release_move_and_path()
		touch.queue_free()
		player.queue_free()
		ground.queue_free()
		await physics_frames(2)
	print("TOPOLOGY_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
func physics_frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
