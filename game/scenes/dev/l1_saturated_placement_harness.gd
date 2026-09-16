extends Node
## Synthetic saturation stress, NOT evidence of a legitimate historical save.
## Disk round-trip uses only guarded fake HOME. Production code is unchanged.
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
var scene: Node
var failures := 0
func check(label: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures += 1
func boot() -> void:
	scene = load("res://scenes/world/starting_grove.tscn").instantiate()
	add_child(scene)
	for i in range(12): await get_tree().process_frame
func teardown() -> void:
	SaveManager.unregister_world()
	scene.queue_free()
	for i in range(3): await get_tree().process_frame
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	if not GUARD.require_isolated_user_data("l1_saturated_placement"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	WorldContext.current_scene = "grove"
	WorldContext.arrival_mode = ""
	await boot()
	var loader: MapLoader = scene.get_node("Ground")
	var session: GroveSession = scene.get_node("GroveSession")
	var ctrl: ReturnPortalController = session.get("_return_portal")
	var pot_cell := loader.cauldron_cell
	var portal_cell := loader.world_to_cell(ctrl.portal.global_position)
	var cells: Dictionary = {}
	# Saturate the complete walkable map: restore can legitimately move a portal
	# before a second fallback query, so just the ORIGINAL radius is insufficient.
	for cell in loader.get_used_cells():
		if loader.is_cell_walkable(cell): cells[cell] = true
	for cell in [Vector2i(13,32),Vector2i(8,30),Vector2i(12,34)]: cells[cell] = true
	var payload: Array = []
	for cell in cells:payload.append({"item_id":"D08","cell":[cell.x,cell.y]})
	SaveManager.call("_apply_placed_objects",payload)
	SaveManager.save_game()
	await teardown()
	SaveManager.pending_load = true
	await boot()
	loader = scene.get_node("Ground")
	session = scene.get_node("GroveSession")
	ctrl = session.get("_return_portal")
	var restored: Dictionary = {}
	var all_d08 := true
	for node in get_tree().get_nodes_in_group("placed_object"):
		if scene.is_ancestor_of(node):
			var object := node as PlacedObject
			restored[object.cell] = true
			if object.item_id != "D08": all_d08 = false
	check("saturated roundtrip preserves every synthetic saved cell",restored==cells and all_d08)
	var pot: Cauldron
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Cauldron and scene.is_ancestor_of(node):pot=node
	var pot_result: Vector2i = session.call("_find_landmark_cell",pot,[Vector2i(13,32)],false)
	var portal_result: Vector2i = session.call("_find_landmark_cell",ctrl.portal,[Vector2i(8,30),Vector2i(12,34)],true)
	check("cauldron saturation returns explicit invalid sentinel",pot_result==Vector2i(-1,-1))
	check("portal saturation returns explicit invalid sentinel",portal_result==Vector2i(-1,-1))
	# Derived portals are rebuilt, not saved placements: a new-game resolved cell
	# need not survive reload. The saturated retry must not assign (-1,-1).
	var loaded_pot := loader.cauldron_cell
	var loaded_portal := loader.world_to_cell(ctrl.portal.global_position)
	session.call("_ensure_landmarks_clear")
	check("failed retry leaves derived landmarks in place, never at sentinel",loader.cauldron_cell==loaded_pot and loader.world_to_cell(ctrl.portal.global_position)==loaded_portal and loaded_pot!=Vector2i(-1,-1) and loaded_portal!=Vector2i(-1,-1))
	print("SATURATION_DERIVED newgame_portal=%s loaded_portal=%s" % [portal_cell,loaded_portal])
	check("saturation is not falsely reported as a clear playable apron",not session.call("_landmark_cell_clear",portal_cell,ctrl.portal))
	print("SATURATION cells=%d preserved=%d fallback_blocked=%s failures=%d" % [cells.size(),restored.size(),pot_result==Vector2i(-1,-1) and portal_result==Vector2i(-1,-1),failures])
	await teardown()
	get_tree().quit(failures)
