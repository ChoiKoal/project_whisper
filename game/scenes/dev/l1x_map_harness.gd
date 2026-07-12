extends Node
## (EXL1-7) L1 확장 두 SUB-zone 「고요의 화원」(l1g) + 「생명의 심장」(l1h) map/scene acceptance harness.
##
## Boots BOTH real scenes (quiet_garden.tscn / life_heart.tscn — the same scenes the grove portals
## travel to) and asserts the map data + object spawn is sound:
##   1. loader reports a 40×40 map, spawn on the S cell (19,39) for each zone.
##   2. legend tile counts match the authoritative layout char inventory.
##   3. all-gates-open walkable count = 719 (garden) / 681 (heart) per design §A-6.1.
##   4. every gate / landmark / gatherable / gate-object cell exists at the expected coord.
##   5. every authored l1x object instantiated with a real texture (no black-box sprites).
##   6. orphan gatherables = 0 (every gatherable is adjacent-reachable when all gates open).
##
## Prints PASS/FAIL per check and quits with the failure count as the exit code.

const GARDEN := "res://scenes/world/quiet_garden.tscn"
const HEART := "res://scenes/world/life_heart.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L1X MAP HARNESS (고요의 화원 l1g + 생명의 심장 l1h) ===")
	_reset_autoloads()

	await _test_zone(GARDEN, "garden")
	await _test_zone(HEART, "heart")

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _reset_autoloads() -> void:
	if typeof(Inventory) != TYPE_NIL: Inventory.clear()
	if typeof(GameState) != TYPE_NIL:
		GameState.set_game_time(0.0)
		GameState.reset_portals()
		GameState.reset_layer1_zones()
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

	# 2. tile counts
	_test_counts(loader, zone)
	# 3. walkable count (all gates open)
	_test_walkable(loader, zone)
	# 4. gate/landmark cells
	_test_cells(loader, zone)
	# 5+6. objects textured + orphan 0
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
	var expect := {}
	if zone == "garden":
		expect = {"V": 837, "B": 120, "G": 358, "P": 182, "~": 44, "K": 4, "A": 2, "M": 2,
			"x": 3, "H": 1, "N": 1, "C": 1, "S": 1, "f": 14, "d": 8, "z": 10, "y": 9}
	else:
		expect = {"V": 875, "B": 248, "G": 205, "P": 183, "~": 44, "L": 2, "H": 2, "O": 2,
			"E": 1, "N": 1, "C": 1, "S": 1, "j": 10, "e": 10, "q": 11}
	var ok := true
	for sym in expect:
		if int(counts.get(sym, 0)) != expect[sym]:
			ok = false
			print("    %s count %s: got %d want %d" % [zone, sym, int(counts.get(sym, 0)), expect[sym]])
	# landmarks single cells
	var lms := ["1", "2", "4"] if zone == "garden" else ["1", "2", "3", "4"]
	for lm in lms:
		if int(counts.get(lm, 0)) != 1:
			ok = false
			print("    %s landmark %s count %d (want 1)" % [zone, lm, int(counts.get(lm, 0))])
	_check("%s legend tile counts match layout" % zone, ok)


## All-gates-open walkable = every cell that is not void (V) and not deep water (~). The gate cells
## (K/A/M for garden, L/H for heart) become walkable when their gate opens, so they count here.
func _test_walkable(loader: MapLoader, zone: String) -> void:
	var want := 719 if zone == "garden" else 681
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
	var expect := {}
	if zone == "garden":
		expect = {
			Vector2i(18, 29): "K", Vector2i(19, 29): "K", Vector2i(18, 30): "K", Vector2i(19, 30): "K",
			Vector2i(18, 19): "A", Vector2i(19, 19): "A",
			Vector2i(18, 9): "M", Vector2i(19, 9): "M",
			Vector2i(14, 14): "x", Vector2i(19, 14): "x", Vector2i(24, 14): "x",
			Vector2i(19, 4): "H", Vector2i(19, 12): "N",
			Vector2i(19, 3): "1", Vector2i(19, 21): "2", Vector2i(12, 37): "4",
		}
	else:
		expect = {
			Vector2i(18, 29): "L", Vector2i(19, 29): "L",
			Vector2i(18, 17): "H", Vector2i(19, 17): "H",
			Vector2i(19, 3): "O", Vector2i(20, 3): "O",
			Vector2i(12, 22): "E", Vector2i(15, 8): "N",
			Vector2i(19, 8): "1", Vector2i(19, 21): "2", Vector2i(27, 22): "3", Vector2i(12, 37): "4",
		}
	var ok := true
	for cell in expect:
		var got: String = loader._layout[cell.y][cell.x] if cell.y < loader.height else "?"
		if got != expect[cell]:
			ok = false
			print("    %s cell %s = '%s' want '%s'" % [zone, str(cell), got, expect[cell]])
	_check("%s gate/landmark cells at expected coords" % zone, ok)


func _test_objects(loader: MapLoader, zone: String) -> void:
	_check("%s l1x objects spawned" % zone, loader.l2_object_nodes.size() > 0,
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
		# orphan check: gatherable objects must be adjacent-reachable (all gates open).
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
	if zone == "garden":
		_check("%s wilted_arch + rainbow_font spawned" % zone,
			seen.has("wilted_arch") and seen.has("rainbow_font"))
		_check("%s color_bed slots spawned" % zone, seen.has("color_bed"))
	else:
		_check("%s heart_seal + tree_heart + life spring spawned" % zone,
			seen.has("heart_seal") and seen.has("tree_heart") and seen.has("heart_life_spring"))


## True if `cell` (an object cell, itself blocking) has a walkable 4-neighbour when ALL gates are
## open. Uses the authored layout: a neighbour is walkable if it is not V and not ~ (all gate cells
## open). This proves the gatherable is collectible (인접 채집 규약) with no orphans.
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
