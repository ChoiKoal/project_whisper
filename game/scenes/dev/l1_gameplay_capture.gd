extends Node
## Normal-root evidence for title → new game → opening → Home nature portal → StartingGrove.
## The only injected state is a documented test teleport onto the real portal apron; travel itself
## is triggered through the real `interact` input and HomeSession save/scene-change path.

const TITLE := "res://scenes/ui/title.tscn"
const TARGET_SIZE := Vector2i(1600, 900)
const ISOLATION_GUARD := preload("res://scenes/dev/isolated_harness_guard.gd")

var _tree: SceneTree
var _out_dir := ""
var _records: Array[Dictionary] = []
var _failed := false


func _ready() -> void:
	if not ISOLATION_GUARD.require_isolated_user_data("l1_gameplay_capture"):
		get_tree().quit(86)
		return
	_tree = get_tree()
	_out_dir = OS.get_environment("L1_CAPTURE_DIR")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://l1-capture")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	if mkdir_error != OK:
		push_error("L1_CAPTURE: evidence directory unavailable: %s (err=%d)" % [_out_dir, mkdir_error])
		_tree.quit(87)
		return
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	call_deferred("_run")


func _run() -> void:
	SaveManager.delete_save()
	SaveManager.new_game()
	_tree.change_scene_to_file(TITLE)
	if not await _wait_scene("Title", 180):
		_fail("title did not boot")
		_finish()
		return
	await _tree.create_timer(1.45, true, false, true).timeout
	var new_game := _find_button(_tree.current_scene, "새로 시작")
	if new_game == null:
		_fail("new-game button missing")
		_finish()
		return
	await _click_control(new_game)
	if not await _wait_scene("Opening", 180):
		_fail("new-game click did not reach Opening")
		_finish()
		return
	await _frames(12)
	# Directly invoke the real Opening unhandled-input handler. Root injection is focus-sensitive on
	# macOS and produced a reproducible no-op; this keeps the code path exact and provenance explicit.
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	_tree.current_scene.call("_unhandled_input", cancel)
	await _tree.create_timer(1.0, true, false, true).timeout
	if not await _wait_scene("HomeIsland", 360):
		_fail("opening input did not reach HomeIsland")
		_finish()
		return
	await _tree.create_timer(4.8, true, false, true).timeout

	var home := _tree.current_scene
	var player := home.get_node("YSortLayer/Player") as Node2D
	var nature: Portal = null
	for node in _tree.get_nodes_in_group("gatherable"):
		if node is Portal and String((node as Portal).layer) == "nature":
			nature = node as Portal
			break
	if nature == null:
		_fail("nature portal missing in Home")
		_finish()
		return
	# Test-only positioning, explicitly recorded in provenance. The interaction and travel remain real.
	player.global_position = nature.entry_stand_point()
	await _physics_frames(5)
	var apron_ready := nature.is_player_in_entry_zone()
	print("L1_CAPTURE_PORTAL apron_ready=%s player=%s stand=%s" % [
		apron_ready, player.global_position, nature.entry_stand_point()])
	if not apron_ready:
		_fail("player teleport did not register in real nature portal apron")
		_finish()
		return
	await _action("interact")
	if not await _wait_scene_seconds("StartingGrove", 10.0):
		_fail("real portal interact did not reach StartingGrove")
		_finish()
		return
	# Let CS-02 landing lock, camera smoothing, day/night, scatter and return portal settle.
	await _tree.create_timer(3.6, true, false, true).timeout
	await _capture("normal-l1-settled.png", "l1_settled_after_real_portal")

	var move := InputEventAction.new()
	move.action = "move_right"
	move.pressed = true
	Input.parse_input_event(move)
	await _tree.create_timer(0.55, true, false, true).timeout
	move.pressed = false
	Input.parse_input_event(move)
	await _tree.create_timer(0.45, true, false, true).timeout
	await _capture("normal-l1-moved.png", "l1_after_real_movement")
	# Exercise the return path through real Player physics, never teleport in L1.
	var grove := _tree.current_scene
	var session := grove.get_node("GroveSession") as GroveSession
	var controller := session.get("_return_portal") as ReturnPortalController
	var traveler := grove.get_node("YSortLayer/Player") as Player
	var stand := controller.portal.entry_stand_point()
	# With semantic blockers a straight segment can cross a solid boulder. Use the
	# same live navigation as gameplay, and still require actual physics/apron arrival.
	var touch := grove.get_node("TouchController") as TouchController
	var ground := grove.get_node("Ground") as MapLoader
	if not touch.move_to(ground.world_to_cell(stand)):
		_fail("return portal has no live tap route")
		_finish()
		return
	var deadline := Time.get_ticks_msec() + 15000
	while traveler.global_position.distance_to(stand) > 10.0 and Time.get_ticks_msec() < deadline:
		await _tree.create_timer(0.1, true, false, true).timeout
	await _physics_frames(4)
	if not controller.portal.is_player_in_entry_zone():
		_fail("real physics walk could not reach return portal apron")
	else:
		await _capture("normal-l1-return-apron.png", "return_apron_after_real_player_path")
		await _action("interact")
		if not await _wait_scene_seconds("HomeIsland", 10.0):
			_fail("real return interact did not reach HomeIsland")
		else:
			await _tree.create_timer(1.0, true, false, true).timeout
			await _capture("normal-home-returned.png", "home_after_real_return_portal")
	_finish()


var _draw_received := false
func _await_rendered_frame() -> bool:
	_draw_received=false
	var receipt:=func(): _draw_received=true
	RenderingServer.frame_post_draw.connect(receipt,CONNECT_ONE_SHOT)
	var deadline:=Time.get_ticks_msec()+2000
	while not _draw_received and Time.get_ticks_msec()<deadline: await _tree.process_frame
	if not _draw_received:
		print("CAPTURE_FORCE_DRAW normal-root; no state injection")
		RenderingServer.force_draw()
		deadline=Time.get_ticks_msec()+1000
		while not _draw_received and Time.get_ticks_msec()<deadline: await _tree.process_frame
	if RenderingServer.frame_post_draw.is_connected(receipt): RenderingServer.frame_post_draw.disconnect(receipt)
	return _draw_received
func _capture(filename: String, phase: String) -> void:
	if not await _await_rendered_frame():
		_fail("no rendered frame received for "+phase)
		return
	var image := _tree.root.get_texture().get_image()
	var size := image.get_size() if image != null else Vector2i.ZERO
	if size != TARGET_SIZE:
		_fail("capture pixel size mismatch actual=%s expected=%s" % [size, TARGET_SIZE])
	var path := _out_dir.path_join(filename)
	var error := ERR_CANT_CREATE if image == null else image.save_png(path)
	if error != OK:
		_fail("image write failed path=%s err=%d" % [path, error])
	var record := _runtime_record(phase)
	record["path"] = path
	record["image_size"] = [size.x, size.y]
	record["save_error"] = error
	_records.append(record)
	print("L1_CAPTURE phase=%s path=%s state=%s" % [phase, path, JSON.stringify(record)])


func _runtime_record(phase: String) -> Dictionary:
	var scene := _tree.current_scene
	var out := {
		"phase": phase,
		"scene": scene.name if scene != null else "",
		"capture_kind": "normal_root_title_new_game_home_real_portal_with_test_apron_teleport",
		"test_state_injection": "Opening._unhandled_input(ui_cancel) called directly; player teleported to nature.entry_stand_point before real interact input",
		"save_present": SaveManager.has_save(),
		"pending_load": SaveManager.pending_load,
		"world_context": WorldContext.to_dict(),
		"portal_states": GameState.portal_states.duplicate(),
		"control_locked": GameState.control_locked(),
	}
	if scene == null or scene.name != "StartingGrove":
		return out
	var loader := scene.get_node("Ground") as MapLoader
	var player := scene.get_node("YSortLayer/Player") as Node2D
	var camera := player.get_node("Camera2D") as Camera2D
	var day_night := scene.get_node("DayNight") as CanvasModulate
	out.merge({
		"map_dimensions": [loader.width, loader.height],
		"spawn_cell": [loader.spawn_cell.x, loader.spawn_cell.y],
		"player_position": [snappedf(player.global_position.x, 0.001), snappedf(player.global_position.y, 0.001)],
		"camera_position": [snappedf(camera.global_position.x, 0.001), snappedf(camera.global_position.y, 0.001)],
		"camera_zoom": [camera.zoom.x, camera.zoom.y],
		"camera_limits": [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom],
		"canvas_modulate": day_night.color.to_html(true),
		"tile_count": loader.get_used_cells().size(),
		"object_spawn_count": loader.object_spawns.size(),
		"return_portal_count": _count_return_portals(scene),
	})
	return out


func _count_return_portals(scene: Node) -> int:
	var session := scene.get_node_or_null("GroveSession") as GroveSession
	if session == null:
		return 0
	var controller := session.get("_return_portal") as ReturnPortalController
	return 1 if is_instance_valid(controller) and is_instance_valid(controller.portal) else 0


func _finish() -> void:
	var manifest := {
		"capture_kind": "normal_root_title_new_game_home_real_portal_with_test_apron_teleport",
		"expected_viewport": [TARGET_SIZE.x, TARGET_SIZE.y],
		"records": _records,
		"failed": _failed,
	}
	var path := _out_dir.path_join("normal-l1-runtime-state.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failed = true
		push_error("L1_CAPTURE: manifest open failed: %s" % path)
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			_failed = true
			push_error("L1_CAPTURE: manifest write failed: %s" % path)
	print("L1_CAPTURE_DONE manifest=%s failed=%s" % [path, _failed])
	_tree.quit(1 if _failed else 0)


func _click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	_tree.root.push_input(press, true)
	await _tree.process_frame
	var release := InputEventMouseButton.new()
	release.position = point
	release.global_position = point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	_tree.root.push_input(release, true)
	await _tree.process_frame


func _action(action_name: String) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	_tree.root.push_input(press, true)
	await _tree.process_frame
	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	_tree.root.push_input(release, true)
	await _tree.process_frame


func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _wait_scene(scene_name: String, max_frames: int) -> bool:
	for _index in range(max_frames):
		if _tree.current_scene != null and _tree.current_scene.name == scene_name:
			return true
		await _tree.process_frame
	return false


func _wait_scene_seconds(scene_name: String, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _tree.current_scene != null and _tree.current_scene.name == scene_name:
			return true
		await _tree.process_frame
	return false


func _frames(count: int) -> void:
	for _index in range(count):
		await _tree.process_frame


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await _tree.physics_frame


func _fail(message: String) -> void:
	_failed = true
	push_error("L1_CAPTURE: " + message)
