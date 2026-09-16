extends "res://scenes/dev/foundation_progression_capture.gd"
## Normal loop with actual modal input. No direct story-state or completion calls.
## Mobile sizes below are desktop viewport simulations, NOT mobile-device evidence.
var dialogue_captures := 0
var resized_once := false
func point_interact(point: Vector2) -> void:
	await super.point_interact(point)
	await _read_dialogue()
func _wait_scene_seconds(scene_name: String, seconds: float) -> bool:
	var found: bool=await super._wait_scene_seconds(scene_name,seconds)
	if found and scene_name=="HomeIsland" and SaveManager.cleared:
		var deadline:=Time.get_ticks_msec()+30000
		while SaveManager.pending_return_ignition and Time.get_ticks_msec()<deadline: await _frames(1)
		await _frames(3)
		await _read_dialogue()
	return found
func _handle_route_interruption(deadline: int) -> void:
	await _read_dialogue()
	await super._handle_route_interruption(deadline)
func _read_dialogue() -> void:
	var panel:=_tree.current_scene.get_node_or_null("DialoguePanel") as DialoguePanel
	if panel==null or not panel.is_open(): return
	var page := 0
	while panel.is_open() and page<16:
		await _action("ui_accept") # first press reveals, later press advances
		await _frames(3)
		if not panel.is_open(): break
		dialogue_captures+=1
		await _capture("dialogue-%02d.png"%dialogue_captures,"normal_dialogue_"+panel._place.text)
		if not resized_once:
			resized_once=true
			await _responsive_captures(panel)
		await _tree.create_timer(0.5).timeout
		# Alternate keyboard and native touch; emulated companion must not leak.
		if page%2==0:
			var event:=InputEventScreenTouch.new()
			event.index=0;event.position=panel.continue_button().get_global_rect().get_center();event.pressed=true
			_tree.root.push_input(event,true)
			await _frames(1)
			event.pressed=false;_tree.root.push_input(event,true)
		else: await _action("ui_accept")
		await _frames(3)
		page+=1
	require(not panel.is_open(),"normal dialogue completed using fresh keyboard/touch input")
func _responsive_captures(panel: DialoguePanel) -> void:
	var window:=_tree.root
	var old_size:=window.size
	var old_content:=window.content_scale_size
	var old_mode:=window.content_scale_mode
	var old_aspect:=window.content_scale_aspect
	var records:Array=[]
	window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	for size in [Vector2i(640,480),Vector2i(390,844),Vector2i(844,390)]:
		window.content_scale_size=size;window.size=size
		await _frames(5)
		if not await _await_rendered_frame():
			_fail("responsive rendered-frame timeout")
			break
		var image:=window.get_texture().get_image()
		if image==null:
			_fail("responsive image missing")
			break
		var path:=_out_dir.path_join("normal-dialogue-simulated-%dx%d.png"%[size.x,size.y])
		var error:=image.save_png(path)
		require(error==OK and image.get_size()==size,"normal-root simulated dialogue pixels %s"%size)
		records.append({"size":str(size),"actual":str(image.get_size()),"path":path,"panel":str(panel.dialogue_rect()),"kind":"normal-route same scene; desktop viewport simulation, not mobile device"})
	window.content_scale_mode=old_mode;window.content_scale_aspect=old_aspect
	window.content_scale_size=old_content;window.size=old_size
	await _frames(5)
	var file:=FileAccess.open(_out_dir.path_join("responsive-dialogue.json"),FileAccess.WRITE)
	if file==null:
		_fail("responsive manifest unavailable")
	else:
		file.store_string(JSON.stringify(records,"\t"));file.close()
func _runtime_record(phase: String) -> Dictionary:
	var result:=super._runtime_record(phase)
	result["layout_revision"]=SaveManager.grove_layout_revision
	result["candidate_provenance"]="l1-v2 only when explicitly selected before new-run Home; production default remains l1-v1. v2 diagonal ascent amendment is engineering layout, not authored-art approval."
	result["dialogue_automation"]="Important modal beats read using fresh ui_accept and native touch; close/reveal via real input, no direct seen flags. Resizes disclosed separately."
	return result
