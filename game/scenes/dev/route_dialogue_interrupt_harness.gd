extends "res://scenes/dev/foundation_dialogue_progression_capture.gd"
## Saved normal-route fixture, not a new-game playthrough. Inject one disclosed tap
## inspection while walking G2 -> Rest to reproduce the observed cairn modal.
var interrupt_sent:=false
var observed_dialogue:=false
func play()->bool:
	var source:=OS.get_environment("FDN_SAVE_FIXTURE")
	var expected:=ProjectSettings.globalize_path("res://").path_join("../evidence/12-foundation-scene/homes/normal-final/Library/Application Support/Godot/app_userdata/Project Whisper/save1.json").simplify_path()
	if not require(source==expected and FileAccess.file_exists(source),"approved isolated historical fixture exists"): return false
	var input:=FileAccess.open(source,FileAccess.READ)
	if not require(input!=null and input.get_length()<2000000,"fixture bounded and readable"):return false
	var text:=input.get_as_text();input.close()
	var data:Variant=JSON.parse_string(text)
	if not require(data is Dictionary and data.get("version")==2 and data.get("quests",{}).get("active_id")=="Q4" and data.get("world_context",{}).get("current_scene")=="grove","fixture expected save and progression shape"):return false
	var out:=FileAccess.open(SaveManager.SAVE_PATH,FileAccess.WRITE)
	if not require(out!=null,"isolated fixture destination writable"):return false
	out.store_string(text);out.close()
	SaveManager.new_game()
	SaveManager.pending_load=true
	_tree.change_scene_to_file("res://scenes/world/starting_grove.tscn")
	if not await _wait_scene_seconds("StartingGrove",5):return false
	await _tree.create_timer(4).timeout
	bind_world()
	if not require(QuestManager.active_id=="Q4","loaded actual pre-G2 saved progress"):return false
	var respawn:ObjectRespawn=_tree.current_scene.get_node("ObjectRespawn")
	if not await tap_object(respawn.entry_for_cell(Vector2i(20,22)).node):return false
	interaction.set_held_item("I7")
	if not await tap_object(find_object("bush_dry")):return false
	interaction.set_held_item("")
	if not require(QuestManager.active_id=="Q5","actual G2 watering from saved inventory"):return false
	var rest:RestStump=find_object("rest_stump")
	var rest_receipt:=[0]
	rest.rested.connect(func():rest_receipt[0]+=1)
	var old_time:=GameState.game_time
	_interrupt_near_cairn()
	var result:=await tap_object(rest)
	await _tree.create_timer(1.6).timeout
	require(rest_receipt[0]==1 and GameState.game_time>old_time+100,"Rest action fires once and really advances time")
	require(interrupt_sent and observed_dialogue,"fresh tap during route opens actual cairn dialogue")
	require(result,"fresh tap after reading interruption reaches real rest")
	require(not GameState.control_locked() and not GameState.ui_modal_open(),"dialogue owns and releases only its leases")
	return result and observed_dialogue and not _failed
func _interrupt_near_cairn()->void:
	var deadline:=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<deadline:
		await _physics_frames(1)
		if player.global_position.distance_to(Vector2(2560,768))<20:
			var story:=_tree.current_scene.get_node("GroveSession/L1HomeStory")
			interrupt_sent=true
			touch.handle_tap(story.cairn.visual_target_point())
			var panel:=_tree.current_scene.get_node("DialoguePanel")
			var wait_until:=Time.get_ticks_msec()+5000
			while not panel.is_open() and Time.get_ticks_msec()<wait_until:await _frames(1)
			observed_dialogue=panel.is_open() and panel._place.text=="돌무더기" and panel._source.text=="관찰" and panel._body.text.begins_with("돌 틈")
			print("FDN13_REPRO keys=",GameState._cinematic_keys," modal=",GameState._modal_keys," place=",panel._place.text," pos=",player.global_position)
			return
func _read_dialogue()->void:
	var panel:=_tree.current_scene.get_node_or_null("DialoguePanel") as DialoguePanel
	if panel==null:return
	for i in range(16):
		if not panel.is_open():break
		await _action("ui_accept");await _frames(3)
func _capture(_file_name:String,phase:String)->void:
	print("FIXTURE_STATE ",phase," lock=",GameState._cinematic_keys," pos=",player.global_position)
