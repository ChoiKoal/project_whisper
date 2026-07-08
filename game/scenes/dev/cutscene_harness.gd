extends Node
## (CQ-6) cutscene_harness — regression coverage for the v1.3.0 컷신 퀄업 pass. Complements
## endgame_harness (E1/E2 branch logic) + sweep_harness (clear-cutscene time restore) by driving
## the cutscene CONTRACT every beat must honor:
##
##   1. TRIGGER → mark_cutscene_seen(id): each cutscene records itself in the Codex 재감상 catalog
##      on its first play (so the replay gallery unlocks). Verified per CS-01~05 + E1/E2.
##   2. control_lock / time_running PAIRING: the entry pauses (time_running=false and/or
##      control_lock=true) and EVERY exit path restores both. Verified for the endings (skip)
##      + the CS-05 ignition beat + the standalone replay.
##   3. ESC-SKIP idempotency + immediate restore: skipping mid-beat frees/finishes at once,
##      records the flag, and restores time+lock. Spamming skip after finish is a no-op.
##   4. 재감상 (replay) gallery: seen cutscenes are playable + side-effect-free; unseen ones are
##      locked. A replay play→skip round-trips time/lock without touching endings/portals/quests.
##
## Assertions print [PASS]/[FAIL]; exit code = failure count. Reparents under the tree root so any
## scene change (none here, but for parity with the other harnesses) can't free it mid-run.

var _fail := 0
var _tree: SceneTree


func _ready() -> void:
	_tree = get_tree()
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	call_deferred("_run")


func _frames(n: int) -> void:
	for i in range(n):
		await _tree.process_frame


func _wait(s: float) -> void:
	await _tree.create_timer(s, true, false, true).timeout


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1


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


func _fresh() -> void:
	SaveManager.delete_save()
	SaveManager.new_game()
	Codex.reset()
	GameState.time_running = true
	GameState.set_control_lock(false)


func _run() -> void:
	print("=== CUTSCENE HARNESS (CQ-6) ===")
	await _test_catalog_seen_registry()
	await _test_ending_pairing_and_skip("E1")
	await _test_ending_pairing_and_skip("E2")
	await _test_cs05_ignition_pairing()
	await _test_replay_playback()
	await _test_replay_skip_restores()
	await _test_codex_replay_tab()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)


# ---- 1. mark_cutscene_seen registry --------------------------------------

## Every catalogued cutscene id must register through mark_cutscene_seen, unlock the replay,
## and stay in canonical order. (The trigger sites themselves are covered by their own beats;
## here we assert the Codex contract the gallery depends on.)
func _test_catalog_seen_registry() -> void:
	print("--- 1: mark_cutscene_seen → 재감상 카탈로그 ---")
	_fresh()
	_check("1: 초기 상태 — 본 컷신 0", Codex.cutscene_seen_count() == 0)
	var ordered: Array = Codex.cutscenes_ordered()
	_check("1: 카탈로그 = 7 (CS-01~05 + E1/E2)", ordered.size() == 7)
	_check("1: 전부 미시청 (잠금)", ordered.all(func(e): return not bool(e.get("seen", true))))
	# The canonical ids, in the catalog's declared order.
	var ids: Array = ordered.map(func(e): return String(e.get("id", "")))
	_check("1: 카탈로그 순서 = 캐논", ids == ["CS-01", "CS-02", "CS-03", "CS-04", "CS-05", "E1", "E2"],
		str(ids))
	# Mark each seen → unlocks, idempotent.
	for cid in ids:
		Codex.mark_cutscene_seen(cid)
	_check("1: 전 컷신 시청 → 7 unlocked", Codex.cutscene_seen_count() == 7)
	Codex.mark_cutscene_seen("CS-01")
	_check("1: 재시청 멱등 (여전히 7)", Codex.cutscene_seen_count() == 7)
	_check("1: 미지 id 무시", not Codex.is_cutscene_seen("CS-99"))


# ---- 2 + 3. ending trigger → pairing → skip ------------------------------

## Drive the real EndingSequence for `eid`: play() must mark it seen + pause (time false, lock
## true); skip_all() must record the ending, restore both, and be idempotent on re-spam.
func _test_ending_pairing_and_skip(eid: String) -> void:
	print("--- 2/3: %s 트리거 → 페어링 → ESC 스킵 ---" % eid)
	_fresh()
	GameState.endings_seen.clear()
	var seq := EndingSequence.new()
	_tree.root.add_child(seq)
	await _frames(2)
	seq.play(eid)
	await _frames(2)
	_check("%s: play → mark_cutscene_seen" % eid, Codex.is_cutscene_seen(eid))
	_check("%s: 진입 — time_running false" % eid, not GameState.time_running)
	_check("%s: 진입 — control_lock true" % eid, GameState.control_locked())
	_check("%s: 아직 미완주 (is_done false)" % eid, not seq.is_done())
	# ESC-skip → immediate finish: ending recorded + BOTH restored.
	seq.skip_all()
	await _frames(2)
	_check("%s: 스킵 → is_done" % eid, seq.is_done())
	_check("%s: 스킵 → endings_seen.%s 기록" % [eid, eid], GameState.has_ending(eid))
	_check("%s: 스킵 → time_running 복원" % eid, GameState.time_running)
	_check("%s: 스킵 → control_lock 해제" % eid, not GameState.control_locked())
	# Spam skip after finish — idempotent (no double-record, no crash).
	var seen_before := GameState.endings_seen.size()
	for i in range(4):
		seq.skip_all()
	_check("%s: 스킵 스팸 멱등 (endings 불변)" % eid, GameState.endings_seen.size() == seen_before)
	# The NG+/타이틀 prompt buttons live on the sequence; free it before it can change scene.
	if is_instance_valid(seq):
		seq.queue_free()
	await _frames(2)


# ---- 2. CS-05 귀환·점화 pairing -------------------------------------------

## The CS-05 ignition beat pauses (time false + lock true) and restores both on completion, while
## marking itself seen. We await the real (short) beat to completion rather than skipping (it has
## no ESC skip — it is a scripted return beat that always runs to the end).
func _test_cs05_ignition_pairing() -> void:
	print("--- 2: CS-05 귀환·점화 — 페어링 + mark seen ---")
	_fresh()
	var scr := load("res://scripts/world/portal_cutscene.gd")
	if scr == null:
		_check("2: portal_cutscene.gd 로드", false)
		return
	var pc: Node = scr.new()
	_tree.root.add_child(pc)
	await _frames(3)
	if not pc.has_method("play_return_ignition"):
		_check("2: play_return_ignition 존재", false)
		pc.queue_free()
		return
	# Drive it (async). Assert the pause engages while it runs.
	pc.call("play_return_ignition")
	await _frames(2)
	_check("2: CS-05 진입 — mark_cutscene_seen", Codex.is_cutscene_seen("CS-05"))
	_check("2: CS-05 진입 — time false + lock true (페어링)",
		not GameState.time_running and GameState.control_locked())
	# The beat is ~5s of cards + holds; wait for it to restore.
	var waited := 0.0
	while GameState.control_locked() and waited < 10.0:
		await _wait(0.25)
		waited += 0.25
	_check("2: CS-05 완주 → time_running 복원", GameState.time_running, "waited=%.1fs" % waited)
	_check("2: CS-05 완주 → control_lock 해제", not GameState.control_locked())
	if is_instance_valid(pc):
		pc.queue_free()
	await _frames(2)


# ---- 4. replay playback (side-effect-free) --------------------------------

## A CutsceneReplay plays a seen cutscene's cards + signature beat WITHOUT gameplay side effects:
## no ending recorded, no portal/quest writes. It pauses time+lock for the beat and restores on
## finish, then frees itself.
func _test_replay_playback() -> void:
	print("--- 4: 재감상 재생 (side-effect-free) ---")
	_fresh()
	GameState.endings_seen.clear()
	var portal_before: String = GameState.portal_state("nature")
	var rep := CutsceneReplay.new()
	_tree.root.add_child(rep)
	await _frames(2)
	rep.play("CS-01")
	await _frames(2)
	_check("4: 재생 진입 — time false + lock true",
		not GameState.time_running and GameState.control_locked())
	_check("4: 재생 중 — endings 미기록 (부작용 없음)", GameState.endings_seen.is_empty())
	_check("4: 재생 중 — 포탈 상태 불변", GameState.portal_state("nature") == portal_before)
	# Let it run to natural completion (CS-01 = heartbeat + 4 cards ≈ 15s) OR skip for speed.
	# skip() sets _done immediately then queue_free()s — read is_done() before the frame frees it.
	rep.skip()
	_check("4: 재생 종료 → is_done", rep.is_done())
	_check("4: 재생 종료 → time+lock 복원",
		GameState.time_running and not GameState.control_locked())
	_check("4: 재생 종료 → endings 여전히 비어있음 (부작용 없음)", GameState.endings_seen.is_empty())
	await _frames(2)
	_check("4: 재생 오버레이 자동 해제 (queue_free)", not is_instance_valid(rep))


# ---- 3. replay ESC skip restores + idempotent -----------------------------

func _test_replay_skip_restores() -> void:
	print("--- 3: 재감상 ESC 스킵 → 즉시 복귀 + 멱등 ---")
	_fresh()
	var rep := CutsceneReplay.new()
	_tree.root.add_child(rep)
	await _frames(2)
	rep.play("E2")
	await _frames(2)
	_check("3: 재생 중 — 페어링", not GameState.time_running and GameState.control_locked())
	# skip() finishes + restores synchronously, then queue_free()s — spam it BEFORE the free frame.
	rep.skip()
	var done_now := rep.is_done()
	# Spam skip after done — no crash, state stays restored.
	for i in range(4):
		rep.skip()
	_check("3: 스킵 → is_done + 복원",
		done_now and GameState.time_running and not GameState.control_locked())
	_check("3: 스킵 스팸 멱등 (복원 유지)",
		GameState.time_running and not GameState.control_locked())
	await _frames(2)


# ---- 4. 도감 재감상 탭 (locked/unlocked + 재생 launch) ----------------------

func _test_codex_replay_tab() -> void:
	print("--- 4: 도감 「재감상」 탭 (잠금/해금 + 재생) ---")
	_fresh()
	# Mark only CS-01 + E2 seen → the rest stay locked.
	Codex.mark_cutscene_seen("CS-01")
	Codex.mark_cutscene_seen("E2")
	var ui := CodexUI.new()
	_tree.root.add_child(ui)
	await _frames(3)
	ui.open()
	await _frames(2)
	var seen := ui.set_replay_filter(true)
	await _frames(2)
	_check("4: 재감상 탭 → 본 컷신 2", seen == 2)
	_check("4: 재감상 행 = 카탈로그 7 (잠금 포함)", ui.replay_row_count() == 7)
	# Launch a replay for a SEEN cutscene → overlay spawns, codex closes.
	var overlay := ui.start_replay("CS-01")
	await _frames(2)
	_check("4: 본 컷신 재생 → 오버레이 생성", overlay != null and is_instance_valid(overlay))
	_check("4: 재생 시 도감 닫힘", not ui.is_open())
	if overlay != null and overlay.has_method("skip"):
		overlay.call("skip")
		await _frames(2)
	_check("4: 재생 종료 → 복원", GameState.time_running and not GameState.control_locked())
	# Launching a LOCKED cutscene is a no-op (no overlay).
	var locked := ui.start_replay("CS-03")
	await _frames(1)
	_check("4: 잠긴 컷신 재생 거부 (오버레이 없음)", locked == null)
	if is_instance_valid(ui):
		ui.queue_free()
	await _frames(2)
