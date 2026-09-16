extends Node
## Synthetic v2 placed-object conflict, isolated disk round-trip only.
const GUARD := preload("res://scenes/dev/isolated_harness_guard.gd")
var scene: Node
var failures := 0
var entered := false

func _ready() -> void:
	call_deferred("_run")

func check(label: String, ok: bool) -> void:
	print("[PASS] " + label if ok else "[FAIL] " + label)
	if not ok: failures += 1

func frames(n: int) -> void:
	for i in range(n): await get_tree().process_frame

func boot() -> void:
	scene = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	await frames(12)

func teardown() -> void:
	SaveManager.unregister_world()
	scene.queue_free()
	await frames(3)

func _run() -> void:
	if not GUARD.require_isolated_user_data("l1_legacy_placement_harness"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	WorldContext.current_scene = "grove"
	WorldContext.arrival_mode = ""
	await boot()
	# D08 was legal on the old ordinary grass at both redesigned landmark positions.
	check("fixture is a blocking structure legal on old grass", ItemDB.placement_blocks("D08"))
	SaveManager.call("_apply_placed_objects", [
		{"item_id":"D08", "cell":[16,35]}, {"item_id":"D08", "cell":[8,32]}
	])
	SaveManager.save_game()
	await teardown()
	SaveManager.pending_load = true
	await boot()
	var loader := scene.get_node("Ground") as MapLoader
	var session := scene.get_node("GroveSession") as GroveSession
	var ctrl = session.get("_return_portal") as ReturnPortalController
	var placed_cells: Array[Vector2i] = []
	for obj in get_tree().get_nodes_in_group("placed_object"):
		if scene.is_ancestor_of(obj): placed_cells.append((obj as PlacedObject).cell)
	check("both saved structures restored without moving or refund", placed_cells.size()==2 and Vector2i(16,35) in placed_cells and Vector2i(8,32) in placed_cells)
	check("cauldron yields new cell to legacy placement", loader.cauldron_cell not in placed_cells)
	check("return portal yields new cell to legacy placement", loader.world_to_cell(ctrl.portal.global_position) not in placed_cells)
	check("cauldron remains on walkable terrain", loader.is_cell_walkable(loader.cauldron_cell))
	var apron_cell := loader.world_to_cell(ctrl.portal.entry_stand_point())
	print("LEGACY_PORTAL apron_cell=",apron_cell," walkable=",loader.is_cell_walkable(apron_cell))
	check("portal approach is walkable terrain",loader.is_cell_walkable(apron_cell))
	# Count evidence from the exact actual controller, not a nonexistent group.
	var watcher = load("res://scenes/dev/l1_gameplay_capture.gd").new()
	check("capture counts real return portal", watcher.has_method("_count_return_portals") and watcher.call("_count_return_portals",scene)==1)
	watcher.free()
	# Real apron physics and keyboard handler; disconnect scene travel for this unit assertion.
	ctrl.entered.disconnect(Callable(session,"_on_return_portal"))
	ctrl.entered.connect(func(): entered=true)
	var player := scene.get_node("YSortLayer/Player") as Node2D
	player.global_position = ctrl.portal.entry_stand_point()
	GameState.time_running = true
	for i in range(6): await get_tree().physics_frame
	ctrl._process(0.1)
	check("restored return portal apron remains reachable", ctrl.portal.is_player_in_entry_zone())
	var press := InputEventAction.new()
	press.action="interact"
	press.pressed=true
	ctrl._input(press)
	check("real return keyboard handler emits entered",entered)
	await teardown()
	print("L1_LEGACY_PLACEMENT failures=",failures)
	get_tree().quit(1 if failures else 0)
