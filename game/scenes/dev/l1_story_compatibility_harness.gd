extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var failures:=0
var scene: Node
func check(label: String,ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ")+label)
	if not ok: failures+=1
func _ready() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in range(n): await get_tree().process_frame
func close_scene() -> void:
	SaveManager.unregister_world();scene.queue_free();await frames(3)
func run() -> void:
	if not GUARD.require_isolated_user_data("story_compatibility"):
		get_tree().quit(86);return
	SaveManager.new_game();WorldContext.arrival_mode=""
	scene=load("res://scenes/world/starting_grove.tscn").instantiate();add_child(scene);await frames(12)
	var story:=scene.get_node("GroveSession/L1HomeStory")
	var ground: MapLoader=scene.get_node("Ground")
	var placements: Array=[]
	# Synthetic saturation, not a historical save: fill ALL candidates after derived story creation.
	for origin in [Vector2i(24,34),Vector2i(19,20)]:
		for y in range(-3,4):
			for x in range(-3,4): placements.append({"item_id":"D08","cell":[origin.x+x,origin.y+y]})
	SaveManager.call("_apply_placed_objects",placements)
	story.call("_restore")
	check("saturated player placements hide derived anchors rather than relocating data",not story.perch.visible and not story.cairn.visible)
	check("hidden anchor has no interactive target",not story.perch.is_in_group("gatherable") and not story.cairn.is_in_group("gatherable"))
	var live: Array=[]
	for obj in get_tree().get_nodes_in_group("placed_object"):
		if scene.is_ancestor_of(obj): live.append(obj.to_dict())
	check("all synthetic saved placement ID/cells unchanged",JSON.stringify(live)==JSON.stringify(placements))
	check("saturation does not invent story outcome",GameState.story_episode().active_outcome=="")
	await close_scene()
	SaveManager.new_game();SaveManager.mark_cleared()
	QuestManager.advance_to("P2")
	for item in ["","D10","D18","D55","D08"]:
		if item!="": GameState.story_record_experiment(item)
		WorldContext.arrival_mode="portal_arrival"
		scene=load("res://scenes/world/home_island.tscn").instantiate();add_child(scene);await frames(12)
		var home:=scene.get_node("HomeSession")
		var before_progress:=QuestManager.progress
		home.call("_materialize_l1h01_trace");home.call("_materialize_l1h01_trace")
		var traces:=scene.find_children("L1H01ReturnTrace","",true,false)
		var outcome: String=GameState.story_episode().active_outcome
		if outcome=="": outcome="bare"
		check("Home branch exactly one "+outcome,traces.size()==1 and traces[0].texture.resource_path.ends_with("home_l1_trace_%s.png" % outcome))
		check("Home trace does not progress P2 placements "+outcome,QuestManager.progress==before_progress and QuestManager.active_id=="P2")
		check("Home pending dialogue read "+outcome,await preload("res://scenes/dev/dialogue_harness_driver.gd").read(scene))
		check("Home record/caption state persisted "+outcome,GameState.story_episode().home_line_seen and Codex.is_cutscene_seen("EP-L1H-01"))
		await close_scene()
	print("STORY_COMPATIBILITY failures=",failures)
	get_tree().quit(1 if failures else 0)
