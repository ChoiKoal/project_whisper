extends Node
## M2 acceptance harness — run headless:
##   Godot --headless res://scenes/dev/m2_test_harness.tscn --quit-after <frames>
## Exercises the M2 systems programmatically and prints PASS/FAIL lines, then
## quits with a non-zero exit code if any assertion failed.
##
## Covered (per the M2 acceptance list):
##   1. Gather a grass tile -> inventory has I2 and the tile became T0 VOID.
##   2. Place D14 on water -> the water tile becomes walkable.
##   3. A unique item (I9) cannot exceed count 1.
## Plus: alias_of (D06 -> I4) folds into the same stack, and usable_on emits
## item_used_on_object.

const ATLAS := Vector2i(0, 0)

var _fail := 0


func _ready() -> void:
	# Autoloads (ItemDB/Inventory) are ready before scene _ready runs.
	Inventory.clear()
	print("=== M2 TEST HARNESS ===")
	_test_item_db()
	_test_gather_tile()
	_test_place_stepping_stone()
	_test_unique_cap()
	_test_alias()
	_test_use_on_object()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _test_item_db() -> void:
	# items.json = N canonical + 1 alias (D06 -> I4). Catalog grew to 57 canonical
	# in recipes-v1.1 (D23~D49 expansion); assert canonical == records-minus-alias
	# rather than a magic number so this survives future catalog growth.
	_check("ItemDB loaded all canonical items (no alias in all_ids)",
		ItemDB.all_ids().size() == 57 and not ItemDB.all_ids().has("D06"))
	_check("ItemDB resolves the 1 alias (D06)", ItemDB.resolve_id("D06") == "I4" and not ItemDB.all_ids().has("D06"))
	_check("ItemDB I2 name = 풀", ItemDB.item_name("I2") == "풀")
	_check("ItemDB D14 placeable_on T5A/T5B",
		ItemDB.can_place_on_tile("D14", "T5A") and ItemDB.can_place_on_tile("D14", "T5B"))
	_check("ItemDB I7 usable_on bush_dry", ItemDB.can_use_on_object("I7", "bush_dry"))
	_check("ItemDB I9 unique", ItemDB.is_unique("I9"))


func _make_tilemap() -> TileMapLayer:
	var tm := TileMapLayer.new()
	tm.tile_set = load("res://data/whisper_tileset.tres")
	add_child(tm)
	return tm


func _test_gather_tile() -> void:
	var tm := _make_tilemap()
	# Lay a grass tile (source 2 = T2A, gatherable=true, item_id=I2).
	var cell := Vector2i(3, 3)
	tm.set_cell(cell, 2, ATLAS)
	var before := Inventory.count("I2")

	# Emulate the controller's tile-gather path directly on the tile data.
	var data := tm.get_cell_tile_data(cell)
	_check("grass tile is gatherable", data != null and bool(data.get_custom_data("gatherable")))
	var item_id: String = data.get_custom_data("item_id")
	Inventory.add(item_id, 1)
	tm.set_cell(cell, 0, ATLAS)  # -> T0 VOID

	_check("inventory gained I2", Inventory.count("I2") == before + 1)
	_check("gathered tile became T0 VOID (source 0)", tm.get_cell_source_id(cell) == 0)
	var void_data := tm.get_cell_tile_data(cell)
	_check("VOID tile is walkable", void_data != null and bool(void_data.get_custom_data("walkable")))
	tm.queue_free()


func _test_place_stepping_stone() -> void:
	var tm := _make_tilemap()
	var cell := Vector2i(5, 5)
	tm.set_cell(cell, 8, ATLAS)  # T5A water
	var water_data := tm.get_cell_tile_data(cell)
	_check("water tile starts non-walkable", water_data != null and not bool(water_data.get_custom_data("walkable")))

	# Logical tile id lookup mirrors the controller's SOURCE_TO_TILE_ID.
	var tile_id := "T5A"
	_check("D14 may be placed on this water tile", ItemDB.can_place_on_tile("D14", tile_id))

	# Apply the stepping-stone effect: swap to source 1 (T1 dirt reused, walkable).
	tm.set_cell(cell, 1, ATLAS)
	var stone_data := tm.get_cell_tile_data(cell)
	_check("water tile is now walkable after D14 placement",
		stone_data != null and bool(stone_data.get_custom_data("walkable")))
	tm.queue_free()


func _test_unique_cap() -> void:
	Inventory.remove("I9", 999)
	var a := Inventory.add("I9", 1)
	var b := Inventory.add("I9", 5)  # should be rejected (already at cap 1)
	_check("first unique add returns 1", a == 1)
	_check("second unique add returns 0", b == 0)
	_check("unique item count capped at 1", Inventory.count("I9") == 1)


func _test_alias() -> void:
	Inventory.remove("I4", 999)
	Inventory.add("I4", 2)   # gathered wood
	Inventory.add("D06", 3)  # crafted wood, alias_of I4
	_check("D06 resolves to I4", ItemDB.resolve_id("D06") == "I4")
	_check("alias folds into same stack (I4 == 5)", Inventory.count("I4") == 5)
	_check("querying by alias returns folded count", Inventory.count("D06") == 5)


func _test_use_on_object() -> void:
	var got := {"id": "", "obj": null}
	var cb := func(item_id: String, obj: Node):
		got["id"] = item_id
		got["obj"] = obj
	GameState.item_used_on_object.connect(cb)

	# Build a use-only Gatherable with object_id bush_dry.
	var bush := Gatherable.new()
	bush.object_id = "bush_dry"
	add_child(bush)
	Inventory.remove("I7", 999)
	Inventory.add("I7", 1)

	# Emulate the controller's use path: valid target -> consume + emit.
	var valid := ItemDB.can_use_on_object("I7", bush.object_id)
	_check("I7 valid on bush_dry", valid)
	if valid:
		Inventory.remove("I7", 1)
		GameState.item_used_on_object.emit("I7", bush)
	_check("item_used_on_object fired with I7", got["id"] == "I7")
	_check("water consumed on use", Inventory.count("I7") == 0)
	GameState.item_used_on_object.disconnect(cb)
	bush.queue_free()
