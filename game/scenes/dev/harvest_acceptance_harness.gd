extends Node
## WH-QA-001 — harvest acceptance harness (CANDIDATE, SETUP UNVERIFIED)
##
## Independent QA fixture for AC A–G of WH-TEAM-001. QA has never executed this
## against the engine: no runnable build has been handed over yet. Every row this
## prints is UNVERIFIED until it is re-run on Ruby's frozen build.
##
## Scope: QA writes TEST code only. This harness observes shipping code; it must
## never be merged into a gameplay path and must not modify Gatherable /
## InteractionController / touch_controller.
##
## ---------------------------------------------------------------------------
## Verdict vocabulary (identical to docs/qa/WH-QA-001-test-spec.md)
##
##   REAL      exercises shipping code. FAIL = candidate game defect.
##   DETECTOR  deliberately-wrong fixture proving the harness can SEE a violation.
##             It PASSES when it catches the planted violation. A DETECTOR FAIL
##             means the harness is blind and every REAL row above is worthless.
##   BLOCKED   cannot run (missing build / module / controller). Never a defect.
##
## ---------------------------------------------------------------------------
## Why grants are counted by SIGNAL as well as by inventory delta
##
## Inventory.add() clamps unique items:  to_add = clampi(1 - current, 0, amount)
## so a second grant of a unique item adds 0 and is INVISIBLE in the count.
## Duplicate detection for unique objects therefore has to watch signal counts.
##
## Why the node guard must land BEFORE Inventory.add()
##
## Inventory.add() itself emits item_added and changed synchronously, before it
## returns into Gatherable.gather(). A listener on either signal can re-enter
## gather() while _spent is still false and queue_free() has not been processed.
## Guarding only ahead of item_gathered leaves that window open.

const REAL := "REAL"
const DETECTOR := "DETECTOR"
const BLOCKED := "BLOCKED"

var _results: Array = []
var _sig_gathered: Array[String] = []   ## GameState.item_gathered
var _sig_added: Array[String] = []      ## Inventory.item_added
var _observers_ready := false

## Re-entrancy probe state (bounded so a real double-grant cannot hang the run).
var _reentry_target: Gatherable = null
var _reentry_budget := 0
var _reentry_fired := 0


func _ready() -> void:
	_wire_observers()
	await _run_all()
	_print_report()


func _wire_observers() -> void:
	var ok := true
	if GameState.has_signal("item_gathered"):
		GameState.item_gathered.connect(_on_item_gathered)
	else:
		_note("SETUP-1", BLOCKED, false, "GameState.item_gathered missing — cannot observe grants")
		ok = false
	if Inventory.has_signal("item_added"):
		Inventory.item_added.connect(_on_item_added)
	else:
		_note("SETUP-2", BLOCKED, false, "Inventory.item_added missing — cannot observe add-signal re-entry")
		ok = false
	_observers_ready = ok


func _on_item_gathered(item_id: String) -> void:
	_sig_gathered.append(item_id)


## Inventory.add() fires this BEFORE gather() reaches its own emit. When a probe is
## armed we re-enter gather() from here — the earliest re-entry window that exists.
func _on_item_added(item_id: String, _amount: int) -> void:
	_sig_added.append(item_id)
	if _reentry_target != null and _reentry_budget > 0:
		_reentry_budget -= 1
		_reentry_fired += 1
		var t := _reentry_target
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			t.gather()


func _note(id: String, kind: String, passed: bool, detail: String) -> void:
	_results.append({"id": id, "kind": kind, "pass": passed, "detail": detail})


func _count(item_id: String) -> int:
	return Inventory.count(item_id) if Inventory.has_method("count") else -1


## Properties are set BEFORE add_child so _ready() builds the footprint from final
## values. _ready() is never invoked manually.
func _make_gatherable(item_id: String, amount: int = 1, unique: bool = false,
		blocks: bool = false, radius: float = 20.0) -> Gatherable:
	var g := Gatherable.new()
	g.item_id = item_id
	g.amount = amount
	g.unique = unique
	g.blocks_movement = blocks
	g.block_radius = radius
	add_child(g)
	return g


# ===========================================================================
# AC A — one action grants exactly once
# ===========================================================================

## A1 (REAL) — same-frame re-call. can_gather() for a NON-UNIQUE node reduces to
## item_id != "", and duplicate suppression rests solely on the deferred
## queue_free(). A second call inside the same frame still passes the guard.
func _t_a1_same_frame_double_gather() -> void:
	var g := _make_gatherable("I1", 1)
	var c0 := _count("I1")
	var s0 := _sig_gathered.size()
	g.gather()
	g.gather()
	var gained := _count("I1") - c0
	var sigs := _sig_gathered.size() - s0
	_note("A1", REAL, gained == 1 and sigs == 1,
		"same-frame double gather -> inv+%d signal x%d (expected 1 / 1)" % [gained, sigs])


## A2 (REAL) — SAME entry point called twice. This is NOT the two-input-path case;
## interact_with_object() is only the touch-arrival path. Named accordingly so the
## report cannot be misread. The genuine E-key + touch collision needs a live
## InteractionController and stays BLOCKED below (A2b).
func _t_a2_same_entry_point_twice(ic: Node) -> void:
	if ic == null or not ic.has_method("interact_with_object"):
		_note("A2", BLOCKED, false, "InteractionController fixture not wired — same-entry-point re-call unrun")
		return
	var g := _make_gatherable("I1", 1)
	var c0 := _count("I1")
	var s0 := _sig_gathered.size()
	ic.interact_with_object(g)
	ic.interact_with_object(g)
	_note("A2", REAL, _count("I1") - c0 == 1 and _sig_gathered.size() - s0 == 1,
		"interact_with_object x2 (same entry point) -> inv+%d signal x%d (expected 1 / 1)"
		% [_count("I1") - c0, _sig_gathered.size() - s0])


## A2b (BLOCKED) — the real AC A vector: keyboard/facing path (interaction_controller
## ~line 538) and touch-arrival path (~line 565) resolving on the same frame. Needs a
## controller fixture plus synthetic input; cannot be faked by calling one method twice.
func _t_a2b_two_input_paths() -> void:
	_note("A2b", BLOCKED, false,
		"E-key path + touch-arrival path on one frame — needs live controller + input injection")


## A3 (REAL) — unique object, sequential double call. Counted by SIGNAL because the
## inventory clamp hides the second grant for unique items.
func _t_a3_unique_sequential() -> void:
	var g := _make_gatherable("I9", 1, true)
	var s0 := _sig_gathered.size()
	g.gather()
	g.gather()
	var sigs := _sig_gathered.size() - s0
	var alive := is_instance_valid(g) and not g.is_queued_for_deletion()
	_note("A3", REAL, sigs == 1 and alive,
		"unique sequential x2 -> signal x%d alive=%s (expected 1 / true)" % [sigs, alive])


## A5 (REAL) — re-entry from inside Inventory.item_added, i.e. BEFORE gather() sets
## _spent and before it emits item_gathered. Budget-limited to one re-entry so a real
## double-grant cannot recurse forever. Run for both unique and non-unique.
func _t_a5_signal_reentry(unique: bool) -> void:
	var item := "I9" if unique else "I1"
	var g := _make_gatherable(item, 1, unique)
	var c0 := _count(item)
	var s0 := _sig_gathered.size()
	_reentry_target = g
	_reentry_budget = 1
	_reentry_fired = 0
	g.gather()
	_reentry_target = null
	_reentry_budget = 0
	var gained := _count(item) - c0
	var sigs := _sig_gathered.size() - s0
	var id := "A5-unique" if unique else "A5-plain"
	_note(id, REAL, sigs == 1,
		"re-entry from item_added (fired=%d) -> inv+%d signal x%d (expect signal 1; inv delta unreliable for unique)"
		% [_reentry_fired, gained, sigs])


## A4 (DETECTOR) — plant a real violation of the one-grant contract and confirm the
## harness sees it. PASSES when the violation is caught.
func _t_a4_detector() -> void:
	var c0 := _count("I1")
	var s0 := _sig_added.size()
	Inventory.add("I1", 1)
	Inventory.add("I1", 1)
	var gained := _count("I1") - c0
	var sigs := _sig_added.size() - s0
	_note("A4", DETECTOR, gained == 2 and sigs == 2,
		"planted double add -> inv+%d item_added x%d (detector PASSES by catching 2 / 2)" % [gained, sigs])


# ===========================================================================
# AC B — commit boundary
# ===========================================================================

## B1 (REAL/BLOCKED) — cancel before commit grants nothing. Uses the confirmed
## WH-HARVEST-001 signatures: begin(target_key, material_kind) / cancel(token).
func _t_b1_cancel_before_commit(state) -> void:
	if state == null or not state.has_method("begin"):
		_note("B1", BLOCKED, false, "HarvestActionState not wired (feat/wh-harvest-001-kana)")
		return
	var c0 := _count("I1")
	var began: Dictionary = state.begin("rock_a", "rock")
	var token: int = began.get("token", -1)
	state.cancel(token)
	_note("B1", REAL, _count("I1") - c0 == 0,
		"begin -> cancel (no commit) -> inv+%d (expected 0)" % (_count("I1") - c0))


## B2 (REAL) — commit stands exactly once when the node dies right after.
func _t_b2_commit_then_destroy() -> void:
	var g := _make_gatherable("I1", 1)
	var c0 := _count("I1")
	var s0 := _sig_gathered.size()
	g.gather()
	g.free()
	_note("B2", REAL, _count("I1") - c0 == 1 and _sig_gathered.size() - s0 == 1,
		"commit then destroy -> inv+%d signal x%d (expected 1 / 1)"
		% [_count("I1") - c0, _sig_gathered.size() - s0])


# ===========================================================================
# AC D — rock footprint
# ===========================================================================

## D1 (REAL) — a blocking rock owns a StaticBody before gather; a non-unique blocker
## must take it away with the node. Awaited so the result reaches the report.
func _t_d1_block_then_pass() -> void:
	var g := _make_gatherable("I2", 1, false, true, 20.0)
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
	await _t_d1_block_then_pass()


func _print_report() -> void:
	var real_fail := 0
	var detector_fail := 0
	var blocked := 0
	print("=== WH-QA-001 harvest acceptance — SETUP UNVERIFIED, not a game PASS ===")
	for r in _results:
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
	print("REAL failures: %d   DETECTOR failures: %d   BLOCKED: %d"
		% [real_fail, detector_fail, blocked])
	if detector_fail > 0:
		print("!! DETECTOR failed: the harness cannot see a planted violation.")
		print("   Every REAL row above is meaningless until that is fixed.")
	print("This run is a contract probe only. It is not an AC PASS and not a real-game,")
	print("real-device result. Re-run on the frozen build before reporting verdicts.")
