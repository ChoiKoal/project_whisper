extends Node
## (L3-1/L3-2) Layer-3 「태엽이 멈춘 도시」 map/clockwork-city acceptance harness.
##
## Boots the REAL clockwork_city.tscn (the scene the machine portal travels to) and asserts the
## Layer-3 map data + tile art + object spawn is sound BEFORE the gate logic runs its course:
##   1. loader reports a 40×40 map, spawn on the S cell (19,37).
##   2. legend tile counts match the authoritative l3_map_layout.txt char inventory (§A-2).
##   3. every gate / landmark / machine cell exists at the expected coord.
##   4. elevation applied: +2 대시계 광장 (O core, H neck), +1 상부 플랫폼 (M).
##   5. gate bottleneck cells g/v/L/H are STATIC-CLOSED (dark, non-walkable) at boot.
##   6. every authored L3 object instantiated with a real texture (no black-box sprites).
##   7. the 정비대 (workbench) spawned near spawn; L3 gather sources (K1-K7) present.
##
## Prints PASS/FAIL per check and quits with the failure count as the exit code.

const CITY := "res://scenes/world/clockwork_city.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L3 MAP HARNESS (clockwork_city 「태엽이 멈춘 도시」) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(CITY)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	_check("loader present", loader != null)
	if loader == null:
		print("=== RESULT: FAIL (no loader) ===")
		get_tree().quit(1)
		return

	_test_dimensions(loader)
	_test_tile_counts(loader)
	_test_gate_cells(loader)
	_test_elevation(loader)
	_test_gate_closure(loader)
	_test_objects_textured(loader)
	_test_gather_sources(loader)
	_test_workbench(loader)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _test_dimensions(loader: MapLoader) -> void:
	_check("map is 40 wide", loader.width == 40, "w=%d" % loader.width)
	_check("map is 40 tall", loader.height == 40, "h=%d" % loader.height)
	_check("spawn cell = S (19,37)", loader.spawn_cell == Vector2i(19, 37),
		"spawn=%s" % str(loader.spawn_cell))


## Expected char inventory from the authoritative l3_map_layout.txt (byte-identical to §A-2).
func _test_tile_counts(loader: MapLoader) -> void:
	var expect := {"V": 908, "B": 150, "G": 335, "M": 54, "O": 52, "p": 22,
		"r": 10, "t": 8, "b": 8, "l": 8, "k": 6, "f": 6, "w": 4,
		"g": 4, "v": 4, "L": 4, "H": 4, "/": 4, "C": 1, "E": 1, "X": 1, "K": 1, "S": 1}
	var counts := {}
	for r in range(loader.height):
		var row: String = loader._layout[r]
		for c in range(row.length()):
			var ch := row[c]
			counts[ch] = int(counts.get(ch, 0)) + 1
	var all_ok := true
	for sym in expect:
		if int(counts.get(sym, 0)) != expect[sym]:
			all_ok = false
			print("    count mismatch %s: got %d want %d" % [sym, int(counts.get(sym, 0)), expect[sym]])
	for lm in ["1", "2", "3", "4"]:
		if int(counts.get(lm, 0)) != 1:
			all_ok = false
			print("    landmark %s count %d (want 1)" % [lm, int(counts.get(lm, 0))])
	_check("legend tile counts match layout char inventory", all_ok)


func _test_gate_cells(loader: MapLoader) -> void:
	var expect := {
		Vector2i(18, 2): "1", Vector2i(19, 2): "K",                       # clock face + mount
		Vector2i(18, 4): "H", Vector2i(19, 5): "H",                       # G4 neck
		Vector2i(17, 11): "C", Vector2i(22, 11): "3",                     # elevator ctrl + cage
		Vector2i(18, 10): "L", Vector2i(19, 11): "L",                     # G3 lift
		Vector2i(17, 19): "E", Vector2i(22, 19): "2",                     # boiler + landmark
		Vector2i(18, 19): "v", Vector2i(19, 20): "v",                     # G2 valve door
		Vector2i(18, 28): "X",                                            # G1 gear assembly
		Vector2i(18, 29): "g", Vector2i(19, 30): "g",                     # G1 gear bridge
		Vector2i(22, 37): "4",                                            # tutorial parts
	}
	var all_ok := true
	for cell in expect:
		var got: String = loader._layout[cell.y][cell.x] if cell.y < loader.height else "?"
		if got != expect[cell]:
			all_ok = false
			print("    cell %s = '%s' want '%s'" % [str(cell), got, expect[cell]])
	_check("all gate/landmark/machine cells at expected coords", all_ok)


func _test_elevation(loader: MapLoader) -> void:
	# +2 대시계 광장: an O cell of the core block (rows 0-3).
	_check("대시계 광장 O(15,2) at height +2", loader.height_at(Vector2i(15, 2)) == 2,
		"h=%d" % loader.height_at(Vector2i(15, 2)))
	var o2 := 0
	for r in range(4):
		for c in range(loader.width):
			if loader._layout[r][c] == "O" and loader.height_at(Vector2i(c, r)) == 2:
				o2 += 1
	_check("대시계 광장 O block raised to +2 (row0-3)", o2 >= 40, "O@+2=%d" % o2)
	# +2 대시계 목 H.
	_check("대시계 목 H(18,4) at height +2", loader.height_at(Vector2i(18, 4)) == 2,
		"h=%d" % loader.height_at(Vector2i(18, 4)))
	# +1 상부 플랫폼: an M cell on row 7.
	_check("상부 플랫폼 M(14,7) at height +1", loader.height_at(Vector2i(14, 7)) == 1,
		"h=%d" % loader.height_at(Vector2i(14, 7)))
	# 기저면(남 플라자 spawn) at height 0.
	_check("남 기어 플라자 spawn area at height 0", loader.height_at(loader.spawn_cell) == 0)
	# Ramps exist (승강기 하차 + 대시계 진입).
	_check("ramp cells present (경사로)", loader.ramp_cells.size() >= 4,
		"ramps=%d" % loader.ramp_cells.size())


func _test_gate_closure(loader: MapLoader) -> void:
	# The four gate bottleneck bands (g/v/L/H) must be STATIC-CLOSED (non-walkable) at boot.
	var gate_cells := {
		"G1 g": [Vector2i(18, 29), Vector2i(19, 29), Vector2i(18, 30), Vector2i(19, 30)],
		"G2 v": [Vector2i(18, 19), Vector2i(19, 19), Vector2i(18, 20), Vector2i(19, 20)],
		"G3 L": [Vector2i(18, 10), Vector2i(19, 10), Vector2i(18, 11), Vector2i(19, 11)],
		"G4 H": [Vector2i(18, 4), Vector2i(19, 4), Vector2i(18, 5), Vector2i(19, 5)],
	}
	var all_closed := true
	for gate in gate_cells:
		for cell in gate_cells[gate]:
			if loader.is_cell_walkable(cell):
				all_closed = false
				print("    %s cell %s is walkable at boot (should be sealed)" % [gate, str(cell)])
	_check("all 4 gate bottlenecks STATIC-CLOSED at boot", all_closed)


func _test_objects_textured(loader: MapLoader) -> void:
	_check("L3 objects spawned", loader.l2_object_nodes.size() > 0,
		"n=%d" % loader.l2_object_nodes.size())
	var untextured := 0
	var has := {"grand_clock": false, "boiler": false, "elevator": false,
		"gear_assembly": false, "clock_mount": false, "elevator_ctrl": false}
	for key in loader.l2_object_nodes:
		var rec: Dictionary = loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		var l3id := String(key).split("@")[0]
		if has.has(l3id):
			has[l3id] = true
		if node is Sprite2D:
			if (node as Sprite2D).texture == null:
				untextured += 1
		elif node is Gatherable:
			if (node as Gatherable).texture == null:
				untextured += 1
	_check("no untextured (black-box) L3 sprites", untextured == 0, "untextured=%d" % untextured)
	for k in has:
		_check("%s spawned" % k, has[k])


func _test_gather_sources(loader: MapLoader) -> void:
	# Each K1-K7 gather source must be represented by at least one spawned Gatherable.
	var seen := {}
	for key in loader.l2_object_nodes:
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node is Gatherable:
			seen[(node as Gatherable).item_id] = true
	var all_present := true
	for k in ["K1", "K2", "K3", "K4", "K5", "K6", "K7"]:
		if not seen.has(k):
			all_present = false
			print("    gather source missing: %s" % k)
	_check("all 7 K-element gather sources (K1-K7) spawned", all_present,
		"seen=%s" % str(seen.keys()))


func _test_workbench(loader: MapLoader) -> void:
	_check("정비대 workbench cell set near spawn", loader.l2_workbench_cell != Vector2i(-1, -1),
		"cell=%s" % str(loader.l2_workbench_cell))
	if loader.l2_workbench_cell != Vector2i(-1, -1):
		var d: int = absi(loader.l2_workbench_cell.x - loader.spawn_cell.x) \
			+ absi(loader.l2_workbench_cell.y - loader.spawn_cell.y)
		_check("workbench within a few cells of spawn (첫 조합 ≤4분)", d <= 6, "manhattan=%d" % d)
