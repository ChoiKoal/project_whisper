extends Node
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var failures := 0
var scene: Node
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in range(n): await get_tree().process_frame
func _ready() -> void: call_deferred("run")
func boot(path := "res://scenes/world/starting_grove.tscn") -> void:
	scene=load(path).instantiate()
	add_child(scene)
	await frames(16)
func close_scene() -> void:
	SaveManager.unregister_world()
	scene.queue_free()
	await frames(3)
func run() -> void:
	if not GUARD.require_isolated_user_data("l1_home_story_harness"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	WorldContext.arrival_mode=""
	await boot()
	var story := scene.get_node_or_null("GroveSession/L1HomeStory")
	check("live grove has episode controller after snapshot restore", story!=null)
	var respawn: ObjectRespawn = scene.get_node("ObjectRespawn")
	var catalog: Array[String]=[]
	for e in respawn._tracked:
		catalog.append("%d,%d:%s:%s" % [e.cell.x,e.cell.y,e.symbol,e.node.item_id if is_instance_valid(e.node) else ""])
	catalog.sort()
	check("all original165 respawn IDs/cells/items exact",catalog==JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/06-shoreline/original-catalog.json")))
	if story!=null:
		var perch: Node2D=story.get("perch")
		check("perch exists and uses actual interaction contract",perch!=null and perch.has_method("on_interact") and perch.is_in_group("gatherable"))
		var ground_at_start: MapLoader=scene.get_node("Ground")
		for anchor in [perch,story.get("cairn")]:
			var cell:=ground_at_start.world_to_cell(anchor.global_position)
			var base_y: float=-80 if anchor.kind=="perch" else -56
			check("story sprite uses terrain height without moving logical interaction cell "+anchor.kind,anchor.offset.y==base_y+ground_at_start.height_offset(cell))
		var interaction: InteractionController=scene.get_node("Interaction")
		interaction.interact_with_object(perch)
		check("inspect waits for reader before committing",not GameState.story_episode().perch_inspected and GameState.control_locked())
		check("inspect reader completes actual input",await preload("res://scenes/dev/dialogue_harness_driver.gd").read(scene))
		check("real object inspect records state without lock",GameState.story_episode().perch_inspected and not GameState.control_locked())
		Inventory.add("I2",2); Inventory.add("I4",1)
		check("real R24 fuse",Fusion.fuse("I2","I2").output=="D09")
		check("real R25 fuse",Fusion.fuse("D09","I4").output=="D10")
		interaction.set_held_item("D10")
		var player: Player=scene.get_node("YSortLayer/Player")
		var ground: MapLoader=scene.get_node("Ground")
		# Isolated setup teleport; real tap controller must distinguish bare grass from raised prop.
		player.global_position=ground.cell_center_world(Vector2i(23,35))
		var touch: TouchController=scene.get_node("TouchController")
		check("story anchor does not steal bare-ground hit test",touch._object_near(ground.cell_center_world(Vector2i(23,35)))==null)
		touch.handle_tap(ground.cell_center_world(Vector2i(23,35)))
		await frames(5)
		# Inherited touch path uses legacy placeable_on (empty on D10), unlike E placement.
		# TouchController is out of this increment's ownership; record the gap, do not claim mobile PASS.
		print("KNOWN_INHERITED_TOUCH_GAP actionable=",touch._cell_is_actionable(Vector2i(23,35))," inventory=",Inventory.count("D10"))
		if Inventory.count("D10")>0: interaction._try_place_on_tile(Vector2i(23,35))
		check("real nest placement succeeds",interaction._placed_object_at(Vector2i(23,35))!=null)
		check("placement triggers nest response",GameState.story_episode().active_outcome=="nest" and story.get("response_count")==1)
		check("nest response has actual persistent sprite",perch.get_node_or_null("Response")!=null and perch.get_node("Response").texture!=null)
		Inventory.add("D10",1);interaction.set_held_item("D10")
		check("occupied placement fails without consuming",not interaction._try_place_on_tile(Vector2i(23,35)) and Inventory.count("D10")==1 and story.get("response_count")==1)
		check("save live nest",SaveManager.save_game())
		var expected:=GameState.story_episode()
		await close_scene()
		SaveManager.pending_load=true
		await boot()
		story=scene.get_node("GroveSession/L1HomeStory")
		check("live reload reconstructs nest and does not replay",GameState.story_episode()==expected and story.get("response_count")==0 and story.get("perch").get_node("Response").texture!=null)
		var clear: ClearSequence=scene.get_node("ClearSequence")
		clear.world_answer_beat.emit()
		check("CS04 answers with world trace",scene.find_child("L1H01WorldAnswer",true,false)!=null)
		for pair in [["D18","bouquet"],["D55","moss"],["D08","other"],["D10","nest"]]:
			var old: PlacedObject=interaction._placed_object_at(Vector2i(23,35)) if is_instance_valid(interaction) else null
			interaction=scene.get_node("Interaction")
			old=interaction._placed_object_at(Vector2i(23,35))
			if old!=null: old.recall();await frames(2)
			Inventory.add(pair[0],1);interaction.set_held_item(pair[0])
			check("real alternate placement "+pair[0],interaction._try_place_on_tile(Vector2i(23,35)))
			check("latest branch "+pair[1],GameState.story_episode().active_outcome==pair[1])
		check("only new outcomes react on revisit",story.get("response_count")==3 and GameState.story_episode().outcomes_seen.size()==4)
		await close_scene()
		# Clear flag injection here tests return reconstruction only, NOT full main progression.
		SaveManager.mark_cleared()
		WorldContext.arrival_mode="portal_arrival"
		await boot("res://scenes/world/home_island.tscn")
		var home: Node=scene.get_node("HomeSession")
		check("Home has materialize episode trace API",home.has_method("_materialize_l1h01_trace"))
		if home.has_method("_materialize_l1h01_trace"):
			home.call("_materialize_l1h01_trace")
			home.call("_materialize_l1h01_trace")
			var traces:=scene.find_children("L1H01ReturnTrace","",true,false)
			check("Home reconstructs exactly one trace",traces.size()==1 and traces[0].texture!=null)
			check("Home dialogue actually read",await preload("res://scenes/dev/dialogue_harness_driver.gd").read(scene))
			check("Home unlocks episode record once",Codex.is_cutscene_seen("EP-L1H-01") and GameState.story_episode().home_line_seen)
	await close_scene()
	print("L1_HOME_STORY failures=",failures)
	get_tree().quit(1 if failures else 0)
