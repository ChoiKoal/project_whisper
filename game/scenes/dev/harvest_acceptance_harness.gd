extends Node
## WH-QA-001 — harvest acceptance harness (CANDIDATE)
##
## Independent QA fixture for AC A–G of WH-TEAM-001.
##
## Scope: QA writes TEST code only. This harness observes shipping code; it must
## never be merged into a gameplay path and must not modify Gatherable /
## InteractionController / touch_controller.
##
## ---------------------------------------------------------------------------
## Verdict vocabulary (identical to docs/qa/WH-QA-001-test-spec.md)
##
##   REAL      exercises shipping code. FAIL = candidate game defect.
##   DETECTOR  deliberately-planted contract violation proving the harness can SEE
##             one. PASSES when it catches the violation. A DETECTOR FAIL means the
##             harness is blind and every REAL row is worthless.
##   BLOCKED   cannot run (missing build / module / controller). Never a defect.
##
## ---------------------------------------------------------------------------
## Run integrity (added after Ruby's engine run of 61a5f2b)
##
## A script error used to drop REAL rows silently while the summary still printed
## "REAL failures: 0". Every case this harness intends to run is therefore declared
## up front in EXPECTED_CASES; if any expected id is missing at report time the run
## is declared INVALID and the exit code is non-zero. A harness that cannot prove it
## ran its own cases must not be allowed to look green.
##
## ---------------------------------------------------------------------------
## Why grants are counted by SIGNAL, and why cases are isolated
##
## Inventory.add() clamps unique items:  to_add = clampi(1 - current, 0, amount)
## and returns BEFORE emitting item_added when the cap is already reached. So:
##   * a duplicate unique grant is invisible in the count, and
##   * if an earlier case left I9 in the inventory, the re-entry probe never fires
##     and A5-unique would "pass" without testing anything.
## Each case therefore starts from a cleared inventory, and A5 additionally asserts
## that the re-entrant gather() actually executed.
##
## Why the node guard must land BEFORE Inventory.add()
##
## Inventory.add() emits item_added and changed synchronously before returning into
## Gatherable.gather(). A listener on either can re-enter gather() while _spent is
## still false and queue_free() has not been processed. Guarding only ahead of
## item_gathered leaves that window open.

const REAL := "REAL"
const DETECTOR := "DETECTOR"
const BLOCKED := "BLOCKED"

## Every case this run intends to report. Missing id at report time => INVALID run.
const EXPECTED_CASES: Array[String] = [
	"A1", "A2", "A2b", "A3", "A4", "A5-plain", "A5-unique",
	"B1", "B2", "B3", "B4", "D1",
]

## Items used by the fixtures. Kept separate per case via _isolate().
const ITEM_PLAIN := "I1"
const ITEM_UNIQUE := "I9"
const ITEM_ROCK := "I2"

var _results: Array = []
var _sig_gathered: Array[String] = []
var _sig_added: Array[String] = []
var _observers_ready := false

## Re-entrancy probe. `_reentry_calls` counts gather() calls we actually made, which
## is the only honest evidence the probe fired; `_reentry_entered` counts callback
## entries and is diagnostic only.
var _reentry_target: Gatherable = null
var _reentry_budget := 0
var _reentry_entered := 0
var _reentry_calls := 0


func _ready() -> void:
	_wire_observers()
	if not _observers_ready:
		_note("SETUP", BLOCKED, false,
			"observation plumbing unavailable — REAL cases were NOT run")
		_print_report()
		return
	await _run_all()
	_print_report()


func _wire_observers() -> void:
	var ok := true
	if GameState.has_signal("item_gathered"):
		GameState.item_gathered.connect(_on_item_gathered)
	else:
		_note("SETUP-1", BLOCKED, false, "GameState.item_gathered missing")
		ok = false
	if Inventory.has_signal("item_added"):
		Inventory.item_added.connect(_on_item_added)
	else:
		_note("SETUP-2", BLOCKED, false, "Inventory.item_added missing")
		ok = false
	if not Inventory.has_method("clear"):
		_note("SETUP-3", BLOCKED, false, "Inventory.clear missing — cases cannot be isolated")
		ok = false
	_observers_ready = ok


func _on_item_gathered(item_id: String) -> void:
	_sig_gathered.append(item_id)


## Fires from inside Inventory.add(), i.e. strictly before gather() reaches its own
## emit — the earliest re-entry window that exists.
func _on_item_added(item_id: String, _amount: int) -> void:
	_sig_added.append(item_id)
	if _reentry_target == null or _reentry_budget <= 0:
		return
	_reentry_entered += 1
	var t := _reentry_target
	if not is_instance_valid(t) or t.is_queued_for_deletion():
		return
	_reentry_budget -= 1
	_reentry_calls += 1          # counted only when the call is really made
	t.gather()


func _note(id: String, kind: String, passed: bool, detail: String) -> void:
	_results.append({"id": id, "kind": kind, "pass": passed, "detail": detail})


func _count(item_id: String) -> int:
	return Inventory.count(item_id)


## Per-case isolation. Without this an earlier case can leave a unique item at its
## cap, which silently disarms the re-entry probe.
func _isolate() -> void:
	Inventory.clear()
	_reentry_target = null
	_reentry_budget = 0
	_reentry_entered = 0
	_reentry_calls = 0


## Properties are assigned before add_child so _ready() sees final values, and only
## properties that exist on the canonical Gatherable are touched. block_radius is
## deliberately NOT set: it is absent from collab/whisper-polish (it exists only in
## the earlier hand-off snapshot) and assigning it raises a script error that used to
## abort the run.
func _make_gatherable(item_id: String, amount: int = 1, unique: bool = false,
		blocks: bool = false) -> Gatherable:
	var g := Gatherable.new()
	g.item_id = item_id
	g.amount = amount
	g.unique = unique
	g.blocks_movement = blocks
	add_child(g)
	return g


# ===========================================================================
# AC A — one action grants exactly once
# ===========================================================================

## A1 (REAL) — same-frame re-call. For a NON-UNIQUE node can_gather() reduces to
## item_id != "", and duplicate suppression rests solely on the deferred queue_free().
func _t_a1_same_frame_double_gather() -> void:
	_isolate()
	var g := _make_gatherable(ITEM_PLAIN, 1)
	var s0 := _sig_gathered.size()
	g.gather()
	g.gather()
	var gained := _count(ITEM_PLAIN)
	var sigs := _sig_gathered.size() - s0
	_note("A1", REAL, gained == 1 and sigs == 1,
		"same-frame double gather -> inv=%d signal x%d (expected 1 / 1)" % [gained, sigs])


## A2 (REAL/BLOCKED) — SAME entry point twice. interact_with_object() is only the
## touch-arrival path; this is not the two-input-path case (see A2b).
func _t_a2_same_entry_point_twice(ic: Node) -> void:
	if ic == null or not ic.has_method("interact_with_object"):
		_note("A2", BLOCKED, false, "InteractionController fixture not wired")
		return
	_isolate()
	var g := _make_gatherable(ITEM_PLAIN, 1)
	var s0 := _sig_gathered.size()
	ic.interact_with_object(g)
	ic.interact_with_object(g)
	_note("A2", REAL, _count(ITEM_PLAIN) == 1 and _sig_gathered.size() - s0 == 1,
		"interact_with_object x2 (same entry point) -> inv=%d signal x%d (expected 1 / 1)"
		% [_count(ITEM_PLAIN), _sig_gathered.size() - s0])


## A2b (BLOCKED) — the genuine AC A vector: keyboard/facing path and touch-arrival
## path resolving on one frame. Needs a live controller plus input injection.
func _t_a2b_two_input_paths() -> void:
	_note("A2b", BLOCKED, false,
		"E-key path + touch-arrival path on one frame — needs live controller + input injection")


## A3 (REAL) — unique object, sequential double call. Judged by SIGNAL count because
## the inventory clamp hides the second grant.
func _t_a3_unique_sequential() -> void:
	_isolate()
	var g := _make_gatherable(ITEM_UNIQUE, 1, true)
	var s0 := _sig_gathered.size()
	g.gather()
	g.gather()
	var sigs := _sig_gathered.size() - s0
	var alive := is_instance_valid(g) and not g.is_queued_for_deletion()
	_note("A3", REAL, sigs == 1 and alive,
		"unique sequential x2 -> signal x%d alive=%s (expected 1 / true)" % [sigs, alive])


## A5 (REAL) — re-entry from inside Inventory.item_added. The probe is only meaningful
## if it actually fired, so a run where _reentry_calls != 1 is reported as FAIL with
## "probe did not arm" rather than being allowed to look like a pass.
func _t_a5_signal_reentry(unique: bool) -> void:
	_isolate()
	var item := ITEM_UNIQUE if unique else ITEM_PLAIN
	var id := "A5-unique" if unique else "A5-plain"
	var pre := _count(item)
	var g := _make_gatherable(item, 1, unique)
	var s0 := _sig_gathered.size()
	_reentry_target = g
	_reentry_budget = 1
	g.gather()
	_reentry_target = null
	_reentry_budget = 0
	var sigs := _sig_gathered.size() - s0
	var armed := _reentry_calls == 1
	if not armed:
		_note(id, REAL, false,
			"PROBE DID NOT ARM — start_count=%d callback_entries=%d reentrant_calls=%d; result is not evidence"
			% [pre, _reentry_entered, _reentry_calls])
		return
	_note(id, REAL, sigs == 1,
		"re-entry executed (calls=%d) -> inv=%d signal x%d (expected signal 1)"
		% [_reentry_calls, _count(item), sigs])


## A4 (DETECTOR) — plant a real one-grant violation and confirm the harness sees it.
func _t_a4_detector() -> void:
	_isolate()
	var s0 := _sig_added.size()
	Inventory.add(ITEM_PLAIN, 1)
	Inventory.add(ITEM_PLAIN, 1)
	var gained := _count(ITEM_PLAIN)
	var sigs := _sig_added.size() - s0
	_note("A4", DETECTOR, gained == 2 and sigs == 2,
		"planted double add -> inv=%d item_added x%d (detector PASSES by catching 2 / 2)"
		% [gained, sigs])


# ===========================================================================
# AC B — commit boundary
# ===========================================================================

## B1 (REAL/BLOCKED) — cancel before commit. The pure module never touches Inventory,
## so "inventory delta == 0" proves nothing. Judged on the module's own contract, per
## Kana: cancel ok -> take_commit rejected as stale_token -> reward_granted false.
func _t_b1_cancel_before_commit(state) -> void:
	if state == null or not state.has_method("begin"):
		_note("B1", BLOCKED, false,
			"HarvestActionState not wired — module-contract cancel check unrun")
		return
	var began: Dictionary = state.begin("rock_a", "rock")
	var token: int = began.get("token", -1)
	var cancelled: Dictionary = state.cancel(token)
	var recommit: Dictionary = state.take_commit(token)
	var granted := true
	if state.has_method("inspect_state"):
		var st: Dictionary = state.inspect_state()
		granted = bool((st.get("last", {}) as Dictionary).get("reward_granted", true))
	var ok := bool(cancelled.get("ok", false)) \
		and String(recommit.get("reason", "")) == "stale_token" \
		and granted == false
	_note("B1", REAL, ok,
		"cancel ok=%s / recommit reason=%s / reward_granted=%s (expected true / stale_token / false)"
		% [cancelled.get("ok"), recommit.get("reason"), granted])


## B2 (REAL) — commit stands exactly once when the node dies right after.
func _t_b2_commit_then_destroy() -> void:
	_isolate()
	var g := _make_gatherable(ITEM_PLAIN, 1)
	var s0 := _sig_gathered.size()
	g.gather()
	g.free()
	_note("B2", REAL, _count(ITEM_PLAIN) == 1 and _sig_gathered.size() - s0 == 1,
		"commit then destroy -> inv=%d signal x%d (expected 1 / 1)"
		% [_count(ITEM_PLAIN), _sig_gathered.size() - s0])


## B3 (BLOCKED) — scene change / save landing in the same beat as the commit.
func _t_b3_commit_then_scene_or_save() -> void:
	_note("B3", BLOCKED, false,
		"commit then scene transition / save — needs live scene tree + SaveManager")


## B4 (BLOCKED) — presentation failure must not roll back or re-issue the grant.
func _t_b4_presentation_failure_keeps_grant() -> void:
	_note("B4", BLOCKED, false,
		"presentation failure must not rollback/re-grant — needs real feedback path")


# ===========================================================================
# AC D — rock footprint
# ===========================================================================

## D1 (REAL) — a blocking rock owns a StaticBody before gather; a non-unique blocker
## must take it away with the node. Awaited so the result reaches the report.
func _t_d1_block_then_pass() -> void:
	_isolate()
	var g := _make_gatherable(ITEM_ROCK, 1, false, true)
	var had_body := _has_static_body(g)
	g.gather()
	await get_tree().process_frame
	var freed := not is_instance_valid(g)
	_note("D1", REAL, had_body and freed,
		"blocker footprint before=%s node freed after=%s (expected true / true)" % [had_body, freed])


func _has_static_body(n: Node) -> bool:
	for c in n.get_children():
		if c is StaticBody2D:
			return true
	return false


# ===========================================================================
# Runner
# ===========================================================================

func _run_all() -> void:
	_t_a1_same_frame_double_gather()
	_t_a2_same_entry_point_twice(null)
	_t_a2b_two_input_paths()
	_t_a3_unique_sequential()
	_t_a5_signal_reentry(false)
	_t_a5_signal_reentry(true)
	_t_a4_detector()
	_t_b1_cancel_before_commit(null)
	_t_b2_commit_then_destroy()
	_t_b3_commit_then_scene_or_save()
	_t_b4_presentation_failure_keeps_grant()
	await _t_d1_block_then_pass()


func _print_report() -> void:
	var real_fail := 0
	var detector_fail := 0
	var blocked := 0
	var seen := {}
	print("=== WH-QA-001 harvest acceptance — contract probe, not a game PASS ===")
	for r in _results:
		seen[r["id"]] = true
		var tag := ""
		match r["kind"]:
			BLOCKED:
				tag = "BLOCKED"
				blocked += 1
			DETECTOR:
				tag = "PASS" if r["pass"] else "FAIL"
				if not r["pass"]:
					detector_fail += 1
			_:
				tag = "PASS" if r["pass"] else "FAIL"
				if not r["pass"]:
					real_fail += 1
		print("  [%s] %s %s — %s" % [r["kind"], r["id"], tag, r["detail"]])

	# A case that never reported is the failure mode that once printed
	# "REAL failures: 0" while a script error had removed half the run.
	var missing: Array[String] = []
	for id in EXPECTED_CASES:
		if not seen.has(id):
			missing.append(id)

	print("REAL failures: %d   DETECTOR failures: %d   BLOCKED: %d   MISSING: %d"
		% [real_fail, detector_fail, blocked, missing.size()])

	var invalid := false
	if missing.size() > 0:
		invalid = true
		print("!! RUN INVALID — expected cases produced no row: %s" % [", ".join(missing)])
		print("   A missing row usually means a script error aborted the run.")
	if detector_fail > 0:
		invalid = true
		print("!! DETECTOR failed: the harness cannot see a planted violation.")
		print("   Every REAL row above is meaningless until that is fixed.")

	if invalid:
		print("RESULT: INVALID")
	elif real_fail > 0:
		print("RESULT: FAIL (%d)" % real_fail)
	else:
		print("RESULT: COMPLETE (no REAL failures; %d blocked)" % blocked)
	print("Scope: contract probe against Gatherable / Inventory only. NOT an AC PASS,")
	print("NOT a real-game or real-device result.")

	# Exit contract for automated runs: 0 only when the run completed and nothing failed.
	var code := 0
	if invalid:
		code = 2
	elif real_fail > 0:
		code = 1
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		get_tree().quit(code)
