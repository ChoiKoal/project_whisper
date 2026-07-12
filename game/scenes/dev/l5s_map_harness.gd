extends Node
## (EXL5-6) L5 확장 SUB-zone 「침묵의 종탑」(l5b) map/scene acceptance harness. l4s_map 패턴 계승.
##
## Boots the real scene (belfry.tscn — 대성당 대제단 곁 종탑 계단이 하강하는 씬) and asserts the map
## data + object spawn is sound:
##   1. loader reports a 40×40 map, spawn on the S cell (19,39).
##   2. legend tile counts match the authoritative layout char inventory (l5x_map_gen.py / l5b layout).
##   3. all-gates-open(부적無) walkable = 696 (l5x_bfs.py 부적無 696 / 부적有 700).
##      = 모든 셀 중 void(V)·균열(x) 제외. 게이트 셀(g/e/L 개방·H 봉헌목)은 전부 포함.
##   4. every gate / landmark / gatherable / gate-object cell exists at the expected coord.
##   5. every authored l5b object instantiated with a real texture (no black-box sprites).
##   6. orphan gatherables = 0 (every gatherable is adjacent-reachable when all gates open).
##
## Prints PASS/FAIL per check and quits with the failure count as the exit code.

const BELFRY := "res://scenes/world/belfry.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L5S MAP HARNESS (침묵의 종탑 l5b) ===")
	_reset_autoloads()
	await _test_zone(BELFRY, "belfry")
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _reset_autoloads() -> void:
	if typeof(Inventory) != TYPE_NIL: Inventory.clear()
	if typeof(GameState) != TYPE_NIL:
		GameState.set_game_time(0.0)
		GameState.reset_portals()
		if GameState.has_method("reset_layer5_zones"): GameState.reset_layer5_zones()
	if typeof(WhisperCurrency) != TYPE_NIL: WhisperCurrency.reset()
	if typeof(SaveManager) != TYPE_NIL: SaveManager.pending_load = false
	if typeof(WorldContext) != TYPE_NIL: WorldContext.current_scene = WorldContext.SCENE_BELFRY


func _test_zone(scene_path: String, zone: String) -> void:
	print("--- zone: %s ---" % zone)
	var scene: PackedScene = load(scene_path)
	_check("%s scene loads" % zone, scene != null)
	if scene == null:
		return
	var map := scene.instantiate()
	add_child(map)
	for i in range(8):
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
	# Authoritative l5b layout inventory (l5b_map_layout.txt 침묵의 종탑 40x40).
	#   V(900) 바래 사라진 허공 · A(179) 착지 상아 바닥 · Q(201) 종실 회랑 +1 · C(182) 타종 울림 회랑 +1 ·
	#     O(69) 종탑 정점 +2 · /(4) 경사로.
	#   게이트: g(4) GB1 종석 잔교 슬롯 · e(2) GB2 종음 결계문 · L(2) GB3 상층문 · y(3) GB3 타종 종 슬롯 ·
	#     H(1) GB4 봉헌 목 · o(1) 정점 큰 종(S12 유니크).
	#   x(4) 종석 균열(부적) · 채집 s(11)/j(10)/z(10)/d(7) · E(1) 종음 결계 본체 · N(1) 종지기 잔영 ·
	#     C 랜드마크는 landmark 아님(C=타일) · F(1) 잔향 성수반 · X(1) GB1 종석 제단 · S(1) 스폰.
	# NB: 정비대(주종대)는 special.workbench_cell(20,38)에 세션이 코드로 스폰 — 레이아웃 심볼 아님.
	var expect := {"V": 900, "A": 179, "Q": 201, "C": 182, "O": 69, "/": 4,
		"g": 4, "e": 2, "L": 2, "y": 3, "H": 1, "o": 1, "x": 4,
		"s": 11, "j": 10, "z": 10, "d": 7, "E": 1, "N": 1, "F": 1, "X": 1, "S": 1}
	var ok := true
	for sym in expect:
		if int(counts.get(sym, 0)) != expect[sym]:
			ok = false
			print("    %s count %s: got %d want %d" % [zone, sym, int(counts.get(sym, 0)), expect[sym]])
	# landmarks 1~5 = each exactly 1 (큰 종·큰 종 실루엣·기록판·조율 종·3 울림 종).
	for lm in ["1", "2", "3", "4", "5"]:
		if int(counts.get(lm, 0)) != 1:
			ok = false
			print("    %s landmark %s count %d (want 1)" % [zone, lm, int(counts.get(lm, 0))])
	_check("%s legend tile counts match layout" % zone, ok)


## All-gates-open(부적無) walkable = every cell that is not 바래 사라진 허공(V) and not 균열(x).
## Gate cells (g bridged / e·L opened / H offering) all become walkable → they count here. 696.
## 부적 착용 시 균열 x(4)까지 traversable → 700 (l5x_bfs.py). 균열은 부적 게이팅이라 기본 walkable 제외.
func _test_walkable(loader: MapLoader, zone: String) -> void:
	var want := 696
	var walk := 0
	for r in range(loader.height):
		var row: String = loader._layout[r]
		for c in range(row.length()):
			var ch := row[c]
			if ch == "V" or ch == "x":
				continue
			walk += 1
	_check("%s all-gates-open(부적無) walkable = %d" % [zone, want], walk == want, "walk=%d" % walk)


func _test_cells(loader: MapLoader, zone: String) -> void:
	var expect := {
		# GB1 무너진 종탑 계단 종석 잔교 g (허공 위) + 종석 제단 X.
		Vector2i(18, 29): "g", Vector2i(19, 29): "g", Vector2i(18, 30): "g", Vector2i(19, 30): "g",
		Vector2i(17, 31): "X",
		# GB2 흐려진 종음 결계문 e + 본체 E.
		Vector2i(18, 17): "e", Vector2i(19, 17): "e",
		# GB3 종탑 상층문 L + 타종 종 슬롯 y (3, 순서 있음).
		Vector2i(18, 6): "L", Vector2i(19, 6): "L",
		Vector2i(14, 12): "y", Vector2i(19, 12): "y", Vector2i(24, 12): "y",
		# GB4 응답의 타종구 봉헌 목 H (정점) + 정점 큰 종 채집 o (S12 유니크).
		Vector2i(19, 3): "H",
		# 종지기 잔영 N · 잔향 성수반 F.
		Vector2i(19, 10): "N", Vector2i(12, 22): "F",
		# landmarks.
		Vector2i(19, 2): "1", Vector2i(27, 22): "3",
	}
	var ok := true
	for cell in expect:
		var got: String = loader._layout[cell.y][cell.x] if cell.y < loader.height else "?"
		if got != expect[cell]:
			ok = false
			print("    %s cell %s = '%s' want '%s'" % [zone, str(cell), got, expect[cell]])
	# o(정점 큰 종) 존재 확인 — 좌표 대신 심볼 유일성으로.
	_check("%s gate/landmark cells at expected coords" % zone, ok)


func _test_objects(loader: MapLoader, zone: String) -> void:
	_check("%s l5b objects spawned" % zone, loader.l2_object_nodes.size() > 0,
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
	# key gate-objects present: GB2 종음 결계 본체 · GB4 봉헌 목 · 정점 큰 종(S12 유니크).
	_check("%s chime_ward + great_bell_altar + great_bell spawned" % zone,
		seen.has("chime_ward") and seen.has("great_bell_altar") and seen.has("great_bell"))
	_check("%s S12 unique 채집원(great_bell) spawned" % zone, seen.has("great_bell"))


func _adjacent_walkable_all_open(loader: MapLoader, cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var n: Vector2i = cell + d
		if n.y < 0 or n.y >= loader.height or n.x < 0 or n.x >= loader.width:
			continue
		var ch: String = loader._layout[n.y][n.x]
		if ch != "V" and ch != "x":
			return true
	return false
