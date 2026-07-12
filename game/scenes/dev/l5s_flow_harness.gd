extends Node
## (EXL5-6) L5 확장 「침묵의 종탑」 FLOW acceptance harness. l5s_map_harness proves the map/objects
## and l5x_bfs.py proves gate ORDER; this proves the ENTRY/GATE/NPC/PURIFICATION/SAVE flow (l4s_flow
## 패턴 계승):
##   1. 라우팅: WorldContext.SCENE_BELFRY 씬 경로(belfry) + cathedral 종탑 하강 계단은 L5 구역1
##      정화(layer5_purified) 후에만 스폰(대제단 봉헌="응답" 후 종탑 계단 활성).
##   2. 종탑 실 씬 부팅 → GB1(종석 잔교 배치)→GB2(정음의 물 사용)→GB3(3종 순서 퍼즐 chime_ordered)→
##      GB4(응답의 타종구 봉헌+3속성 소비+컷신 C-4) 순서 구동 → belfry_purified.
##      순서 오류(GB3 종 역순)·부분(2종)만으론 상층문 미개방(완결성). 3속성 부족 시 봉헌 실패.
##   3. 잔재 NPC 라인(N-bellkeeper) = 레이어 라인과 독립 공존, 진상 조각(petrified_pilgrim) 비게이팅.
##   4. 컷신 C-4 (control_lock/time_running 페어링) → 종료 후 복원 + ESC(ui_cancel) 스킵.
##      잔향 성수반 F = idempotent add_vita(1).
##   5. 세이브: belfry_purified 지속 + 재진입 시 게이트 end-state 재적용(컷신 미재생, 구세이브 호환).
##   6. NG+ 리셋: 플래그 dormant (reset_layer5_zones). 포탈 라인 불변(sub-zone 비관여).
##
## Boots the REAL belfry.tscn and drives the real controller/signals.
## API 직접 정화 호출 금지 — 실제 게이트 시그널(placed_object_placed/item_used_on_object)로 구동.
## Prints PASS/FAIL; quits with the failure count as exit code.

const BELFRY := "res://scenes/world/belfry.tscn"

var _fail := 0
var _belfry_sig := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L5S FLOW HARNESS (종탑 진입/게이트/NPC/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer5_zones"): GameState.reset_layer5_zones()
	GameState.reset_layer5()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false
	SaveManager.unregister_world()
	GameState.belfry_purified.connect(func(_z): _belfry_sig = true)

	await _test_routing()
	await _test_gate_chain()
	_test_npc_line_coexist()
	await _test_save_and_ngplus()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. 라우팅 + 종탑 하강 계단 개방 조건 --------------------------------

func _test_routing() -> void:
	_check("SCENE_BELFRY 씬 경로 = belfry",
		WorldContext.scene_path(WorldContext.SCENE_BELFRY).findn("belfry") >= 0)
	# cathedral 종탑 하강 계단은 L5 구역1 정화(layer5_purified) 후에만 스폰.
	GameState.layer5_purified_flag = false
	var cath_scene: PackedScene = load("res://scenes/world/cathedral.tscn")
	var cath: Node = cath_scene.instantiate()
	add_child(cath)
	for i in range(8):
		await get_tree().process_frame
	var sess: Node = _find_with_prop(cath, "_belfry_descent_spawned")
	_check("cathedral 세션 present", sess != null)
	if sess != null:
		_check("미정화 L5: 종탑 하강 계단 미스폰 (종탑 잠김)",
			not bool(sess.get("_belfry_descent_spawned")))
	cath.queue_free()
	for i in range(3):
		await get_tree().process_frame
	# 정화 상태로 재부팅 → 하강 계단 스폰.
	GameState.layer5_purified_flag = true
	var cath2: Node = cath_scene.instantiate()
	add_child(cath2)
	for i in range(8):
		await get_tree().process_frame
	var sess2: Node = _find_with_prop(cath2, "_belfry_descent_spawned")
	if sess2 != null:
		_check("정화 L5: 종탑 하강 계단 스폰 (종탑 개방)",
			bool(sess2.get("_belfry_descent_spawned")))
	cath2.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 2. 게이트 체인 GB1→GB2→GB3→GB4 → 정화 -------------------------------

func _test_gate_chain() -> void:
	WorldContext.current_scene = WorldContext.SCENE_BELFRY
	if GameState.has_method("reset_layer5_zones"): GameState.reset_layer5_zones()
	_belfry_sig = false
	WhisperCurrency.reset()
	var scene: PackedScene = load(BELFRY)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(10):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	var gates: Node = map.get_node_or_null("L5bGateController")
	_check("종탑 loader + L5bGateController present", loader != null and gates != null)
	if loader == null or gates == null:
		map.queue_free()
		return
	var g := loader.legend_gates()
	var gb1 := _cells(g.get("GB1", {}).get("cells", []))
	var gb2 := _cells(g.get("GB2", {}).get("cells", []))
	var gb3: Dictionary = g.get("GB3", {})
	var gb3_slots := _cells(gb3.get("slot_cells", []))
	var gb3_door := _cells(gb3.get("cells", []))
	var gb1_altar: Variant = g.get("GB1", {}).get("altar", [])
	var altar_cell: Vector2i = Vector2i.ZERO
	if gb1_altar is Array and (gb1_altar as Array).size() >= 2:
		altar_cell = Vector2i(int(gb1_altar[0]), int(gb1_altar[1]))
	elif not gb1.is_empty():
		altar_cell = gb1[0]

	# GB1 종석 잔교(D325) → 종석 제단 X 배치 → 잔교 g 셀 walkable. 배치 전엔 non-walkable(허공).
	var pre_walk := loader.is_cell_walkable(gb1[0]) if not gb1.is_empty() else true
	_check("GB1 배치 전 종석 잔교 g non-walkable (허공)", not pre_walk)
	GameState.placed_object_placed.emit("D325", altar_cell)
	await get_tree().process_frame
	var gb1_walk := true
	for c in gb1:
		if not loader.is_cell_walkable(c):
			gb1_walk = false
	_check("GB1 종석 잔교 배치 → 잔교 g walkable (종석 다리)", gb1_walk)

	# GB2 흐려진 종음 결계: 정음의 물(D327) 사용 → e 셀 개방.
	var pre2 := loader.is_cell_walkable(gb2[0]) if not gb2.is_empty() else true
	_check("GB2 사용 전 흐려진 종음 결계문 e non-walkable", not pre2)
	var ward := _find_use_target(loader, "chime_ward")
	_check("GB2 흐려진 종음 결계 use-target present", ward != null)
	if ward != null:
		GameState.item_used_on_object.emit("D327", ward)
	await get_tree().process_frame
	var gb2_walk := true
	for c in gb2:
		if not loader.is_cell_walkable(c):
			gb2_walk = false
	_check("GB2 정음의 물 사용 → 결계문 e walkable (개방)", gb2_walk)

	# GB3 타종 울림 순서 미니 퍼즐 (chime_ordered_3): D328→D329→D330 순서대로 y 슬롯 배치 → 상층문 L 개방.
	# (a) 역순(D329 먼저) → 미해결. (b) 2종만 → 미해결. (c) 정순 3종 완성 → 해결(완결성).
	if gb3_slots.size() >= 3:
		# (a) 역순: D329을 먼저 배치 → 상층문 여전히 잠김.
		GameState.placed_object_placed.emit("D329", gb3_slots[1])
		GameState.placed_object_placed.emit("D328", gb3_slots[0])
		await get_tree().process_frame
		var wrong_order := gb3_door.is_empty() or loader.is_cell_walkable(gb3_door[0])
		_check("GB3 역순 타종(2종) → 상층문 L 여전히 잠김 (순서 강제)", not wrong_order)
		# (c) 정순으로 다시: D328→D329→D330. 컨트롤러가 distinct-chime 순서로 판정.
		GameState.placed_object_placed.emit("D328", gb3_slots[0])
		GameState.placed_object_placed.emit("D329", gb3_slots[1])
		await get_tree().process_frame
		var partial := gb3_door.is_empty() or loader.is_cell_walkable(gb3_door[0])
		_check("GB3 정순 2종만 → 상층문 L 여전히 잠김 (미완)", not partial)
		GameState.placed_object_placed.emit("D330", gb3_slots[2])
		await get_tree().process_frame
	var gb3_walk := true
	for c in gb3_door:
		if not loader.is_cell_walkable(c):
			gb3_walk = false
	_check("GB3 3종 순서 완성 → 상층문 L walkable (퍼즐 해결)", gb3_walk)

	# 잔향 성수반 F: idempotent add_vita — 두 번 트리거해도 +1만.
	var v0 := WhisperCurrency.vita
	if gates.has_method("_grant_vita"):
		gates.call("_grant_vita", null)
		gates.call("_grant_vita", null)   # 중복 시도
	_check("잔향 성수반 → vita +1 (첫 재획득)", WhisperCurrency.vita == v0 + 1, "vita=%d" % WhisperCurrency.vita)
	_check("잔향 성수반 재방문 중복 없음 (idempotent)", WhisperCurrency.vita == v0 + 1)

	# GB4 응답의 타종구 봉헌: 3속성 부족 시 봉헌 실패 검증 후, 3속성 확보하고 봉헌 → 컷신 C-4 → belfry_purified.
	var bell_altar := _find_use_target(loader, "great_bell_altar")
	_check("GB4 봉헌 목 use-target present", bell_altar != null)
	_check("GB4 봉헌 전 belfry_purified_flag=false", not GameState.belfry_purified_flag)
	# (3속성 sink) 속삭임 0으로 만들고 봉헌 시도 → 실패(정화 안 됨).
	WhisperCurrency.reset()
	if bell_altar != null:
		GameState.item_used_on_object.emit("D332", bell_altar)
	await get_tree().process_frame
	_check("GB4 3속성 부족 시 봉헌 실패 (정화 안 됨, 유일 3속성 sink)", not GameState.belfry_purified_flag)
	# 3속성(에너지·마력·생명) 각1 확보 후 재봉헌 → 정화.
	WhisperCurrency.add_energy(1)
	WhisperCurrency.add_mana(1)
	WhisperCurrency.add_vita(1)
	if bell_altar != null:
		GameState.item_used_on_object.emit("D332", bell_altar)
	# 컷신 중엔 time_running=false + control_lock. 종료까지 대기.
	var saw_lock := false
	var saw_ctrl_lock := false
	for i in range(120):
		await get_tree().create_timer(0.1).timeout
		if not GameState.time_running:
			saw_lock = true
		if GameState.has_method("control_locked") and GameState.control_locked():
			saw_ctrl_lock = true
		if GameState.belfry_purified_flag:
			break
	_check("GB4 컷신 C-4 중 time_running=false (락 페어링)", saw_lock)
	_check("GB4 컷신 C-4 중 control_lock 활성 (페어링)", saw_ctrl_lock)
	_check("GB4 응답의 타종구 봉헌 → belfry_purified_flag set", GameState.belfry_purified_flag)
	_check("GB4 → belfry_purified 시그널 발화", _belfry_sig)
	_check("GB4 봉헌 → 3속성 각1 소모 (energy·mana·vita sink)",
		WhisperCurrency.energy == 0 and WhisperCurrency.mana == 0 and WhisperCurrency.vita == 0,
		"e=%d m=%d v=%d" % [WhisperCurrency.energy, WhisperCurrency.mana, WhisperCurrency.vita])
	_check("컷신 종료 후 time_running=true 복원", GameState.time_running)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 3. 잔재 NPC 라인 독립 공존 (진상 조각 비게이팅) --------------------

func _test_npc_line_coexist() -> void:
	QuestManager.reset()
	var l5_line := QuestManager.active_id
	QuestManager.activate_npc_line("bellkeeper")
	_check("N-bellkeeper 라인 활성 (첫 접촉)", QuestManager.npc_active_id("bellkeeper") == "N-bellkeeper-Q1")
	_check("NPC 라인 ≠ 레이어 라인 (독립 공존)",
		QuestManager.npc_active_id("bellkeeper") != l5_line and QuestManager.active_id == l5_line)

	# bellkeeper Q1(제작 D324)→Q2(배치 any)→Q3(회고 petrified_pilgrim). 회고는 조사만으로 비게이팅 완료.
	GameState.item_crafted.emit("D324", "EX-L5-R01")
	_check("bellkeeper Q1(제작 D324) → Q2(배치) 진행", QuestManager.npc_active_id("bellkeeper") == "N-bellkeeper-Q2")
	GameState.placed_object_placed.emit("D333", Vector2i(5, 5))
	_check("bellkeeper Q2(배치) → Q3(회고) 진행", QuestManager.npc_active_id("bellkeeper") == "N-bellkeeper-Q3")
	# 진상 조각 petrified_pilgrim = 대성당과 공유(재조사 심화) — 6번째 게이트 추가 없이 조사만으로 완료.
	GameState.truth_shard_investigated.emit("petrified_pilgrim")
	_check("bellkeeper Q3(회고) 조사만으로 완료 → 라인 종료 (petrified_pilgrim 비게이팅)",
		QuestManager.npc_line_finished("bellkeeper"))


# ---- 4. 세이브 지속 + 재진입 재적용 + NG+ 리셋 --------------------------

func _test_save_and_ngplus() -> void:
	var d := SaveManager.build_save_dict()
	_check("세이브: belfry_purified 플래그 지속", bool(d.get("belfry_purified", false)))

	# 재진입: belfry_purified=true 상태로 종탑 재부팅 → 게이트 end-state 즉시 재적용(컷신 미재생).
	_belfry_sig = false
	WorldContext.current_scene = WorldContext.SCENE_BELFRY
	GameState.belfry_purified_flag = true
	var scene: PackedScene = load(BELFRY)
	var map: Node = scene.instantiate()
	add_child(map)
	for i in range(10):
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
		_check("재진입(정화됨): 모든 종탑 게이트 즉시 walkable (구세이브 호환)", reopened)
	_check("재진입: 정화 컷신 미재생 (belfry 시그널 재발화 안 함)", not _belfry_sig)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame

	# NG+ 리셋: 플래그 dormant. 포탈 라인은 sub-zone과 무관하므로 불변.
	GameState.set_portal_state("divinity", GameState.PORTAL_OPEN)
	var div_before := GameState.portal_state("divinity")
	GameState.reset_layer5_zones()
	_check("NG+ 리셋: belfry 플래그 dormant", not GameState.belfry_purified_flag)
	_check("NG+ 리셋: 포탈 라인 불변 (sub-zone 비관여)",
		GameState.portal_state("divinity") == div_before)


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
