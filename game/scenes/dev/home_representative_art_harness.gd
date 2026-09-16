extends Node
## Recovery representative-art contract for the Home maker yard.
## RED before implementation: no maker symbols, assets, or generic ground/world-deco records.

const HOME := "res://scenes/world/home_island.tscn"
const ISOLATION_GUARD := preload("res://scenes/dev/isolated_harness_guard.gd")
const EXPECTED_CELLS := {
	"i": Vector2i(5, 13),
	"m": Vector2i(8, 12),
	"w": Vector2i(9, 14),
	"e": Vector2i(10, 15),
}
const WORLD_IDS := ["maker_inputs", "maker_build", "maker_whisper"]
const WORLD_ASSETS := {
	"maker_inputs": "res://assets/objects/home_maker_inputs.png",
	"maker_build": "res://assets/objects/home_maker_build.png",
	"maker_whisper": "res://assets/objects/home_maker_whisper.png",
}
const GROUND_ASSET := "res://assets/objects/home_maker_yard.png"

var _fail := 0
var _scene: Node


func _check(label: String, condition: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if condition else "FAIL", label,
		("  (%s)" % detail) if detail != "" else ""])
	if not condition:
		_fail += 1


func _ready() -> void:
	print("=== HOME REPRESENTATIVE ART CONTRACT ===")
	if not ISOLATION_GUARD.require_isolated_user_data("home_representative_art_harness"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	SaveManager.delete_save()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	WorldContext.arrival_mode = ""
	SaveManager.pending_load = false
	_scene = load(HOME).instantiate()
	add_child(_scene)
	for _frame in range(8):
		await get_tree().process_frame
	_test_core_invariants()
	_test_maker_layout_and_ground_art()
	_test_world_props()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	SaveManager.unregister_world()
	_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(_fail)


func _loader() -> MapLoader:
	return _scene.get_node("Ground") as MapLoader


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _test_core_invariants() -> void:
	var loader := _loader()
	_check("home dimensions remain 31x25", loader.width == 31 and loader.height == 25,
		"%dx%d" % [loader.width, loader.height])
	_check("spawn id/cell stays compatible", loader.spawn_cell == Vector2i(10, 9), str(loader.spawn_cell))
	_check("cauldron id/cell stays compatible", loader.cauldron_cell == Vector2i(7, 12), str(loader.cauldron_cell))
	_check("observation id/cell stays compatible", loader.observation_cell == Vector2i(14, 11), str(loader.observation_cell))
	_check("portal ids/cells remain unchanged", loader.portal_cells == {
		"nature": Vector2i(7, 5), "science": Vector2i(9, 4), "machine": Vector2i(10, 3),
		"magic": Vector2i(12, 4), "divinity": Vector2i(13, 5),
	}, str(loader.portal_cells))
	for cell in EXPECTED_CELLS.values():
		_check("maker cell remains walkable %s" % cell, loader.is_cell_walkable(cell))


func _test_maker_layout_and_ground_art() -> void:
	var loader := _loader()
	for symbol in EXPECTED_CELLS:
		var cells: Array = loader.cells_with_symbol(symbol)
		_check("maker symbol %s has one authored anchor" % symbol,
			cells.size() == 1 and cells[0] == EXPECTED_CELLS[symbol], str(cells))
	_check("maker-yard ground asset exists", ResourceLoader.exists(GROUND_ASSET))
	var has_store := _has_property(loader, "ground_deco_nodes")
	_check("MapLoader exposes generic ground-deco records", has_store)
	if not has_store:
		return
	var records: Dictionary = loader.get("ground_deco_nodes")
	_check("maker-yard ground decal spawned once", records.size() == 1, str(records.keys()))
	if records.is_empty():
		return
	var record: Dictionary = records.values()[0]
	var node := record.get("node") as Sprite2D
	_check("ground decal stays under world objects", node != null and node.get_parent() == loader and node.z_index == 1)
	_check("ground decal is a substantial authored terrain plate",
		node != null and node.texture != null and node.texture.get_width() >= 896 and node.texture.get_height() >= 320,
		str(node.texture.get_size()) if node != null and node.texture != null else "null")


func _test_world_props() -> void:
	var loader := _loader()
	var ysort := _scene.get_node("YSortLayer") as Node2D
	var world_nodes: Dictionary = {}
	for world_id in WORLD_IDS:
		var asset_path: String = WORLD_ASSETS[world_id]
		_check("%s authored world asset exists" % world_id, ResourceLoader.exists(asset_path), asset_path)
		var found: Dictionary = {}
		for key in loader.l2_object_nodes:
			var candidate: Dictionary = loader.l2_object_nodes[key]
			var spec: Dictionary = candidate.get("spec", {})
			if String(spec.get("l2_id", "")) == world_id:
				found = candidate
				break
		_check("%s spawned from data-driven worlddeco" % world_id,
			not found.is_empty() and String((found.get("spec", {}) as Dictionary).get("kind", "")) == "worlddeco")
		if found.is_empty():
			continue
		var node := found.get("node") as Sprite2D
		world_nodes[world_id] = node
		_check("%s uses native world scale and Y-sort parent" % world_id,
			node != null and node.get_parent() == ysort and node.scale.is_equal_approx(Vector2.ONE))
		_check("%s has readable non-icon dimensions" % world_id,
			node != null and node.texture != null and node.texture.get_width() >= 128 and node.texture.get_height() >= 128,
			str(node.texture.get_size()) if node != null and node.texture != null else "null")
		_check("%s preserves transparent bottom clearance for a complete ground silhouette" % world_id,
			node != null and node.texture != null and _bottom_clearance(node.texture) >= 4,
			"clearance=%d" % (_bottom_clearance(node.texture) if node != null and node.texture != null else -1))
		var blocks := false
		if node != null:
			for child in node.get_children():
				if child is StaticBody2D:
					blocks = true
		_check("%s remains nonblocking for save/progression reachability" % world_id, not blocks)
	var cauldron_x := loader.cell_center_world(loader.cauldron_cell).x
	var cauldron_y := loader.cell_center_world(loader.cauldron_cell).y
	var inputs := world_nodes.get("maker_inputs") as Sprite2D
	var build := world_nodes.get("maker_build") as Sprite2D
	var whisper := world_nodes.get("maker_whisper") as Sprite2D
	_check("maker stations read left-to-right as inputs → cauldron → Build → Whisper",
		inputs != null and build != null and whisper != null
		and inputs.position.x < cauldron_x and cauldron_x < build.position.x and build.position.x < whisper.position.x,
		"inputs=%s cauldron=%.0f build=%s whisper=%s" % [
			inputs.position.x if inputs != null else -1, cauldron_x,
			build.position.x if build != null else -1, whisper.position.x if whisper != null else -1])
	_check("inputs and cauldron keep distinct readable footprints",
		inputs != null and cauldron_x - inputs.position.x >= 128.0,
		"gap=%s" % (cauldron_x - inputs.position.x if inputs != null else -1))
	_check("Build and Whisper stay one readable station-step apart",
		build != null and whisper != null and whisper.position.x - build.position.x <= 256.0,
		"gap=%s" % (whisper.position.x - build.position.x if build != null and whisper != null else -1))
	_check("Build and Whisper sit below the dais instead of crossing the player focal",
		build != null and whisper != null and build.position.y >= cauldron_y + 64.0 and whisper.position.y >= cauldron_y + 64.0,
		"cauldron_y=%.0f build_y=%s whisper_y=%s" % [cauldron_y,
			build.position.y if build != null else -1, whisper.position.y if whisper != null else -1])


func _bottom_clearance(texture: Texture2D) -> int:
	var image := texture.get_image()
	if image == null:
		return -1
	for y in range(image.get_height() - 1, -1, -1):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				return image.get_height() - 1 - y
	return image.get_height()
