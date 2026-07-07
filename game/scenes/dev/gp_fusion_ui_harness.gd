extends Node
## v1.1.0 GP-3 조합 UI 리워크 harness — §4 검증 (2슬롯+결과 미리보기/재료 필터/최근 조합/도감 연결).
##
## Drives a LIVE FusionUI node through its REAL public/UI paths (open / _on_strip_pressed /
## _on_filter_chip / _on_recent_pressed / _on_fuse_pressed) — never pokes private preview state and
## never calls Fusion.fuse() directly except to seed a "discovered" recipe for the known-preview case.
## The whole point of §4 is "로직 무변경, 미리보기는 소비 없는 Fusion.peek": so the LOAD-BEARING
## assertions here are (a) the preview reflects the four peek states, and (b) peek/preview MUTATE
## NOTHING — inventory, discovered count, and the GP-2 hint stage are all unchanged after previewing.
##
## Recipe fixtures (from data/recipes.json):
##   R01: I1(흙) + I7(물) → I3           — a real, cost-free recipe (unknown until discovered).
##   F01: I2 + I4         → D219 (실패)   — a 실패 조합 mapping.
##   (I1 + I9-essence etc. — no pair; used for the "none" state via two inert-but-unmatched ids.)
##
## Assertions print [PASS]/[FAIL]; exit code = failure count.

const FUSION_UI := "res://scripts/ui/fusion_ui.gd"

# R01
const REC_A := "I1"
const REC_B := "I7"
const REC_OUT := "I3"
# F01 (fail mapping)
const FAIL_A := "I2"
const FAIL_B := "I4"
const FAIL_OUT := "D219"

var _tree: SceneTree
var _fail := 0
var _ui: FusionUI

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

## Fresh session + a live FusionUI mounted under the tree root.
func _fresh_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
		await _frames(1)
	SaveManager.new_game()
	var script: Script = load(FUSION_UI)
	_ui = script.new() as FusionUI
	_tree.root.add_child(_ui)
	await _frames(2)

func _run() -> void:
	print("=== v1.1.0 GP-3 FUSION UI HARNESS (§4) ===")
	await _test_peek_side_effect_free()
	await _test_preview_states()
	await _test_filter()
	await _test_recent()
	await _test_codex_link()
	await _test_hint_no_regression()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)

# ---- A. peek is pure (the whole §4.4 contract) ----------------------------

func _test_peek_side_effect_free() -> void:
	print("--- A. Fusion.peek 소비 없음 ---")
	await _fresh_ui()
	Inventory.add(REC_A, 1)
	Inventory.add(REC_B, 1)
	var inv_a := Inventory.count(REC_A)
	var inv_b := Inventory.count(REC_B)
	var disc := Codex.discovered_recipe_count()
	var pk := Fusion.peek(REC_A, REC_B)
	_check("peek returns a valid state", pk.get("state", "") != "",
		"state=%s" % str(pk.get("state", "")))
	_check("peek consumes NO inventory", Inventory.count(REC_A) == inv_a and Inventory.count(REC_B) == inv_b)
	_check("peek discovers NO recipe", Codex.discovered_recipe_count() == disc)
	# order independence
	var pk2 := Fusion.peek(REC_B, REC_A)
	_check("peek is order-independent", pk2.get("recipe_id", "") == pk.get("recipe_id", ""))
	# empty slot → empty
	_check("peek('' , x) → empty", String(Fusion.peek("", REC_B).get("state", "")) == "empty")

# ---- B. preview reflects the four peek states through the REAL slot path ---

func _test_preview_states() -> void:
	print("--- B. 실시간 결과 미리보기 4상태 ---")
	await _fresh_ui()
	_ui.open()
	await _frames(2)

	# unknown: undiscovered valid recipe → silhouette (result icon present, darkened modulate).
	Inventory.add(REC_A, 1)
	Inventory.add(REC_B, 1)
	_ui._rebuild_strip()
	_ui._on_strip_pressed(REC_A)
	_ui._on_strip_pressed(REC_B)
	await _frames(1)
	var pk := Fusion.peek(REC_A, REC_B)
	_check("B1 undiscovered recipe → peek state 'unknown'", String(pk.get("state", "")) == "unknown",
		"state=%s" % str(pk.get("state", "")))
	var icon: TextureRect = _ui.get("_result_icon")
	_check("B1 unknown → result slot shows a silhouette (icon set + darkened)",
		icon != null and icon.texture != null and icon.modulate != Color.WHITE)

	# known: discover R01 for real, then re-preview → 확정 output (full-bright icon).
	# (Fusion.fuse here is the seed, not the thing under test.)
	var res := Fusion.fuse(REC_A, REC_B)
	_check("seed: R01 discovered via fuse", bool(res.get("matched", false)) and Codex.is_recipe_discovered("R01"))
	Inventory.add(REC_A, 1)
	Inventory.add(REC_B, 1)
	_ui._clear_inputs()
	_ui._on_strip_pressed(REC_A)
	_ui._on_strip_pressed(REC_B)
	await _frames(1)
	_check("B2 discovered recipe → peek state 'known'",
		String(Fusion.peek(REC_A, REC_B).get("state", "")) == "known")
	_check("B2 known → result slot shows confirmed output (full-bright)",
		icon.texture != null and icon.modulate == Color.WHITE)
	var nm: Label = _ui.get("_result_name")
	_check("B2 known → result name is the real item name",
		nm != null and nm.text == ItemDB.item_name(REC_OUT), "name=%s" % (nm.text if nm else "<nil>"))

	# fail: a mapped 실패 조합 → gray junk preview.
	Inventory.add(FAIL_A, 1)
	Inventory.add(FAIL_B, 1)
	_ui._clear_inputs()
	_ui._on_strip_pressed(FAIL_A)
	_ui._on_strip_pressed(FAIL_B)
	await _frames(1)
	_check("B3 실패 매핑 → peek state 'fail'",
		String(Fusion.peek(FAIL_A, FAIL_B).get("state", "")) == "fail")
	_check("B3 fail → result slot is a gray preview (icon set, grayed)",
		icon.texture != null and icon.modulate != Color.WHITE)

	# none: clearing one slot resets the preview to "???".
	_ui._on_slot_pressed(0)
	await _frames(1)
	_check("B4 emptying a slot resets preview to ???", nm.text == "???", "name=%s" % nm.text)

# ---- C. category filter ---------------------------------------------------

func _test_filter() -> void:
	print("--- C. 재료 후보 필터 ---")
	await _fresh_ui()
	# Start from a known-empty inventory, then add exactly two items whose names live in different
	# FILTER_CATEGORIES buckets (I7 물 / I1 흙) so the filter counts are deterministic regardless of
	# whatever new_game seeds elsewhere.
	Inventory.clear()
	Inventory.add("I1", 1)   # 흙
	Inventory.add("I7", 1)   # 물
	_ui.open()
	await _frames(2)

	# The load-bearing bit is the predicate _matches_filter, which reads the CURRENTLY active filter.
	# (Strip child_count is unreliable within a frame: _rebuild_strip queue_free()s the old rows,
	#  which are freed deferred, so an immediate get_child_count() double-counts. We settle a frame
	#  and assert the predicate + the strip's post-settle membership instead of raw counts.)
	_ui.set_strip_filter("전체")
	await _frames(2)
	_check("전체 filter: predicate accepts both items",
		_ui._matches_filter("I1") and _ui._matches_filter("I7"))
	_check("전체 filter: strip lists both in-stock items", _strip_ids_count() == 2,
		"strip=%s" % str(_strip_ids()))

	_ui.set_strip_filter("물")
	await _frames(2)
	var water_name := ItemDB.item_name("I7")
	var earth_name := ItemDB.item_name("I1")
	_check("물 filter: accepts the 물-named item (%s)" % water_name, _ui._matches_filter("I7"))
	_check("물 filter: rejects the 흙-named item (%s)" % earth_name, not _ui._matches_filter("I1"))
	_check("물 filter: strip narrows to the 물 item only", _strip_ids_count() == 1,
		"strip=%s" % str(_strip_ids()))

	# Non-destructive: back to 전체 restores both (inventory untouched by filtering).
	_ui.set_strip_filter("전체")
	await _frames(2)
	_check("전체 filter restores both items (filter is non-destructive)", _strip_ids_count() == 2,
		"strip=%s" % str(_strip_ids()))

## Live strip rows that are NOT pending deletion (Button rows added by _add_strip_item).
func _strip_ids() -> Array:
	var out: Array = []
	var strip: Control = _ui.get("_strip")
	if strip == null:
		return out
	for c in strip.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c)
	return out

func _strip_ids_count() -> int:
	return _strip_ids().size()

# ---- D. recent-fusion queue + one-tap re-craft ----------------------------

func _test_recent() -> void:
	print("--- D. 최근 조합 원탭 재조합 ---")
	await _fresh_ui()
	_ui.open()
	await _frames(2)
	var recent0: Array = _ui.get("_recent")
	_check("recent starts empty", recent0.is_empty())

	# A real UI-path fuse should record the pair.
	Inventory.add(REC_A, 2)
	Inventory.add(REC_B, 2)
	_ui._rebuild_strip()
	_ui._on_strip_pressed(REC_A)
	_ui._on_strip_pressed(REC_B)
	_ui._on_fuse_pressed()
	if _ui.has_method("_skip_sequence"):
		_ui._skip_sequence()
	await _frames(2)
	var recent1: Array = _ui.get("_recent")
	_check("successful fuse records a 최근 조합 pair", recent1.size() == 1,
		"size=%d" % recent1.size())

	# One-tap re-craft: press the recorded pair → both slots auto-fill (stock present).
	_ui._clear_inputs()
	_ui._on_recent_pressed(REC_A, REC_B)
	await _frames(1)
	var inputs: Array = _ui.get("_inputs")
	_check("one-tap re-craft fills both slots",
		inputs.size() == 2 and inputs[0] != "" and inputs[1] != "",
		"inputs=%s" % str(inputs))
	# dedup: fusing the same pair again keeps the queue at one entry.
	Inventory.add(REC_A, 1)
	Inventory.add(REC_B, 1)
	_ui._on_fuse_pressed()
	if _ui.has_method("_skip_sequence"):
		_ui._skip_sequence()
	await _frames(2)
	_check("re-fusing the same pair does NOT duplicate the queue",
		(_ui.get("_recent") as Array).size() == 1)

# ---- E. 도감 연결 count ----------------------------------------------------

func _test_codex_link() -> void:
	print("--- E. 도감 연결 카운트 ---")
	await _fresh_ui()
	_ui.open()
	await _frames(2)
	var lbl: Label = _ui.get("_codex_link_lbl")
	_check("codex link label present", lbl != null)
	var before := lbl.text if lbl else ""
	_check("codex link shows M = total recipes", before.contains(str(RecipeDB.all_ids().size())),
		"text='%s' total=%d" % [before, RecipeDB.all_ids().size()])
	# Discover a recipe → the live label reflects the new count.
	Fusion.fuse(REC_A, REC_B)
	await _frames(2)
	_check("codex link updates on discovery",
		lbl != null and lbl.text.contains("%d /" % Codex.discovered_recipe_count()),
		"text='%s' discovered=%d" % [lbl.text if lbl else "", Codex.discovered_recipe_count()])

# ---- F. GP-2 hint no-regression (previewing must not advance the gauge) ----

func _test_hint_no_regression() -> void:
	print("--- F. GP-2 힌트 무회귀 (미리보기가 힌트 게이지를 건드리지 않음) ---")
	await _fresh_ui()
	_ui.open()
	await _frames(2)
	# Advance the hint gauge with 3 distinct real fails so some recipe reaches stage >= 1.
	_register_distinct_fails(3)
	await _frames(1)
	var staged := _first_staged_recipe()
	_check("F setup: a recipe reached hint stage >= 1", staged != "",
		"focus=%s" % staged)
	if staged == "":
		return
	var stage_before := Codex.hint_stage(staged)
	# Now PREVIEW that very recipe's inputs many times through the real slot path.
	var inputs: Array = RecipeDB.get_recipe(staged).get("inputs", [])
	if inputs.size() == 2:
		Inventory.add(String(inputs[0]), 1)
		Inventory.add(String(inputs[1]), 1)
		for i in range(5):
			_ui._clear_inputs()
			_ui._on_strip_pressed(String(inputs[0]))
			_ui._on_strip_pressed(String(inputs[1]))
			await _frames(1)
	_check("previewing a staged recipe does NOT change its hint stage",
		Codex.hint_stage(staged) == stage_before,
		"before=%d after=%d" % [stage_before, Codex.hint_stage(staged)])
	# And unknown-preview surfaces the staged poetic name (GP-2 ↔ GP-3 integration).
	if inputs.size() == 2 and stage_before >= 1:
		var nm: Label = _ui.get("_result_name")
		_check("unknown preview uses the staged poetic name",
			nm != null and nm.text == Codex.hint_poetic_name(staged),
			"name='%s'" % (nm.text if nm else ""))

## Feed n DISTINCT non-recipe pairs through the real fail path (Fusion.fuse on dead-ends).
func _register_distinct_fails(n: int) -> void:
	var pool: Array = ItemDB.all_ids()
	var made := 0
	var used := {}
	for i in range(pool.size()):
		for j in range(i + 1, pool.size()):
			if made >= n:
				return
			var a := String(pool[i])
			var b := String(pool[j])
			if not RecipeDB.find_recipe([a, b]).is_empty():
				continue
			var key := a + "|" + b
			if used.has(key):
				continue
			used[key] = true
			Inventory.add(a, 1)
			Inventory.add(b, 1)
			Fusion.fuse(a, b)
			made += 1

## The first undiscovered recipe currently at hint stage >= 1, or "".
func _first_staged_recipe() -> String:
	for rid in RecipeDB.all_ids():
		var r := String(rid)
		if not Codex.is_recipe_discovered(r) and Codex.hint_stage(r) >= 1:
			return r
	return ""
