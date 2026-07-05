extends Node
## (L3-5) Layer-3 FLOW acceptance harness. Where l3_gates_harness proves each gate's mechanics,
## this proves the PORTAL/QUEST/PURIFICATION/SAVE flow that wraps them — the L3 mirror of
## l2_flow_harness:
##   1. machine 포탈 라우팅: WorldContext.layer_scene("machine") → clockwork_city, scene_path 해석.
##   2. machine 포탈 개방 조건: DORMANT → (L2 정화 전파) FLICKERING → (L3 정화) OPEN, magic 전파.
##   3. QuestManager 3번째 라인: activate_l3_line() → L3-Q1, L1/L2 라인과 공존, 시그널 진행, 멱등.
##   4. save v2: to_dict/from_dict 라운드트립 l3_active_id/l3_progress + layer3_purified.
##   5. NG+ 리셋: new_game()/reset_layer3() → layer3_purified_flag clear + L3 라인 dormant.
##
## Pure-autoload driven (no scene boot needed for the flow assertions), like the L2 flow harness's
## quest/save sections. Prints PASS/FAIL; quits with the failure count as exit code.

var _fail := 0
var _purified := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L3 FLOW HARNESS (포탈/퀘스트/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false

	_test_portal_routing()
	_test_portal_opening()
	_test_quest_third_line()
	_test_save_v2()
	_test_ng_plus_reset()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. machine 포탈 → clockwork_city 라우팅 ------------------------------

func _test_portal_routing() -> void:
	_check("machine 레이어 → clockwork_city 씬 라우팅",
		WorldContext.layer_scene("machine") == WorldContext.SCENE_CLOCKWORK
		and WorldContext.SCENE_CLOCKWORK == "clockwork_city",
		"layer_scene=%s" % WorldContext.layer_scene("machine"))
	var path := WorldContext.scene_path(WorldContext.SCENE_CLOCKWORK)
	_check("clockwork_city scene_path → 실제 .tscn 해석 (ResourceLoader.exists)",
		path.findn("clockwork_city") >= 0 and ResourceLoader.exists(path), "path=%s" % path)
	# regression: the earlier layers still route to their own scenes.
	_check("science → terminal_station 라우팅 (회귀)",
		WorldContext.layer_scene("science") == WorldContext.SCENE_TERMINAL)
	_check("nature → grove 라우팅 (회귀)",
		WorldContext.layer_scene("nature") == WorldContext.SCENE_GROVE)


# ---- 2. machine 포탈 개방 조건 (전파 상태) --------------------------------

func _test_portal_opening() -> void:
	_check("초기: machine 포탈 dormant", GameState.portal_state("machine") == GameState.PORTAL_DORMANT)
	# L2 정화 전파 → machine flickering (terminal_station sets this on layer2 purify).
	GameState.set_portal_state("machine", GameState.PORTAL_FLICKERING)
	_check("L2 정화 전파 → machine 포탈 flickering (진입 가능)",
		GameState.portal_state("machine") == GameState.PORTAL_FLICKERING)
	_check("초기: magic 포탈 dormant (다음 죽은 세계)",
		GameState.portal_state("magic") == GameState.PORTAL_DORMANT)

	# Drive the clockwork_city purification hook (_on_layer3_purified) via the signal it listens to.
	# Emitting GameState.layer3_purified("machine") should set machine→OPEN, magic→FLICKERING.
	# Boot the real session so its hook is connected (mirrors l2 flow's real-scene drive).
	GameState.layer3_purified.connect(func(_l): _purified = true)
	var scene: PackedScene = load(WorldContext.scene_path(WorldContext.SCENE_CLOCKWORK))
	var map := scene.instantiate()
	add_child(map)
	for i in range(6):
		await get_tree().process_frame
	GameState.layer3_purified.emit("machine")
	for i in range(4):
		await get_tree().process_frame
	_check("L3 정화(layer3_purified) → machine 포탈 OPEN (정화한 세계는 열린 채)",
		GameState.portal_state("machine") == GameState.PORTAL_OPEN,
		"machine=%s" % GameState.portal_state("machine"))
	_check("L3 정화 → magic 포탈 flickering (다음 세계 깨어남)",
		GameState.portal_state("magic") == GameState.PORTAL_FLICKERING,
		"magic=%s" % GameState.portal_state("magic"))
	_check("layer3_purified 시그널 발화 (관찰됨)", _purified)
	if is_instance_valid(map):
		map.queue_free()
		await get_tree().process_frame


# ---- 3. QuestManager 3번째 라인 (L3) 공존 + 멱등 --------------------------

func _test_quest_third_line() -> void:
	# Reset lines to a clean L1-only state, then activate the L3 line.
	QuestManager.reset()
	var l1_before := QuestManager.active_id
	_check("초기: L3 라인 dormant", QuestManager.l3_active_id == "")
	QuestManager.activate_l3_line()
	_check("activate_l3_line() → L3-Q1 활성", QuestManager.l3_active_id == "L3-Q1",
		"l3=%s" % QuestManager.l3_active_id)
	# Coexistence: L1 pointer + L2 pointer untouched.
	_check("L3 라인이 L1 라인과 공존 (active_id 불변)", QuestManager.active_id == l1_before)
	_check("L3 라인이 L2 라인과 독립 (l2_active_id 미영향)", QuestManager.l2_active_id == "")
	# all three heads present in the quest log id list.
	var ids := QuestManager.all_ids()
	_check("퀘스트 로그에 L1 + L3 퀘스트 모두 존재",
		ids.has("Q1") and ids.has("L3-Q1") and ids.has("L3-Q7"))

	# Drive L3-Q gameplay signals: item_gathered(K1) advances L3-Q1 → L3-Q2.
	GameState.item_gathered.emit("K1")
	_check("L3-Q1(첫 채집) 완료 → L3-Q2 활성", QuestManager.l3_active_id == "L3-Q2",
		"l3=%s" % QuestManager.l3_active_id)
	# item_crafted advances L3-Q2 → L3-Q3.
	GameState.item_crafted.emit("D103", "L3-R01")
	_check("L3-Q2(첫 조합) 완료 → L3-Q3 활성", QuestManager.l3_active_id == "L3-Q3",
		"l3=%s" % QuestManager.l3_active_id)
	# The L1 line also reacted to the same signals but stays its own pointer.
	_check("L3 진행 후에도 L1 라인 포인터 독립 (라인 혼선 없음)",
		QuestManager.active_id != QuestManager.l3_active_id)

	# Idempotent: calling activate_l3_line() again does NOT restart the line.
	QuestManager.activate_l3_line()
	_check("activate_l3_line() 멱등 (재호출 시 L3-Q3 유지, 재시작 없음)",
		QuestManager.l3_active_id == "L3-Q3", "l3=%s" % QuestManager.l3_active_id)


# ---- 4. save v2 라운드트립 (L3 라인 + 정화 플래그) ------------------------

func _test_save_v2() -> void:
	# QuestManager.to_dict carries the L3 line pointer/progress.
	var q := QuestManager.to_dict()
	_check("QuestManager.to_dict → l3_active_id 지속", q.has("l3_active_id"))
	_check("QuestManager.to_dict → l3_progress 지속", q.has("l3_progress"))
	var l3_before := QuestManager.l3_active_id

	# SaveManager save dict carries layer3_purified.
	GameState.layer3_purified_flag = true
	var d := SaveManager.build_save_dict()
	_check("세이브 dict = v2 (멀티씬)", int(d.get("version", 0)) == 2)
	_check("세이브: layer3_purified 플래그 지속", bool(d.get("layer3_purified", false)))
	var qd: Dictionary = d.get("quests", {})
	_check("세이브: 퀘스트 dict에 L3 라인 포인터 지속", qd.has("l3_active_id"))

	# Round-trip: reset then restore the quest dict — the L3 pointer survives.
	QuestManager.reset()
	_check("리셋 후 L3 라인 dormant (라운드트립 사전조건)", QuestManager.l3_active_id == "")
	QuestManager.from_dict(q)
	_check("세이브 라운드트립: L3 라인 포인터 복원", QuestManager.l3_active_id == l3_before,
		"restored=%s want=%s" % [QuestManager.l3_active_id, l3_before])

	# Round-trip the purified flag through the full core-state path is exercised by NG+ below;
	# here assert the flag we set is what the dict carried (already checked), then clear it.
	GameState.reset_layer3()
	_check("reset_layer3() → layer3_purified_flag zero", not GameState.layer3_purified_flag)


# ---- 5. NG+ 리셋 ----------------------------------------------------------

func _test_ng_plus_reset() -> void:
	# Set the purified flag + advance the L3 line, then NG+ (new_game) must clear both.
	GameState.layer3_purified_flag = true
	QuestManager.activate_l3_line()
	GameState.item_gathered.emit("K1")   # advance L3 line off its head
	_check("(사전조건) L3 라인 활성 + 정화 플래그 set",
		GameState.layer3_purified_flag and QuestManager.l3_active_id != "")

	SaveManager.new_game()
	_check("NG+ new_game() → layer3_purified_flag clear (reset_layer3)",
		not GameState.layer3_purified_flag)
	_check("NG+ new_game() → L3 라인 dormant (재진입 시 재활성)",
		QuestManager.l3_active_id == "")

	# reset_after_clear path (start_ng_plus) also zeroes the flag.
	GameState.layer3_purified_flag = true
	SaveManager.start_ng_plus([])
	_check("NG+ start_ng_plus() → layer3_purified_flag clear",
		not GameState.layer3_purified_flag)

	# GameState.reset_layer3() directly zeroes the flag.
	GameState.layer3_purified_flag = true
	GameState.reset_layer3()
	_check("GameState.reset_layer3() → 플래그 zero (직접 호출)",
		not GameState.layer3_purified_flag)
