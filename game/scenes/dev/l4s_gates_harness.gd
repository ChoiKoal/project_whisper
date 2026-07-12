extends Node
## (EXL4-6) L4 확장 「부유 서고」 게이트 토폴로지/실링 acceptance harness. l4s_flow_harness drives the
## full chain (GW1~GW4 순서 퍼즐·봉헌 포함); THIS harness proves the static gate wiring on a freshly-
## booted scene (before any placement/use), complementing l4x_bfs.py (order proof):
##   1. legend gates GW1~GW4 = 4종 타입 비반복 (placement/use/placement-puzzle/chain — level-design B).
##      GW1·GW3 둘 다 placement이나 비인접(use형 GW2가 사이) + 조작 결 다름(단일 배치 vs 순서 3서판).
##   2. 각 게이트 병목 셀이 legend에 존재 + 부팅 직후 닫힘 셀은 non-walkable (seal 적용).
##      GW1 g(허공 잔교)·GW2 v(결계문)·GW3 L(통로문) 닫힘 = 벽. GW3 3 서판 슬롯 존재.
##   3. GW4 봉헌 목 H는 void 병목이 아니라 최심부 코어 봉헌 지점(GW3 통과 후 도달) — 지형 벽 아님.
##   4. 게이트 컨트롤러가 부팅 시 idle 아님(활성) + 정화 전 archive_purified_flag=false.
##
## Boots the REAL floating_archive.tscn. Prints PASS/FAIL; quits with the failure count as exit code.

const ARCHIVE := "res://scenes/world/floating_archive.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L4s GATES HARNESS (부유 서고 게이트 토폴로지/실링) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	if GameState.has_method("reset_layer4_zones"): GameState.reset_layer4_zones()
	WhisperCurrency.reset()
	SaveManager.pending_load = false
	WorldContext.current_scene = WorldContext.SCENE_ARCHIVE

	var scene: PackedScene = load(ARCHIVE)
	var map := scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L4aGateController")
	_check("loader present", loader != null)
	_check("L4aGateController present", gates != null)
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
	for gid in ["GW1", "GW2", "GW3", "GW4"]:
		_check("%s legend 존재" % gid, g.has(gid))
	# 타입 비반복: GW1 placement(bridge) → GW2 use → GW3 placement(puzzle) → GW4 chain.
	# GW1·GW3 둘 다 placement이나 비인접(use형 GW2가 사이) + 조작 결 다름(단일 다리석 vs 순서 3서판).
	var t1 := String(g.get("GW1", {}).get("type", ""))
	var t2 := String(g.get("GW2", {}).get("type", ""))
	var t3 := String(g.get("GW3", {}).get("type", ""))
	var t4 := String(g.get("GW4", {}).get("type", ""))
	_check("GW1=placement(bridge)", t1 == "placement" and String(g["GW1"].get("kind", "")) == "bridge")
	_check("GW2=use", t2 == "use")
	_check("GW3=placement(puzzle) seal_ordered_3 3슬롯", t3 == "placement" \
		and String(g["GW3"].get("kind", "")) == "puzzle" \
		and String(g["GW3"].get("puzzle", "")) == "seal_ordered_3" \
		and _cells(g["GW3"].get("slot_cells", [])).size() == 3)
	_check("GW4=chain(offering)", t4 == "chain")
	# 인접 게이트 타입 비반복(level-design B): GW1≠GW2, GW2≠GW3, GW3≠GW4.
	_check("인접 게이트 타입 비반복 (배치→사용→배치퍼즐→체인)",
		t1 != t2 and t2 != t3 and t3 != t4)


# ---- 2: 부팅 직후 닫힘 게이트 seal (non-walkable) --------------------------

func _test_gate_seal(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	var gw1 := _cells(g.get("GW1", {}).get("cells", []))
	var gw2 := _cells(g.get("GW2", {}).get("cells", []))
	var gw3_door := _cells(g.get("GW3", {}).get("cells", []))
	# 부팅 직후(아무 배치/사용 없음) 게이트 병목은 전부 non-walkable = 벽.
	var gw1_sealed := true
	for c in gw1:
		if loader.is_cell_walkable(c): gw1_sealed = false
	_check("GW1 부유 서가 잔교 g 부팅 시 non-walkable (허공 seal)", gw1_sealed and not gw1.is_empty())
	var gw2_sealed := true
	for c in gw2:
		if loader.is_cell_walkable(c): gw2_sealed = false
	_check("GW2 흐려진 열람 결계문 v 부팅 시 non-walkable (컨트롤러 seal)", gw2_sealed and not gw2.is_empty())
	var gw3_sealed := true
	for c in gw3_door:
		if loader.is_cell_walkable(c): gw3_sealed = false
	_check("GW3 금서고 통로문 L 부팅 시 non-walkable (컨트롤러 seal)", gw3_sealed and not gw3_door.is_empty())


# ---- 3: GW4 봉헌 목 = 최심부 코어 봉헌 지점 (지형 벽 아님) -----------------

func _test_offering_point(loader: MapLoader) -> void:
	var g := loader.legend_gates()
	var gw4 := _cells(g.get("GW4", {}).get("cells", []))
	_check("GW4 봉헌 목 H 셀 존재", gw4.size() == 1, "n=%d" % gw4.size())
	# H는 최심부 코어 방(row1~4) 안. GW3 통로문을 넘고 경사로로 +2 오르면 도달하는 봉헌 지점(§A-6.2).
	if not gw4.is_empty():
		_check("GW4 봉헌 목 H는 최심부 코어(row<=4)에 위치", gw4[0].y <= 4, "H=%s" % str(gw4[0]))
	# archive_core_altar 오브젝트가 봉헌 대상으로 스폰됨.
	var altar_seen := false
	for key in loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == "archive_core_altar":
			altar_seen = true
	_check("GW4 금서고 코어 봉헌 목(archive_core_altar) 오브젝트 스폰", altar_seen)


# ---- 4: 컨트롤러 활성 + 정화 전 상태 --------------------------------------

func _test_controller_active(gates: Node) -> void:
	_check("게이트 컨트롤러 활성 (idle 아님)", bool(gates.get("_active")))
	_check("정화 전 archive_purified_flag = false", not GameState.archive_purified_flag)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out
