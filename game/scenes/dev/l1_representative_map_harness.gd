extends Node
## First-region representative map contract: unclutter the arrival, expose a dirt first-loop,
## preserve every canonical landmark, and move only the procedural return portal off the cauldron.

const GROVE := "res://scenes/world/starting_grove.tscn"
const ISOLATION_GUARD := preload("res://scenes/dev/isolated_harness_guard.gd")
const RETURN_CELL := Vector2i(8, 30)
const FIRST_FLOWER := Vector2i(14, 35)
const CAULDRON_CELL := Vector2i(16, 35)
const HARVEST_MARKER := "res://assets/objects/l1_first_harvest.png"
const DIRT_LOOP := [
	Vector2i(12, 31), Vector2i(13, 31), Vector2i(14, 31),
	Vector2i(14, 32), Vector2i(15, 32), Vector2i(16, 32), Vector2i(17, 32),
	Vector2i(13, 33), Vector2i(14, 33), Vector2i(15, 33), Vector2i(16, 33), Vector2i(17, 33),
	Vector2i(13, 34), Vector2i(14, 34), Vector2i(15, 34), Vector2i(16, 34), Vector2i(17, 34), Vector2i(8, 32),
	Vector2i(13, 35), Vector2i(15, 35), Vector2i(16, 35), Vector2i(17, 35),
	Vector2i(13, 36),
]

var _fail := 0
var _scene: Node


func _check(label: String, condition: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if condition else "FAIL", label,
		("  (%s)" % detail) if detail != "" else ""])
	if not condition:
		_fail += 1


func _ready() -> void:
	print("=== L1 REPRESENTATIVE MAP CONTRACT ===")
	if not ISOLATION_GUARD.require_isolated_user_data("l1_representative_map_harness"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	SaveManager.delete_save()
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	WorldContext.arrival_mode = "portal_arrival"
	WorldContext.travel_layer = "nature"
	_scene = load(GROVE).instantiate()
	add_child(_scene)
	for _frame in range(10):
		await get_tree().process_frame
	_test_landmark_compatibility()
	_test_authored_first_loop()
	_test_contextual_prompts()
	_test_return_portal_separation()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	SaveManager.unregister_world()
	_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(_fail)


func _loader() -> MapLoader:
	return _scene.get_node("Ground") as MapLoader


func _test_landmark_compatibility() -> void:
	var loader := _loader()
	_check("L1 dimensions remain 40x40", loader.width == 40 and loader.height == 40)
	_check("spawn cell remains (12,32)", loader.spawn_cell == Vector2i(12, 32), str(loader.spawn_cell))
	_check("cauldron id moves after the first harvest instead of facing the empty-handed spawn",
		loader.cauldron_cell == CAULDRON_CELL, str(loader.cauldron_cell))
	_check("rest stump cell remains (12,33)", loader.stump_cell == Vector2i(12, 33), str(loader.stump_cell))
	_check("first authored flower remains an I5 gatherable source", _has_object_spawn(FIRST_FLOWER, "F"))
	_check("world-tree cells remain four", loader.world_tree_cells.size() == 4, str(loader.world_tree_cells))
	_check("stepping-slot count remains three", loader.stepping_slot_cells.size() == 3, str(loader.stepping_slot_cells))
	_check("cauldron stays reachable but outside the spawn interaction cell",
		loader.cell_center_world(loader.cauldron_cell).distance_to(loader.cell_center_world(loader.spawn_cell)) >= 512.0)


func _test_authored_first_loop() -> void:
	var loader := _loader()
	var wrong: Array[String] = []
	for cell in DIRT_LOOP:
		if loader.get_cell_source_id(cell) != 1 or not loader.is_cell_walkable(cell):
			wrong.append("%s:src%d" % [cell, loader.get_cell_source_id(cell)])
	_check("spawn→first flower→north route is authored walkable dirt", wrong.is_empty(), str(wrong))
	_check("first flower stays on contrasting grass", loader.get_cell_source_id(FIRST_FLOWER) == 2,
		"source=%d" % loader.get_cell_source_id(FIRST_FLOWER))
	_check("first-harvest authored ground marker exists", ResourceLoader.exists(HARVEST_MARKER), HARVEST_MARKER)
	var marker_found := false
	for record in loader.ground_deco_nodes.values():
		var spec: Dictionary = record.get("spec", {})
		if String(spec.get("ground_id", "")) == "first_harvest":
			marker_found = true
			break
	_check("first-harvest marker spawned below actors", marker_found, str(loader.ground_deco_nodes.keys()))
	# Dirt automatically excludes deterministic scatter on itself and adjacent cells.
	var crowded := 0
	var nearby: Array[String] = []
	for entry in loader.object_spawns:
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		if cell != FIRST_FLOWER and cell.distance_squared_to(FIRST_FLOWER) <= 9:
			crowded += 1
			nearby.append("%s:%s" % [cell, entry.get("symbol", "")])
	_check("first flower has a clear one-cell reading pocket", crowded == 0,
		"nearby_objects=%d %s" % [crowded, nearby])


func _test_contextual_prompts() -> void:
	var loader := _loader()
	var interaction := _scene.get_node("Interaction") as InteractionController
	interaction.set("_target_object", loader.rest_stump)
	_check("rest stump prompt says rest, never combine", String(interaction.call("_prompt_text")) == "E 쉬기",
		String(interaction.call("_prompt_text")))
	var cauldron: Cauldron = null
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Cauldron and String((node as Cauldron).object_id) == "cauldron":
			cauldron = node as Cauldron
			break
	interaction.set("_target_object", cauldron)
	_check("cauldron prompt remains combine", cauldron != null and String(interaction.call("_prompt_text")) == "E 조합",
		String(interaction.call("_prompt_text")))


func _test_return_portal_separation() -> void:
	var loader := _loader()
	var session := _scene.get_node("GroveSession") as GroveSession
	var controller = session.get("_return_portal") as ReturnPortalController
	var portal: Portal = controller.portal if controller != null else null
	var cell := loader.world_to_cell(portal.global_position) if portal != null else Vector2i(-1, -1)
	_check("return portal moved to dedicated west pad", cell == RETURN_CELL, "cell=%s" % cell)
	_check("return portal no longer overlaps spawn/cauldron/stump cluster",
		portal != null and portal.global_position.distance_to(loader.cell_center_world(loader.cauldron_cell)) >= 768.0,
		"distance=%.1f" % (portal.global_position.distance_to(loader.cell_center_world(loader.cauldron_cell)) if portal != null else -1.0))
	_check("return portal remains OPEN and functional", portal != null and portal.is_enterable()
		and GameState.portal_states.get("return") == GameState.PORTAL_OPEN,
		str(GameState.portal_states))


func _has_object_spawn(cell: Vector2i, symbol: String) -> bool:
	for entry in _loader().object_spawns:
		if entry.get("cell", Vector2i(-1, -1)) == cell and String(entry.get("symbol", "")) == symbol:
			return true
	return false
