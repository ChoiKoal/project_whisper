extends Node
const GUARD=preload("res://scenes/dev/isolated_harness_guard.gd")
var fail:=0
func check(label:String,ok:bool)->void:
	print("[%s] %s"%["PASS" if ok else "FAIL",label])
	if not ok:fail+=1
func frames(n:=4)->void:
	for i in range(n):await get_tree().process_frame
func _ready()->void:
	if not GUARD.require_isolated_user_data("story_dialogue"):
		get_tree().quit(86)
		return
	call_deferred("run")
func dismiss(panel:Node)->void:
	for i in range(12):
		if not panel.is_open():break
		var input:=InputEventAction.new()
		input.action="ui_accept";input.pressed=true
		get_viewport().push_input(input,true)
		await frames(1)
		input.pressed=false
		get_viewport().push_input(input,true)
		await frames(2)
func run()->void:
	SaveManager.new_game()
	WorldContext.arrival_mode=""
	var scene:Node=load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene);await frames(15)
	var story:=scene.find_child("L1HomeStory",true,false)
	var panel:=scene.get_node_or_null("DialoguePanel")
	story._inspect(story.perch)
	check("real Grove inspect uses persistent panel",panel!=null and panel.is_open())
	check("inspect not saved as seen before dismissal",not GameState.story_episode().perch_inspected)
	if panel!=null:
		story._inspect(story.perch)
		check("duplicate inspect not queued twice",panel.pending_count()==0)
		panel.cancel_all();await frames()
		check("cancel leaves inspect unseen",not GameState.story_episode().perch_inspected)
		story._inspect(story.perch);await frames()
		await dismiss(panel)
		check("completed inspect commits seen",GameState.story_episode().perch_inspected)
		story._inspect(story.cairn);await frames()
		check("cairn source/place mapped",panel.is_open() and panel._place.text=="돌무더기")
		panel.cancel_all()
	SaveManager.unregister_world();scene.queue_free();await frames()
	SaveManager.new_game();SaveManager.cleared=true
	WorldContext.arrival_mode="portal_arrival"
	scene=load("res://scenes/world/home_island.tscn").instantiate()
	add_child(scene);await frames(15)
	panel=scene.get_node_or_null("DialoguePanel")
	var session:=scene.get_node("HomeSession")
	check("first return has persistent Home dialogue",panel!=null and panel.is_open())
	check("Home line/replay not committed merely by enqueue",not GameState.story_episode().home_line_seen and not GameState.story_episode().record_unlocked)
	if panel!=null:
		session._materialize_l1h01_trace()
		check("repeated materialize joins one display",panel.pending_count()==0)
		panel.cancel_all();await frames()
		check("Home cancellation leaves line retryable",not GameState.story_episode().home_line_seen)
		for i in range(9):panel.enqueue(["대기"],"fill%d"%i)
		session._materialize_l1h01_trace();await frames()
		check("rejected Home queue does not unlock record",not GameState.story_episode().home_line_seen and not GameState.story_episode().record_unlocked)
		panel.cancel_all();await frames()
		session._materialize_l1h01_trace();await frames()
		await dismiss(panel)
		check("Home record commits after actual dismissal",GameState.story_episode().home_line_seen and GameState.story_episode().record_unlocked)
		check("own modal and time leases released",not panel.has_own_leases() and not GameState.ui_modal_open())
	SaveManager.unregister_world();scene.queue_free();await frames()
	print("STORY_DIALOGUE_DONE failures=%d"%fail)
	get_tree().quit(1 if fail else 0)
