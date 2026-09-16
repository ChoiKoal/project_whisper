extends Node
## FDN-01: actual candidate map/Player/TouchController contracts, isolated save only.
## Endpoint teleports and G2 bloom are explicit fixtures, not normal quest completion.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const CANDIDATE = "res://scenes/foundation/representative_grove.tscn"
const SIDES = [TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]
var failed := 0
var checks := 0
var scene: Node
var ground: MapLoader
var player: Player
var touch: TouchController
func check(label: String, ok: bool, detail := "") -> void:
	checks += 1
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failed += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("foundation_contract"):
		get_tree().quit(86)
		return
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func boot() -> void:
	var path := OS.get_environment("FDN_SCENE")
	scene = load(CANDIDATE if path.is_empty() else path).instantiate()
	add_child(scene)
	await frames(12)
	ground = scene.get_node("Ground")
	player = scene.get_node("YSortLayer/Player")
	touch = scene.get_node("TouchController")
func catalog() -> Array[String]:
	var out: Array[String] = []
	for entry in scene.get_node("ObjectRespawn")._tracked:
		var item: String = str(entry.node.item_id) if is_instance_valid(entry.node) else ""
		out.append("%d,%d:%s:%s" % [entry.cell.x, entry.cell.y, entry.symbol, item])
	out.sort()
	return out
func walls() -> Array[Node]:
	var out: Array[Node] = []
	for n in scene.get_node("YSortLayer").get_children():
		if n.get_meta("render_role", "") == "vertical_occluder": out.append(n)
	return out
func run() -> void:
	SaveManager.new_game()
	WorldContext.arrival_mode = ""
	await boot()
	GameState.time_running = true
	var original: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/06-shoreline/original-catalog.json"))
	check("frozen catalog165 exact IDs/cells/types", catalog() == original)
	var interaction := scene.get_node("Interaction") as InteractionController
	check("actual interaction resolves subclass Ground, not missing wiring",interaction._tilemap==ground and ground is MapLoader)
	check("actual touch resolves same map",touch._loader==ground)
	check("actor subtree sorts at logical foot rather than lifted sprite", not player.y_sort_enabled)
	var expected_faces := 0
	var mixed := 0
	for cell in ground.hill_cells:
		if ground.is_ramp(cell): continue
		var local_faces := 0
		var receiver_levels: Array[int] = []
		for d in [Vector2i(1,0), Vector2i(0,1)]:
			var nb := ground.terrain_neighbor(cell,d)
			if not ground.is_ramp(nb) and ground.height_at(nb) < ground.height_at(cell):
				expected_faces += 1
				local_faces += 1
				receiver_levels.append(ground.height_at(nb))
		if local_faces == 2 and receiver_levels[0] != receiver_levels[1]: mixed += 1
	check("split face set exactly matches live topology", walls().size() == expected_faces, "expected=%d actual=%d mixed=%d" % [expected_faces,walls().size(),mixed])
	var roots_ok := true
	var single_ok := true
	for wall in walls():
		var cell: Vector2i = wall.get_meta("raised_cell")
		var expected := ground.cell_center_world(cell) + Vector2(0,32)
		roots_ok = roots_ok and wall.global_position.is_equal_approx(expected)
		var d: Vector2i = wall.get_meta("face_depths")
		single_ok = single_ok and ((d.x>0) != (d.y>0))
	check("wall logical contact roots are not object-lifted again", roots_ok)
	check("corner faces have independent receiver/depth metadata", single_ok and not walls().is_empty())
	# Rebuilding only display terrain must preserve object nodes, physics and save coords.
	var before_catalog := catalog()
	var before_player := player.position
	var old_walls := walls()
	var expected_colliders := ground.ledge_collider_count
	ground._build_elevation()
	await frames(3)
	check("rebuild removes every prior reparented wall", old_walls.all(func(n): return not is_instance_valid(n)))
	check("rebuild wall count stable, no duplicate sibling occluders", walls().size()==expected_faces)
	check("rebuild collider count stable",ground.ledge_collider_count==expected_colliders)
	check("rebuild preserves logical player and object catalog",player.position.is_equal_approx(before_player) and catalog()==before_catalog)
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is BushDry and scene.is_ancestor_of(node): node.bloom()
	await frames(3)
	touch.refresh_grid()
	for ramp in [Vector2i(18,17), Vector2i(18,22)]:
		var pair: Array[Vector2i] = []
		for i in range(2):
			var a := ground.get_neighbor_cell(ramp,SIDES[i])
			var b := ground.get_neighbor_cell(ramp,SIDES[i+2])
			if ground.height_at(a) != ground.height_at(b) and ground.is_cell_walkable(a) and ground.is_cell_walkable(b):
				pair.assign([a,b] if ground.height_at(a) < ground.height_at(b) else [b,a])
				break
		check("ramp endpoints exist %s" % ramp,pair.size()==2)
		if pair.size()!=2: continue
		for reverse in [false,true]:
			var start: Vector2i = pair[1] if reverse else pair[0]
			var end: Vector2i = pair[0] if reverse else pair[1]
			for mode in ["tap","keyboard"]:
				player.release_move_and_path()
				player.global_position=ground.cell_center_world(start)
				await frames(3)
				var target:=ground.cell_center_world(end)
				if mode=="tap":
					check("public touch route accepted %s %s" % [ramp,reverse],touch.move_to(end))
				var visited := false
				for i in range(150):
					if mode=="keyboard":
						# Binary keyboard actions, feedback steering only; no path API or
						# position injection during crossing. Release each axis on arrival.
						var delta := target-player.global_position
						for action in Player.MOVE_ACTIONS: Input.action_release(action)
						if absf(delta.x)>2.5: Input.action_press("move_right" if delta.x>0 else "move_left")
						if absf(delta.y)>2.5: Input.action_press("move_down" if delta.y>0 else "move_up")
					await frames(1)
					visited = visited or ground.world_to_cell(player.global_position)==ramp
					if player.global_position.distance_to(target)<7: break
				player.release_move_and_path()
				check("actual %s traversal %s reverse=%s visits ramp and reaches endpoint" % [mode,ramp,reverse],visited and player.global_position.distance_to(target)<9,"pos=%s target=%s" % [player.position,target])
	# Save actual reached logical endpoint; renderer adds no schema/placement changes.
	# Synthetic placed-object fixture, through the real creation API, then disk restore.
	var placed_cell := Vector2i(19,20)
	interaction._spawn_placed_object("D08",placed_cell)
	await frames(20)
	var save_position := player.global_position
	check("isolated disk save succeeds", SaveManager.save_game())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	SaveManager.unregister_world()
	scene.queue_free()
	await frames(3)
	SaveManager.pending_load=true
	await boot()
	check("save/load retains logical foot",player.global_position.distance_to(save_position)<0.01,"actual=%s expected=%s" % [player.global_position,save_position])
	check("save/load constructs one exact wall set",walls().size()==expected_faces)
	var restored: PlacedObject
	for node in scene.get_node("YSortLayer").get_children():
		if node is PlacedObject and node.cell==placed_cell: restored=node
	check("raised placed object actually restored from disk",restored!=null)
	if restored!=null:
		ground._on_foundation_child(restored)
		ground._on_foundation_child(restored)
		await frames(3)
		var adapters := 0
		for node in restored.get_children():
			if node.name=="FoundationSurface": adapters+=1
		check("restored placed object has one adapter after duplicate notifications",adapters==1)
		var ghost: PlacementGhost=scene.get_node("PlacementGhost")
		var logical:=ground.cell_center_world(placed_cell)
		ghost.show_ghost("D08",logical,true)
		check("restored placement visual matches projected ghost",restored.to_global(restored.offset).distance_to(ghost._sprite.to_global(ghost._sprite.offset))<0.1)
		check("restored placement root target and save cell remain logical",restored.global_position.is_equal_approx(logical) and restored.target_point().is_equal_approx(logical) and restored.to_dict().cell==[placed_cell.x,placed_cell.y])
		ghost.hide_ghost()
	check("resave succeeds",SaveManager.save_game())
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	for key in ["placed_objects","objects","void_cells","stepping_stones","gates"]:
		check("save renderer preserves "+key,JSON.stringify(after.worlds.grove[key])==JSON.stringify(data.worlds.grove[key]))
	# Remove Ground while YSort survives: walls must not leak outside owner lifetime.
	var retiring := walls()
	SaveManager.unregister_world()
	# Partial-owner teardown fixture: suspend sibling controllers that legitimately
	# require Ground for active gameplay, leaving YSort alive for the leak assertion.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	ground.queue_free()
	await frames(3)
	check("Ground exit removes externally parented walls",retiring.all(func(n): return not is_instance_valid(n)) and walls().is_empty())
	scene.queue_free()
	await frames(3)
	print("FOUNDATION_RESULT checks=%d failures=%d" % [checks,failed])
	get_tree().quit(1 if failed else 0)
