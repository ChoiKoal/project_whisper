extends Node
## Save identity differential against the inherited spawn topology, not HEAD assets.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
class LegacySpawn extends MapLoader:
	func _is_spawn_rim_cell(cell: Vector2i) -> bool:
		if is_ramp(cell) or height_at(cell)<=0: return false
		for d in [Vector2i(1,0),Vector2i(0,1)]:
			if height_at(cell+d)<height_at(cell) and not is_ramp(cell+d): return true
		return false
var failures := 0
func check(label: String, ok: bool, detail := "") -> void:
	print("[%s] %s %s" % ["PASS" if ok else "FAIL",label,detail])
	if not ok: failures += 1
func _ready() -> void:
	if not GUARD.require_isolated_user_data("terrain_identity"):
		get_tree().quit(86)
		return
	call_deferred("run")
func catalog(loader: MapLoader) -> Array[String]:
	var result: Array[String] = []
	for entry in loader.object_spawns: result.append("%s:%s" % [entry.cell,entry.symbol])
	result.sort()
	return result
func run() -> void:
	SaveManager.new_game()
	var legacy: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	var old_ground: MapLoader = legacy.get_node("Ground")
	# set_script resets exports; explicitly preserve all scene wiring.
	var wiring := {}
	for key in ["ysort_layer_path","feedback_layer_path","player_path","fade_rect_path"]: wiring[key]=old_ground.get(key)
	old_ground.set_script(LegacySpawn)
	for key in wiring: old_ground.set(key,wiring[key])
	add_child(legacy)
	await get_tree().process_frame
	await get_tree().process_frame
	var baseline := catalog(old_ground)
	SaveManager.unregister_world()
	legacy.queue_free()
	await get_tree().process_frame
	SaveManager.new_game()
	var current: Node = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(current)
	await get_tree().process_frame
	await get_tree().process_frame
	var ground: MapLoader = current.get_node("Ground")
	var live := catalog(ground)
	check("spawn cell/symbol catalog matches inherited identity exactly", live==baseline,"baseline=%d current=%d" % [baseline.size(),live.size()])
	for key in baseline:
		if key not in live: print("CATALOG_REMOVED ",key)
	for key in live:
		if key not in baseline: print("CATALOG_ADDED ",key)
	var respawn: ObjectRespawn = current.get_node("ObjectRespawn")
	var missing := 0
	var raised := 0
	for entry in respawn._tracked:
		if ground.height_at(entry.cell)>0:
			raised += 1
			if entry.node==null or not is_instance_valid(entry.node):
				missing += 1
				print("UNINDEXED_RAISED ",entry.cell," ",entry.symbol)
	check("raised gatherables are indexed as present",raised>0 and missing==0,"raised=%d missing=%d" % [raised,missing])
	var player: Player = current.get_node("YSortLayer/Player")
	var plateau := Vector2i(16,20)
	player.release_move_and_path()
	player.position = ground.map_to_local(plateau)
	await get_tree().physics_frame
	await get_tree().process_frame
	check("plateau body remains logical cell centre",player.position.is_equal_approx(ground.map_to_local(plateau)))
	# Body-only atlas anchor is independently verified by foundation_cues_harness;
	# this test measures ONLY height displacement, not the former baked-shadow anchor.
	check("plateau sprite alone receives the height lift",is_equal_approx(player.get_node("AnimatedSprite2D").position.y,player._base_anim_position.y+ground.height_offset(plateau)),"sprite_y=%s height=%s" % [player.get_node("AnimatedSprite2D").position.y,ground.height_offset(plateau)])
	var ramp_cell := Vector2i(16,23)
	var climb: String = ground._ramp_climb_dir(ramp_cell)
	var axis := {"nw":Vector2(-16,-8),"ne":Vector2(16,-8),"sw":Vector2(-16,8),"se":Vector2(16,8)}
	player.position = ground.map_to_local(ramp_cell)+axis[climb]
	await get_tree().process_frame
	await get_tree().process_frame
	check("ramp sprite follows surface within the cell, not a mid-height snap",is_equal_approx(player.get_node("AnimatedSprite2D").position.y,player._base_anim_position.y-32.0*0.75),"sprite_y=%s" % player.get_node("AnimatedSprite2D").position.y)
	player.position = ground.map_to_local(plateau)
	# Isolated on-disk v2 roundtrip: a gathered raised flower must remain absent,
	# with the same timer/cell/symbol; its neighbour must remain live exactly once.
	GameState.time_running = false
	var entry: Dictionary = respawn.entry_for_cell(plateau)
	check("raised save fixture exists",not entry.is_empty() and is_instance_valid(entry.node))
	if not entry.is_empty() and is_instance_valid(entry.node):
		entry.node.free()
		entry.node = null
		entry.respawn_at = GameState.game_time + GameState.DAY_LENGTH
	var due: float = entry.respawn_at
	SaveManager.save_game()
	check("isolated disk save exists",SaveManager.has_save())
	SaveManager.unregister_world()
	current.queue_free()
	await get_tree().process_frame
	SaveManager.pending_load = true
	current = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(current)
	for i in range(12): await get_tree().process_frame
	ground = current.get_node("Ground")
	respawn = current.get_node("ObjectRespawn")
	player = current.get_node("YSortLayer/Player")
	entry = respawn.entry_for_cell(plateau)
	check("raised absence/timer/cell survives disk load",entry.node==null and is_equal_approx(entry.respawn_at,due) and entry.symbol=="F")
	check("raised player logical cell survives disk load",ground.world_to_cell(player.position)==plateau,"position=%s" % player.position)
	var present_before := 0
	for state in SaveManager.call("_object_states"):
		if state.present: present_before += 1
	check("only deliberately gathered object is absent after reload",present_before==baseline.size()-1,"present=%d" % present_before)
	GameState.set_game_time(due+1.0)
	respawn.force_tick()
	var matching := 0
	for node in current.get_node("YSortLayer").get_children():
		if node is Gatherable and node.get_meta("_lift_cell",Vector2i(-1,-1))==plateau: matching += 1
	check("one raised object respawns at its saved cell",matching==1 and is_instance_valid(entry.node))
	SaveManager.unregister_world()
	current.queue_free()
	await get_tree().process_frame
	print("IDENTITY_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
