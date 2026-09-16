extends Node
## Acceptance contract for tangible placed-object world art.
## Run headless; exercises the real PlacedObject class and real imported textures.

const ART_CATALOG := "res://scripts/world/placed_object_art.gd"
const EXPECTED_WORLD_PREFIX := "res://assets/objects/placed/"
const PROBE_WORLD_ID := "D29" # 화분: representative authored world object
const PROBE_FALLBACK_ID := "D92" # 빈 액자: intentionally unresolved in this increment

var _fail := 0


func _check(label: String, condition: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if condition else "FAIL", label,
		("  (%s)" % detail) if detail != "" else ""])
	if not condition:
		_fail += 1


func _ready() -> void:
	print("=== WORLD OBJECT PRESENCE CONTRACT ===")
	await _test_world_art_probe()
	await _test_fallback_and_gameplay_contracts()
	_test_catalog_contract()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _settle_spawn(object: PlacedObject) -> void:
	add_child(object)
	await get_tree().process_frame
	await get_tree().create_timer(0.28).timeout


func _test_world_art_probe() -> void:
	var object := PlacedObject.new()
	object.setup(PROBE_WORLD_ID, Vector2i(7, 9))
	object.position = Vector2(321, 456)
	await _settle_spawn(object)
	var path := String(object.texture.resource_path) if object.texture != null else ""
	_check("D29 renders from placed world-art resources",
		path.begins_with(EXPECTED_WORLD_PREFIX), path)
	_check("D29 is not a scaled 48x48 codex icon",
		object.texture != null and object.texture.get_width() >= 96 and object.texture.get_height() >= 96,
		str(object.texture.get_size()) if object.texture != null else "null")
	_check("world art uses native world scale", object.scale.is_equal_approx(Vector2.ONE), str(object.scale))
	_check("world art bottom-center is the placement origin",
		object.texture != null and is_equal_approx(object.offset.y, -float(object.texture.get_height()) * 0.5),
		"offset=%s height=%s" % [object.offset, object.texture.get_height() if object.texture != null else 0])
	_check("ready/tween preserves placement position", object.position.is_equal_approx(Vector2(321, 456)), str(object.position))
	_check("placed world art remains y-sort enabled", object.y_sort_enabled)
	object.free()


func _test_fallback_and_gameplay_contracts() -> void:
	var fallback := PlacedObject.new()
	fallback.setup(PROBE_FALLBACK_ID, Vector2i(11, 13))
	await _settle_spawn(fallback)
	_check("unresolved item explicitly falls back to its codex icon",
		fallback.texture == ItemDB.icon(PROBE_FALLBACK_ID), String(fallback.texture.resource_path))
	_check("fallback keeps legacy icon scale",
		fallback.scale.is_equal_approx(Vector2(PlacedObject.WORLD_SCALE, PlacedObject.WORLD_SCALE)), str(fallback.scale))
	_check("fallback keeps legacy icon lift", fallback.offset.is_equal_approx(Vector2(0, -14)), str(fallback.offset))
	_check("fallback keeps original id/cell save payload",
		fallback.to_dict() == {"item_id": PROBE_FALLBACK_ID, "cell": [11, 13]}, str(fallback.to_dict()))
	fallback.free()

	var wall := PlacedObject.new()
	wall.setup("D46", Vector2i(5, 6))
	await _settle_spawn(wall)
	var body: StaticBody2D = null
	for child in wall.get_children():
		if child is StaticBody2D:
			body = child
			break
	var circle: CircleShape2D = null
	if body != null and body.get_child_count() > 0:
		var collision := body.get_child(0) as CollisionShape2D
		if collision != null:
			circle = collision.shape as CircleShape2D
	_check("blocking footprint/collision remains present", body != null)
	_check("blocking collision radius remains unchanged",
		circle != null and is_equal_approx(circle.radius, PlacedObject.BLOCK_RADIUS),
		str(circle.radius) if circle != null else "null")
	wall.free()


func _test_catalog_contract() -> void:
	var exists := ResourceLoader.exists(ART_CATALOG)
	_check("world-art catalog resource exists", exists)
	if not exists:
		return
	var catalog: GDScript = load(ART_CATALOG)
	var ids: Array = catalog.call("world_asset_ids")
	_check("bounded increment has substantial explicit coverage", ids.size() >= 24, "mapped=%d" % ids.size())
	var seen := {}
	var bad: Array[String] = []
	for id_variant in ids:
		var id := String(id_variant)
		if seen.has(id) or not ItemDB.has_item(id):
			bad.append(id)
			continue
		seen[id] = true
		var pclass := ItemDB.placement_class(id)
		var path := String(catalog.call("texture_path", id))
		if (pclass != "structure" and pclass != "decor") or not path.begins_with("res://assets/objects/") or not ResourceLoader.exists(path):
			bad.append(id)
			continue
		var tex := load(path) as Texture2D
		if tex == null or (tex.get_width() == 48 and tex.get_height() == 48):
			bad.append(id)
	_check("every mapping is unique, persistent, loadable world art", bad.is_empty(), str(bad))
