extends Node
## (v1.1.0 GP-5 §3) gp_gate_puzzle_harness — 게이트 미니 퍼즐 4종의 계약 검증.
##
## 각 퍼즐 타입(fuse/gear/rune/chime)에 대해:
##   1. GatePuzzle.open(root, type, on_success, on_skip) 로 모달을 띄운다(실 팩토리 경로).
##   2. solve_for_test() → on_success가 정확히 한 번, on_skip 0회 — 그리고 모달이 스스로 닫힌다.
##   3. 새 인스턴스에서 skip_for_test() → on_skip이 한 번(스킵 = 그냥 장착 = 동일 개방).
##   4. on_skip을 주지 않은 인스턴스에서 skip → on_success로 폴백(스킵도 개방).
##   5. 접근성: 스킵 버튼이 항상 존재하고, 색맹 대응(색+숫자/문양 병기)이 실 UI에 있다.
##   6. 모달 push/pop: 열릴 때 control_lock, 닫힐 때 해제 — 게이트가 안 막힌다.
##
## 실 게이트 컨트롤러 통합은 별도 flow 하네스(l2~l5)가 커버; 여기서는 퍼즐 계약 자체를 전수.
## [PASS]/[FAIL] 출력, exit code = 실패 수.

const TYPES := ["fuse", "gear", "rune", "chime"]

var _tree: SceneTree
var _fail := 0
var _succ := 0
var _skip := 0


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


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _run() -> void:
	print("=== v1.1.0 GP-5 GATE PUZZLE HARNESS ===")
	# A minimal scene root the modals can parent under.
	var root := Node.new()
	root.name = "PuzzleHarnessRoot"
	_tree.root.add_child(root)

	for t in TYPES:
		await _test_solve(root, t)
		await _test_skip(root, t)
		await _test_skip_fallback(root, t)
		await _test_accessibility(root, t)

	root.queue_free()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)


# ---- solve → success ------------------------------------------------------

func _test_solve(root: Node, t: String) -> void:
	print("--- %s: solve → success ---" % t)
	_succ = 0
	_skip = 0
	var lock_before := GameState.control_locked() if GameState.has_method("control_locked") else false
	var p := GatePuzzle.open(root, t, _on_success, _on_skip)
	_check("%s: modal opened" % t, p != null)
	if p == null:
		return
	await _frames(2)
	p.solve_for_test()
	await _frames(2)
	_check("%s: success fired exactly once on solve" % t, _succ == 1, "succ=%d" % _succ)
	_check("%s: skip did NOT fire on solve" % t, _skip == 0, "skip=%d" % _skip)
	_check("%s: modal freed after solve" % t, not is_instance_valid(p))
	_check("%s: control_lock released after solve" % t,
		(GameState.control_locked() if GameState.has_method("control_locked") else false) == lock_before)


# ---- skip → skip callback (그냥 장착) --------------------------------------

func _test_skip(root: Node, t: String) -> void:
	print("--- %s: skip → skip callback ---" % t)
	_succ = 0
	_skip = 0
	var p := GatePuzzle.open(root, t, _on_success, _on_skip)
	if p == null:
		_check("%s: modal opened (skip test)" % t, false)
		return
	await _frames(2)
	p.skip_for_test()
	await _frames(2)
	_check("%s: skip fired once on skip" % t, _skip == 1, "skip=%d" % _skip)
	_check("%s: success did NOT fire when skip provided" % t, _succ == 0, "succ=%d" % _succ)
	_check("%s: modal freed after skip" % t, not is_instance_valid(p))


# ---- skip with no skip callback → falls back to success --------------------

func _test_skip_fallback(root: Node, t: String) -> void:
	print("--- %s: skip fallback → success (스킵=개방) ---" % t)
	_succ = 0
	_skip = 0
	var p := GatePuzzle.open(root, t, _on_success)   # no on_skip
	if p == null:
		_check("%s: modal opened (fallback test)" % t, false)
		return
	await _frames(2)
	p.skip_for_test()
	await _frames(2)
	_check("%s: skip w/o callback falls back to success (개방 보장)" % t, _succ == 1, "succ=%d" % _succ)


# ---- accessibility: skip button + colorblind labels always present ---------

func _test_accessibility(root: Node, t: String) -> void:
	var p := GatePuzzle.open(root, t, _on_success, _on_skip)
	if p == null:
		_check("%s: modal opened (a11y test)" % t, false)
		return
	await _frames(2)
	var buttons := _all_buttons(p)
	var has_skip := false
	for b in buttons:
		if "건너뛰기" in b.text or "그냥" in b.text or "침묵" in b.text or "억지로" in b.text:
			has_skip = true
	_check("%s: skip button always exposed (접근성)" % t, has_skip)
	# Colorblind: at least one numeric/glyph label present in an interactive element.
	var has_symbol := false
	for b in buttons:
		if b.text.strip_edges() != "" and (b.text.contains("1") or b.text.contains("2") or b.text.contains("소") or b.text.contains("중") or b.text.contains("대")):
			has_symbol = true
	_check("%s: color+symbol 병기 (색맹 대응)" % t, has_symbol)
	p.skip_for_test()
	await _frames(2)


func _all_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_buttons(c))
	return out


func _on_success() -> void:
	_succ += 1

func _on_skip() -> void:
	_skip += 1
