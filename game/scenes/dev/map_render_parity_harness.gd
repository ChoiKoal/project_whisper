extends Node
## Map-first render parity contract: gameplay default must preserve the pixel grid and
## expose enough topology to be a valid map-review baseline. Uses the real camera script.

const CAMERA_SCRIPT := "res://scripts/world/camera_zoom.gd"
const HOME := "res://scenes/world/home_island.tscn"
const ISOLATION_GUARD := preload("res://scenes/dev/isolated_harness_guard.gd")

var _fail := 0


func _check(label: String, condition: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if condition else "FAIL", label,
		("  (%s)" % detail) if detail != "" else ""])
	if not condition:
		_fail += 1


func _ready() -> void:
	print("=== MAP RENDER PARITY CONTRACT ===")
	if not ISOLATION_GUARD.require_isolated_user_data("map_render_parity_harness"):
		get_tree().quit(86)
		return
	await _test_camera_pixel_grid()
	await _test_real_home_scene_contracts()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _test_camera_pixel_grid() -> void:
	var script := load(CAMERA_SCRIPT) as GDScript
	var camera := Camera2D.new()
	camera.set_script(script)
	add_child(camera)
	await get_tree().process_frame
	_check("settled gameplay defaults to native integer zoom 1.0",
		camera.zoom.is_equal_approx(Vector2.ONE), str(camera.zoom))

	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	camera.call("_unhandled_input", wheel_up)
	_check("wheel-up selects the next integer zoom (2.0)",
		camera.zoom.is_equal_approx(Vector2(2, 2)), str(camera.zoom))

	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	camera.call("_unhandled_input", wheel_down)
	_check("wheel-down returns to native integer zoom (1.0)",
		camera.zoom.is_equal_approx(Vector2.ONE), str(camera.zoom))
	camera.free()


func _test_real_home_scene_contracts() -> void:
	SaveManager.delete_save()
	SaveManager.new_game()
	var home_scene := load(HOME) as PackedScene
	var home: Node = home_scene.instantiate()
	add_child(home)
	await get_tree().process_frame
	await get_tree().process_frame
	var loader := home.get_node("Ground") as MapLoader
	var player := home.get_node("YSortLayer/Player") as Node2D
	var day_night := home.get_node("DayNight") as CanvasModulate
	_check("home uses authored 31x25 source layout", loader.width == 31 and loader.height == 25,
		"%dx%d" % [loader.width, loader.height])
	_check("fresh spawn cell is preserved", loader.spawn_cell == Vector2i(10, 9), str(loader.spawn_cell))
	_check("fresh player remains at authored spawn", player.global_position.is_equal_approx(loader.cell_center_world(loader.spawn_cell)),
		"player=%s expected=%s" % [player.global_position, loader.cell_center_world(loader.spawn_cell)])
	_check("home remains a fixed twilight world", String(day_night.get("fixed_tone")) == "#8a86b8",
		String(day_night.get("fixed_tone")))
	_check("new game keeps canonical portal progression",
		GameState.portal_states.get("nature") == GameState.PORTAL_FLICKERING
		and GameState.portal_states.get("science") == GameState.PORTAL_DORMANT
		and GameState.portal_states.get("machine") == GameState.PORTAL_DORMANT
		and GameState.portal_states.get("magic") == GameState.PORTAL_DORMANT
		and GameState.portal_states.get("divinity") == GameState.PORTAL_DORMANT,
		str(GameState.portal_states))
	home.queue_free()
