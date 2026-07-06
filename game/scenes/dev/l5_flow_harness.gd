extends Node
## (L5-5) Layer-5 FLOW acceptance harness. Where l5_gates_harness proves each gate's mechanics,
## this proves the PORTAL/QUEST/PURIFICATION/SAVE/완결 flow that wraps them — the L5 mirror of
## l4_flow_harness, plus the 다섯 포탈 완결 → 빛의 문 예고 (마지막 레이어 §C-4):
##   1. divinity 포탈 라우팅: WorldContext.layer_scene("divinity") → cathedral, scene_path 해석.
##   2. divinity 포탈 개방 조건: DORMANT → (L4 정화 전파) FLICKERING → (L5 정화) OPEN.
##   3. QuestManager 5번째 라인: activate_l5_line() → L5-Q1, L1~L4 라인과 5중 공존, 진행, 멱등.
##   4. 다섯 포탈 완결: 5레이어(L1~L5) 전부 정화 시에만 set_all_portals(OPEN) + 빛의 문 예고 발동,
##      진행 순서 무관 5-AND, 멱등(재발동 없음). 4레이어까지만이면 미발동.
##   5. save v2: to_dict/from_dict 라운드트립 l5_active_id/l5_progress + vita + layer5_purified +
##      light_gate_previewed.
##   6. NG+ 리셋: new_game()/reset_layer5() → layer5_purified_flag + 빛의 문 플래그 clear + L5 라인
##      dormant + 5레이어 union.
##
## Pure-autoload driven for the quest/save/완결 assertions; boots the real cathedral for the
## purification portal-propagation hook (mirror l4 flow). Prints PASS/FAIL; quits with the failure
## count as exit.

var _fail := 0
var _purified := false
var _lit := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L5 FLOW HARNESS (포탈/퀘스트/정화/세이브/다섯 포탈 완결) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	GameState.reset_layer4()
	GameState.reset_layer5()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false
	SaveManager.cleared = false

	_test_portal_routing()
	await _test_portal_opening()
	_test_quest_fifth_line()
	_test_five_portal_completion()
	_test_save_v2()
	_test_ng_plus_reset()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. divinity 포탈 → cathedral 라우팅 ---------------------------------

func _test_portal_routing() -> void:
	_check("divinity 레이어 → cathedral 씬 라우팅",
		WorldContext.layer_scene("divinity") == WorldContext.SCENE_CATHEDRAL
		and WorldContext.SCENE_CATHEDRAL == "cathedral",
		"layer_scene=%s" % WorldContext.layer_scene("divinity"))
	var path := WorldContext.scene_path(WorldContext.SCENE_CATHEDRAL)
	_check("cathedral scene_path → 실제 .tscn 해석 (ResourceLoader.exists)",
		path.findn("cathedral") >= 0 and ResourceLoader.exists(path), "path=%s" % path)
	# regression: the earlier layers still route to their own scenes.
	_check("magic → mage_tower 라우팅 (회귀)",
		WorldContext.layer_scene("magic") == WorldContext.SCENE_MAGE_TOWER)
	_check("machine → clockwork_city 라우팅 (회귀)",
		WorldContext.layer_scene("machine") == WorldContext.SCENE_CLOCKWORK)
	_check("science → terminal_station 라우팅 (회귀)",
		WorldContext.layer_scene("science") == WorldContext.SCENE_TERMINAL)
	_check("nature → grove 라우팅 (회귀)",
		WorldContext.layer_scene("nature") == WorldContext.SCENE_GROVE)


# ---- 2. divinity 포탈 개방 조건 (전파 상태) ------------------------------

func _test_portal_opening() -> void:
	_check("초기: divinity 포탈 dormant", GameState.portal_state("divinity") == GameState.PORTAL_DORMANT)
	# L4 정화 전파 → divinity flickering (mage_tower sets this on layer4 purify).
	GameState.set_portal_state("divinity", GameState.PORTAL_FLICKERING)
	_check("L4 정화 전파 → divinity 포탈 flickering (진입 가능)",
		GameState.portal_state("divinity") == GameState.PORTAL_FLICKERING)

	# Boot the real cathedral so its _on_layer5_purified hook is connected, then emit the purify
	# signal — divinity should go OPEN (마지막 레이어 = 다음 포탈 없음).
	GameState.layer5_purified.connect(func(_l): _purified = true)
	var scene: PackedScene = load(WorldContext.scene_path(WorldContext.SCENE_CATHEDRAL))
	var map := scene.instantiate()
	add_child(map)
	for i in range(6):
		await get_tree().process_frame
	GameState.layer5_purified.emit("divinity")
	for i in range(4):
		await get_tree().process_frame
	_check("L5 정화(layer5_purified) → divinity 포탈 OPEN (정화한 세계는 열린 채)",
		GameState.portal_state("divinity") == GameState.PORTAL_OPEN,
		"divinity=%s" % GameState.portal_state("divinity"))
	_check("layer5_purified 시그널 발화 (관찰됨)", _purified)
	# 이 시점은 L1~L4 미정화 → 다섯 포탈 완결 미발동 (light_gate 예고 아직).
	_check("4레이어 미정화 상태: 빛의 문 예고 미발동 (5-AND 아님)",
		not GameState.light_gate_previewed_flag)
	if is_instance_valid(map):
		map.queue_free()
		await get_tree().process_frame
	# clean up for the later dedicated 완결 test.
	GameState.reset_portals()
	GameState.reset_layer5()
	SaveManager.cleared = false


# ---- 3. QuestManager 5번째 라인 (L5) 5중 공존 + 멱등 ---------------------

func _test_quest_fifth_line() -> void:
	QuestManager.reset()
	var l1_before := QuestManager.active_id
	_check("초기: L5 라인 dormant", QuestManager.l5_active_id == "")
	QuestManager.activate_l2_line()
	QuestManager.activate_l3_line()
	QuestManager.activate_l4_line()
	QuestManager.activate_l5_line()
	_check("activate_l5_line() → L5-Q1 활성", QuestManager.l5_active_id == "L5-Q1",
		"l5=%s" % QuestManager.l5_active_id)
	_check("L5 라인이 L1 라인과 공존 (active_id 불변)", QuestManager.active_id == l1_before)
	_check("5중 라인 공존 (L2/L3/L4/L5 포인터 모두 각자 head)",
		QuestManager.l2_active_id == "L2-Q1" and QuestManager.l3_active_id == "L3-Q1"
		and QuestManager.l4_active_id == "L4-Q1" and QuestManager.l5_active_id == "L5-Q1")
	var ids := QuestManager.all_ids()
	_check("퀘스트 로그에 L1 + L5 퀘스트 모두 존재 (L5-Q1~L5-Q7)",
		ids.has("Q1") and ids.has("L5-Q1") and ids.has("L5-Q7"))

	# Drive L5-Q gameplay signals: item_gathered advances L5-Q1 → L5-Q2.
	GameState.item_gathered.emit("S1")
	_check("L5-Q1(첫 채집) 완료 → L5-Q2 활성", QuestManager.l5_active_id == "L5-Q2",
		"l5=%s" % QuestManager.l5_active_id)
	# item_crafted advances L5-Q2 → L5-Q3.
	GameState.item_crafted.emit("D177", "L5-R01")
	_check("L5-Q2(첫 조합) 완료 → L5-Q3 활성", QuestManager.l5_active_id == "L5-Q3",
		"l5=%s" % QuestManager.l5_active_id)
	# power_node_energized(lantern_path) advances L5-Q3 → L5-Q4 (G1 등불 봉헌).
	GameState.power_node_energized.emit("lantern_path")
	_check("L5-Q3(등불 봉헌) 완료 → L5-Q4 활성", QuestManager.l5_active_id == "L5-Q4",
		"l5=%s" % QuestManager.l5_active_id)
	# Other lines stay independent (no cross-talk).
	_check("L5 진행 후에도 타 라인 포인터 독립 (라인 혼선 없음)",
		QuestManager.l5_active_id != QuestManager.l4_active_id
		and QuestManager.l5_active_id != QuestManager.l3_active_id)

	# Idempotent: calling activate_l5_line() again does NOT restart the line.
	QuestManager.activate_l5_line()
	_check("activate_l5_line() 멱등 (재호출 시 L5-Q4 유지, 재시작 없음)",
		QuestManager.l5_active_id == "L5-Q4", "l5=%s" % QuestManager.l5_active_id)


# ---- 4. 다섯 포탈 완결 → 빛의 문 예고 (§C-4, 5-AND, 멱등) ------------------

func _test_five_portal_completion() -> void:
	# Clean five-layer slate.
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	GameState.reset_layer4()
	GameState.reset_layer5()
	SaveManager.cleared = false
	GameState.five_portals_lit.connect(func(): _lit = true)

	_check("초기: 5레이어 미정화 → five_layers_purified() false",
		not GameState.five_layers_purified())
	# Purify L2~L5 but NOT L1 → still not complete (5-AND requires L1 clear).
	GameState.layer2_purified_flag = true
	GameState.layer3_purified_flag = true
	GameState.layer4_purified_flag = true
	GameState.layer5_purified_flag = true
	_check("L1 미클리어(4레이어만) → five_layers_purified() false (5-AND)",
		not GameState.five_layers_purified())
	_check("4레이어만 → maybe_light_five_portals() 미발동",
		not GameState.maybe_light_five_portals() and not GameState.light_gate_previewed_flag)

	# Now clear L1 (진행 순서 무관 — L1을 마지막에 완료해도 완결).
	SaveManager.cleared = true
	_check("5레이어 전부 완료 → five_layers_purified() true (순서 무관)",
		GameState.five_layers_purified())
	var fired := GameState.maybe_light_five_portals()
	_check("5레이어 완료 → maybe_light_five_portals() 발동 (true 반환)", fired)
	_check("다섯 포탈 전부 OPEN (set_all_portals)",
		GameState.portal_state("nature") == GameState.PORTAL_OPEN
		and GameState.portal_state("science") == GameState.PORTAL_OPEN
		and GameState.portal_state("machine") == GameState.PORTAL_OPEN
		and GameState.portal_state("magic") == GameState.PORTAL_OPEN
		and GameState.portal_state("divinity") == GameState.PORTAL_OPEN)
	_check("빛의 문 예고 플래그 set (light_gate_previewed)",
		GameState.light_gate_previewed_flag)
	_check("five_portals_lit 시그널 발화 (관찰됨)", _lit)

	# Idempotent: a second call is a no-op (no re-fire).
	_lit = false
	var fired2 := GameState.maybe_light_five_portals()
	_check("maybe_light_five_portals() 멱등 (재호출 false, 재발화 없음)",
		not fired2 and not _lit)


# ---- 5. save v2 라운드트립 (L5 라인 + vita + 정화 + 빛의 문) --------------

func _test_save_v2() -> void:
	var q := QuestManager.to_dict()
	_check("QuestManager.to_dict → l5_active_id 지속", q.has("l5_active_id"))
	_check("QuestManager.to_dict → l5_progress 지속", q.has("l5_progress"))
	var l5_before := QuestManager.l5_active_id

	# Grant vita + purified + 빛의 문 예고 so all appear in the save dict.
	WhisperCurrency.reset()
	WhisperCurrency.add_vita(1)
	GameState.layer5_purified_flag = true
	GameState.light_gate_previewed_flag = true
	var d := SaveManager.build_save_dict()
	_check("세이브 dict = v2 (멀티씬)", int(d.get("version", 0)) == 2)
	_check("세이브: layer5_purified 플래그 지속", bool(d.get("layer5_purified", false)))
	_check("세이브: 빛의 문 예고 플래그 지속 (light_gate_previewed)",
		bool(d.get("light_gate_previewed", false)))
	var w: Dictionary = d.get("whisper", {})
	_check("세이브: vita Whisper 지속 (vita=1)", int(w.get("vita", -1)) == 1, "vita=%s" % str(w.get("vita")))
	var qd: Dictionary = d.get("quests", {})
	_check("세이브: 퀘스트 dict에 L5 라인 포인터 지속", qd.has("l5_active_id"))

	# Round-trip: reset then restore — the L5 pointer + vita survive.
	QuestManager.reset()
	WhisperCurrency.reset()
	_check("리셋 후 L5 라인 dormant + vita 0 (라운드트립 사전조건)",
		QuestManager.l5_active_id == "" and WhisperCurrency.vita == 0)
	QuestManager.from_dict(q)
	WhisperCurrency.from_dict(w)
	_check("세이브 라운드트립: L5 라인 포인터 복원", QuestManager.l5_active_id == l5_before,
		"restored=%s want=%s" % [QuestManager.l5_active_id, l5_before])
	_check("세이브 라운드트립: vita Whisper 복원 (1)", WhisperCurrency.vita == 1,
		"vita=%d" % WhisperCurrency.vita)

	GameState.reset_layer5()
	WhisperCurrency.reset()
	_check("reset_layer5() → layer5_purified_flag + 빛의 문 플래그 zero",
		not GameState.layer5_purified_flag and not GameState.light_gate_previewed_flag)


# ---- 6. NG+ 리셋 (5레이어) -----------------------------------------------

func _test_ng_plus_reset() -> void:
	GameState.layer2_purified_flag = true
	GameState.layer3_purified_flag = true
	GameState.layer4_purified_flag = true
	GameState.layer5_purified_flag = true
	GameState.light_gate_previewed_flag = true
	QuestManager.activate_l5_line()
	GameState.item_gathered.emit("S1")   # advance L5 line off its head
	_check("(사전조건) L5 라인 활성 + 5레이어 정화 플래그 + 빛의 문 예고 set",
		GameState.layer5_purified_flag and GameState.light_gate_previewed_flag
		and QuestManager.l5_active_id != "")

	SaveManager.new_game()
	_check("NG+ new_game() → layer5_purified_flag clear (reset_layer5)",
		not GameState.layer5_purified_flag)
	_check("NG+ new_game() → 빛의 문 예고 플래그 clear",
		not GameState.light_gate_previewed_flag)
	_check("NG+ new_game() → 5레이어 union 리셋 (L2~L5 플래그 clear)",
		not GameState.layer2_purified_flag and not GameState.layer3_purified_flag
		and not GameState.layer4_purified_flag and not GameState.layer5_purified_flag)
	_check("NG+ new_game() → L5 라인 dormant (재진입 시 재활성)",
		QuestManager.l5_active_id == "")

	# reset_after_clear path (start_ng_plus) also zeroes the L5 flag.
	GameState.layer5_purified_flag = true
	GameState.light_gate_previewed_flag = true
	SaveManager.start_ng_plus([])
	_check("NG+ start_ng_plus() → layer5_purified_flag clear",
		not GameState.layer5_purified_flag)

	# GameState.reset_layer5() directly zeroes both flags.
	GameState.layer5_purified_flag = true
	GameState.light_gate_previewed_flag = true
	GameState.reset_layer5()
	_check("GameState.reset_layer5() → 플래그 zero (직접 호출)",
		not GameState.layer5_purified_flag and not GameState.light_gate_previewed_flag)
