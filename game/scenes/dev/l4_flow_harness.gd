extends Node
## (L4-5) Layer-4 FLOW acceptance harness. Where l4_gates_harness proves each gate's mechanics,
## this proves the PORTAL/QUEST/PURIFICATION/SAVE flow that wraps them — the L4 mirror of
## l3_flow_harness:
##   1. magic 포탈 라우팅: WorldContext.layer_scene("magic") → mage_tower, scene_path 해석.
##   2. magic 포탈 개방 조건: DORMANT → (L3 정화 전파) FLICKERING → (L4 정화) OPEN, divinity 전파.
##   3. QuestManager 4번째 라인: activate_l4_line() → L4-Q1, L1/L2/L3 라인과 4중 공존, 진행, 멱등.
##   4. save v2: to_dict/from_dict 라운드트립 l4_active_id/l4_progress + mana + layer4_purified.
##   5. NG+ 리셋: new_game()/reset_layer4() → layer4_purified_flag clear + L4 라인 dormant + 4레이어.
##
## Pure-autoload driven for the quest/save assertions; boots the real mage_tower for the purification
## portal-propagation hook (mirror l3 flow). Prints PASS/FAIL; quits with the failure count as exit.

var _fail := 0
var _purified := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L4 FLOW HARNESS (포탈/퀘스트/정화/세이브) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	GameState.reset_layer4()
	WhisperCurrency.reset()
	QuestManager.reset()
	SaveManager.pending_load = false

	_test_portal_routing()
	await _test_portal_opening()
	_test_quest_fourth_line()
	_test_save_v2()
	_test_ng_plus_reset()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1. magic 포탈 → mage_tower 라우팅 -----------------------------------

func _test_portal_routing() -> void:
	_check("magic 레이어 → mage_tower 씬 라우팅",
		WorldContext.layer_scene("magic") == WorldContext.SCENE_MAGE_TOWER
		and WorldContext.SCENE_MAGE_TOWER == "mage_tower",
		"layer_scene=%s" % WorldContext.layer_scene("magic"))
	var path := WorldContext.scene_path(WorldContext.SCENE_MAGE_TOWER)
	_check("mage_tower scene_path → 실제 .tscn 해석 (ResourceLoader.exists)",
		path.findn("mage_tower") >= 0 and ResourceLoader.exists(path), "path=%s" % path)
	# regression: the earlier layers still route to their own scenes.
	_check("machine → clockwork_city 라우팅 (회귀)",
		WorldContext.layer_scene("machine") == WorldContext.SCENE_CLOCKWORK)
	_check("science → terminal_station 라우팅 (회귀)",
		WorldContext.layer_scene("science") == WorldContext.SCENE_TERMINAL)
	_check("nature → grove 라우팅 (회귀)",
		WorldContext.layer_scene("nature") == WorldContext.SCENE_GROVE)


# ---- 2. magic 포탈 개방 조건 (전파 상태) ---------------------------------

func _test_portal_opening() -> void:
	_check("초기: magic 포탈 dormant", GameState.portal_state("magic") == GameState.PORTAL_DORMANT)
	# L3 정화 전파 → magic flickering (clockwork_city sets this on layer3 purify).
	GameState.set_portal_state("magic", GameState.PORTAL_FLICKERING)
	_check("L3 정화 전파 → magic 포탈 flickering (진입 가능)",
		GameState.portal_state("magic") == GameState.PORTAL_FLICKERING)
	_check("초기: divinity 포탈 dormant (다음 죽은 세계 = Layer 5)",
		GameState.portal_state("divinity") == GameState.PORTAL_DORMANT)

	# Drive the mage_tower purification hook (_on_layer4_purified) via the signal it listens to.
	# Emitting GameState.layer4_purified("magic") should set magic→OPEN, divinity→FLICKERING.
	GameState.layer4_purified.connect(func(_l): _purified = true)
	var scene: PackedScene = load(WorldContext.scene_path(WorldContext.SCENE_MAGE_TOWER))
	var map := scene.instantiate()
	add_child(map)
	for i in range(6):
		await get_tree().process_frame
	GameState.layer4_purified.emit("magic")
	for i in range(4):
		await get_tree().process_frame
	_check("L4 정화(layer4_purified) → magic 포탈 OPEN (정화한 세계는 열린 채)",
		GameState.portal_state("magic") == GameState.PORTAL_OPEN,
		"magic=%s" % GameState.portal_state("magic"))
	_check("L4 정화 → divinity 포탈 flickering (다음 세계 깨어남)",
		GameState.portal_state("divinity") == GameState.PORTAL_FLICKERING,
		"divinity=%s" % GameState.portal_state("divinity"))
	_check("layer4_purified 시그널 발화 (관찰됨)", _purified)
	if is_instance_valid(map):
		map.queue_free()
		await get_tree().process_frame


# ---- 3. QuestManager 4번째 라인 (L4) 4중 공존 + 멱등 ---------------------

func _test_quest_fourth_line() -> void:
	# Reset to a clean L1-only state, then bring up L2/L3/L4 to prove 4-line coexistence.
	QuestManager.reset()
	var l1_before := QuestManager.active_id
	_check("초기: L4 라인 dormant", QuestManager.l4_active_id == "")
	QuestManager.activate_l2_line()
	QuestManager.activate_l3_line()
	QuestManager.activate_l4_line()
	_check("activate_l4_line() → L4-Q1 활성", QuestManager.l4_active_id == "L4-Q1",
		"l4=%s" % QuestManager.l4_active_id)
	# Coexistence: all four independent pointers live at once.
	_check("L4 라인이 L1 라인과 공존 (active_id 불변)", QuestManager.active_id == l1_before)
	_check("4중 라인 공존 (L2/L3/L4 포인터 모두 각자 head)",
		QuestManager.l2_active_id == "L2-Q1" and QuestManager.l3_active_id == "L3-Q1"
		and QuestManager.l4_active_id == "L4-Q1")
	# all four heads present in the quest log id list.
	var ids := QuestManager.all_ids()
	_check("퀘스트 로그에 L1 + L4 퀘스트 모두 존재",
		ids.has("Q1") and ids.has("L4-Q1") and ids.has("L4-Q7"))

	# Drive L4-Q gameplay signals: item_gathered(P1) advances L4-Q1 → L4-Q2.
	GameState.item_gathered.emit("P1")
	_check("L4-Q1(첫 채집) 완료 → L4-Q2 활성", QuestManager.l4_active_id == "L4-Q2",
		"l4=%s" % QuestManager.l4_active_id)
	# item_crafted advances L4-Q2 → L4-Q3.
	GameState.item_crafted.emit("D140", "L4-R01")
	_check("L4-Q2(첫 조합) 완료 → L4-Q3 활성", QuestManager.l4_active_id == "L4-Q3",
		"l4=%s" % QuestManager.l4_active_id)
	# The other lines stay their own pointers (no line cross-talk).
	_check("L4 진행 후에도 타 라인 포인터 독립 (라인 혼선 없음)",
		QuestManager.l4_active_id != QuestManager.l3_active_id
		and QuestManager.l4_active_id != QuestManager.l2_active_id)

	# Idempotent: calling activate_l4_line() again does NOT restart the line.
	QuestManager.activate_l4_line()
	_check("activate_l4_line() 멱등 (재호출 시 L4-Q3 유지, 재시작 없음)",
		QuestManager.l4_active_id == "L4-Q3", "l4=%s" % QuestManager.l4_active_id)


# ---- 4. save v2 라운드트립 (L4 라인 + mana + 정화 플래그) ----------------

func _test_save_v2() -> void:
	# QuestManager.to_dict carries the L4 line pointer/progress.
	var q := QuestManager.to_dict()
	_check("QuestManager.to_dict → l4_active_id 지속", q.has("l4_active_id"))
	_check("QuestManager.to_dict → l4_progress 지속", q.has("l4_progress"))
	var l4_before := QuestManager.l4_active_id

	# Grant mana + purified so both appear in the save dict.
	WhisperCurrency.add_mana(1)
	GameState.layer4_purified_flag = true
	var d := SaveManager.build_save_dict()
	_check("세이브 dict = v2 (멀티씬)", int(d.get("version", 0)) == 2)
	_check("세이브: layer4_purified 플래그 지속", bool(d.get("layer4_purified", false)))
	var w: Dictionary = d.get("whisper", {})
	_check("세이브: mana Whisper 지속 (mana=1)", int(w.get("mana", -1)) == 1, "mana=%s" % str(w.get("mana")))
	var qd: Dictionary = d.get("quests", {})
	_check("세이브: 퀘스트 dict에 L4 라인 포인터 지속", qd.has("l4_active_id"))

	# Round-trip: reset then restore — the L4 pointer + mana survive.
	QuestManager.reset()
	WhisperCurrency.reset()
	_check("리셋 후 L4 라인 dormant + mana 0 (라운드트립 사전조건)",
		QuestManager.l4_active_id == "" and WhisperCurrency.mana == 0)
	QuestManager.from_dict(q)
	WhisperCurrency.from_dict(w)
	_check("세이브 라운드트립: L4 라인 포인터 복원", QuestManager.l4_active_id == l4_before,
		"restored=%s want=%s" % [QuestManager.l4_active_id, l4_before])
	_check("세이브 라운드트립: mana Whisper 복원 (1)", WhisperCurrency.mana == 1,
		"mana=%d" % WhisperCurrency.mana)

	GameState.reset_layer4()
	WhisperCurrency.reset()
	_check("reset_layer4() → layer4_purified_flag zero", not GameState.layer4_purified_flag)


# ---- 5. NG+ 리셋 (4레이어) -----------------------------------------------

func _test_ng_plus_reset() -> void:
	# Set all four purified flags + advance the L4 line, then NG+ must clear them all.
	GameState.layer2_purified_flag = true
	GameState.layer3_purified_flag = true
	GameState.layer4_purified_flag = true
	QuestManager.activate_l4_line()
	GameState.item_gathered.emit("P1")   # advance L4 line off its head
	_check("(사전조건) L4 라인 활성 + 4레이어 정화 플래그 set",
		GameState.layer4_purified_flag and QuestManager.l4_active_id != "")

	SaveManager.new_game()
	_check("NG+ new_game() → layer4_purified_flag clear (reset_layer4)",
		not GameState.layer4_purified_flag)
	_check("NG+ new_game() → 4레이어 union 리셋 (L2/L3/L4 플래그 clear)",
		not GameState.layer2_purified_flag and not GameState.layer3_purified_flag
		and not GameState.layer4_purified_flag)
	_check("NG+ new_game() → L4 라인 dormant (재진입 시 재활성)",
		QuestManager.l4_active_id == "")

	# reset_after_clear path (start_ng_plus) also zeroes the L4 flag.
	GameState.layer4_purified_flag = true
	SaveManager.start_ng_plus([])
	_check("NG+ start_ng_plus() → layer4_purified_flag clear",
		not GameState.layer4_purified_flag)

	# GameState.reset_layer4() directly zeroes the flag.
	GameState.layer4_purified_flag = true
	GameState.reset_layer4()
	_check("GameState.reset_layer4() → 플래그 zero (직접 호출)",
		not GameState.layer4_purified_flag)
