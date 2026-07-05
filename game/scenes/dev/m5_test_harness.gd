extends Node
## M5 acceptance harness — save/load + New Game Plus.
##
## Covers (per M5 acceptance §2):
##   A. save → mutate → load restores: inventory, codex (incl. attempted pairs),
##      VOID tiles, bush bloomed state, stepping stone, game_time, player pos.
##   B. autosave file has a version field.
##   C. NG+ carryover: after a simulated clear with N discovered recipes, NG+ reset
##      leaves exactly 3 discovered (all from the previous set) for N>=3, all N for
##      N<3; lifetime history is a superset; run number incremented; world reset
##      (VOID cleared, inventory empty).
##
## The load side instances a FRESH starting_grove (deterministic base map) and lets
## SaveManager.apply_world_state overlay the saved diff — exactly the real
## "이어하기" path.

const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0
var _scene_a: Node = null
var _scene_b: Node = null


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== M5 TEST HARNESS ===")
	# Clean slate.
	SaveManager.new_game()
	SaveManager.delete_save()

	await _test_save_load_roundtrip()
	await _test_ng_plus()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- helpers -------------------------------------------------------------

func _instance_grove() -> Node:
	# Instance a grove but suppress its GroveSession auto-load: the harness drives
	# save/load itself. We register the world manually after build.
	SaveManager.pending_load = false
	var scene: PackedScene = load(GROVE)
	var n := scene.instantiate()
	add_child(n)
	return n


func _register(scene: Node) -> void:
	var loader := scene.get_node("Ground") as MapLoader
	var player := scene.get_node("YSortLayer/Player") as Node2D
	var respawn := scene.get_node("ObjectRespawn") as ObjectRespawn
	SaveManager.register_world(loader, player, respawn)


func _find(scene: Node, cls) -> Node:
	return _search(scene, cls)

func _search(node: Node, cls) -> Node:
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _search(c, cls)
		if r != null:
			return r
	return null


# ==== A + B: save → mutate → load =========================================

func _test_save_load_roundtrip() -> void:
	# --- build scene A, mutate a bunch of state, save ---
	SaveManager.new_game()
	_scene_a = _instance_grove()
	await get_tree().process_frame
	await get_tree().process_frame
	_register(_scene_a)

	var loader_a := _scene_a.get_node("Ground") as MapLoader
	var player_a := _scene_a.get_node("YSortLayer/Player") as Node2D
	var interaction_a := _scene_a.get_node("Interaction") as InteractionController

	# Inventory + held item
	Inventory.add("I2", 4)
	Inventory.add("I5", 2)
	interaction_a.set_held_item("I5")

	# Codex: discover a recipe + record a failed (attempted) pair
	Codex.discover_recipe("R04")
	Codex.register_failed_fusion("I1", "I2")   # a wrong pair -> attempted set

	# Time + player position
	GameState.set_game_time(GameState.DAY_LENGTH * 1.5 + 123.0)
	var moved_pos := loader_a.cell_center_world(Vector2i(20, 20))
	player_a.global_position = moved_pos

	# Map: gather a grass tile → HOLLOW (빈 자국, src 11, v0.3.1), place a stepping
	# stone on a K slot. (A real gather writes src 11; emulate that here.)
	var void_cell := Vector2i(15, 30)
	loader_a.set_cell(void_cell, 11, Vector2i(0, 0))
	var k_cell: Vector2i = loader_a.stepping_slot_cells[0]
	loader_a.set_cell(k_cell, 1, Vector2i(0, 0))  # emulate D14 placement

	# Gate: bloom the bush
	var bush_a := _find(_scene_a, BushDry) as BushDry
	bush_a.bloom()
	await get_tree().process_frame

	# Object: gather one tracked spawn object (it frees) so save records it absent
	var respawn_a := _scene_a.get_node("ObjectRespawn") as ObjectRespawn
	var gathered_cell := Vector2i(-1, -1)
	for entry in respawn_a._tracked:
		var n = entry["node"]
		if n is Gatherable and not (n as Gatherable).unique:
			gathered_cell = entry["cell"]
			(n as Gatherable).gather()      # frees the node
			break
	await get_tree().process_frame
	respawn_a.force_tick()                  # schedules respawn_at = now + DAY_LENGTH
	_check("picked a gatherable object to remove", gathered_cell != Vector2i(-1, -1))

	# Save
	var saved := SaveManager.save_game()
	_check("save_game() wrote file", saved and SaveManager.has_save())

	# Version field present in the file
	var raw := SaveManager._read_save()
	_check("save has version field", int(raw.get("version", -1)) == SaveManager.SAVE_VERSION)

	# Snapshot expected values before we tear down / mutate away
	var exp_time := GameState.game_time
	var exp_pos := moved_pos

	# --- tear down A, clobber live state, instance fresh B, load ---
	SaveManager.unregister_world()
	_scene_a.queue_free()
	_scene_a = null
	await get_tree().process_frame

	# Clobber autoload state so load has to actually restore it.
	Inventory.clear()
	Inventory.add("I9", 1)          # junk that must be wiped
	Codex.reset()
	GameState.set_game_time(0.0)

	_scene_b = _instance_grove()
	await get_tree().process_frame
	await get_tree().process_frame
	_register(_scene_b)

	var loader_b := _scene_b.get_node("Ground") as MapLoader
	var player_b := _scene_b.get_node("YSortLayer/Player") as Node2D
	var interaction_b := _scene_b.get_node("Interaction") as InteractionController

	SaveManager.load_game()
	await get_tree().process_frame

	# --- assertions ---
	_check("inventory I2 restored (=4)", Inventory.count("I2") == 4)
	_check("inventory I5 restored (=2)", Inventory.count("I5") == 2)
	_check("junk I9 cleared on load", Inventory.count("I9") == 0)
	_check("held item restored (I5)", interaction_b.get_held_item() == "I5")

	_check("codex recipe R04 restored", Codex.is_recipe_discovered("R04"))
	# attempted pair suppression survived: re-failing I1+I2 must NOT tick the gauge
	var g0 := Codex.hint_gauge()
	var ticked := Codex.register_failed_fusion("I1", "I2")
	_check("codex attempted-pair restored (no re-tick)", Codex.hint_gauge() == g0 and not ticked)

	# GameState.game_time keeps accumulating in _process; load restores the exact
	# saved value via set_game_time, but the one idle frame awaited after load adds
	# a single frame's delta on top. Tolerate one generous frame (0.1s) so the
	# check verifies restoration without racing the real-time clock. (Pre-existing
	# harness fragility surfaced under heavier scenes; the restore itself is exact.)
	_check("game_time restored", abs(GameState.game_time - exp_time) < 0.1)
	_check("player position restored", player_b.global_position.distance_to(exp_pos) < 1.0)

	# v0.3.1: gathered cells reload as the walkable HOLLOW (src 11), and it's walkable.
	_check("HOLLOW tile restored (빈 자국, src 11)", loader_b.get_cell_source_id(void_cell) == 11)
	_check("restored HOLLOW is walkable", loader_b.is_cell_walkable(void_cell))
	_check("stepping stone restored (walkable src 1)", loader_b.get_cell_source_id(k_cell) == 1)

	var bush_b := _find(_scene_b, BushDry) as BushDry
	_check("bush bloom state restored", bush_b != null and bush_b.is_bloomed())

	# Object removal restored: the object we gathered in A is absent in B, and its
	# respawn timer was restored (so it will come back later, not immediately).
	var obj_at_cell := _object_at(_scene_b, loader_b, gathered_cell)
	_check("gathered object stays removed after load", obj_at_cell == null)
	var respawn_b := _scene_b.get_node("ObjectRespawn") as ObjectRespawn
	var entry_b: Variant = null
	for e in respawn_b._tracked:
		if e["cell"] == gathered_cell:
			entry_b = e
	_check("removed object has a pending respawn timer",
		entry_b != null and float(entry_b["respawn_at"]) > GameState.game_time)

	# clean up
	SaveManager.unregister_world()
	_scene_b.queue_free()
	_scene_b = null
	await get_tree().process_frame


# ==== C: New Game Plus =====================================================

func _test_ng_plus() -> void:
	# ---- case N >= 3: exactly 3 carried, all from previous set ----
	SaveManager.new_game()
	Inventory.add("I4", 9)                       # some world inventory
	GameState.set_game_time(GameState.DAY_LENGTH * 3.0)

	var discovered := ["R01", "R02", "R03", "R04", "R05"]  # N = 5
	for rid in discovered:
		Codex.discover_recipe(rid)
	SaveManager.mark_cleared()

	var prev_run := SaveManager.run_number
	var carried := SaveManager.start_ng_plus()

	_check("NG+ carried exactly 3 (N>=3)", carried.size() == 3)
	var all_from_prev := true
	for rid in carried:
		if rid not in discovered:
			all_from_prev = false
	_check("NG+ carried all from previous set", all_from_prev)
	_check("NG+ carried are distinct", _distinct(carried))

	# exactly the 3 carried are discovered in the fresh codex
	var disc_now: Array = Codex.to_dict().get("recipes", [])
	_check("NG+ fresh codex has exactly 3 discovered recipes", disc_now.size() == 3)
	var carried_match := true
	for rid in carried:
		if not Codex.is_recipe_discovered(rid):
			carried_match = false
	_check("NG+ the 3 carried are discovered", carried_match)

	# carryover markers
	var marked := true
	for rid in carried:
		if not SaveManager.is_carried_recipe(rid):
			marked = false
	_check("NG+ carried flagged for 속삭임 marker", marked)

	# lifetime superset: every discovered recipe from the finished run is recorded
	var lifetime_ok := true
	for rid in discovered:
		if not SaveManager.is_lifetime_recipe(rid):
			lifetime_ok = false
	_check("NG+ lifetime history is a superset", lifetime_ok)
	_check("NG+ lifetime count >= discovered count", SaveManager.lifetime_recipes.size() >= discovered.size())

	# run number incremented, world reset
	_check("NG+ run number incremented", SaveManager.run_number == prev_run + 1)
	_check("NG+ inventory reset (empty)", Inventory.is_empty())
	_check("NG+ time reset to 0", GameState.game_time == 0.0)
	_check("NG+ cleared flag reset", not SaveManager.cleared)

	# world reset (VOID cleared): a fresh grove has no gathered VOID beyond base
	var grove := _instance_grove()
	await get_tree().process_frame
	await get_tree().process_frame
	var loader := grove.get_node("Ground") as MapLoader
	# a base grass cell near spawn should be grass (src 2), not VOID
	_check("NG+ world VOID cleared (base grass intact)", loader.get_cell_source_id(Vector2i(12, 31)) == 2)
	grove.queue_free()
	await get_tree().process_frame

	# ---- case N < 3: carries all N ----
	SaveManager.new_game()
	Codex.discover_recipe("R10")
	Codex.discover_recipe("R11")                 # N = 2
	SaveManager.mark_cleared()
	var carried2 := SaveManager.start_ng_plus()
	_check("NG+ N<3 carries all N (=2)", carried2.size() == 2)
	var set2_ok := Codex.is_recipe_discovered("R10") and Codex.is_recipe_discovered("R11")
	_check("NG+ N<3 both carried discovered", set2_ok)
	_check("NG+ N<3 lifetime keeps both", SaveManager.is_lifetime_recipe("R10") and SaveManager.is_lifetime_recipe("R11"))

	# ---- case N == 0: carries none, still resets ----
	SaveManager.new_game()
	SaveManager.mark_cleared()
	var carried3 := SaveManager.start_ng_plus()
	_check("NG+ N==0 carries none", carried3.size() == 0)
	_check("NG+ N==0 fresh codex empty recipes", Codex.to_dict().get("recipes", []).size() == 0)


func _object_at(scene: Node, loader: MapLoader, cell: Vector2i) -> Node:
	var ysort := scene.get_node("YSortLayer")
	var target := loader.cell_center_world(cell)
	for ch in ysort.get_children():
		if ch is Gatherable and (ch as Node2D).position.distance_to(target) < 4.0:
			return ch
	return null


func _distinct(a: Array) -> bool:
	var seen := {}
	for x in a:
		if seen.has(x):
			return false
		seen[x] = true
	return true
