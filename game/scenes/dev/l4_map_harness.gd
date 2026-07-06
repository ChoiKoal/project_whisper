extends Node
## (L4-1/L4-2) Layer-4 「봉인이 풀린 마탑」 map/mage-tower acceptance harness.
##
## Boots the REAL mage_tower.tscn (the scene the machine portal travels to) and asserts the
## Layer-4 map data + tile art + object spawn is sound BEFORE the gate logic runs its course:
##   1. loader reports a 40×40 map, spawn on the S cell (19,37).
##   2. legend tile counts match the authoritative l4_map_layout.txt char inventory (§A-2).
##   3. every gate / landmark cell exists at the expected coord.
##   4. elevation applied: +2 봉인 챔버 (O core), +1 부유 결정 (M).
##   5. gate bottleneck cells g/v/L/H are STATIC-CLOSED (dark, non-walkable) at boot.
##   6. every authored L4 object instantiated with a real texture (no black-box sprites).
##   7. the 정비대 (workbench) spawned near spawn; L4 gather sources (P1-P7) present.
##
## Prints PASS/FAIL per check and quits with the failure count as the exit code.

const TOWER := "res://scenes/world/mage_tower.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L4 MAP HARNESS (mage_tower 「봉인이 풀린 마탑」) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(TOWER)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
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


## Expected char inventory from the authoritative l4_map_layout.txt (byte-identical to §A-2).
func _test_tile_counts(loader: MapLoader) -> void:
	var expect := {"V": 876, "A": 170, "R": 179, "M": 242, "O": 53, "H": 2,
		"L": 4, "g": 4, "v": 4, "x": 6, "/": 6, "q": 11, "m": 11, "s": 6,
		"y": 4, "z": 4, "d": 7, "o": 4, "C": 1, "E": 1, "S": 1}
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
		Vector2i(18, 29): "g", Vector2i(19, 30): "g",                     # G1 rune_bridge
		Vector2i(18, 19): "v", Vector2i(19, 20): "v",                     # G2 ward door
		Vector2i(18, 10): "L", Vector2i(19, 11): "L",                     # G3 crack gate
		Vector2i(18, 4): "H", Vector2i(19, 4): "H",                       # G4 seal neck (H on row 4)
		Vector2i(17, 19): "E",                                            # G2 mana spring
		Vector2i(17, 11): "C",                                            # G3 ward pillar
	}
	var all_ok := true
	for cell in expect:
		var got: String = loader._layout[cell.y][cell.x] if cell.y < loader.height else "?"
		if got != expect[cell]:
			all_ok = false
			print("    cell %s = '%s' want '%s'" % [str(cell), got, expect[cell]])
	_check("all gate/landmark cells at expected coords", all_ok)


func _test_elevation(loader: MapLoader) -> void:
	# +2 봉인 챔버: discover the first O cell dynamically (safer than a hardcoded coord).
	var o_cell := Vector2i(-1, -1)
	var o2 := 0
	for r in range(loader.height):
		for c in range(loader.width):
			if loader._layout[r][c] == "O":
				if o_cell == Vector2i(-1, -1):
					o_cell = Vector2i(c, r)
				if loader.height_at(Vector2i(c, r)) == 2:
					o2 += 1
	_check("봉인 챔버 O cell at height +2", o_cell != Vector2i(-1, -1) and loader.height_at(o_cell) == 2,
		"O%s h=%d" % [str(o_cell), loader.height_at(o_cell)])
	_check("봉인 챔버 O block raised to +2", o2 >= 40, "O@+2=%d" % o2)
	# +1 부유 결정: discover the first M cell dynamically.
	var m_cell := Vector2i(-1, -1)
	for r in range(loader.height):
		for c in range(loader.width):
			if loader._layout[r][c] == "M":
				m_cell = Vector2i(c, r)
				break
		if m_cell != Vector2i(-1, -1):
			break
	_check("부유 결정 M cell at height +1", m_cell != Vector2i(-1, -1) and loader.height_at(m_cell) == 1,
		"M%s h=%d" % [str(m_cell), loader.height_at(m_cell)])
	# 기저면(남 spawn) at height 0.
	_check("남 마탑 진입 spawn area at height 0", loader.height_at(loader.spawn_cell) == 0)
	# Ramps exist ('/' ramp chars).
	_check("ramp cells present (경사로)", loader.ramp_cells.size() >= 1,
		"ramps=%d" % loader.ramp_cells.size())


func _test_gate_closure(loader: MapLoader) -> void:
	# The four gate bottleneck bands must be STATIC-CLOSED (non-walkable) at boot. The sealed
	# tiles are the ones carrying a dark gate char (g/v/L/H → source 31); the G4 neck band's
	# lower row is a '/' ramp approach (walkable by design), so seal-check only the char cells
	# discovered from the layout rather than the raw legend band (which lists the ramp too).
	var gate_bands := {
		"G1 g": {"cells": [Vector2i(18, 29), Vector2i(19, 29), Vector2i(18, 30), Vector2i(19, 30)], "char": "g"},
		"G2 v": {"cells": [Vector2i(18, 19), Vector2i(19, 19), Vector2i(18, 20), Vector2i(19, 20)], "char": "v"},
		"G3 L": {"cells": [Vector2i(18, 10), Vector2i(19, 10), Vector2i(18, 11), Vector2i(19, 11)], "char": "L"},
		"G4 H": {"cells": [Vector2i(18, 4), Vector2i(19, 4), Vector2i(18, 5), Vector2i(19, 5)], "char": "H"},
	}
	var all_closed := true
	var sealed := 0
	for gate in gate_bands:
		var want_char: String = gate_bands[gate]["char"]
		for cell in gate_bands[gate]["cells"]:
			# Only the cells that actually carry the sealed dark gate char are STATIC-CLOSED tiles.
			if loader._layout[cell.y][cell.x] != want_char:
				continue
			sealed += 1
			if loader.is_cell_walkable(cell):
				all_closed = false
				print("    %s cell %s is walkable at boot (should be sealed)" % [gate, str(cell)])
	_check("all 4 gate bottleneck (g/v/L/H) tiles STATIC-CLOSED at boot", all_closed and sealed >= 14,
		"sealed=%d" % sealed)


func _test_objects_textured(loader: MapLoader) -> void:
	_check("L4 objects spawned", loader.l2_object_nodes.size() > 0,
		"n=%d" % loader.l2_object_nodes.size())
	var untextured := 0
	var has := {"mana_spring": false, "ward_door": false, "crack_gate": false,
		"seal_core": false, "rune_bridge": false}
	for key in loader.l2_object_nodes:
		var rec: Dictionary = loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		var l4id := String(key).split("@")[0]
		if has.has(l4id):
			has[l4id] = true
		if node is Sprite2D:
			if (node as Sprite2D).texture == null:
				untextured += 1
		elif node is Gatherable:
			if (node as Gatherable).texture == null:
				untextured += 1
	_check("no untextured (black-box) L4 sprites", untextured == 0, "untextured=%d" % untextured)
	for k in has:
		_check("%s spawned" % k, has[k])


func _test_gather_sources(loader: MapLoader) -> void:
	# Each P1-P7 gather source must be represented by at least one spawned Gatherable.
	var seen := {}
	for key in loader.l2_object_nodes:
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node is Gatherable:
			seen[(node as Gatherable).item_id] = true
	var all_present := true
	for p in ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]:
		if not seen.has(p):
			all_present = false
			print("    gather source missing: %s" % p)
	_check("all 7 mana gather sources (P1-P7) spawned", all_present,
		"seen=%s" % str(seen.keys()))


func _test_workbench(loader: MapLoader) -> void:
	_check("정비대 workbench cell set near spawn", loader.l2_workbench_cell != Vector2i(-1, -1),
		"cell=%s" % str(loader.l2_workbench_cell))
	if loader.l2_workbench_cell != Vector2i(-1, -1):
		var d: int = absi(loader.l2_workbench_cell.x - loader.spawn_cell.x) \
			+ absi(loader.l2_workbench_cell.y - loader.spawn_cell.y)
		_check("workbench within a few cells of spawn (첫 조합 ≤4분)", d <= 6, "manhattan=%d" % d)
