extends Node
## (EG-1~EG-4) endgame_harness — validates the door of light + endings E1/E2 + truth shards.
## Modeled on l5_flow_harness. Boots the REAL home_island scene under the tree root, drives the
## endgame flow programmatically, and asserts the branch logic + control_lock/time_running pairing.
##
## Sub-tests (설계 §6.2):
##   A: five_portals_lit → home boot spawns the 빛의 문 (light_gate) at the dais focus.
##   B: entry prompt — 조각 <5 → [돌아선다] locked; =5 → unlocked.
##   C: [들어간다] → E1 완주 (montage → credits, endings_seen.E1, control_lock/time_running 페어링).
##   취소: 프롬프트 열고 [아직 아니야] → 프롬프트 닫힘 + control_lock 해제 + E1 미발동 (QA 필수).
##   D: 조각 5 + [돌아선다] → E2 완주 (endings_seen.E2).
##   E: 진상 조각 5종 조사 → 플래그·최종 카드 트리거.
##   F: NG+ → 조각 리셋 / endings_seen 보존.
##   G: 세이브/로드 라운드트립 — 조각 진행·엔딩 기록 지속.

var _fail := 0
var _tree: SceneTree
var _home: Node = null


func _ready() -> void:
	_tree = get_tree()
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	# Reparent under root so change_scene / scene loads don't free the harness mid-run.
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await _tree.process_frame


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _fresh() -> void:
	SaveManager.delete_save()
	SaveManager.new_game()


## Boot the real home island and return its HomeSession node (searched by class).
func _boot_home() -> Node:
	if _home != null and is_instance_valid(_home):
		_home.queue_free()
		_home = null
		await _frames(2)
	WorldContext.current_scene = WorldContext.SCENE_HOME
	WorldContext.arrival_mode = ""
	var scene: PackedScene = load(WorldContext.scene_path(WorldContext.SCENE_HOME))
	_home = scene.instantiate()
	add_child(_home)
	await _frames(10)
	return _search(_home, HomeSession)


func _search(node: Node, cls) -> Node:
	if node == null:
		return null
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _search(c, cls)
		if r != null:
			return r
	return null


func _find_light_gate() -> Portal:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n is Portal and (n as Portal).object_id == "light_gate":
			return n
	return null


func _run() -> void:
	print("=== ENDGAME HARNESS ===")
	await _test_a_spawn()
	await _test_b_prompt_gate()
	await _test_cancel()
	await _test_c_e1()
	await _test_d_e2()
	await _test_e_shards()
	await _test_e2_investigate()
	await _test_e3_codex_tab()
	await _test_f_ngplus()
	await _test_g_save_roundtrip()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)


# ---- A: light gate spawn --------------------------------------------------

func _test_a_spawn() -> void:
	print("--- A: 빛의 문 스폰 (five_portals_lit / 예고 플래그) ---")
	_fresh()
	# Not lit yet → no gate on boot.
	var hs := await _boot_home()
	_check("HomeSession booted", hs != null)
	_check("A: 미완결 시 빛의 문 미스폰", _find_light_gate() == null)

	# Fully purify all five + light the portals, reboot → gate present.
	SaveManager.cleared = true
	GameState.layer2_purified_flag = true
	GameState.layer3_purified_flag = true
	GameState.layer4_purified_flag = true
	GameState.layer5_purified_flag = true
	var fired := GameState.maybe_light_five_portals()
	_check("A: maybe_light_five_portals 발동", fired and GameState.light_gate_previewed_flag)
	await _boot_home()
	var gate := _find_light_gate()
	_check("A: 예고 플래그 → 부팅 시 빛의 문 스폰", gate != null)
	_check("A: 빛의 문 = platinum Portal", gate != null and gate.platinum)
	# It must NOT be a travel portal (not in portal_states / never routes).
	_check("A: 빛의 문 layer는 라우팅 대상 아님 ('light')",
		gate != null and gate.layer == "light")


# ---- B: [돌아선다] gate on truth shards ------------------------------------

func _test_b_prompt_gate() -> void:
	print("--- B: 진입 프롬프트 [돌아선다] 게이트 ---")
	# From A the run is fully purified + gate spawned. Ensure shards NOT complete.
	GameState.reset_truth_shards()
	var hs := await _boot_home()
	hs.call("_open_ending_prompt")
	await _frames(2)
	var turn := _find_button(hs, "돌아선다")
	var enter := _find_button(hs, "들어간다")
	var cancel := _find_button(hs, "아직 아니야")
	_check("B: 프롬프트 3선택지 존재", turn != null and enter != null and cancel != null)
	_check("B: 조각<5 → [돌아선다] 잠김", turn != null and turn.disabled)
	_check("B: [들어간다] 항상 가용", enter != null and not enter.disabled)
	# control_lock engaged while prompt open.
	_check("B: 프롬프트 중 control_lock true", GameState.control_locked())
	# Complete the shards → reopen → unlocked.
	hs.call("_cancel_ending_prompt")
	await _frames(2)
	_check("B: [아직 아니야]로 닫힘 후 control_lock 해제", not GameState.control_locked())
	for sid in GameState.TRUTH_SHARD_IDS:
		GameState.collect_truth_shard(sid)
	_check("B: 5조각 완성 → truth_final_seen", GameState.truth_final_seen)
	hs.call("_open_ending_prompt")
	await _frames(2)
	turn = _find_button(hs, "돌아선다")
	_check("B: 조각=5 → [돌아선다] 해금", turn != null and not turn.disabled)
	hs.call("_cancel_ending_prompt")
	await _frames(2)


func _find_button(root: Node, text: String) -> Button:
	# Search the whole tree (the modal lives on a CanvasLayer under HomeSession).
	return _search_button(_tree.root, text)


func _search_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var r := _search_button(c, text)
		if r != null:
			return r
	return null


# ---- 취소 경로 (QA 필수) --------------------------------------------------

func _test_cancel() -> void:
	print("--- 취소: [아직 아니야] → 엔딩 미발동, 플레이 복귀 ---")
	GameState.reset_truth_shards()   # even mid-shard, cancel must be safe
	var hs := await _boot_home()
	GameState.endings_seen.clear()
	hs.call("_open_ending_prompt")
	await _frames(2)
	_check("취소: 프롬프트 열림 (control_lock)", GameState.control_locked())
	hs.call("_cancel_ending_prompt")
	await _frames(2)
	_check("취소: control_lock 해제 (플레이 복귀)", not GameState.control_locked())
	_check("취소: time_running 복원", GameState.time_running)
	_check("취소: 어떤 엔딩도 미기록", GameState.endings_seen.is_empty())
	# The E2 chance is not burned: reopening still offers the choices.
	hs.call("_open_ending_prompt")
	await _frames(2)
	_check("취소: 재접근 가능 (E2 기회 미소각)", _find_button(hs, "들어간다") != null)
	hs.call("_cancel_ending_prompt")
	await _frames(2)


# ---- C: E1 완주 -----------------------------------------------------------

func _test_c_e1() -> void:
	print("--- C: [들어간다] → E1 완주 ---")
	var hs := await _boot_home()
	GameState.endings_seen.clear()
	hs.call("_open_ending_prompt")
	await _frames(2)
	# Commit to E1.
	hs.call("_choose_enter")
	await _frames(3)
	var seq := _search(hs, EndingSequence)
	_check("C: EndingSequence 생성 (E1)", seq != null)
	_check("C: E1 진입 시 control_lock true", GameState.control_locked())
	_check("C: E1 진입 시 time_running false (페어링)", not GameState.time_running)
	# Skip to finish (montage/credits collapse; record + restore must still fire — 멱등).
	if seq != null:
		seq.call("skip_all")
	await _frames(3)
	_check("C: E1 완주 → endings_seen.E1", GameState.has_ending("E1"))
	_check("C: E1 완주 → control_lock 해제", not GameState.control_locked())
	_check("C: E1 완주 → time_running 복원", GameState.time_running)


# ---- D: E2 완주 -----------------------------------------------------------

func _test_d_e2() -> void:
	print("--- D: 조각5 + [돌아선다] → E2 완주 ---")
	var hs := await _boot_home()
	GameState.endings_seen.clear()
	for sid in GameState.TRUTH_SHARD_IDS:
		GameState.collect_truth_shard(sid)
	hs.call("_open_ending_prompt")
	await _frames(2)
	hs.call("_choose_turn_back")
	await _frames(3)
	var seq := _search(hs, EndingSequence)
	_check("D: EndingSequence 생성 (E2)", seq != null)
	_check("D: E2 진입 시 control_lock/time 페어링",
		GameState.control_locked() and not GameState.time_running)
	if seq != null:
		seq.call("skip_all")
	await _frames(3)
	_check("D: E2 완주 → endings_seen.E2", GameState.has_ending("E2"))
	_check("D: E2 완주 → control_lock 해제 + time 복원",
		not GameState.control_locked() and GameState.time_running)


# ---- E: 진상 조각 조사 ----------------------------------------------------

func _test_e_shards() -> void:
	print("--- E: 진상 조각 조사 → 플래그 + 최종 카드 ---")
	GameState.reset_truth_shards()
	var complete_fired := [false]
	var cb := func(): complete_fired[0] = true
	GameState.truth_shards_complete.connect(cb)
	var count := 0
	for sid in GameState.TRUTH_SHARD_IDS:
		var got: bool = GameState.collect_truth_shard(sid)
		count += 1
		_check("E: 조각 수집 '%s' → 플래그" % sid, got and GameState.has_truth_shard(sid))
		_check("E: 조각 카운트 = %d" % count, GameState.truth_shard_count() == count)
	# Re-collecting is idempotent.
	_check("E: 재수집 멱등", not GameState.collect_truth_shard(GameState.TRUTH_SHARD_IDS[0]))
	_check("E: 5조각 → truth_shards_complete 발화", complete_fired[0])
	_check("E: 5조각 → truth_final_seen (돌아선다 해금)", GameState.truth_final_seen)
	GameState.truth_shards_complete.disconnect(cb)


# ---- E2: TruthShard 조사 오브젝트 (실제 노드 on_interact) --------------------

func _test_e2_investigate() -> void:
	print("--- E2: TruthShard on_interact → 조각 수집 + 로그 기록 + 카드 ---")
	_fresh()
	Codex.reset()
	var s := TruthShard.new()
	s.setup("stopped_robot", "멈춘 로봇", "…마지막 로그: 우리는 효율적이었다. 영원할 만큼은, 아니었다.")
	add_child(s)
	await _frames(2)
	_check("E2: TruthShard 는 gatherable 그룹 (조사형)", s.is_in_group("gatherable"))
	_check("E2: 채집 불가 (조사만)", not s.can_gather())
	s.on_interact()
	await _frames(2)
	_check("E2: on_interact → GameState 조각 수집", GameState.has_truth_shard("stopped_robot"))
	_check("E2: on_interact → Codex 로그 기록", Codex.truth_log_count() == 1)
	_check("E2: 조사 중 control_lock (카드 모달)", GameState.control_locked())
	s.call("_close_card")
	await _frames(2)
	_check("E2: 카드 닫힘 → control_lock 해제", not GameState.control_locked())
	# Idempotent re-investigate (no double count).
	s.on_interact()
	await _frames(2)
	_check("E2: 재조사 멱등 (카운트 1 유지)", GameState.truth_shard_count() == 1)
	s.call("_close_card")
	await _frames(2)
	s.queue_free()
	await _frames(2)


# ---- E3: 도감 「기록」 탭 ---------------------------------------------------

func _test_e3_codex_tab() -> void:
	print("--- E3: 도감 「기록(진상)」 탭 ---")
	_fresh()
	Codex.reset()
	# Record all five shard logs + trigger the final card.
	Codex.record_truth_log("world_tree", "세계수의 잎", "잎 뒤의 글.")
	Codex.record_truth_log("l2_last_log", "마지막 로그 스크린", "관제탑 로그.")
	Codex.record_truth_log("stopped_robot", "멈춘 로봇", "로봇 로그.")
	Codex.record_truth_log("mage_ghost", "마법사의 잔영", "마법사 로그.")
	_check("E3: 4조각 → truth_final_seen 아직", not Codex.truth_final_seen())
	Codex.record_truth_log("petrified_pilgrim", "석화된 순례자", "순례자 로그.")
	_check("E3: 5조각 → truth_final_seen", Codex.truth_final_seen())
	_check("E3: truth_logs_ordered 5개 (정렬)", Codex.truth_logs_ordered().size() == 5)
	_check("E3: 정렬 순서 = 캐논 (world_tree 먼저)",
		String(Codex.truth_logs_ordered()[0].get("id")) == "world_tree")
	# Drive the real CodexUI 기록 tab.
	var ui := CodexUI.new()
	add_child(ui)
	await _frames(3)
	ui.open()
	await _frames(2)
	var rows := ui.set_truth_filter(true)
	await _frames(2)
	_check("E3: 기록 탭 → 조각 로그 노출 (5)", rows == 5)
	_check("E3: 기록 탭 행 수 (5조각 + 최종카드 패널)", ui.truth_row_count() >= 5)
	ui.close()
	ui.queue_free()
	await _frames(2)


# ---- F: NG+ 리셋/보존 -----------------------------------------------------

func _test_f_ngplus() -> void:
	print("--- F: NG+ → 조각 리셋 / endings_seen 보존 ---")
	# Seed a full run: shards + both endings seen.
	for sid in GameState.TRUTH_SHARD_IDS:
		GameState.collect_truth_shard(sid)
	GameState.record_ending("E1")
	GameState.record_ending("E2")
	SaveManager.cleared = true
	SaveManager.start_ng_plus()
	_check("F: NG+ → 진상 조각 리셋", GameState.truth_shard_count() == 0)
	_check("F: NG+ → truth_final_seen 리셋", not GameState.truth_final_seen)
	_check("F: NG+ → endings_seen 보존 (lifetime E1/E2)",
		GameState.has_ending("E1") and GameState.has_ending("E2"))
	_check("F: NG+ → 빛의 문 예고 리셋", not GameState.light_gate_previewed_flag)


# ---- G: 세이브/로드 라운드트립 --------------------------------------------

func _test_g_save_roundtrip() -> void:
	print("--- G: 세이브/로드 — 조각·엔딩 기록 지속 ---")
	_fresh()
	GameState.collect_truth_shard("world_tree")
	GameState.collect_truth_shard("stopped_robot")
	GameState.record_ending("E1")
	SaveManager.save_game()
	# Wipe live state, reload core.
	GameState.reset_truth_shards()
	GameState.endings_seen.clear()
	var data := SaveManager._read_save()
	SaveManager._apply_core_state(data)
	_check("G: 조각 진행 지속 (2)", GameState.truth_shard_count() == 2)
	_check("G: world_tree 조각 지속", GameState.has_truth_shard("world_tree"))
	_check("G: endings_seen.E1 지속", GameState.has_ending("E1"))
	# v0.9.0 세이브 (결측 키) 로드 → 기본값 (빈/false) — null 가드.
	var legacy := {"version": 2}
	SaveManager._apply_core_state(legacy)
	_check("G: 결측 키 마이그레이션 (조각 0)", GameState.truth_shard_count() == 0)
	_check("G: 결측 키 마이그레이션 (endings 빈)", GameState.endings_seen.is_empty())
