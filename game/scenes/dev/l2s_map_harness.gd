extends Node
## (EXL2-6) L2 확장 SUB-zone 「지하 데이터 성소」(l2s) map/scene acceptance harness.
##
## Boots the real scene (data_sanctum.tscn — the scene the 정비 승강로 하강 travels to) and asserts
## the map data + object spawn is sound:
##   1. loader reports a 40×40 map, spawn on the S cell (19,39).
##   2. legend tile counts match the authoritative layout char inventory.
##   3. all-gates-open walkable count = 699 per design §A-6.1 (l2x_bfs.py).
##   4. every gate / landmark / gatherable / gate-object cell exists at the expected coord.
##   5. every authored l2s object instantiated with a real texture (no black-box sprites).
##   6. orphan gatherables = 0 (every gatherable is adjacent-reachable when all gates open).
##
## Prints PASS/FAIL per check and quits with the failure count as the exit code.

const SANCTUM := "res://scenes/world/data_sanctum.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L2S MAP HARNESS (지하 데이터 성소 l2s) ===")
	_reset_autoloads()
	await _test_zone(SANCTUM, "sanctum")
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _reset_autoloads() -> void:
	if typeof(Inventory) != TYPE_NIL: Inventory.clear()
	if typeof(GameState) != TYPE_NIL:
		GameState.set_game_time(0.0)
		GameState.reset_portals()
		if GameState.has_method("reset_layer2_zones"): GameState.reset_layer2_zones()
	if typeof(WhisperCurrency) != TYPE_NIL: WhisperCurrency.reset()
	if typeof(SaveManager) != TYPE_NIL: SaveManager.pending_load = false


func _test_zone(scene_path: String, zone: String) -> void:
	print("--- zone: %s ---" % zone)
	var scene: PackedScene = load(scene_path)
	_check("%s scene loads" % zone, scene != null)
	if scene == null:
		return
	var map := scene.instantiate()
	add_child(map)
	for i in range(6):
		await get_tree().process_frame

	var loader := map.get_node_or_null("Ground") as MapLoader
	_check("%s loader present" % zone, loader != null)
	if loader == null:
		map.queue_free()
		return

	# 1. dimensions + spawn
	_check("%s map 40x40" % zone, loader.width == 40 and loader.height == 40,
		"%dx%d" % [loader.width, loader.height])
	_check("%s spawn = (19,39)" % zone, loader.spawn_cell == Vector2i(19, 39),
		"spawn=%s" % str(loader.spawn_cell))

	_test_counts(loader, zone)
	_test_walkable(loader, zone)
	_test_cells(loader, zone)
	_test_objects(loader, zone)

	map.queue_free()
	await get_tree().process_frame


func _count_layout(loader: MapLoader) -> Dictionary:
	var counts := {}
	for r in range(loader.height):
		var row: String = loader._layout[r]
		for c in range(row.length()):
			var ch := row[c]
			counts[ch] = int(counts.get(ch, 0)) + 1
	return counts


func _test_counts(loader: MapLoader, zone: String) -> void:
	var counts := _count_layout(loader)
	# Authoritative l2s layout inventory (l2x_map_gen.py). GB1 K(2), GB2 D(2), GB3 M(2)+x(3),
	# GB4 H(1)+O(1). 채집 h(10)/k(10)/o(10)/b(7). E(1) 잔류 전력. N(1) 관리 드론.
	var expect := {"V": 857, "B": 71, "G": 389, "P": 184, "~": 44, "K": 2, "D": 2, "M": 2,
		"x": 3, "H": 1, "O": 1, "E": 1, "N": 1, "S": 1, "h": 10, "k": 10, "o": 10, "b": 7}
	var ok := true
	for sym in expect:
		if int(counts.get(sym, 0)) != expect[sym]:
			ok = false
			print("    %s count %s: got %d want %d" % [zone, sym, int(counts.get(sym, 0)), expect[sym]])
	for lm in ["1", "2", "3", "4"]:
		if int(counts.get(lm, 0)) != 1:
			ok = false
			print("    %s landmark %s count %d (want 1)" % [zone, lm, int(counts.get(lm, 0))])
	_check("%s legend tile counts match layout" % zone, ok)


## All-gates-open walkable = every cell that is not void (V) and not deep water (~ 냉각 침수로).
## Gate cells (K bridged / D·M opened / H offering) all become walkable → they count here. 699.
func _test_walkable(loader: MapLoader, zone: String) -> void:
	var want := 699
	var walk := 0
	for r in range(loader.height):
		var row: String = loader._layout[r]
		for c in range(row.length()):
			var ch := row[c]
			if ch == "V" or ch == "~":
				continue
			walk += 1
	_check("%s all-gates-open walkable = %d" % [zone, want], walk == want, "walk=%d" % walk)


func _test_cells(loader: MapLoader, zone: String) -> void:
	var expect := {
		Vector2i(18, 29): "K", Vector2i(19, 29): "K",
		Vector2i(18, 17): "D", Vector2i(19, 17): "D",
		Vector2i(18, 6): "M", Vector2i(19, 6): "M",
		Vector2i(14, 12): "x", Vector2i(19, 12): "x", Vector2i(24, 12): "x",
		Vector2i(19, 3): "H", Vector2i(20, 2): "O",
		Vector2i(12, 22): "E", Vector2i(19, 10): "N",
		Vector2i(19, 2): "1", Vector2i(19, 21): "2", Vector2i(27, 22): "3", Vector2i(12, 37): "4",
	}
	var ok := true
	for cell in expect:
		var got: String = loader._layout[cell.y][cell.x] if cell.y < loader.height else "?"
		if got != expect[cell]:
			ok = false
			print("    %s cell %s = '%s' want '%s'" % [zone, str(cell), got, expect[cell]])
	_check("%s gate/landmark cells at expected coords" % zone, ok)


func _test_objects(loader: MapLoader, zone: String) -> void:
	_check("%s l2s objects spawned" % zone, loader.l2_object_nodes.size() > 0,
		"n=%d" % loader.l2_object_nodes.size())
	var untextured := 0
	var gatherables := 0
	var orphan := 0
	var seen := {}
	for key in loader.l2_object_nodes:
		var rec: Dictionary = loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		var l2id := String(key).split("@")[0]
		seen[l2id] = true
		var tex_ok := true
		if node is Sprite2D:
			tex_ok = (node as Sprite2D).texture != null
		elif node is Gatherable:
			tex_ok = (node as Gatherable).texture != null
		if not tex_ok:
			untextured += 1
			print("    %s untextured: %s" % [zone, l2id])
		if node is Gatherable and (node as Gatherable).item_id != "":
			gatherables += 1
			var cell: Vector2i = rec.get("cell", Vector2i(-1, -1))
			if not _adjacent_walkable_all_open(loader, cell):
				orphan += 1
				print("    %s ORPHAN gatherable %s @ %s" % [zone, l2id, str(cell)])
	_check("%s no untextured (black-box) sprites" % zone, untextured == 0, "untextured=%d" % untextured)
	_check("%s gatherables spawned" % zone, gatherables > 0, "n=%d" % gatherables)
	_check("%s orphan gatherables = 0" % zone, orphan == 0, "orphan=%d" % orphan)
	# key gate-objects present
	_check("%s sealed_bulkhead + backup_altar + backup_core + power_residue spawned" % zone,
		seen.has("sealed_bulkhead") and seen.has("backup_altar") and seen.has("backup_core") \
		and seen.has("sanctum_power_residue"))
	_check("%s J12 unique 채집원(backup_core) spawned" % zone, seen.has("backup_core"))


func _adjacent_walkable_all_open(loader: MapLoader, cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var n: Vector2i = cell + d
		if n.y < 0 or n.y >= loader.height or n.x < 0 or n.x >= loader.width:
			continue
		var ch: String = loader._layout[n.y][n.x]
		if ch != "V" and ch != "~":
			return true
	return false
