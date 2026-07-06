extends Node
## (L5-1/L5-2) Layer-5 「응답 없는 대성당」 map/cathedral acceptance harness.
##
## Boots the REAL cathedral.tscn (the scene the divinity portal travels to) and asserts the
## Layer-5 map data + tile art + object spawn is sound BEFORE the gate logic runs its course:
##   1. loader reports a 40×40 map, spawn on the S cell (19,37).
##   2. legend tile counts match the authoritative l5_map_layout.txt char inventory (§A-2).
##   3. every gate / landmark / re-acquire (A/B) cell exists at the expected coord.
##   4. elevation applied: +2 대제단 (O core / H neck), +1 회랑 (C 성가 회랑, Q 침묵의 회랑).
##   5. gate bottleneck cells g/e/Y/H are STATIC-CLOSED (dark, non-walkable) at boot.
##   6. every authored L5 object instantiated with a real texture (no black-box sprites).
##   7. the 봉헌 작업대 (workbench) spawned near spawn; L5 gather sources (S1-S7) present.
##
## Prints PASS/FAIL per check and quits with the failure count as the exit code.

const CATHEDRAL := "res://scenes/world/cathedral.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L5 MAP HARNESS (cathedral 「응답 없는 대성당」) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(CATHEDRAL)
	var map := scene.instantiate()
	add_child(map)
	for _i in range(6):
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
	_test_reacquire_cells(loader)
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


## Expected char inventory from the authoritative l5_map_layout.txt (byte-identical to §A-2).
func _test_tile_counts(loader: MapLoader) -> void:
	var expect := {"V": 878, "P": 170, "L": 178, "Q": 150, "C": 89, "O": 51,
		"H": 2, "g": 4, "e": 4, "Y": 4, "/": 6,
		"h": 8, "r": 7, "b": 8, "p": 8, "n": 8, "w": 6, "k": 9,
		"X": 1, "E": 1, "W": 1, "A": 1, "B": 1, "S": 1}
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
		Vector2i(18, 29): "g", Vector2i(19, 30): "g",   # G1 dead lantern
		Vector2i(18, 19): "e", Vector2i(19, 20): "e",   # G2 life door
		Vector2i(18, 10): "Y", Vector2i(19, 11): "Y",   # G3 silence gate
		Vector2i(18, 4): "H", Vector2i(19, 4): "H",     # G4 offering neck (H row 4)
		Vector2i(17, 19): "E",                          # G2 life spring
		Vector2i(17, 12): "W",                          # G3 choir stand
		Vector2i(17, 31): "X",                          # G1 lantern altar
	}
	var all_ok := true
	for cell in expect:
		var got: String = loader._layout[cell.y][cell.x] if cell.y < loader.height else "?"
		if got != expect[cell]:
			all_ok = false
			print("    cell %s = '%s' want '%s'" % [str(cell), got, expect[cell]])
	_check("all gate/landmark cells at expected coords", all_ok)


## §A-4 재획득처 특례: 발전 제단 A (12,13) 에너지·마력 성물함 B (27,13) 마력, 침묵의 회랑(+1)에 배치.
func _test_reacquire_cells(loader: MapLoader) -> void:
	_check("발전 제단 A at (12,13)", loader._layout[13][12] == "A")
	_check("마력 성물함 B at (27,13)", loader._layout[13][27] == "B")
	_check("A on 침묵의 회랑 (+1)", loader.height_at(Vector2i(12, 13)) == 1,
		"h=%d" % loader.height_at(Vector2i(12, 13)))
	_check("B on 침묵의 회랑 (+1)", loader.height_at(Vector2i(27, 13)) == 1,
		"h=%d" % loader.height_at(Vector2i(27, 13)))


func _test_elevation(loader: MapLoader) -> void:
	# +2 대제단: discover the first O cell dynamically.
	var o_cell := Vector2i(-1, -1)
	var o2 := 0
	for r in range(loader.height):
		for c in range(loader.width):
			if loader._layout[r][c] == "O":
				if o_cell == Vector2i(-1, -1):
					o_cell = Vector2i(c, r)
				if loader.height_at(Vector2i(c, r)) == 2:
					o2 += 1
	_check("대제단 O cell at height +2", o_cell != Vector2i(-1, -1) and loader.height_at(o_cell) == 2,
		"O%s h=%d" % [str(o_cell), loader.height_at(o_cell)])
	_check("대제단 O block raised to +2", o2 >= 40, "O@+2=%d" % o2)
	# +1 회랑: C (상부 성가 회랑) and Q (침묵의 회랑).
	_check("상부 성가 회랑 C at height +1", loader.height_at(Vector2i(10, 6)) == 1,
		"h=%d" % loader.height_at(Vector2i(10, 6)))
	_check("침묵의 회랑 Q at height +1", loader.height_at(Vector2i(10, 12)) == 1,
		"h=%d" % loader.height_at(Vector2i(10, 12)))
	# 기저면(남 spawn) + 광장/참배길 at height 0.
	_check("남 대성당 진입 spawn area at height 0", loader.height_at(loader.spawn_cell) == 0)
	# Ramps exist ('/' ramp chars).
	_check("ramp cells present (경사로)", loader.ramp_cells.size() >= 1,
		"ramps=%d" % loader.ramp_cells.size())


func _test_gate_closure(loader: MapLoader) -> void:
	# The four gate bottleneck bands must be STATIC-CLOSED (non-walkable) at boot. Seal-check
	# only the cells that carry a dark gate char (g/e/Y/H → source 38); the G4 neck band's lower
	# row is a '/' ramp approach (walkable by design).
	var gate_bands := {
		"G1 g": {"cells": [Vector2i(18, 29), Vector2i(19, 29), Vector2i(18, 30), Vector2i(19, 30)], "char": "g"},
		"G2 e": {"cells": [Vector2i(18, 19), Vector2i(19, 19), Vector2i(18, 20), Vector2i(19, 20)], "char": "e"},
		"G3 Y": {"cells": [Vector2i(18, 10), Vector2i(19, 10), Vector2i(18, 11), Vector2i(19, 11)], "char": "Y"},
		"G4 H": {"cells": [Vector2i(18, 4), Vector2i(19, 4), Vector2i(18, 5), Vector2i(19, 5)], "char": "H"},
	}
	var all_closed := true
	var sealed := 0
	for gate in gate_bands:
		var want_char: String = gate_bands[gate]["char"]
		for cell in gate_bands[gate]["cells"]:
			if loader._layout[cell.y][cell.x] != want_char:
				continue
			sealed += 1
			if loader.is_cell_walkable(cell):
				all_closed = false
				print("    %s cell %s is walkable at boot (should be sealed)" % [gate, str(cell)])
	_check("all 4 gate bottleneck (g/e/Y/H) tiles STATIC-CLOSED at boot", all_closed and sealed >= 14,
		"sealed=%d" % sealed)


func _test_objects_textured(loader: MapLoader) -> void:
	_check("L5 objects spawned", loader.l2_object_nodes.size() > 0,
		"n=%d" % loader.l2_object_nodes.size())
	var untextured := 0
	var has := {"life_spring": false, "life_door": false, "silence_gate": false,
		"lantern_altar": false, "choir_stand": false, "dead_lantern": false,
		"pilgrim_dynamo": false, "mana_reliquary": false}
	for key in loader.l2_object_nodes:
		var rec: Dictionary = loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		var l5id := String(key).split("@")[0]
		if has.has(l5id):
			has[l5id] = true
		if node is Sprite2D:
			if (node as Sprite2D).texture == null:
				untextured += 1
		elif node is Gatherable:
			if (node as Gatherable).texture == null:
				untextured += 1
	_check("no untextured (black-box) L5 sprites", untextured == 0, "untextured=%d" % untextured)
	for k in has:
		_check("%s spawned" % k, has[k])


func _test_gather_sources(loader: MapLoader) -> void:
	# Each S1-S7 gather source must be represented by at least one spawned Gatherable.
	var seen := {}
	for key in loader.l2_object_nodes:
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node is Gatherable:
			seen[(node as Gatherable).item_id] = true
	var all_present := true
	for s in ["S1", "S2", "S3", "S4", "S5", "S6", "S7"]:
		if not seen.has(s):
			all_present = false
			print("    gather source missing: %s" % s)
	_check("all 7 divine gather sources (S1-S7) spawned", all_present,
		"seen=%s" % str(seen.keys()))


func _test_workbench(loader: MapLoader) -> void:
	_check("봉헌 작업대 workbench cell set near spawn", loader.l2_workbench_cell != Vector2i(-1, -1),
		"cell=%s" % str(loader.l2_workbench_cell))
	if loader.l2_workbench_cell != Vector2i(-1, -1):
		var d: int = absi(loader.l2_workbench_cell.x - loader.spawn_cell.x) \
			+ absi(loader.l2_workbench_cell.y - loader.spawn_cell.y)
		_check("workbench within a few cells of spawn (첫 조합 pacing)", d <= 6, "manhattan=%d" % d)
