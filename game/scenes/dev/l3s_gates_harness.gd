extends Node
## (EXL3-6) L3 확장 「태엽 광산」 게이트 토폴로지/실링 acceptance harness. l3s_flow_harness drives the
## full chain; THIS harness proves the static gate wiring on a freshly-booted scene (before any
## placement/use), complementing l3x_bfs.py (order proof):
##   1. legend gates GM1~GM4 = 4종 타입 비반복 (placement/use/puzzle-placement/chain — level-design B).
##   2. 각 게이트 병목 셀이 legend에 존재 + 부팅 직후 닫힘 셀은 non-walkable (seal 적용).
##      GM1 K(암반 자연 seal)·GM2 D·GM3 M 닫힘 = 벽. GM3 3 레버 슬롯 존재.
##   3. GM4 봉헌 목 H는 void 병목이 아니라 갱도 내부 봉헌 지점(GM3 통과 후 도달) — 지형 벽 아님.
##   4. 게이트 컨트롤러가 부팅 시 idle 아님(활성) + 정화 전 mine_purified_flag=false.
##
## Boots the REAL clockwork_mine.tscn. Prints PASS/FAIL; quits with the failure count as exit code.

const MINE := "res://scenes/world/clockwork_mine.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L3s GATES HARNESS (광산 게이트 토폴로지/실링) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer3_zones"): GameState.reset_layer3_zones()
	WhisperCurrency.reset()
	SaveManager.pending_load = false
	WorldContext.current_scene = WorldContext.SCENE_MINE

	var scene: PackedScene = load(MINE)
	var map := scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L3mGateController")
	_check("loader present", loader != null)
	_check("L3mGateController present", gates != null)
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
	for gid in ["GM1", "GM2", "GM3", "GM4"]:
		_check("%s legend 존재" % gid, g.has(gid))
	# 타입 비반복: GM1 placement(stepping) → GM2 use → GM3 placement(puzzle) → GM4 chain.
	# GM1·GM3 둘 다 placement이나 비인접(use형 GM2가 사이) + 조작 결 다름(단일 배치 vs 3레버 전환).
	var t1 := String(g.get("GM1", {}).get("type", ""))
	var t2 := String(g.get("GM2", {}).get("type", ""))
	var t3 := String(g.get("GM3", {}).get("type", ""))
	var t4 := String(g.get("GM4", {}).get("type", ""))
	_check("GM1=placement(stepping)", t1 == "placement" and String(g["GM1"].get("kind", "")) == "stepping")
	_check("GM2=use", t2 == "use")
	_check("GM3=placement(puzzle) 3슬롯", t3 == "placement" and String(g["GM3"].get("kind", "")) == "puzzle" \
		and _cells(g["GM3"].get("slot_cells", [])).size() == 3)
	_check("GM4=chain(offering)", t4 == "chain")
	# 인접 게이트 타입 비반복(level-design B): GM1≠GM2, GM2≠GM3, GM3≠GM4.
	_check("인접 게이트 타입 비반복 (배치→사용→배치퍼즐→체인)",
		t1 != t2 and t2 != t3 and t3 != t4)


# ---- 2: 부팅 직후 닫힘 게이트 seal (non-walkable) --------------------------

func _test_gate_seal(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	var gm1 := _cells(g.get("GM1", {}).get("cells", []))
	var gm2 := _cells(g.get("GM2", {}).get("cells", []))
	var gm3_door := _cells(g.get("GM3", {}).get("cells", []))
	# 부팅 직후(아무 배치/사용 없음) 게이트 병목은 전부 non-walkable = 벽.
	var gm1_sealed := true
	for c in gm1:
		if loader.is_cell_walkable(c): gm1_sealed = false
	_check("GM1 붕락 낙석 협곡 K 부팅 시 non-walkable (자연 암반 seal)", gm1_sealed and not gm1.is_empty())
	var gm2_sealed := true
	for c in gm2:
		if loader.is_cell_walkable(c): gm2_sealed = false
	_check("GM2 막힌 통풍문 D 부팅 시 non-walkable (컨트롤러 seal)", gm2_sealed and not gm2.is_empty())
	var gm3_sealed := true
	for c in gm3_door:
		if loader.is_cell_walkable(c): gm3_sealed = false
	_check("GM3 광차문 M 부팅 시 non-walkable (컨트롤러 seal)", gm3_sealed and not gm3_door.is_empty())


# ---- 3: GM4 봉헌 목 = 갱도 내부 봉헌 지점 (지형 벽 아님) -------------------

func _test_offering_point(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	var gm4 := _cells(g.get("GM4", {}).get("cells", []))
	_check("GM4 봉헌 목 H 셀 존재", gm4.size() == 1, "n=%d" % gm4.size())
	# H는 최심부 갱도(row1~5) 안. GM3 광차문을 넘으면 도달하는 봉헌 지점 — offering 특례(§A-6.2).
	if not gm4.is_empty():
		_check("GM4 봉헌 목 H는 최심부 갱도(row<=5)에 위치", gm4[0].y <= 5, "H=%s" % str(gm4[0]))
	# excavator_altar 오브젝트가 봉헌 대상으로 스폰됨.
	var altar_seen := false
	for key in loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == "excavator_altar":
			altar_seen = true
	_check("GM4 태엽 노심 봉헌 목(excavator_altar) 오브젝트 스폰", altar_seen)


# ---- 4: 컨트롤러 활성 + 정화 전 상태 --------------------------------------

func _test_controller_active(gates: Node) -> void:
	_check("게이트 컨트롤러 활성 (idle 아님)", bool(gates.get("_active")))
	_check("정화 전 mine_purified_flag = false", not GameState.mine_purified_flag)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out
