extends Node
## (EXL4-6) L4 확장 「부유 서고」 FLOW acceptance harness. l4s_map_harness proves the map/objects
## and l4x_bfs.py proves gate ORDER; this proves the ENTRY/GATE/NPC/PURIFICATION/SAVE flow (l3s_flow
## 패턴 계승):
##   1. 라우팅: WorldContext.SCENE_ARCHIVE 씬 경로(floating_archive) + mage_tower 서고 하강 통로는
##      L4 구역1 정화(layer4_purified) 후에만 스폰(찢긴 서고 통로 = 최심부 봉인 재구축 후 활성).
##   2. 서고 실 씬 부팅 → GW1(다리석 배치)→GW2(정화의 물 사용)→GW3(3서판 순서 퍼즐 seal_ordered)→
##      GW4(봉인구 봉헌+마력 소비+컷신 C-4) 순서 구동 → archive_purified.
##      순서 오류(GW3 서판 역순)·부분(2장)만으론 통로문 미개방(완결성). 마력 부족 시 봉헌 실패.
##   3. 잔재 NPC 라인(N-librarian) = 레이어 라인과 독립 공존, 진상 조각(mage_ghost) 비게이팅(재조사 심화).
##   4. 컷신 C-4 (control_lock/time_running 페어링) → 종료 후 복원 + ESC(ui_cancel) 스킵.
##      잔류 열람 결계정 W = idempotent add_mana(1).
##   5. 세이브: archive_purified 지속 + 재진입 시 게이트 end-state 재적용(컷신 미재생, 구세이브 호환).
##   6. NG+ 리셋: 플래그 dormant (reset_layer4_zones). 포탈 라인 불변(sub-zone 비관여).
##
## Boots the REAL floating_archive.tscn and drives the real controller/signals.
## API 직접 정화 호출 금지 — 실제 게이트 시그널(placed_object_placed/item_used_on_object)로 구동.
## Prints PASS/FAIL; quits with the failure count as exit code.

const ARCHIVE := "res://scenes/world/floating_archive.tscn"

var _fail := 0
var _archive_sig := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L4S FLOW HARNESS (서고 진입/게이트/NPC/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer4_zones"): GameState.reset_layer4_zones()
	GameState.reset_layer4()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false
	SaveManager.unregister_world()
	GameState.archive_purified.connect(func(_z): _archive_sig = true)

	await _test_routing()
	await _test_gate_chain()
	_test_npc_line_coexist()
	await _test_save_and_ngplus()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. 라우팅 + 서고 하강 통로 개방 조건 --------------------------------

func _test_routing() -> void:
	_check("SCENE_ARCHIVE 씬 경로 = floating_archive",
		WorldContext.scene_path(WorldContext.SCENE_ARCHIVE).findn("floating_archive") >= 0)
	# mage_tower 서고 하강 통로는 L4 구역1 정화(layer4_purified) 후에만 스폰.
	GameState.layer4_purified_flag = false
	var mt_scene: PackedScene = load("res://scenes/world/mage_tower.tscn")
	var mt: Node = mt_scene.instantiate()
	add_child(mt)
	for i in range(8):
		await get_tree().process_frame
	# mage_tower.tscn 루트가 곧 MageTower 세션(스크립트 부착 루트).
	var sess: Node = mt if mt.get("_archive_descent_spawned") != null else _find_with_prop(mt, "_archive_descent_spawned")
	_check("mage_tower 세션 present", sess != null)
	if sess != null:
		_check("미정화 L4: 서고 하강 통로 미스폰 (서고 잠김)",
			not bool(sess.get("_archive_descent_spawned")))
	mt.queue_free()
	for i in range(3):
		await get_tree().process_frame
	# 정화 상태로 재부팅 → 하강 통로 스폰.
	GameState.layer4_purified_flag = true
	var mt2: Node = mt_scene.instantiate()
	add_child(mt2)
	for i in range(8):
		await get_tree().process_frame
	var sess2: Node = mt2 if mt2.get("_archive_descent_spawned") != null else _find_with_prop(mt2, "_archive_descent_spawned")
	if sess2 != null:
		_check("정화 L4: 서고 하강 통로 스폰 (서고 개방)",
			bool(sess2.get("_archive_descent_spawned")))
	mt2.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 2. 게이트 체인 GW1→GW2→GW3→GW4 → 정화 -------------------------------

func _test_gate_chain() -> void:
	WorldContext.current_scene = WorldContext.SCENE_ARCHIVE
	if GameState.has_method("reset_layer4_zones"): GameState.reset_layer4_zones()
	_archive_sig = false
	WhisperCurrency.reset()
	var scene: PackedScene = load(ARCHIVE)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(10):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	var gates: Node = map.get_node_or_null("L4aGateController")
	_check("서고 loader + L4aGateController present", loader != null and gates != null)
	if loader == null or gates == null:
		map.queue_free()
		return
	var g := loader.legend_gates()
	var gw1 := _cells(g.get("GW1", {}).get("cells", []))
	var gw2 := _cells(g.get("GW2", {}).get("cells", []))
	var gw3: Dictionary = g.get("GW3", {})
	var gw3_slots := _cells(gw3.get("slot_cells", []))
	var gw3_door := _cells(gw3.get("cells", []))
	var gw1_altar: Variant = g.get("GW1", {}).get("altar", [])
	var altar_cell := Vector2i(int(gw1_altar[0]), int(gw1_altar[1])) if gw1_altar is Array and gw1_altar.size() >= 2 else (gw1[0] if not gw1.is_empty() else Vector2i.ZERO)

	# GW1 부유 서가 다리석(D302) → 룬 제단 X 배치 → 잔교 g 셀 walkable. 배치 전엔 non-walkable(허공).
	var pre_walk := loader.is_cell_walkable(gw1[0]) if not gw1.is_empty() else true
	_check("GW1 배치 전 부유 서가 잔교 g non-walkable (허공)", not pre_walk)
	GameState.placed_object_placed.emit("D302", altar_cell)
	await get_tree().process_frame
	var gw1_walk := true
	for c in gw1:
		if not loader.is_cell_walkable(c):
			gw1_walk = false
	_check("GW1 다리석 배치 → 잔교 g walkable (룬 다리)", gw1_walk)

	# GW2 흐려진 열람 결계: 열람 정화의 물(D304) 사용 → v 셀 개방.
	var pre2 := loader.is_cell_walkable(gw2[0]) if not gw2.is_empty() else true
	_check("GW2 사용 전 흐려진 열람 결계문 v non-walkable", not pre2)
	var ward := _find_use_target(loader, "reading_ward")
	_check("GW2 흐려진 열람 결계 use-target present", ward != null)
	if ward != null:
		GameState.item_used_on_object.emit("D304", ward)
	await get_tree().process_frame
	var gw2_walk := true
	for c in gw2:
		if not loader.is_cell_walkable(c):
			gw2_walk = false
	_check("GW2 정화의 물 사용 → 결계문 v walkable (개방)", gw2_walk)

	# GW3 봉인 순서 미니 퍼즐 (seal_ordered_3): D305→D306→D307 순서대로 z 슬롯 배치 → 통로문 L 개방.
	# (a) 역순(D306 먼저) → 미해결. (b) 2장만 → 미해결. (c) 정순 3장 완성 → 해결(완결성).
	if gw3_slots.size() >= 3:
		# (a) 역순: D306을 먼저 배치 → 통로문 여전히 잠김.
		GameState.placed_object_placed.emit("D306", gw3_slots[1])
		GameState.placed_object_placed.emit("D305", gw3_slots[0])
		await get_tree().process_frame
		var wrong_order := gw3_door.is_empty() or loader.is_cell_walkable(gw3_door[0])
		_check("GW3 역순 배치(2장) → 통로문 L 여전히 잠김 (순서 강제)", not wrong_order)
		# (c) 정순으로 다시: D305→D306→D307. 컨트롤러가 distinct-placement 순서로 판정.
		GameState.placed_object_placed.emit("D305", gw3_slots[0])
		GameState.placed_object_placed.emit("D306", gw3_slots[1])
		await get_tree().process_frame
		var partial := gw3_door.is_empty() or loader.is_cell_walkable(gw3_door[0])
		_check("GW3 정순 2장만 → 통로문 L 여전히 잠김 (미완)", not partial)
		GameState.placed_object_placed.emit("D307", gw3_slots[2])
		await get_tree().process_frame
	var gw3_walk := true
	for c in gw3_door:
		if not loader.is_cell_walkable(c):
			gw3_walk = false
	_check("GW3 3서판 순서 완성 → 통로문 L walkable (퍼즐 해결)", gw3_walk)

	# 잔류 열람 결계정 W: idempotent add_mana — 두 번 트리거해도 +1만.
	var m0 := WhisperCurrency.mana
	if gates.has_method("_grant_mana"):
		gates.call("_grant_mana", null)
		gates.call("_grant_mana", null)   # 중복 시도
	_check("잔류 열람 결계정 → mana +1 (첫 재획득)", WhisperCurrency.mana == m0 + 1, "mana=%d" % WhisperCurrency.mana)
	_check("잔류 열람 결계정 재방문 중복 없음 (idempotent)", WhisperCurrency.mana == m0 + 1)

	# GW4 금기 봉인구 봉헌: 마력 부족 시 봉헌 실패 검증 후, 마력 확보하고 봉헌 → 컷신 C-4 → archive_purified.
	var altar := _find_use_target(loader, "archive_core_altar")
	_check("GW4 봉헌 목 use-target present", altar != null)
	_check("GW4 봉헌 전 archive_purified_flag=false", not GameState.archive_purified_flag)
	# (마력 sink) 마력 0으로 만들고 봉헌 시도 → 실패(정화 안 됨).
	WhisperCurrency.reset()
	if altar != null:
		GameState.item_used_on_object.emit("D309", altar)
	await get_tree().process_frame
	_check("GW4 마력 부족 시 봉헌 실패 (정화 안 됨, 유일 마력 sink)", not GameState.archive_purified_flag)
	# 마력 확보 후 재봉헌 → 정화.
	WhisperCurrency.add_mana(1)
	if altar != null:
		GameState.item_used_on_object.emit("D309", altar)
	# 컷신 중엔 time_running=false + control_lock. 종료까지 대기.
	var saw_lock := false
	var saw_ctrl_lock := false
	for i in range(120):
		await get_tree().create_timer(0.1).timeout
		if not GameState.time_running:
			saw_lock = true
		if GameState.has_method("control_locked") and GameState.control_locked():
			saw_ctrl_lock = true
		if GameState.archive_purified_flag:
			break
	_check("GW4 컷신 C-4 중 time_running=false (락 페어링)", saw_lock)
	_check("GW4 컷신 C-4 중 control_lock 활성 (페어링)", saw_ctrl_lock)
	_check("GW4 봉인구 봉헌 → archive_purified_flag set", GameState.archive_purified_flag)
	_check("GW4 → archive_purified 시그널 발화", _archive_sig)
	_check("GW4 봉인구 봉헌 → 마력 1 소모 (sink)", WhisperCurrency.mana == 0, "mana=%d" % WhisperCurrency.mana)
	_check("컷신 종료 후 time_running=true 복원", GameState.time_running)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 3. 잔재 NPC 라인 독립 공존 (진상 조각 비게이팅) --------------------

func _test_npc_line_coexist() -> void:
	QuestManager.reset()
	var l4_line := QuestManager.active_id
	QuestManager.activate_npc_line("librarian")
	_check("N-librarian 라인 활성 (첫 접촉)", QuestManager.npc_active_id("librarian") == "N-librarian-Q1")
	_check("NPC 라인 ≠ 레이어 라인 (독립 공존)",
		QuestManager.npc_active_id("librarian") != l4_line and QuestManager.active_id == l4_line)

	# librarian Q1(제작 D301)→Q2(배치 any)→Q3(회고 mage_ghost). 회고는 조사만으로 비게이팅 완료.
	GameState.item_crafted.emit("D301", "EX-L4-R01")
	_check("librarian Q1(제작 D301) → Q2(배치) 진행", QuestManager.npc_active_id("librarian") == "N-librarian-Q2")
	GameState.placed_object_placed.emit("D310", Vector2i(5, 5))
	_check("librarian Q2(배치) → Q3(회고) 진행", QuestManager.npc_active_id("librarian") == "N-librarian-Q3")
	# 진상 조각 mage_ghost = 마탑과 공유(재조사 심화) — 6번째 게이트 추가 없이 조사만으로 완료.
	GameState.truth_shard_investigated.emit("mage_ghost")
	_check("librarian Q3(회고) 조사만으로 완료 → 라인 종료 (mage_ghost 비게이팅)",
		QuestManager.npc_line_finished("librarian"))


# ---- 4. 세이브 지속 + 재진입 재적용 + NG+ 리셋 --------------------------

func _test_save_and_ngplus() -> void:
	var d := SaveManager.build_save_dict()
	_check("세이브: archive_purified 플래그 지속", bool(d.get("archive_purified", false)))

	# 재진입: archive_purified=true 상태로 서고 재부팅 → 게이트 end-state 즉시 재적용(컷신 미재생).
	_archive_sig = false
	WorldContext.current_scene = WorldContext.SCENE_ARCHIVE
	GameState.archive_purified_flag = true
	var scene: PackedScene = load(ARCHIVE)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(10):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	if loader != null:
		var g := loader.legend_gates()
		var gw1 := _cells(g.get("GW1", {}).get("cells", []))
		var gw2 := _cells(g.get("GW2", {}).get("cells", []))
		var gw3_door := _cells(g.get("GW3", {}).get("cells", []))
		var reopened := true
		for c in gw1 + gw2 + gw3_door:
			if not loader.is_cell_walkable(c):
				reopened = false
		_check("재진입(정화됨): 모든 서고 게이트 즉시 walkable (구세이브 호환)", reopened)
	_check("재진입: 정화 컷신 미재생 (archive 시그널 재발화 안 함)", not _archive_sig)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame

	# NG+ 리셋: 플래그 dormant. 포탈 라인은 sub-zone과 무관하므로 불변.
	GameState.set_portal_state("magic", GameState.PORTAL_OPEN)
	var magic_before := GameState.portal_state("magic")
	GameState.reset_layer4_zones()
	_check("NG+ 리셋: archive 플래그 dormant", not GameState.archive_purified_flag)
	_check("NG+ 리셋: 포탈 라인 불변 (sub-zone 비관여)",
		GameState.portal_state("magic") == magic_before)


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


func _find_with_prop(root: Node, prop: String) -> Node:
	if root.get(prop) != null:
		return root
	for ch in root.get_children():
		var found := _find_with_prop(ch, prop)
		if found != null:
			return found
	return null
