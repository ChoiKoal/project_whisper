extends Node
## Frozen pre-shore catalog/save fixture, then live six-cell bank and disk compatibility.
## Every write is beneath a runner-bound isolated HOME/evidence directory.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const BANK := [Vector2i(11,35),Vector2i(11,36),Vector2i(10,37),Vector2i(11,37),Vector2i(10,38),Vector2i(11,38)]
const SIDES := [TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE]
var failures := 0
var scene: Node
var evidence: String
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("shoreline_contract"):
		get_tree().quit(86)
		return
	evidence = OS.get_environment("SHORELINE_EVIDENCE")
	if evidence != ProjectSettings.globalize_path("res://../evidence/06-shoreline").simplify_path():
		get_tree().quit(87)
		return
	call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await get_tree().physics_frame
func boot() -> void:
	scene = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	for i in range(12): await get_tree().process_frame
	await frames(3)
func close_scene() -> void:
	SaveManager.unregister_world()
	scene.queue_free()
	for i in range(3): await get_tree().process_frame
func catalog() -> Array[String]:
	var out: Array[String] = []
	var respawn: ObjectRespawn = scene.get_node("ObjectRespawn")
	for entry in respawn._tracked:
		var item := ""
		if is_instance_valid(entry.node): item = str(entry.node.item_id)
		out.append("%d,%d:%s:%s" % [entry.cell.x,entry.cell.y,entry.symbol,item])
	out.sort()
	return out
func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	check("evidence file opens "+path,file!=null)
	if file == null: return
	var encoded := JSON.stringify(value,"	")
	file.store_string(encoded)
	check("evidence write completed",file.get_error()==OK)
	file.close()
	check("evidence JSON readback matches",FileAccess.get_file_as_string(path)==encoded)
func canonical(value: Variant) -> String:
	# JSON parsing converts integer coordinates to floats; compare JSON domain values.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))
func point_blocked(ground: MapLoader, cell: Vector2i, player: Player) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = ground.to_global(ground.map_to_local(cell))
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return not ground.get_world_2d().direct_space_state.intersect_point(query).is_empty()
func run() -> void:
	SaveManager.new_game()
	WorldContext.arrival_mode = ""
	await boot()
	GameState.time_running = false
	var ground: MapLoader = scene.get_node("Ground")
	var player: Player = scene.get_node("YSortLayer/Player")
	var touch: TouchController = scene.get_node("TouchController")
	var baseline_mode := OS.get_environment("SHORELINE_MODE").begins_with("baseline")
	var live_catalog := catalog()
	check("live catalog contains original165",live_catalog.size()==165,str(live_catalog.size()))
	if baseline_mode:
		write_json(evidence.path_join("original-catalog.json"),live_catalog)
		var sources := []
		for y in range(ground.height):
			for x in range(ground.width): sources.append(ground.get_cell_source_id(Vector2i(x,y)))
		write_json(evidence.path_join("original-sources.json"),sources)
		for cell in BANK:
			check("baseline proposed bank is collidable water %s" % cell,ground.get_cell_source_id(cell) in [8,9] and not ground.is_cell_walkable(cell) and point_blocked(ground,cell,player))
		# Synthetic old-map v2 fixture, not a real user's historical save.
		SaveManager.call("_apply_placed_objects",[{"item_id":"D08","cell":[16,35]},{"item_id":"D08","cell":[8,32]}])
		var interaction: InteractionController = scene.get_node("Interaction")
		Inventory.add("D14",1)
		interaction.set_held_item("D14")
		check("old-map real G1 stepping placement",interaction._try_place_on_tile(ground.stepping_slot_cells[0]))
		interaction.set_held_item("")
		ground.set_cell(Vector2i(12,31),11,Vector2i.ZERO)
		var respawn: ObjectRespawn = scene.get_node("ObjectRespawn")
		var entry: Dictionary = respawn.entry_for_cell(Vector2i(16,20))
		check("old-map raised object fixture exists",not entry.is_empty() and is_instance_valid(entry.node))
		if not entry.is_empty() and is_instance_valid(entry.node):
			entry.node.free()
			entry.node=null
			entry.respawn_at=GameState.game_time+GameState.DAY_LENGTH
		check("old-map disk save succeeds",SaveManager.save_game())
		write_json(evidence.path_join("original-save.json"),JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH)))
	else:
		var original: Array = JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("original-catalog.json")))
		check("catalog exact cell/symbol/item identity vs frozen pre-change165",live_catalog==original)
		var old_sources: Array = JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("original-sources.json")))
		var changed: Array[Vector2i] = []
		for y in range(ground.height):
			for x in range(ground.width):
				var cell := Vector2i(x,y)
				if ground.get_cell_source_id(cell)!=int(old_sources[y*ground.width+x]): changed.append(cell)
		check("actual TileMap source delta exactly candidate6",changed.size()==BANK.size() and changed.all(func(c): return c in BANK),str(changed))
		for cell in BANK:
			var td := ground.get_cell_tile_data(cell)
			check("new bank soil walkability and graph %s" % cell,ground.get_cell_source_id(cell)==1 and ground.is_cell_walkable(cell) and touch._astar.has_point(touch._pid(cell)))
			check("new bank has no TileSet collision polygon %s" % cell,td!=null and td.get_collision_polygons_count(0)==0)
			check("new bank actual physics space unblocked %s" % cell,not point_blocked(ground,cell,player))
			for side in SIDES:
				var water := ground.get_neighbor_cell(cell,side)
				if ground.get_cell_source_id(water) in [8,9]:
					check("adjacent water remains actual collider %s" % water,point_blocked(ground,water,player) and not ground.is_cell_walkable(water))
		# Do not burn physical traversal time when the requested feature is absent.
		if failures==0:
			GameState.time_running = true
			for cell in BANK:
				check("real tap route accepted %s" % cell,touch.move_to(cell))
				var target := ground.map_to_local(cell)
				for i in range(420):
					await frames(1)
					if player.position.distance_to(target)<7: break
				player.release_move_and_path()
				check("real Player reaches new bank %s" % cell,player.position.distance_to(target)<9,"position=%s target=%s" % [player.position,target])
			# Odd/even row actual keyboard traversal between new-bank centres.
			# Setup teleports are isolated-harness-only; root capture has none in L1.
			for pair in [[BANK[0],BANK[1]],[BANK[1],BANK[3]]]:
				for reverse in [false,true]:
					var start: Vector2i=pair[1] if reverse else pair[0]
					var end: Vector2i=pair[0] if reverse else pair[1]
					player.position=ground.map_to_local(start)
					await frames(3)
					var target:=ground.map_to_local(end)
					var delta:=target-player.position
					Input.action_press("move_right" if delta.x>0 else "move_left")
					Input.action_press("move_down" if delta.y>0 else "move_up")
					for i in range(100):
						await frames(1)
						if player.position.distance_to(target)<7: break
					player.release_move_and_path()
					check("new bank keyboard crossing %s -> %s" % [start,end],player.position.distance_to(target)<9,"position=%s target=%s" % [player.position,target])
			GameState.time_running = false
		await close_scene()
		SaveManager.new_game()
		var original_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("original-save.json")))
		write_json(SaveManager.SAVE_PATH,original_save)
		SaveManager.pending_load=true
		await boot()
		GameState.time_running=false
		ground=scene.get_node("Ground")
		var expected: Dictionary = original_save.worlds.grove
		var current: Dictionary = SaveManager.call("_map_dict")
		for key in ["placed_objects","objects","void_cells","stepping_stones","gates"]:
			check("old-map save preserves exact "+key,canonical(current[key])==canonical(expected[key]))
		check("restored hollow keeps exact original coordinate",ground.get_cell_source_id(Vector2i(12,31))==11)
		check("restored old-map save writes again",SaveManager.save_game())
		var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
		for key in ["placed_objects","objects","void_cells","stepping_stones","gates"]:
			check("disk resave preserves exact "+key,JSON.stringify(persisted.worlds.grove[key])==JSON.stringify(expected[key]))
	await close_scene()
	print("SHORELINE_RESULT failures=%d baseline=%s" % [failures,baseline_mode])
	get_tree().quit(1 if failures else 0)
