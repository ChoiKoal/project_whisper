extends Node
## Test-only normal-viewport evidence watcher.
## Uses real Control mouse input and real opening ui_cancel input, then reads the root Window.

const TITLE := "res://scenes/ui/title.tscn"
const TARGET_SIZE := Vector2i(1600, 900)
const ISOLATION_GUARD := preload("res://scenes/dev/isolated_harness_guard.gd")

var _out_dir := ""
var _records: Array[Dictionary] = []
var _failed := false
var _viewport_mismatch_reported := false
var _capture_pixel_size := Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ISOLATION_GUARD.require_isolated_user_data("map_parity_capture_watcher"):
		get_tree().quit(86)
		return
	_out_dir = OS.get_environment("MAP_PARITY_EVIDENCE_DIR")
	if _out_dir == "":
		_out_dir = ProjectSettings.globalize_path("user://map-parity")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	if mkdir_error != OK:
		push_error("MAP_PARITY_CAPTURE: evidence directory unavailable: %s (err=%d)" % [_out_dir, mkdir_error])
		get_tree().quit(87)
		return
	call_deferred("_run")


func _run() -> void:
	# This HOME is isolated by the command. Delete only that fake-home save.
	SaveManager.delete_save()
	await _frames(2)
	get_tree().change_scene_to_file(TITLE)
	if not await _wait_scene("Title", 3.0):
		_fail("title scene did not boot")
		_finish()
		return
	await get_tree().create_timer(1.45, true, false, true).timeout
	await _capture("normal-title-before.png", "title")

	var new_game := _find_button(get_tree().current_scene, "새로 시작")
	if new_game == null:
		_fail("new-game button not found")
		_finish()
		return
	await _click_control(new_game)
	if not await _wait_scene("Opening", 3.0):
		_fail("real new-game click did not reach Opening")
		_finish()
		return
	await _frames(12)
	await _capture("normal-opening-before.png", "opening")

	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _frames(2)
	cancel.pressed = false
	Input.parse_input_event(cancel)
	if not await _wait_scene("HomeIsland", 6.0):
		_fail("real opening input did not reach HomeIsland")
		_finish()
		return

	# Capture the camera reveal the player actually sees, then its settled gameplay state.
	await get_tree().create_timer(1.20, true, false, true).timeout
	await _capture("normal-home-reveal-before.png", "fresh_reveal")
	await get_tree().create_timer(4.20, true, false, true).timeout
	await _capture("normal-home-settled-before.png", "settled_gameplay")

	# One-variable diagnostic only: same scene/player/camera center, integer 1.0 zoom.
	# This is explicitly a probe, not normal-gameplay provenance.
	var home := get_tree().current_scene
	var live_camera := home.get_node("YSortLayer/Player/Camera2D") as Camera2D
	var prior_zoom := live_camera.zoom
	live_camera.zoom = Vector2.ONE
	await _frames(3)
	await _capture("probe-home-integer-zoom1.png", "diagnostic_integer_zoom_1")
	live_camera.zoom = prior_zoom
	await _frames(3)

	# Exercise the normal player input path and capture the same live follow camera after movement.
	var move := InputEventAction.new()
	move.action = "move_right"
	move.pressed = true
	Input.parse_input_event(move)
	await get_tree().create_timer(0.55, true, false, true).timeout
	move.pressed = false
	Input.parse_input_event(move)
	await get_tree().create_timer(0.45, true, false, true).timeout
	await _capture("normal-home-moved-before.png", "live_after_input")
	_finish()


func _click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	print("MAP_PARITY_INPUT click text=%s point=%s rect=%s" % [
		(control as Button).text if control is Button else control.name,
		point, control.get_global_rect()])
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_tree().root.push_input(motion, true)
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	get_tree().root.push_input(press, true)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = point
	release.global_position = point
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	get_tree().root.push_input(release, true)
	await get_tree().process_frame


func _capture(filename: String, phase: String) -> void:
	await RenderingServer.frame_post_draw
	var root := get_tree().root
	var actual_size := Vector2i(root.get_visible_rect().size.round())
	if actual_size != TARGET_SIZE:
		_failed = true
		if not _viewport_mismatch_reported:
			_viewport_mismatch_reported = true
			push_error("MAP_PARITY_CAPTURE: root viewport mismatch actual=%s expected=%s" % [actual_size, TARGET_SIZE])
	var image := root.get_texture().get_image()
	if image != null:
		_capture_pixel_size = image.get_size()
		if _capture_pixel_size != TARGET_SIZE:
			_failed = true
			if not _viewport_mismatch_reported:
				_viewport_mismatch_reported = true
				push_error("MAP_PARITY_CAPTURE: capture pixel size mismatch actual=%s expected=%s" % [
					_capture_pixel_size, TARGET_SIZE])
	var path := _out_dir.path_join(_tagged_filename(filename))
	var error := ERR_CANT_CREATE if image == null else image.save_png(path)
	var record := _runtime_record(phase)
	record["path"] = path
	record["save_error"] = error
	record["image_size"] = [image.get_width(), image.get_height()] if image != null else [0, 0]
	_records.append(record)
	print("MAP_PARITY_CAPTURE phase=%s path=%s err=%d state=%s" % [phase, path, error, JSON.stringify(record)])
	if error != OK:
		_failed = true


func _runtime_record(phase: String) -> Dictionary:
	var out := {
		"phase": phase,
		"scene": get_tree().current_scene.name if get_tree().current_scene != null else "",
		"root_visible_rect": _vec2(get_tree().root.get_visible_rect().size),
		"save_present": SaveManager.has_save(),
		"pending_load": SaveManager.pending_load,
		"world_context": WorldContext.to_dict(),
		"game_time": GameState.game_time,
		"portal_states": GameState.portal_states.duplicate(),
	}
	var scene := get_tree().current_scene
	if scene == null or scene.name != "HomeIsland":
		return out
	var loader := scene.get_node("Ground") as MapLoader
	var player := scene.get_node("YSortLayer/Player") as Node2D
	var camera := player.get_node("Camera2D") as Camera2D
	var day_night := scene.get_node("DayNight") as CanvasModulate
	out.merge({
		"map_dimensions": [loader.width, loader.height],
		"layout_override": loader.layout_path_override,
		"legend_override": loader.legend_path_override,
		"height_override": loader.height_path_override,
		"spawn_cell": _vec2i(loader.spawn_cell),
		"player_position": _vec2(player.global_position),
		"camera_global_position": _vec2(camera.global_position),
		"camera_zoom": _vec2(camera.zoom),
		"camera_offset": _vec2(camera.offset),
		"camera_limits": [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom],
		"camera_smoothing": camera.position_smoothing_enabled,
		"fixed_tone": String(day_night.get("fixed_tone")),
		"canvas_modulate": day_night.color.to_html(true),
		"tile_count": loader.get_used_cells().size(),
		"island_cell_count": _count_island_cells(loader),
	})
	return out


func _count_island_cells(loader: MapLoader) -> int:
	var count := 0
	for row in range(loader.height):
		for column in range(loader.width):
			if loader._is_island_cell(Vector2i(column, row)):
				count += 1
	return count


func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _wait_scene(scene_name: String, timeout_seconds: float) -> bool:
	# Frame-count timeouts raced Opening's wall-clock fade at uncapped rendering FPS.
	# Check completion before timeout: loading a scene can itself occupy the last frame.
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while true:
		if get_tree().current_scene != null and get_tree().current_scene.name == scene_name:
			return true
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return false


func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _vec2(value: Vector2) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001)]


func _vec2i(value: Vector2i) -> Array:
	return [value.x, value.y]


func _tagged_filename(filename: String) -> String:
	var tag := _safe_tag(OS.get_environment("MAP_PARITY_TAG"))
	if tag == "" or tag == "before":
		return filename
	if filename.ends_with("-before.png"):
		return filename.trim_suffix("-before.png") + "-" + tag + ".png"
	if filename.ends_with(".png"):
		return filename.trim_suffix(".png") + "-" + tag + ".png"
	return filename + "-" + tag


func _safe_tag(raw: String) -> String:
	var out := ""
	for index in range(raw.length()):
		var code := raw.unicode_at(index)
		var character := raw.substr(index, 1)
		var ascii_alphanumeric := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if ascii_alphanumeric or character == "-" or character == "_":
			out += character
	return out.left(48)


func _fail(message: String) -> void:
	_failed = true
	push_error("MAP_PARITY_CAPTURE: " + message)


func _finish() -> void:
	var logical_size := Vector2i(get_tree().root.get_visible_rect().size.round())
	var actual_size := _capture_pixel_size if _capture_pixel_size != Vector2i.ZERO else logical_size
	var manifest := {
		"capture_kind": "normal_root_window_via_real_title_and_input_flow",
		"project_viewport": [actual_size.x, actual_size.y],
		"expected_viewport": [TARGET_SIZE.x, TARGET_SIZE.y],
		"logical_viewport": [logical_size.x, logical_size.y],
		"records": _records,
		"failed": _failed,
	}
	var manifest_name := "normal-runtime-state-before.json"
	var tag := _safe_tag(OS.get_environment("MAP_PARITY_TAG"))
	if tag != "" and tag != "before":
		manifest_name = "normal-runtime-state-%s.json" % tag
	var manifest_path := _out_dir.path_join(manifest_name)
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_failed = true
		push_error("MAP_PARITY_CAPTURE: manifest open failed: %s (err=%d)" % [manifest_path, FileAccess.get_open_error()])
	else:
		file.store_string(JSON.stringify(manifest, "	"))
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			_failed = true
			push_error("MAP_PARITY_CAPTURE: manifest write failed: %s (err=%d)" % [manifest_path, write_error])
		else:
			var verify := FileAccess.open(manifest_path, FileAccess.READ)
			if verify == null:
				_failed = true
				push_error("MAP_PARITY_CAPTURE: manifest readback open failed: %s" % manifest_path)
			else:
				var parsed = JSON.parse_string(verify.get_as_text())
				verify.close()
				if not parsed is Dictionary or String((parsed as Dictionary).get("capture_kind", "")) != String(manifest["capture_kind"]):
					_failed = true
					push_error("MAP_PARITY_CAPTURE: manifest readback validation failed: %s" % manifest_path)
	print("MAP_PARITY_DONE manifest=%s failed=%s" % [manifest_path, _failed])
	get_tree().quit(1 if _failed else 0)
