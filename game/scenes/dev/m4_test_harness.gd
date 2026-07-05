extends Node
## M4 acceptance harness. Loads the real starting_grove scene and asserts the
## map/gate/time behavior per the M4 acceptance list. Prints PASS/FAIL and quits
## with the failure count as exit code.
##
## Covered:
##   - map loads 40×40 with expected tile counts per legend
##   - spawn / cauldron / stump positions match layout
##   - G1 water cell impassable, then passable after D14 placement
##   - G2 bush blocks, then opens after I7 use
##   - G3 entrance blocked at noon, open at night (set game_time directly)
##   - rest stump jumps time to evening
##   - world_tree_planted triggers clear state
##   - object respawn after a day tick; VOID tiles persist

var _fail := 0

# Expected exact tile-symbol counts from the transcribed layout.
const EXPECT_COUNTS := {
	"V": 721, "G": 476, "g": 169, "W": 84, "w": 45, "T": 25, "F": 23,
	"m": 16, "D": 10, "R": 7, "s": 5, "O": 4, "K": 3, "M": 2, "N": 2,
	"S": 1, "C": 1, "U": 1, "B": 1, "1": 0, "2": 1, "3": 1, "4": 2,
}


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	Inventory.clear()
	GameState.set_game_time(0.0)
	print("=== M4 TEST HARNESS ===")
	var scene: PackedScene = load("res://scenes/world/starting_grove.tscn")
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader

	_test_map_dims(loader)
	_test_tile_counts(loader)
	_test_landmarks(loader)
	_test_g1(loader)
	await _test_g2(map, loader)
	await _test_g3(loader)
	_test_rest_stump(loader)
	_test_clear()
	await _test_respawn_and_void(loader)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _test_map_dims(loader: MapLoader) -> void:
	_check("map is 40 rows", loader.height == 40)
	_check("map is 40 cols", loader.width == 40)
	var used := loader.get_used_cells().size()
	_check("all 1600 cells populated", used == 40 * 40)


func _test_tile_counts(loader: MapLoader) -> void:
	var ok := true
	for sym in EXPECT_COUNTS:
		var exp: int = EXPECT_COUNTS[sym]
		if exp == 0:
			continue  # symbols with no tile entry ('1' is landmark-only, absent)
		var got: int = int(loader.tile_counts.get(sym, 0))
		if got != exp:
			ok = false
			print("    tile '%s' expected %d got %d" % [sym, exp, got])
	_check("tile counts match legend exactly", ok)


func _test_landmarks(loader: MapLoader) -> void:
	_check("spawn cell = (12,32)", loader.spawn_cell == Vector2i(12, 32))
	_check("cauldron cell = (13,32)", loader.cauldron_cell == Vector2i(13, 32))
	_check("stump cell = (12,33)", loader.stump_cell == Vector2i(12, 33))
	_check("bush cell = (18,16)", loader.bush_cell == Vector2i(18, 16))
	_check("3 stepping-stone slots (K)", loader.stepping_slot_cells.size() == 3)
	_check("2 night-gate cells (N)", loader.night_gate_cells.size() == 2)
	_check("4 world-tree cells (O)", loader.world_tree_cells.size() == 4)
	# world tree object present + unique
	var wt := _find_first(WorldTree)
	_check("WorldTree spawned, unique I9", wt != null and wt.unique and wt.item_id == "I9")


func _test_g1(loader: MapLoader) -> void:
	# The K stepping-stone slots are water (non-walkable) until D14 placed.
	var k: Vector2i = loader.stepping_slot_cells[0]
	var kd := loader.get_cell_tile_data(k)
	_check("G1 stone slot starts non-walkable (water)",
		kd != null and not bool(kd.get_custom_data("walkable")))
	# place D14 via the interaction controller's effect path.
	var interaction := (get_child(0).get_node("Interaction")) as InteractionController
	Inventory.add("D14", 1)
	interaction.set_held_item("D14")
	var placed: bool = interaction.call("_try_place_on_tile", k)
	var kd2 := loader.get_cell_tile_data(k)
	_check("G1 opens: D14 placed, cell now walkable",
		placed and kd2 != null and bool(kd2.get_custom_data("walkable")))


func _test_g2(map: Node, loader: MapLoader) -> void:
	var bush := _find_first(BushDry)
	_check("G2 bush present", bush != null)
	if bush == null:
		return
	_check("G2 bush blocks (not bloomed)", not bush.is_bloomed())
	# Use I7 on the bush: emit the framework signal (as the controller would).
	Inventory.add("I7", 1)
	GameState.item_used_on_object.emit("I7", bush)
	await get_tree().process_frame
	_check("G2 opens: bush bloomed after I7 use", bush.is_bloomed())


func _test_g3(loader: MapLoader) -> void:
	var gate := _find_first(NightGate)
	_check("G3 night gate present", gate != null)
	if gate == null:
		return
	# Noon (day): blocked.
	GameState.set_game_time(GameState.DAY_LENGTH * 0.30)  # deep in day
	await get_tree().process_frame
	_check("G3 blocked at noon (day)", not gate.is_open())
	# Night: open.
	GameState.set_game_time(GameState.DAY_LENGTH * 0.85)  # night window
	await get_tree().process_frame
	_check("G3 open at night", gate.is_open())


func _test_rest_stump(loader: MapLoader) -> void:
	# Put time at early day; rest jumps to this day's evening start.
	GameState.set_game_time(GameState.DAY_LENGTH * 0.20)
	var stump := loader.rest_stump
	_check("rest stump present", stump != null)
	if stump == null:
		return
	stump.fade_rect = null  # skip fade for the test (instant)
	stump.rest()
	var evening_start := GameState.DAY_END * GameState.DAY_LENGTH
	_check("rest stump jumps to evening start", abs(GameState.game_time - evening_start) < 0.01)
	_check("phase is evening after rest", GameState.phase() == "evening")


func _test_clear() -> void:
	var got := {"hit": false}
	GameState.world_tree_planted.connect(func(_c): got["hit"] = true)
	var clear := _find_first_canvas(ClearSequence)
	_check("ClearSequence present", clear != null)
	GameState.world_tree_planted.emit(Vector2i(5, 5))
	_check("world_tree_planted fired", got["hit"])
	# clear sequence should now be active
	_check("clear sequence active after plant", clear != null and clear.is_active())


func _test_respawn_and_void(loader: MapLoader) -> void:
	var respawn := (get_child(0).get_node("ObjectRespawn")) as ObjectRespawn
	_check("ObjectRespawn present", respawn != null)
	# Gather a tree object: find one, free it, then advance a full day + tick.
	var tree := _find_first(Gatherable)
	# pick a non-unique gatherable that is on the object_spawns list
	var target: Gatherable = null
	for entry in loader.object_spawns:
		var n = _find_object_at(loader, entry["cell"])
		if n is Gatherable and not (n as Gatherable).unique:
			target = n
			break
	_check("found a respawnable object", target != null)
	if target == null:
		return
	var cell: Vector2i = _cell_of(loader, target)
	# gather it (frees the node)
	target.gather()
	await get_tree().process_frame
	respawn.force_tick()  # schedules respawn_at = now + DAY_LENGTH
	# advance a full day and tick
	GameState.set_game_time(GameState.game_time + GameState.DAY_LENGTH + 1.0)
	respawn.force_tick()
	await get_tree().process_frame
	var back := _find_object_at(loader, cell)
	_check("object respawned after a full game day", back is Gatherable)

	# HOLLOW persistence: gather a grass tile → HOLLOW (빈 자국, src 11, v0.3.1), ensure
	# the emptied mark stays and no object respawns onto it.
	var gcell := Vector2i(12, 31)  # grass near spawn (row31 is grass 'G')
	loader.set_cell(gcell, 11, Vector2i(0, 0))  # emulate tile-gather → HOLLOW
	GameState.set_game_time(GameState.game_time + GameState.DAY_LENGTH * 2.0)
	respawn.force_tick()
	_check("HOLLOW tile persists (never respawns to ground)", loader.get_cell_source_id(gcell) == 11)


# ---- helpers -------------------------------------------------------------

func _find_first(cls) -> Node:
	return _search(get_child(0), cls)

func _search(node: Node, cls) -> Node:
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _search(c, cls)
		if r != null:
			return r
	return null

func _find_first_canvas(cls) -> Node:
	return _search(get_child(0), cls)

func _find_object_at(loader: MapLoader, cell: Vector2i) -> Node:
	var ysort := get_child(0).get_node("YSortLayer")
	var target := loader.cell_center_world(cell)
	for ch in ysort.get_children():
		if ch is Gatherable and (ch as Node2D).position.distance_to(target) < 4.0:
			return ch
	return null

func _cell_of(loader: MapLoader, node: Node2D) -> Vector2i:
	return loader.world_to_cell(node.position)
