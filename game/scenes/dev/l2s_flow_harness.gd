extends Node
## (EXL2-6) L2 확장 「지하 데이터 성소」 FLOW acceptance harness. l2s_map_harness proves the map/objects
## and l2x_bfs.py proves gate ORDER; this proves the ENTRY/GATE/NPC/PURIFICATION/SAVE flow:
##   1. 라우팅: WorldContext.SCENE_SANCTUM 씬 경로 + terminal_station 승강로 하강은 L2 정화 후에만 스폰.
##   2. 성소 실 씬 부팅 → GB1(디딤돌 배치)→GB2(격벽 사용)→GB3(3조각 정합 퍼즐)→GB4(봉헌) 순서 구동
##      → sanctum_purified. 부분(2조각)만으론 GB3 미개방(완결성).
##   3. 잔재 NPC 라인(N-archivist) = 레이어 라인과 독립 공존, 진상 조각(l2_last_log) 비게이팅.
##   4. 컷신 C-4 (control_lock/time_running 페어링) → 종료 후 복원. 잔류 전력 노드 = idempotent add_energy(1).
##   5. 세이브: sanctum_purified 지속 + 재진입 시 게이트 end-state 재적용(컷신 미재생, 구세이브 호환).
##   6. NG+ 리셋: 플래그 dormant (reset_layer2_zones). 포탈 라인 불변(sub-zone 비관여).
##
## Boots the REAL data_sanctum.tscn and drives the real controller/signals.
## API 직접 정화 호출 금지 — 실제 게이트 시그널(placed_object_placed/item_used_on_object)로 구동.
## Prints PASS/FAIL; quits with the failure count as exit code.

const SANCTUM := "res://scenes/world/data_sanctum.tscn"

var _fail := 0
var _sanctum_sig := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L2s FLOW HARNESS (성소 진입/게이트/NPC/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer2_zones"): GameState.reset_layer2_zones()
	GameState.reset_layer2()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false
	SaveManager.unregister_world()
	GameState.sanctum_purified.connect(func(_z): _sanctum_sig = true)

	await _test_routing()
	await _test_gate_chain()
	await _test_npc_line_coexist()
	await _test_save_and_ngplus()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. 라우팅 + 승강로 하강 개방 조건 ------------------------------------

func _test_routing() -> void:
	_check("SCENE_SANCTUM 씬 경로 = data_sanctum",
		WorldContext.scene_path(WorldContext.SCENE_SANCTUM).findn("data_sanctum") >= 0)
	# terminal_station 승강로 하강은 L2 정화(layer2_purified) 후에만 스폰.
	GameState.layer2_purified_flag = false
	var ts_scene: PackedScene = load("res://scenes/world/terminal_station.tscn")
	var ts: Node = ts_scene.instantiate()
	add_child(ts)
	for i in range(6):
		await get_tree().process_frame
	var sess: Node = ts.get_node_or_null("TerminalStation")
	_check("terminal_station TerminalStation present", sess != null)
	if sess != null:
		_check("미정화 L2: 승강로 하강 미스폰 (성소 잠김)",
			not bool(sess.get("_sanctum_descent_spawned")))
	ts.queue_free()
	for i in range(3):
		await get_tree().process_frame
	# 정화 상태로 재부팅 → 승강로 하강 스폰.
	GameState.layer2_purified_flag = true
	var ts2: Node = ts_scene.instantiate()
	add_child(ts2)
	for i in range(6):
		await get_tree().process_frame
	var sess2: Node = ts2.get_node_or_null("TerminalStation")
	if sess2 != null:
		_check("정화 L2: 승강로 하강 스폰 (성소 개방)",
			bool(sess2.get("_sanctum_descent_spawned")))
	ts2.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 2. 게이트 체인 GB1→GB2→GB3→GB4 → 정화 -------------------------------

func _test_gate_chain() -> void:
	WorldContext.current_scene = WorldContext.SCENE_SANCTUM
	if GameState.has_method("reset_layer2_zones"): GameState.reset_layer2_zones()
	_sanctum_sig = false
	WhisperCurrency.reset()
	var scene: PackedScene = load(SANCTUM)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	var gates: Node = map.get_node_or_null("L2sGateController")
	_check("성소 loader + L2sGateController present", loader != null and gates != null)
	if loader == null or gates == null:
		map.queue_free()
		return
	var g := loader.legend_gates()
	var gb1 := _cells(g.get("GB1", {}).get("cells", []))
	var gb2 := _cells(g.get("GB2", {}).get("cells", []))
	var gb3: Dictionary = g.get("GB3", {})
	var gb3_slots := _cells(gb3.get("slot_cells", []))
	var gb3_door := _cells(gb3.get("cells", []))

	# GB1 방수 디딤돌(D256) → 냉각 침수로 K 배치. 배치 전엔 non-walkable(냉각수).
	var pre_walk := loader.is_cell_walkable(gb1[0]) if not gb1.is_empty() else true
	_check("GB1 배치 전 냉각 침수로 K non-walkable", not pre_walk)
	for c in gb1:
		GameState.placed_object_placed.emit("D256", c)
	await get_tree().process_frame
	var gb1_walk := true
	for c in gb1:
		if not loader.is_cell_walkable(c):
			gb1_walk = false
	_check("GB1 방수 디딤돌 배치 → K walkable (발판)", gb1_walk)

	# GB2 봉인 격벽: 디코더 젤(D258) 사용 → D 셀 개방.
	var pre2 := loader.is_cell_walkable(gb2[0]) if not gb2.is_empty() else true
	_check("GB2 사용 전 봉인 격벽 D non-walkable", not pre2)
	var bulkhead := _find_use_target(loader, "sealed_bulkhead")
	_check("GB2 봉인 격벽 use-target present", bulkhead != null)
	if bulkhead != null:
		GameState.item_used_on_object.emit("D258", bulkhead)
	await get_tree().process_frame
	var gb2_walk := true
	for c in gb2:
		if not loader.is_cell_walkable(c):
			gb2_walk = false
	_check("GB2 디코더 젤 사용 → 격벽 D walkable (개방)", gb2_walk)

	# GB3 3조각 정합 미니 퍼즐: α(D259)·β(D260)·γ(D261) 슬롯 배치 → 데이터 문 M 개방.
	# 부분(2조각)만으론 미개방 → 완결성 확인.
	if gb3_slots.size() >= 2:
		GameState.placed_object_placed.emit("D259", gb3_slots[0])
		GameState.placed_object_placed.emit("D260", gb3_slots[1])
		await get_tree().process_frame
		var door_partial := gb3_door.is_empty() or loader.is_cell_walkable(gb3_door[0])
		_check("GB3 2조각만 정합 → 데이터 문 M 여전히 잠김", not door_partial)
	if gb3_slots.size() >= 3:
		GameState.placed_object_placed.emit("D261", gb3_slots[2])
		await get_tree().process_frame
	var gb3_walk := true
	for c in gb3_door:
		if not loader.is_cell_walkable(c):
			gb3_walk = false
	_check("GB3 3조각 정합 완성 → 데이터 문 M walkable (퍼즐 해결)", gb3_walk)

	# 잔류 전력 노드: idempotent add_energy — 두 번 트리거해도 +1만.
	var e0 := WhisperCurrency.energy
	if gates.has_method("_grant_energy"):
		gates.call("_grant_energy", null)
		gates.call("_grant_energy", null)   # 중복 시도
	_check("잔류 전력 노드 → energy +1 (첫 재획득)", WhisperCurrency.energy == e0 + 1, "energy=%d" % WhisperCurrency.energy)
	_check("잔류 전력 노드 재방문 중복 없음 (idempotent)", WhisperCurrency.energy == e0 + 1)

	# GB4 백업 봉헌: 복원 코어(D263) 봉헌 → 컷신 C-4 → sanctum_purified.
	_check("GB4 봉헌 전 sanctum_purified_flag=false", not GameState.sanctum_purified_flag)
	var altar := _find_use_target(loader, "backup_altar")
	_check("GB4 백업 봉헌 목 use-target present", altar != null)
	if altar != null:
		GameState.item_used_on_object.emit("D263", altar)
	# 컷신 중엔 time_running=false. 종료까지 대기.
	var saw_lock := false
	for i in range(120):
		await get_tree().create_timer(0.1).timeout
		if not GameState.time_running:
			saw_lock = true
		if GameState.sanctum_purified_flag:
			break
	_check("GB4 컷신 C-4 중 time_running=false (락 페어링)", saw_lock)
	_check("GB4 백업 봉헌 → sanctum_purified_flag set", GameState.sanctum_purified_flag)
	_check("GB4 → sanctum_purified 시그널 발화", _sanctum_sig)
	_check("컷신 종료 후 time_running=true 복원", GameState.time_running)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 3. 잔재 NPC 라인 독립 공존 (진상 조각 비게이팅) --------------------

func _test_npc_line_coexist() -> void:
	QuestManager.reset()
	var l2_line := QuestManager.active_id
	QuestManager.activate_npc_line("archivist")
	_check("N-archivist 라인 활성 (첫 접촉)", QuestManager.npc_active_id("archivist") == "N-archivist-Q1")
	_check("NPC 라인 ≠ 레이어 라인 (독립 공존)",
		QuestManager.npc_active_id("archivist") != l2_line and QuestManager.active_id == l2_line)

	# archivist Q1(제작 D257)→Q2(배치)→Q3(회고 l2_last_log) 순서 구동. 회고는 조사만으로 비게이팅 완료.
	GameState.item_crafted.emit("D257", "EX-L2-R03")
	_check("archivist Q1(제작) → Q2(배치) 진행", QuestManager.npc_active_id("archivist") == "N-archivist-Q2")
	GameState.placed_object_placed.emit("D268", Vector2i(5, 5))
	_check("archivist Q2(배치) → Q3(회고) 진행", QuestManager.npc_active_id("archivist") == "N-archivist-Q3")
	GameState.truth_shard_investigated.emit("l2_last_log")
	_check("archivist Q3(회고) 조사만으로 완료 → 라인 종료",
		QuestManager.npc_line_finished("archivist"))


# ---- 4. 세이브 지속 + 재진입 재적용 + NG+ 리셋 --------------------------

func _test_save_and_ngplus() -> void:
	var d := SaveManager.build_save_dict()
	_check("세이브: sanctum_purified 플래그 지속", bool(d.get("sanctum_purified", false)))

	# 재진입: sanctum_purified=true 상태로 성소 재부팅 → 게이트 end-state 즉시 재적용(컷신 미재생).
	_sanctum_sig = false
	WorldContext.current_scene = WorldContext.SCENE_SANCTUM
	GameState.sanctum_purified_flag = true
	var scene: PackedScene = load(SANCTUM)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	if loader != null:
		var g := loader.legend_gates()
		var gb1 := _cells(g.get("GB1", {}).get("cells", []))
		var gb2 := _cells(g.get("GB2", {}).get("cells", []))
		var gb3_door := _cells(g.get("GB3", {}).get("cells", []))
		var reopened := true
		for c in gb1 + gb2 + gb3_door:
			if not loader.is_cell_walkable(c):
				reopened = false
		_check("재진입(정화됨): 모든 성소 게이트 즉시 walkable (구세이브 호환)", reopened)
	_check("재진입: 정화 컷신 미재생 (sanctum 시그널 재발화 안 함)", not _sanctum_sig)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame

	# NG+ 리셋: 플래그 dormant. 포탈 라인은 sub-zone과 무관하므로 불변.
	GameState.set_portal_state("science", GameState.PORTAL_OPEN)
	var science_before := GameState.portal_state("science")
	GameState.reset_layer2_zones()
	_check("NG+ 리셋: sanctum 플래그 dormant", not GameState.sanctum_purified_flag)
	_check("NG+ 리셋: 포탈 라인 불변 (sub-zone 비관여)",
		GameState.portal_state("science") == science_before)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


func _obj_id_of(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if node.has_method("get"):
		var v: Variant = node.get("object_id")
		if typeof(v) == TYPE_STRING and String(v) != "":
			return String(v)
	if node.has_method("get_meta"):
		return String(node.get_meta("object_id", ""))
	return ""


func _find_use_target(loader: MapLoader, object_id: String) -> Node:
	for key in loader.l2_object_nodes.keys():
		if String(key).split("@")[0] != object_id:
			continue
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node == null:
			continue
		if _obj_id_of(node) == object_id:
			return node
		for ch in node.get_children():
			if _obj_id_of(ch) == object_id:
				return ch
		return node
	return null
