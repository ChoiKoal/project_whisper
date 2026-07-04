extends Node
## M2 integration check — loads the real test_map scene and drives the actual
## InteractionController / Gatherable / Inventory wiring (node paths, groups,
## held-item flow), not emulated logic. Prints PASS/FAIL and quits.

var _fail := 0


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	Inventory.clear()
	print("=== M2 INTEGRATION ===")
	var scene: PackedScene = load("res://scenes/world/test_map.tscn")
	var map := scene.instantiate()
	add_child(map)
	# Let _ready() run on children (map build, group registration).
	await get_tree().process_frame
	await get_tree().process_frame

	var interaction := map.get_node("Interaction") as InteractionController
	_check("InteractionController present", interaction != null)

	# Gatherable objects registered into the group (7 gatherable + 1 use-only bush;
	# the M3 Cauldron also joins this group but is not a Gatherable — skip it).
	var all_in_group := get_tree().get_nodes_in_group(Gatherable.GROUP)
	var gatherables := []
	for n in all_in_group:
		if n is Gatherable:
			gatherables.append(n)
	_check("gatherable group populated (>=8)", gatherables.size() >= 8)

	# Every expected gather item id is reachable from a world object or a tile.
	var object_items := {}
	for n in gatherables:
		var g := n as Gatherable
		if g.item_id != "":
			object_items[g.item_id] = true
	_check("objects yield I2", object_items.has("I2"))
	_check("objects yield I4 (trees)", object_items.has("I4"))
	_check("objects yield I5 (flower)", object_items.has("I5"))
	_check("objects yield I6 (rock)", object_items.has("I6"))
	_check("objects yield I8 (stone)", object_items.has("I8"))

	# Drive a real gather on the rock object.
	var rock: Gatherable = null
	for n in gatherables:
		if (n as Gatherable).item_id == "I6":
			rock = n
			break
	var before := Inventory.count("I6")
	var granted := rock.gather()
	_check("rock.gather() granted I6", granted == "I6" and Inventory.count("I6") == before + 1)
	_check("non-unique rock freed after gather", is_instance_valid(rock) == false or rock.is_queued_for_deletion())

	# Held-item placement flow through the controller: give D14, hold it, place on
	# a real water cell that the controller resolves.
	Inventory.add("D14", 1)
	interaction.set_held_item("D14")
	_check("controller holds D14", interaction.get_held_item() == "D14")

	# Find a water cell on the real map and place via the controller's public path.
	var ground := map.get_node("Ground") as TileMapLayer
	var water_cell := _find_source_cell(ground, 8)  # T5A
	_check("found a water cell on map", water_cell != Vector2i(-9999, -9999))
	if water_cell != Vector2i(-9999, -9999):
		var wd := ground.get_cell_tile_data(water_cell)
		_check("map water cell non-walkable pre-place", not bool(wd.get_custom_data("walkable")))
		var placed: bool = interaction.call("_try_place_on_tile", water_cell)
		_check("controller placed D14 on water", placed)
		var wd2 := ground.get_cell_tile_data(water_cell)
		_check("map water cell walkable post-place", bool(wd2.get_custom_data("walkable")))
		_check("D14 consumed from inventory", Inventory.count("D14") == 0)

	# world_tree_planted signal fires when D22 placed on VOID.
	var planted := {"hit": false}
	GameState.world_tree_planted.connect(func(_c): planted["hit"] = true)
	Inventory.add("D22", 1)
	interaction.set_held_item("D22")
	var void_cell := _find_source_cell(ground, 0)
	if void_cell == Vector2i(-9999, -9999):
		# no VOID on the fresh map; make one
		void_cell = Vector2i(0, 0)
		ground.set_cell(void_cell, 0, Vector2i(0, 0))
	var planted_ok: bool = interaction.call("_try_place_on_tile", void_cell)
	_check("controller planted D22 on VOID", planted_ok and planted["hit"])

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _find_source_cell(tm: TileMapLayer, src: int) -> Vector2i:
	for cell in tm.get_used_cells():
		if tm.get_cell_source_id(cell) == src:
			return cell
	return Vector2i(-9999, -9999)
