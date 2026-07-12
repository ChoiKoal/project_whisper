extends Node
## (EXL3-6) L3 확장 「태엽 광산」 FLOW acceptance harness. l3s_map_harness proves the map/objects
## and l3x_bfs.py proves gate ORDER; this proves the ENTRY/GATE/NPC/PURIFICATION/SAVE flow:
##   1. 라우팅: WorldContext.SCENE_MINE 씬 경로 + clockwork_city 승강로 하강은 L3 정화 후에만 스폰.
##   2. 광산 실 씬 부팅 → GM1(궤도판 배치)→GM2(통풍문 사용)→GM3(3레버 전환 퍼즐)→GM4(봉헌) 순서 구동
##      → mine_purified. 부분(2레버)만으론 GM3 미개방(완결성).
##   3. 잔재 NPC 라인(N-digger) = 레이어 라인과 독립 공존, 진상 조각(stopped_robot) 비게이팅.
##   4. 컷신 C-4 (control_lock/time_running 페어링) → 종료 후 복원. 잔류 태엽 발전기 = idempotent add_energy(1).
##   5. 세이브: mine_purified 지속 + 재진입 시 게이트 end-state 재적용(컷신 미재생, 구세이브 호환).
##   6. NG+ 리셋: 플래그 dormant (reset_layer3_zones). 포탈 라인 불변(sub-zone 비관여).
##
## Boots the REAL clockwork_mine.tscn and drives the real controller/signals.
## API 직접 정화 호출 금지 — 실제 게이트 시그널(placed_object_placed/item_used_on_object)로 구동.
## Prints PASS/FAIL; quits with the failure count as exit code.

const MINE := "res://scenes/world/clockwork_mine.tscn"

var _fail := 0
var _mine_sig := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L3s FLOW HARNESS (광산 진입/게이트/NPC/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer3_zones"): GameState.reset_layer3_zones()
	GameState.reset_layer3()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false
	SaveManager.unregister_world()
	GameState.mine_purified.connect(func(_z): _mine_sig = true)

	await _test_routing()
	await _test_gate_chain()
	await _test_npc_line_coexist()
	await _test_save_and_ngplus()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. 라우팅 + 승강로 하강 개방 조건 ------------------------------------

func _test_routing() -> void:
	_check("SCENE_MINE 씬 경로 = clockwork_mine",
		WorldContext.scene_path(WorldContext.SCENE_MINE).findn("clockwork_mine") >= 0)
	# clockwork_city 승강로 하강은 L3 정화(layer3_purified) 후에만 스폰.
	GameState.layer3_purified_flag = false
	var cc_scene: PackedScene = load("res://scenes/world/clockwork_city.tscn")
	var cc: Node = cc_scene.instantiate()
	add_child(cc)
	for i in range(6):
		await get_tree().process_frame
	var sess: Node = cc.get_node_or_null("ClockworkCity")
	_check("clockwork_city ClockworkCity present", sess != null)
	if sess != null:
		_check("미정화 L3: 승강로 하강 미스폰 (광산 잠김)",
			not bool(sess.get("_mine_descent_spawned")))
	cc.queue_free()
	for i in range(3):
		await get_tree().process_frame
	# 정화 상태로 재부팅 → 승강로 하강 스폰.
	GameState.layer3_purified_flag = true
	var cc2: Node = cc_scene.instantiate()
	add_child(cc2)
	for i in range(6):
		await get_tree().process_frame
	var sess2: Node = cc2.get_node_or_null("ClockworkCity")
	if sess2 != null:
		_check("정화 L3: 승강로 하강 스폰 (광산 개방)",
			bool(sess2.get("_mine_descent_spawned")))
	cc2.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 2. 게이트 체인 GM1→GM2→GM3→GM4 → 정화 -------------------------------

func _test_gate_chain() -> void:
	WorldContext.current_scene = WorldContext.SCENE_MINE
	if GameState.has_method("reset_layer3_zones"): GameState.reset_layer3_zones()
	_mine_sig = false
	WhisperCurrency.reset()
	var scene: PackedScene = load(MINE)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	var gates: Node = map.get_node_or_null("L3mGateController")
	_check("광산 loader + L3mGateController present", loader != null and gates != null)
	if loader == null or gates == null:
		map.queue_free()
		return
	var g := loader.legend_gates()
	var gm1 := _cells(g.get("GM1", {}).get("cells", []))
	var gm2 := _cells(g.get("GM2", {}).get("cells", []))
	var gm3: Dictionary = g.get("GM3", {})
	var gm3_slots := _cells(gm3.get("slot_cells", []))
	var gm3_door := _cells(gm3.get("cells", []))

	# GM1 붕락 궤도판(D279) → 붕락 낙석 협곡 K 배치. 배치 전엔 non-walkable(암반).
	var pre_walk := loader.is_cell_walkable(gm1[0]) if not gm1.is_empty() else true
	_check("GM1 배치 전 붕락 낙석 협곡 K non-walkable", not pre_walk)
	for c in gm1:
		GameState.placed_object_placed.emit("D279", c)
	await get_tree().process_frame
	var gm1_walk := true
	for c in gm1:
		if not loader.is_cell_walkable(c):
			gm1_walk = false
	_check("GM1 붕락 궤도판 배치 → K walkable (궤도판)", gm1_walk)

	# GM2 막힌 통풍문: 감압 밸브 젤(D281) 사용 → D 셀 개방.
	var pre2 := loader.is_cell_walkable(gm2[0]) if not gm2.is_empty() else true
	_check("GM2 사용 전 막힌 통풍문 D non-walkable", not pre2)
	var vent := _find_use_target(loader, "vent_door")
	_check("GM2 막힌 통풍문 use-target present", vent != null)
	if vent != null:
		GameState.item_used_on_object.emit("D281", vent)
	await get_tree().process_frame
	var gm2_walk := true
	for c in gm2:
		if not loader.is_cell_walkable(c):
			gm2_walk = false
	_check("GM2 감압 밸브 젤 사용 → 통풍문 D walkable (개방)", gm2_walk)

	# GM3 3레버 전환 미니 퍼즐: α(D282)·β(D283)·γ(D284) 슬롯 배치 → 광차문 M 개방.
	# 부분(2레버)만으론 미개방 → 완결성 확인.
	if gm3_slots.size() >= 2:
		GameState.placed_object_placed.emit("D282", gm3_slots[0])
		GameState.placed_object_placed.emit("D283", gm3_slots[1])
		await get_tree().process_frame
		var door_partial := gm3_door.is_empty() or loader.is_cell_walkable(gm3_door[0])
		_check("GM3 2레버만 전환 → 광차문 M 여전히 잠김", not door_partial)
	if gm3_slots.size() >= 3:
		GameState.placed_object_placed.emit("D284", gm3_slots[2])
		await get_tree().process_frame
	var gm3_walk := true
	for c in gm3_door:
		if not loader.is_cell_walkable(c):
			gm3_walk = false
	_check("GM3 3레버 전환 완성 → 광차문 M walkable (퍼즐 해결)", gm3_walk)

	# 잔류 태엽 발전기: idempotent add_energy — 두 번 트리거해도 +1만.
	var e0 := WhisperCurrency.energy
	if gates.has_method("_grant_energy"):
		gates.call("_grant_energy", null)
		gates.call("_grant_energy", null)   # 중복 시도
	_check("잔류 태엽 발전기 → energy +1 (첫 재획득)", WhisperCurrency.energy == e0 + 1, "energy=%d" % WhisperCurrency.energy)
	_check("잔류 태엽 발전기 재방문 중복 없음 (idempotent)", WhisperCurrency.energy == e0 + 1)

	# GM4 태엽 노심 봉헌: 태엽 노심(D286) 봉헌 → 컷신 C-4 → mine_purified.
	_check("GM4 봉헌 전 mine_purified_flag=false", not GameState.mine_purified_flag)
	var altar := _find_use_target(loader, "excavator_altar")
	_check("GM4 태엽 노심 봉헌 목 use-target present", altar != null)
	if altar != null:
		GameState.item_used_on_object.emit("D286", altar)
	# 컷신 중엔 time_running=false. 종료까지 대기.
	var saw_lock := false
	for i in range(120):
		await get_tree().create_timer(0.1).timeout
		if not GameState.time_running:
			saw_lock = true
		if GameState.mine_purified_flag:
			break
	_check("GM4 컷신 C-4 중 time_running=false (락 페어링)", saw_lock)
	_check("GM4 태엽 노심 봉헌 → mine_purified_flag set", GameState.mine_purified_flag)
	_check("GM4 → mine_purified 시그널 발화", _mine_sig)
	_check("컷신 종료 후 time_running=true 복원", GameState.time_running)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 3. 잔재 NPC 라인 독립 공존 (진상 조각 비게이팅) --------------------

func _test_npc_line_coexist() -> void:
	QuestManager.reset()
	var l3_line := QuestManager.active_id
	QuestManager.activate_npc_line("digger")
	_check("N-digger 라인 활성 (첫 접촉)", QuestManager.npc_active_id("digger") == "N-digger-Q1")
	_check("NPC 라인 ≠ 레이어 라인 (독립 공존)",
		QuestManager.npc_active_id("digger") != l3_line and QuestManager.active_id == l3_line)

	# digger Q1(제작 D278)→Q2(배치)→Q3(회고 stopped_robot) 순서 구동. 회고는 조사만으로 비게이팅 완료.
	GameState.item_crafted.emit("D278", "EX-L3-R01")
	_check("digger Q1(제작) → Q2(배치) 진행", QuestManager.npc_active_id("digger") == "N-digger-Q2")
	GameState.placed_object_placed.emit("D291", Vector2i(5, 5))
	_check("digger Q2(배치) → Q3(회고) 진행", QuestManager.npc_active_id("digger") == "N-digger-Q3")
	GameState.truth_shard_investigated.emit("stopped_robot")
	_check("digger Q3(회고) 조사만으로 완료 → 라인 종료",
		QuestManager.npc_line_finished("digger"))


# ---- 4. 세이브 지속 + 재진입 재적용 + NG+ 리셋 --------------------------

func _test_save_and_ngplus() -> void:
	var d := SaveManager.build_save_dict()
	_check("세이브: mine_purified 플래그 지속", bool(d.get("mine_purified", false)))

	# 재진입: mine_purified=true 상태로 광산 재부팅 → 게이트 end-state 즉시 재적용(컷신 미재생).
	_mine_sig = false
	WorldContext.current_scene = WorldContext.SCENE_MINE
	GameState.mine_purified_flag = true
	var scene: PackedScene = load(MINE)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	if loader != null:
		var g := loader.legend_gates()
		var gm1 := _cells(g.get("GM1", {}).get("cells", []))
		var gm2 := _cells(g.get("GM2", {}).get("cells", []))
		var gm3_door := _cells(g.get("GM3", {}).get("cells", []))
		var reopened := true
		for c in gm1 + gm2 + gm3_door:
			if not loader.is_cell_walkable(c):
				reopened = false
		_check("재진입(정화됨): 모든 광산 게이트 즉시 walkable (구세이브 호환)", reopened)
	_check("재진입: 정화 컷신 미재생 (mine 시그널 재발화 안 함)", not _mine_sig)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame

	# NG+ 리셋: 플래그 dormant. 포탈 라인은 sub-zone과 무관하므로 불변.
	GameState.set_portal_state("machine", GameState.PORTAL_OPEN)
	var machine_before := GameState.portal_state("machine")
	GameState.reset_layer3_zones()
	_check("NG+ 리셋: mine 플래그 dormant", not GameState.mine_purified_flag)
	_check("NG+ 리셋: 포탈 라인 불변 (sub-zone 비관여)",
		GameState.portal_state("machine") == machine_before)


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
