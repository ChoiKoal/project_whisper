extends Node
## WH-QA-001 — harvest acceptance harness (CANDIDATE, SETUP UNVERIFIED)
##
## Independent QA fixture for AC A–G of WH-TEAM-001. This file has NEVER been run
## against the engine by QA: the source pack is a partial read-only snapshot, not a
## build. Treat every result below as UNVERIFIED until Ruby supplies a frozen build
## (hash + run command + isolated save) and this harness is re-run there.
##
## Scope rule from the handoff: QA writes TEST code only. This harness must not be
## merged into gameplay paths and must not modify Gatherable / InteractionController
## / touch_controller. It only *observes* them.
##
## Two kinds of case live here and they must never be conflated in a report:
##   REAL   — exercises shipping code paths; a failure is a candidate game defect.
##   MUTANT — deliberately wrong fixture used to prove the harness can detect a
##            failure at all. A MUTANT failing is GOOD and is not a game bug.

const REAL := "REAL"
const MUTANT := "MUTANT"

var _results: Array = []
var _grant_log: Array = []      ## every Inventory.add observed, in order
var _signal_log: Array = []     ## every GameState.item_gathered observed

# --------------------------------------------------------------------------
# Observation plumbing. We do not patch Inventory; we mirror it by listening to
# the public signal and by reading counts before/after. If the real build exposes
# no such signal for adds, this section is the first thing to re-fix on the build.
# --------------------------------------------------------------------------

func _ready() -> void:
	if GameState.has_signal("item_gathered"):
		GameState.item_gathered.connect(_on_item_gathered)
	else:
		_note("SETUP", MUTANT, false, "GameState.item_gathered missing — harness cannot observe grants")
	_run_all()
	_print_report()


func _on_item_gathered(item_id: String) -> void:
	_signal_log.append(item_id)


func _note(id: String, kind: String, passed: bool, detail: String) -> void:
	_results.append({"id": id, "kind": kind, "pass": passed, "detail": detail})


func _count(item_id: String) -> int:
	return Inventory.count(item_id) if Inventory.has_method("count") else -1


## Build a throwaway Gatherable. Non-unique by default: that is the class of object
## AC A is about, because unique objects are already guarded by `_spent`.
func _make_gatherable(item_id: String, amount: int = 1, unique: bool = false) -> Gatherable:
	var g := Gatherable.new()
	g.item_id = item_id
	g.amount = amount
	g.unique = unique
	add_child(g)
	return g


# --------------------------------------------------------------------------
# AC A — one action grants exactly once
# --------------------------------------------------------------------------

## A1 (REAL) — the headline case. `Gatherable.gather()` guards only on can_gather(),
## and for a NON-UNIQUE node can_gather() is `item_id != ""`, which stays true until
## the node is actually freed. queue_free() is deferred to end-of-frame, so a second
## call inside the SAME frame still passes the guard.
## Reproduces the handoff's named vector: "queue_free 전 재호출".
func _t_a1_same_frame_double_gather() -> void:
	var g := _make_gatherable("I1", 1)
	var before := _count("I1")
	var sig_before := _signal_log.size()
	g.gather()
	g.gather()   # same frame, node not freed yet
	var gained := _count("I1") - before
	var sigs := _signal_log.size() - sig_before
	# EXPECTED: gained == 1 and sigs == 1
	_note("A1", REAL, gained == 1 and sigs == 1,
		"same-frame double gather → gained=%d signals=%d (expected 1/1)" % [gained, sigs])


## A2 (REAL) — same vector through the two public entry points rather than the node.
## InteractionController has two independent gather call sites (the facing/E path and
## interact_with_object(), used by touch). Neither consults is_queued_for_deletion().
## A keyboard interact and a touch-arrival interact landing on the same frame is the
## realistic in-game shape of A1.
func _t_a2_two_entry_points_same_frame(ic: Node) -> void:
	if ic == null or not ic.has_method("interact_with_object"):
		_note("A2", REAL, false, "BLOCKED: InteractionController not wired in harness")
		return
	var g := _make_gatherable("I1", 1)
	var before := _count("I1")
	ic.interact_with_object(g)
	ic.interact_with_object(g)
	var gained := _count("I1") - before
	_note("A2", REAL, gained == 1, "two entry-point calls → gained=%d (expected 1)" % gained)


## A3 (REAL) — unique objects must grant once and stay in the world.
func _t_a3_unique_single_grant() -> void:
	var g := _make_gatherable("I9", 1, true)
	var before := _count("I9")
	g.gather()
	g.gather()
	var gained := _count("I9") - before
	var alive := is_instance_valid(g) and not g.is_queued_for_deletion()
	_note("A3", REAL, gained == 1 and alive,
		"unique double gather → gained=%d alive=%s (expected 1/true)" % [gained, alive])


## A4 (MUTANT) — prove the harness can see a double grant at all. If A4 "passes"
## (i.e. reports 1), the detector is broken and A1/A2 results are meaningless.
func _t_a4_mutant_detector_check() -> void:
	var g := _make_gatherable("I1", 1)
	var before := _count("I1")
	Inventory.add("I1", 1)
	Inventory.add("I1", 1)   # deliberately wrong: two grants
	var gained := _count("I1") - before
	_note("A4", MUTANT, gained == 2,
		"detector sees intentional double add → gained=%d (expect 2; MUTANT pass = harness healthy)" % gained)
	g.queue_free()


# --------------------------------------------------------------------------
# AC B — cancel before commit grants nothing; interruption after commit neither
#        loses nor duplicates
# --------------------------------------------------------------------------

## B1 (REAL) — cancel before commit. Needs Kana's action-state module; until that
## API exists this is BLOCKED rather than failing, so it can't be misread as a defect.
func _t_b1_cancel_before_commit(action_state) -> void:
	if action_state == null:
		_note("B1", REAL, false, "BLOCKED: WH-HARVEST-001 action module not delivered yet")
		return
	var before := _count("I1")
	action_state.begin("I1")
	action_state.cancel()
	_note("B1", REAL, _count("I1") - before == 0,
		"cancel before commit → delta=%d (expected 0)" % (_count("I1") - before))


## B2 (REAL) — commit, then the node dies mid-presentation. Grant must stand exactly
## once; a failed flourish must NOT roll back or re-grant.
func _t_b2_commit_then_target_destroyed() -> void:
	var g := _make_gatherable("I1", 1)
	var before := _count("I1")
	g.gather()
	g.free()                  # simulate scene teardown right after commit
	var gained := _count("I1") - before
	_note("B2", REAL, gained == 1, "commit then destroy → gained=%d (expected 1)" % gained)


# --------------------------------------------------------------------------
# AC D — rock footprint: blocks before gather, passable after, restored on respawn
# --------------------------------------------------------------------------

## D1 (REAL) — a blocking rock creates a StaticBody; gathering a non-unique blocker
## must remove it with the node. Verifies the footprint is gone, not merely hidden.
func _t_d1_block_then_pass() -> void:
	var g := _make_gatherable("I2", 1)
	g.blocks_movement = true
	g.block_radius = 20.0
	g._ready()                       # force footprint creation in the fixture
	var had_body := _has_static_body(g)
	g.gather()
	await get_tree().process_frame   # let queue_free actually land
	var gone := not is_instance_valid(g)
	_note("D1", REAL, had_body and gone,
		"rock footprint before=%s node_freed_after=%s (expected true/true)" % [had_body, gone])


func _has_static_body(n: Node) -> bool:
	for c in n.get_children():
		if c is StaticBody2D:
			return true
	return false


# --------------------------------------------------------------------------
# Runner
# --------------------------------------------------------------------------

func _run_all() -> void:
	_t_a1_same_frame_double_gather()
	_t_a2_two_entry_points_same_frame(null)   # wire the real controller on the build
	_t_a3_unique_single_grant()
	_t_a4_mutant_detector_check()
	_t_b1_cancel_before_commit(null)          # wire Kana's module when delivered
	_t_b2_commit_then_target_destroyed()
	_t_d1_block_then_pass()


func _print_report() -> void:
	var real_fail := 0
	var blocked := 0
	print("=== WH-QA-001 harvest acceptance (UNVERIFIED SETUP) ===")
	for r in _results:
		var tag := "PASS" if r["pass"] else "FAIL"
		if r["detail"].begins_with("BLOCKED"):
			tag = "BLOCKED"
			blocked += 1
		elif not r["pass"] and r["kind"] == REAL:
			real_fail += 1
		print("  [%s] %s %s — %s" % [r["kind"], r["id"], tag, r["detail"]])
	print("REAL failures: %d   BLOCKED: %d" % [real_fail, blocked])
	print("NOTE: MUTANT rows failing is expected-healthy. This run does not constitute")
	print("      a real-game PASS; it must be re-run on Ruby's frozen build.")
