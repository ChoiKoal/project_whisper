extends Node
## (EXL1-5) L1 확장 FLOW acceptance harness. Where l1x_map_harness proves the two SUB-zone maps/objects
## and l1x_bfs.py proves gate ORDER, this proves the PORTAL/QUEST/PURIFICATION/SAVE flow that wraps them:
##   1. 존 라우팅: WorldContext.SCENE_GARDEN/HEART 씬 경로 + grove zone 포탈은 clear 후에만 스폰.
##   2. 화원(고요의 화원) 실 씬 부팅 → GA1→GA2→GA3(3색 퍼즐)→GA4 봉헌 순서 구동 → garden_purified.
##   3. 잔재 NPC 라인(N-gardener/N-constructor) = L1~L5 레이어 라인과 독립 공존 (진상 조각 비게이팅).
##   4. 심장(생명의 심장) 실 씬 부팅 → GH1→GH2 봉헌 → 컷신 C-4 (control_lock/time_running 페어링) →
##      heart_purified. 생명의 샘물 E = idempotent add_vita(1) (중복 파밍 불가).
##   5. 세이브: 두 정화 플래그 지속 + 재진입 시 게이트 end-state 재적용(컷신 미재생). 구세이브 호환.
##   6. NG+ 리셋: 두 플래그 dormant (reset_layer1_zones). 포탈 라인 불변(sub-zone은 라인 비관여).
##
## Boots the REAL quiet_garden.tscn / life_heart.tscn and drives the real controllers/signals.
## API 직접 정화 호출 금지 — 실제 게이트 시그널(placed_object_placed/item_used_on_object)로 구동.
## Prints PASS/FAIL; quits with the failure count as exit code.

const GARDEN := "res://scenes/world/quiet_garden.tscn"
const HEART := "res://scenes/world/life_heart.tscn"

var _fail := 0
var _garden_sig := false
var _heart_sig := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L1x FLOW HARNESS (화원·심장 포탈/퀘스트/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer1_zones()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false
	SaveManager.unregister_world()
	GameState.garden_purified.connect(func(_z): _garden_sig = true)
	GameState.heart_purified.connect(func(_z): _heart_sig = true)

	await _test_routing()
	await _test_garden()
	await _test_npc_lines_coexist()
	await _test_heart()
	await _test_save_and_ngplus()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. 존 라우팅 ---------------------------------------------------------

func _test_routing() -> void:
	_check("SCENE_GARDEN 씬 경로 = quiet_garden",
		WorldContext.scene_path(WorldContext.SCENE_GARDEN).findn("quiet_garden") >= 0)
	_check("SCENE_HEART 씬 경로 = life_heart",
		WorldContext.scene_path(WorldContext.SCENE_HEART).findn("life_heart") >= 0)
	# grove zone 포탈은 세계수 정화(cleared) 후에만 스폰 — 미클리어 시 생성 안 됨.
	SaveManager.cleared = false
	var grove_scene: PackedScene = load("res://scenes/world/starting_grove.tscn")
	var grove: Node = grove_scene.instantiate()
	add_child(grove)
	for i in range(6):
		await get_tree().process_frame
	var sess: Node = grove.get_node_or_null("GroveSession")
	_check("grove GroveSession present", sess != null)
	if sess != null:
		_check("미클리어 grove: zone 포탈 미스폰 (화원/심장 잠김)",
			not bool(sess.get("_zone_portals_spawned")))
	grove.queue_free()
	for i in range(3):
		await get_tree().process_frame
	# cleared 상태로 재부팅 → zone 포탈 스폰.
	SaveManager.cleared = true
	var grove2: Node = grove_scene.instantiate()
	add_child(grove2)
	for i in range(6):
		await get_tree().process_frame
	var sess2: Node = grove2.get_node_or_null("GroveSession")
	if sess2 != null:
		_check("클리어 grove: zone 포탈 스폰 (화원·심장 개방)",
			bool(sess2.get("_zone_portals_spawned")))
	grove2.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 2. 화원 게이트 순서 구동 → 정화 -------------------------------------

func _test_garden() -> void:
	WorldContext.current_scene = WorldContext.SCENE_GARDEN
	GameState.reset_layer1_zones()
	var garden_scene: PackedScene = load(GARDEN)
	var map: Node = garden_scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	var gates: Node = map.get_node_or_null("L1xGateController")
	_check("화원 loader + L1xGateController present", loader != null and gates != null)
	if loader == null or gates == null:
		map.queue_free()
		return
	var g := loader.legend_gates()
	var ga1 := _cells(g.get("GA1", {}).get("cells", []))
	var ga2 := _cells(g.get("GA2", {}).get("cells", []))
	var ga3: Dictionary = g.get("GA3", {})
	var ga3_slots := _cells(ga3.get("slot_cells", []))
	var ga3_door := _cells(ga3.get("cells", []))

	# GA1 꽃돌다리(D223) → 색의 여울 K 배치 (각 K 셀). 배치 전엔 non-walkable(물).
	var pre_walk := loader.is_cell_walkable(ga1[0]) if not ga1.is_empty() else true
	_check("GA1 배치 전 색의 여울 K non-walkable", not pre_walk)
	for c in ga1:
		GameState.placed_object_placed.emit("D223", c)
	await get_tree().process_frame
	var ga1_walk := true
	for c in ga1:
		if not loader.is_cell_walkable(c):
			ga1_walk = false
	_check("GA1 꽃돌다리 배치 → K walkable (다리 생성)", ga1_walk)

	# GA2 시든 아치: 개화의 물감(D225) 사용 → A 셀 개방.
	var arch := _find_use_target(loader, "wilted_arch")
	_check("GA2 시든 아치 use-target present", arch != null)
	if arch != null:
		GameState.item_used_on_object.emit("D225", arch)
	await get_tree().process_frame
	var ga2_walk := true
	for c in ga2:
		if not loader.is_cell_walkable(c):
			ga2_walk = false
	_check("GA2 개화의 물감 사용 → 아치 A walkable (개화)", ga2_walk)

	# GA3 3색 배치 미니 퍼즐: 빨(D226)·노(D227)·파(D228)를 슬롯에 각각 배치 → 색의 문 M 개방.
	# 부분(2색)만으론 미개방 → 순서강제·완결성 확인.
	if ga3_slots.size() >= 2:
		GameState.placed_object_placed.emit("D226", ga3_slots[0])
		GameState.placed_object_placed.emit("D227", ga3_slots[1])
		await get_tree().process_frame
		var door_walk_partial := ga3_door.is_empty() or loader.is_cell_walkable(ga3_door[0])
		_check("GA3 2색만 배치 → 색의 문 M 여전히 잠김", not door_walk_partial)
	if ga3_slots.size() >= 3:
		GameState.placed_object_placed.emit("D228", ga3_slots[2])
		await get_tree().process_frame
	var ga3_walk := true
	for c in ga3_door:
		if not loader.is_cell_walkable(c):
			ga3_walk = false
	_check("GA3 3색 완성 → 색의 문 M walkable (퍼즐 해결)", ga3_walk)

	# GA4 색의 봉헌: 색의 정수(D230)를 무지개 분수에 봉헌 → garden_purified.
	_check("GA4 봉헌 전 garden_purified_flag=false", not GameState.garden_purified_flag)
	var font := _find_use_target(loader, "rainbow_font")
	_check("GA4 무지개 분수 use-target present", font != null)
	if font != null:
		GameState.item_used_on_object.emit("D230", font)
	for i in range(30):
		await get_tree().create_timer(0.1).timeout
		if GameState.garden_purified_flag:
			break
	_check("GA4 색의 봉헌 → garden_purified_flag set", GameState.garden_purified_flag)
	_check("GA4 → garden_purified 시그널 발화", _garden_sig)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 3. 잔재 NPC 라인 독립 공존 (진상 조각 비게이팅) --------------------

func _test_npc_lines_coexist() -> void:
	QuestManager.reset()
	# L1 레이어 라인은 이미 active_id 로 살아있음. NPC 라인 활성 시 서로 다른 포인터.
	var l1_line := QuestManager.active_id
	QuestManager.activate_npc_line("gardener")
	QuestManager.activate_npc_line("constructor")
	_check("N-gardener 라인 활성 (첫 접촉)", QuestManager.npc_active_id("gardener") == "N-gardener-Q1")
	_check("N-constructor 라인 활성 (첫 접촉)", QuestManager.npc_active_id("constructor") == "N-constructor-Q1")
	_check("NPC 라인 ≠ L1 레이어 라인 (독립 공존)",
		QuestManager.npc_active_id("gardener") != l1_line
		and QuestManager.active_id == l1_line)

	# 진상 조각 비게이팅: 회고 의뢰(Q3)는 truth_shard_investigated 조사만으로 항상 회수 —
	# 하드 게이트 없음. gardener Q1(제작)→Q2(배치)→Q3(회고) 순서 구동.
	GameState.item_crafted.emit("D227", "EX-L1-R06")     # gardener Q1: 노란 물감 제작
	_check("gardener Q1(제작) → Q2(배치) 진행", QuestManager.npc_active_id("gardener") == "N-gardener-Q2")
	GameState.placed_object_placed.emit("D226", Vector2i(5, 5))  # Q2: 배치
	_check("gardener Q2(배치) → Q3(회고) 진행", QuestManager.npc_active_id("gardener") == "N-gardener-Q3")
	GameState.truth_shard_investigated.emit("gardener_petrified")  # Q3: 진상 조사 (비게이팅)
	_check("gardener Q3(회고) 조사만으로 완료 → 라인 종료",
		QuestManager.npc_line_finished("gardener"))


# ---- 4. 심장 게이트 → 컷신 → 정화 + 생명의 샘물 idempotent --------------

func _test_heart() -> void:
	WorldContext.current_scene = WorldContext.SCENE_HEART
	# Only clear the heart flag — the garden was purified above and must stay purified so the
	# save test can assert BOTH flags persist (reset_layer1_zones() would wipe garden too).
	GameState.heart_purified_flag = false
	WhisperCurrency.reset()
	var heart_scene: PackedScene = load(HEART)
	var map: Node = heart_scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	var gates: Node = map.get_node_or_null("L1xGateController")
	_check("심장 loader + L1xGateController present", loader != null and gates != null)
	if loader == null or gates == null:
		map.queue_free()
		return
	var g := loader.legend_gates()
	var gh1 := _cells(g.get("GH1", {}).get("cells", []))
	var gh2 := _cells(g.get("GH2", {}).get("cells", []))

	# GH1 뒤엉킨 뿌리문: 소생의 수액(D232) 사용 → L 셀 개방.
	var pre := loader.is_cell_walkable(gh1[0]) if not gh1.is_empty() else true
	_check("GH1 사용 전 뿌리문 L non-walkable", not pre)
	var root_gate := _find_use_target(loader, "root_gate")
	_check("GH1 뿌리문 use-target present (컨트롤러 wrap)", root_gate != null)
	if root_gate != null:
		GameState.item_used_on_object.emit("D232", root_gate)
	await get_tree().process_frame
	var gh1_walk := true
	for c in gh1:
		if not loader.is_cell_walkable(c):
			gh1_walk = false
	_check("GH1 소생의 수액 사용 → 뿌리문 L walkable", gh1_walk)

	# 생명의 샘물 E: idempotent add_vita — proximity area. 두 번 트리거해도 +1만.
	var vita0 := WhisperCurrency.vita
	if gates.has_method("_grant_life_spring"):
		gates.call("_grant_life_spring", null)
		gates.call("_grant_life_spring", null)   # 중복 시도
	_check("생명의 샘물 → vita +1 (첫 획득)", WhisperCurrency.vita == vita0 + 1, "vita=%d" % WhisperCurrency.vita)
	_check("생명의 샘물 재방문 중복 없음 (idempotent)", WhisperCurrency.vita == vita0 + 1)

	# GH2 심장 봉인: 되살아난 심장(D235) 봉헌 → 컷신 C-4 → heart_purified.
	# 컷신은 control_lock/time_running 페어링 — 종료 후 복원 확인.
	_check("GH2 봉헌 전 heart_purified_flag=false", not GameState.heart_purified_flag)
	var seal := _find_use_target(loader, "heart_seal")
	_check("GH2 심장 봉인 use-target present", seal != null)
	if seal != null:
		GameState.item_used_on_object.emit("D235", seal)
	# 컷신 중엔 time_running=false. 종료까지 대기.
	var saw_lock := false
	for i in range(120):
		await get_tree().create_timer(0.1).timeout
		if not GameState.time_running:
			saw_lock = true
		if GameState.heart_purified_flag:
			break
	_check("GH2 컷신 C-4 중 time_running=false (락 페어링)", saw_lock)
	_check("GH2 심장 봉인 봉헌 → heart_purified_flag set", GameState.heart_purified_flag)
	_check("GH2 → heart_purified 시그널 발화", _heart_sig)
	_check("컷신 종료 후 time_running=true 복원", GameState.time_running)
	var gh2_walk := true
	for c in gh2:
		if not loader.is_cell_walkable(c):
			gh2_walk = false
	_check("GH2 정화 후 봉인목 H walkable (최심부 개방)", gh2_walk)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame


# ---- 5. 세이브 지속 + 재진입 재적용 + NG+ 리셋 --------------------------

func _test_save_and_ngplus() -> void:
	# 두 플래그가 세이브 dict에 지속.
	var d := SaveManager.build_save_dict()
	_check("세이브: garden_purified 플래그 지속", bool(d.get("garden_purified", false)))
	_check("세이브: heart_purified 플래그 지속", bool(d.get("heart_purified", false)))

	# 재진입: garden_purified=true 상태로 화원 재부팅 → 게이트 end-state 즉시 재적용(컷신 미재생).
	_garden_sig = false
	WorldContext.current_scene = WorldContext.SCENE_GARDEN
	GameState.garden_purified_flag = true
	var reentry_scene: PackedScene = load(GARDEN)
	var map: Node = reentry_scene.instantiate()
	add_child(map)
	for i in range(8):
		await get_tree().process_frame
	var loader := map.get_node("Ground") as MapLoader
	if loader != null:
		var g := loader.legend_gates()
		var ga1 := _cells(g.get("GA1", {}).get("cells", []))
		var ga3_door := _cells(g.get("GA3", {}).get("cells", []))
		var reopened := true
		for c in ga1 + ga3_door:
			if not loader.is_cell_walkable(c):
				reopened = false
		_check("재진입(정화됨): 모든 화원 게이트 즉시 walkable (구세이브 호환)", reopened)
	_check("재진입: 정화 컷신 미재생 (garden 시그널 재발화 안 함)", not _garden_sig)
	map.queue_free()
	for i in range(3):
		await get_tree().process_frame

	# NG+ 리셋: 두 플래그 dormant. 포탈 라인은 sub-zone과 무관하므로 불변.
	GameState.set_portal_state("nature", GameState.PORTAL_OPEN)
	var nature_before := GameState.portal_state("nature")
	GameState.reset_layer1_zones()
	_check("NG+ 리셋: garden/heart 플래그 dormant",
		not GameState.garden_purified_flag and not GameState.heart_purified_flag)
	_check("NG+ 리셋: 포탈 라인 불변 (sub-zone 비관여)",
		GameState.portal_state("nature") == nature_before)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


## Find the use-target node the controller identifies as `object_id`. Mirrors
## L1xGateController._on_item_used matching: object_id lives either as a String
## property or a "object_id" meta. The loader stores spawned objects as "l2_id@cell",
## so wilted_arch / rainbow_font / heart_seal are found by that key prefix. The
## controller-spawned root_gate lives directly on the YSortLayer (not in the map).
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
	# Loader-spawned objects: keyed as "l2_id@cell". The l2_id IS the semantic id.
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
		# The controller matches these by their l2_id key even when the spawned
		# sprite carries no object_id property — return the keyed node itself.
		return node
	# root_gate is spawned by the controller directly on the YSortLayer.
	var ys := loader.get_node_or_null(loader.ysort_layer_path)
	if ys != null:
		for ch in ys.get_children():
			if _obj_id_of(ch) == object_id:
				return ch
	return null
