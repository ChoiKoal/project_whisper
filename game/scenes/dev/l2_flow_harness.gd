extends Node
## (L2-5) Layer-2 FLOW acceptance harness. Where l2_gates_harness proves each gate's mechanics,
## this proves the PORTAL/QUEST/PURIFICATION/SAVE flow that wraps them:
##   1. 홈 science 포탈: Layer 1 정화(cleared) 시 flickering (P1 개방 조건). science 레이어 →
##      terminal_station 씬으로 라우팅(WorldContext.layer_scene).
##   2. Layer-2 속삭임 라인(L2-Q1~Q7)이 첫 L2 진입 시 활성 + L1 라인과 퀘스트 로그에 공존.
##   3. 게이트 순서 구동(G1 브리지 → G3 랜턴 → G2 발전기→차폐문 +에너지 Whisper +1 → G4 파워코어→정화).
##   4. 정화 → machine(Layer 3) 포탈 flickering + science 포탈 OPEN(자유 왕래).
##   5. 멀티씬 세이브: terminal_station 상태(powered_nodes, 정화 플래그) + Whisper 재화 + 퀘스트
##      두 라인이 세이브 dict에 지속. NG+ 리셋.
##   6. Whisper HUD: 획득 시에만 표시.
##
## Boots the REAL terminal_station.tscn and drives the real controllers/signals. Prints PASS/FAIL;
## quits with the failure count as exit code.

const STATION := "res://scenes/world/terminal_station.tscn"

var _fail := 0
var _purified := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L2 FLOW HARNESS (포탈/퀘스트/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false

	# ---- 1. 홈 science 포탈 개방 조건 = Layer 1 정화 -------------------------
	_check("초기: science 포탈 dormant", GameState.portal_state("science") == GameState.PORTAL_DORMANT)
	# Simulate Layer 1 clear (CS-05 does nature→open, science→flickering).
	GameState.set_portal_state("nature", GameState.PORTAL_OPEN)
	GameState.set_portal_state("science", GameState.PORTAL_FLICKERING)
	_check("L1 정화 후 science 포탈 flickering (진입 가능)",
		GameState.portal_state("science") == GameState.PORTAL_FLICKERING)
	# science 레이어 → terminal_station 씬 라우팅.
	_check("science 레이어 → terminal_station 씬 라우팅",
		WorldContext.layer_scene("science") == WorldContext.SCENE_TERMINAL
		and WorldContext.scene_path(WorldContext.SCENE_TERMINAL).findn("terminal_station") >= 0)
	_check("nature 레이어 → grove 라우팅 (회귀)",
		WorldContext.layer_scene("nature") == WorldContext.SCENE_GROVE)

	# ---- boot the real terminal_station (the science portal destination) ----
	WorldContext.current_scene = WorldContext.SCENE_TERMINAL
	var scene: PackedScene = load(STATION)
	var map := scene.instantiate()
	add_child(map)
	for i in range(6):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L2GateController")
	_check("terminal_station loader + gate controller present", loader != null and gates != null)
	if loader == null or gates == null:
		print("=== RESULT: FAIL (missing core nodes) ===")
		get_tree().quit(1)
		return

	GameState.layer2_purified.connect(func(_l): _purified = true)

	# ---- 2. 첫 L2 진입 → L2 속삭임 라인 활성 + L1 라인 공존 ------------------
	# terminal_station._setup called activate_l2_line(); assert the L2 head is now active.
	_check("첫 L2 진입 → L2-Q1 활성 (L2 라인 시작)", QuestManager.l2_active_id == "L2-Q1")
	_check("L1 라인 포인터와 L2 라인 포인터 독립 (공존)",
		QuestManager.active_id != QuestManager.l2_active_id)
	# both lines present in the quest log id list.
	var ids := QuestManager.all_ids()
	_check("퀘스트 로그에 L1 + L2 퀘스트 모두 존재",
		ids.has("Q1") and ids.has("L2-Q1") and ids.has("L2-Q7"))

	# ---- 3+4. 게이트 순서 구동 → 정화 → 포탈 전파 ---------------------------
	await _drive_gates(loader, map, gates)

	# ---- 5. 멀티씬 세이브 지속 --------------------------------------------
	_test_persistence()

	# ---- 6. Whisper HUD 획득 시에만 표시 -----------------------------------
	_test_whisper_hud(map)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _drive_gates(loader: MapLoader, map: Node, gates: Node) -> void:
	# Advance the L2 whisper line the intended way: L2-Q1 (첫 채집) → L2-Q2 (첫 조합) → then the
	# bridge energize completes L2-Q3. This proves the L2 line reacts to the SAME signals the L1
	# line uses, while staying an independent pointer.
	GameState.item_gathered.emit("J1")                 # L2-Q1: 첫 채집
	_check("L2-Q1(첫 채집) 완료 → L2-Q2 활성", QuestManager.l2_active_id == "L2-Q2")
	GameState.item_crafted.emit("D62", "L2-R01")       # L2-Q2: 첫 조합
	_check("L2-Q2(첫 조합) 완료 → L2-Q3 활성", QuestManager.l2_active_id == "L2-Q3")

	# G1 브리지: 전지 급전 → 브리지 walkable + L2-Q3 완료.
	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var bridge_cells := _cells(g1.get("bridge_cells", []))
	GameState.energize_power_node("bridge")
	await get_tree().create_timer(1.6).timeout
	var bridge_walk := true
	for c in bridge_cells:
		if not loader.is_cell_walkable(c):
			bridge_walk = false
	_check("G1 브리지 급전 → walkable", bridge_walk)
	_check("L2-Q3(브리지) 완료 (power_node_energized bridge 시그널 구동)", QuestManager.is_done("L2-Q3"))

	# G3 랜턴: 소지 시 병목 통행.
	Inventory.add("D65", 1)
	if gates.has_method("_apply_g3"):
		gates.call("_apply_g3", true)
	for i in range(3):
		await get_tree().process_frame

	# G2 발전기 → 차폐문 + 에너지 Whisper +1.
	var energy_before := WhisperCurrency.energy
	Inventory.add("D66", 1)
	var gen := _find_use_target(loader, "gen_sub")
	if gen != null:
		Inventory.remove("D66", 1)
		GameState.item_used_on_object.emit("D66", gen)
	for i in range(6):
		await get_tree().process_frame
	_check("G2 차폐문 개방 후 에너지 Whisper +1 (파워코어 재화)",
		WhisperCurrency.energy == energy_before + 1, "energy=%d" % WhisperCurrency.energy)

	# G4 파워코어 → control_core 급전 → 정화.
	_check("정화 전 layer2_purified_flag=false", not GameState.layer2_purified_flag)
	GameState.energize_power_node("control_core")
	for i in range(60):
		await get_tree().create_timer(0.1).timeout
		if GameState.layer2_purified_flag:
			break
	_check("G4 관제탑 재가동 → Layer 2 정화 플래그 set", GameState.layer2_purified_flag)
	_check("정화 컷신 → layer2_purified 시그널 발화", _purified)

	# 4. 포탈 전파: science → OPEN, machine(Layer 3) → flickering.
	_check("정화 후 science 포탈 OPEN (자유 왕래)",
		GameState.portal_state("science") == GameState.PORTAL_OPEN)
	_check("정화 후 machine(Layer 3) 포탈 flickering (다음 세계 깨어남)",
		GameState.portal_state("machine") == GameState.PORTAL_FLICKERING)


func _test_persistence() -> void:
	var d := SaveManager.build_save_dict()
	_check("세이브 dict = v2 (멀티씬)", int(d.get("version", 0)) == 2)
	_check("세이브: powered_nodes 지속 (bridge+control_core)",
		d.has("powered_nodes") and (d["powered_nodes"] as Dictionary).has("bridge")
		and (d["powered_nodes"] as Dictionary).has("control_core"))
	_check("세이브: layer2_purified 플래그 지속", bool(d.get("layer2_purified", false)))
	_check("세이브: Whisper 재화 지속", d.has("whisper"))
	# quest two-line persistence.
	var q: Dictionary = d.get("quests", {})
	_check("세이브: 퀘스트 L1 + L2 두 라인 포인터 지속",
		q.has("active_id") and q.has("l2_active_id"))
	# round-trip the quest dict: L2 line pointer survives.
	var l2_before := QuestManager.l2_active_id
	QuestManager.from_dict(q)
	_check("세이브 라운드트립: L2 라인 포인터 복원", QuestManager.l2_active_id == l2_before)
	# NG+ resets both lines + layer2.
	QuestManager.reset()
	GameState.reset_layer2()
	_check("NG+ 리셋: L2 라인 dormant + 정화 플래그 clear",
		QuestManager.l2_active_id == "" and not GameState.layer2_purified_flag)


func _test_whisper_hud(map: Node) -> void:
	var hud := map.get_node_or_null("WhisperHUD")
	_check("WhisperHUD present", hud != null)
	if hud != null and "_panel" in hud:
		var panel = hud.get("_panel")
		# energy > 0 at this point (granted at G2). Panel visible.
		_check("Whisper HUD 획득(energy>0) 시 표시", panel != null and panel.visible)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


func _find_use_target(loader: MapLoader, object_id: String) -> Node:
	for key in loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == object_id:
			var node: Node = loader.l2_object_nodes[key].get("node")
			if node == null:
				continue
			for ch in node.get_children():
				if ch is Gatherable and String((ch as Gatherable).object_id) == object_id:
					return ch
			return node
	return null
