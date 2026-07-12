extends Node
## (EXL2-6) L2 확장 「지하 데이터 성소」 게이트 토폴로지/실링 acceptance harness. l2s_flow_harness drives
## the full chain; THIS harness proves the static gate wiring on a freshly-booted scene (before any
## placement/use), complementing l2x_bfs.py (order proof):
##   1. legend gates GB1~GB4 = 4종 타입 비반복 (placement/use/puzzle-placement/chain — level-design B).
##   2. 각 게이트 병목 셀이 legend에 존재 + 부팅 직후 닫힘 셀은 non-walkable (seal 적용).
##      GB1 K(냉각수 자연 seal)·GB2 D·GB3 M 닫힘 = 벽. GB3 3 정합 슬롯 존재.
##   3. GB4 봉헌 목 H는 void 병목이 아니라 사원 내부 봉헌 지점(GB3 통과 후 도달) — 지형 벽 아님.
##   4. 게이트 컨트롤러가 부팅 시 idle 아님(활성) + 정화 전 sanctum_purified_flag=false.
##
## Boots the REAL data_sanctum.tscn. Prints PASS/FAIL; quits with the failure count as exit code.

const SANCTUM := "res://scenes/world/data_sanctum.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L2s GATES HARNESS (성소 게이트 토폴로지/실링) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer2_zones"): GameState.reset_layer2_zones()
	WhisperCurrency.reset()
	SaveManager.pending_load = false
	WorldContext.current_scene = WorldContext.SCENE_SANCTUM

	var scene: PackedScene = load(SANCTUM)
	var map := scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L2sGateController")
	_check("loader present", loader != null)
	_check("L2sGateController present", gates != null)
	if loader == null or gates == null:
		print("=== RESULT: FAIL (missing core nodes) ===")
		get_tree().quit(1)
		return

	_test_gate_types(loader)
	_test_gate_seal(loader)
	_test_offering_point(loader)
	_test_controller_active(gates)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1: 게이트 4종 타입 비반복 --------------------------------------------

func _test_gate_types(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	for gid in ["GB1", "GB2", "GB3", "GB4"]:
		_check("%s legend 존재" % gid, g.has(gid))
	# 타입 비반복: GB1 placement(stepping) → GB2 use → GB3 placement(puzzle) → GB4 chain.
	# GB1·GB3 둘 다 placement이나 비인접(use형 GB2가 사이) + 조작 결 다름(단일 배치 vs 3조각 정합).
	var t1 := String(g.get("GB1", {}).get("type", ""))
	var t2 := String(g.get("GB2", {}).get("type", ""))
	var t3 := String(g.get("GB3", {}).get("type", ""))
	var t4 := String(g.get("GB4", {}).get("type", ""))
	_check("GB1=placement(stepping)", t1 == "placement" and String(g["GB1"].get("kind", "")) == "stepping")
	_check("GB2=use", t2 == "use")
	_check("GB3=placement(puzzle) 3슬롯", t3 == "placement" and String(g["GB3"].get("kind", "")) == "puzzle" \
		and _cells(g["GB3"].get("slot_cells", [])).size() == 3)
	_check("GB4=chain(offering)", t4 == "chain")
	# 인접 게이트 타입 비반복(level-design B): GB1≠GB2, GB2≠GB3, GB3≠GB4.
	_check("인접 게이트 타입 비반복 (배치→사용→배치퍼즐→체인)",
		t1 != t2 and t2 != t3 and t3 != t4)


# ---- 2: 부팅 직후 닫힘 게이트 seal (non-walkable) --------------------------

func _test_gate_seal(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	var gb1 := _cells(g.get("GB1", {}).get("cells", []))
	var gb2 := _cells(g.get("GB2", {}).get("cells", []))
	var gb3_door := _cells(g.get("GB3", {}).get("cells", []))
	# 부팅 직후(아무 배치/사용 없음) 게이트 병목은 전부 non-walkable = 벽.
	var gb1_sealed := true
	for c in gb1:
		if loader.is_cell_walkable(c): gb1_sealed = false
	_check("GB1 냉각 침수로 K 부팅 시 non-walkable (자연 물 seal)", gb1_sealed and not gb1.is_empty())
	var gb2_sealed := true
	for c in gb2:
		if loader.is_cell_walkable(c): gb2_sealed = false
	_check("GB2 봉인 격벽 D 부팅 시 non-walkable (컨트롤러 seal)", gb2_sealed and not gb2.is_empty())
	var gb3_sealed := true
	for c in gb3_door:
		if loader.is_cell_walkable(c): gb3_sealed = false
	_check("GB3 데이터 문 M 부팅 시 non-walkable (컨트롤러 seal)", gb3_sealed and not gb3_door.is_empty())


# ---- 3: GB4 봉헌 목 = 사원 내부 봉헌 지점 (지형 벽 아님) -------------------

func _test_offering_point(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	var gb4 := _cells(g.get("GB4", {}).get("cells", []))
	_check("GB4 봉헌 목 H 셀 존재", gb4.size() == 1, "n=%d" % gb4.size())
	# H는 사원(row1~5) 안. GB3 데이터 문을 넘으면 도달하는 봉헌 지점 — offering 특례(§A-6.2).
	if not gb4.is_empty():
		_check("GB4 봉헌 목 H는 최심부 사원(row<=5)에 위치", gb4[0].y <= 5, "H=%s" % str(gb4[0]))
	# backup_altar 오브젝트가 봉헌 대상으로 스폰됨.
	var altar_seen := false
	for key in loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == "backup_altar":
			altar_seen = true
	_check("GB4 백업 봉헌 목(backup_altar) 오브젝트 스폰", altar_seen)


# ---- 4: 컨트롤러 활성 + 정화 전 상태 --------------------------------------

func _test_controller_active(gates: Node) -> void:
	_check("게이트 컨트롤러 활성 (idle 아님)", bool(gates.get("_active")))
	_check("정화 전 sanctum_purified_flag = false", not GameState.sanctum_purified_flag)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out
