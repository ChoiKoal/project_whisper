extends Node
## v1.1.0 GP-2/GP-3 RESULT-FIRST HINT harness — §2 조합 힌트 리워크 검증.
##
## The redesign: instead of revealing a random ingredient half ("? + [재료] = ?"), the hint gauge
## now advances ONE undiscovered recipe through 3 RESULT-FIRST stages:
##   stage 1 → result silhouette + poetic name (Codex.hint_poetic_name / hint_output_for_recipe)
##   stage 2 → + 재료 카테고리 두 개 (Codex.hint_categories)
##   stage 3 → + 재료 한 개 실제 공개 (Codex.hint_for_recipe)
## Each HINT_THRESHOLD (3) DISTINCT failed pairs advances the focus recipe by one stage.
##
## This harness drives the REAL Codex API (register_failed_fusion / Fusion.fuse on non-recipe
## pairs) — no private pokes — and asserts:
##   1. 3 distinct fails → some recipe at stage 1 (result revealed, ingredient still hidden).
##   2. 3 more distinct fails → that recipe advances to stage 2 (categories available).
##   3. 3 more → stage 3 (one ingredient revealed).
##   4. Stage never exceeds HINT_STAGE_MAX.
##   5. Poetic name / output resolve for the focused recipe (silhouette data present).
##   6. Save → reset → load roundtrip preserves the staged hint exactly.
##   7. Legacy-save migration: a bare-String hint loads as stage 3.
## Exit code = failure count.

var _tree: SceneTree
var _fail := 0

func _ready() -> void:
	_tree = get_tree()
	call_deferred("_run")

func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1

## Feed `n` DISTINCT never-before-attempted non-recipe pairs to bump the gauge without repeats.
## Draws partners from the FULL item pool (I/D/J/K/P/S ids) so we can always find enough dead-end
## pairs (skipping any pair that actually matches a recipe, and any pair already attempted).
func _fail_n_distinct(n: int, used: Dictionary) -> void:
	var pool: Array = ItemDB.all_ids()
	var made := 0
	for i in range(pool.size()):
		if made >= n:
			break
		var a := String(pool[i])
		for j in range(i + 1, pool.size()):
			if made >= n:
				break
			var b := String(pool[j])
			var ca := ItemDB.resolve_id(a)
			var cb := ItemDB.resolve_id(b)
			if ca == cb:
				continue
			var pair := [ca, cb]
			pair.sort()
			var key := "%s|%s" % [pair[0], pair[1]]
			if used.has(key):
				continue
			if not RecipeDB.find_recipe([ca, cb]).is_empty():
				continue
			used[key] = true
			Codex.register_failed_fusion(ca, cb)
			made += 1

func _max_stage_recipe() -> String:
	var best := ""
	var best_stage := 0
	for rid: String in Codex.revealed_hints().keys():
		var s := Codex.hint_stage(rid)
		if s > best_stage:
			best_stage = s
			best = rid
	return best

func _run() -> void:
	print("=== v1.1.0 GP-2/3 RESULT-FIRST HINT HARNESS ===")
	Codex.reset()
	var used := {}

	# 1. First threshold → a recipe reaches stage 1 (result-first reveal).
	_fail_n_distinct(Codex.HINT_THRESHOLD, used)
	var focus := _max_stage_recipe()
	_check("after %d fails → a recipe at stage 1" % Codex.HINT_THRESHOLD,
		focus != "" and Codex.hint_stage(focus) == 1, "focus=%s stage=%d" % [focus, Codex.hint_stage(focus)])
	# At stage 1 the ingredient is still hidden.
	_check("stage 1 hides the ingredient", Codex.hint_for_recipe(focus) == "")
	# Result silhouette data present.
	_check("stage 1 exposes result output id", Codex.hint_output_for_recipe(focus) != "",
		"out=%s" % Codex.hint_output_for_recipe(focus))
	_check("stage 1 exposes a poetic name", Codex.hint_poetic_name(focus) != "",
		"name=%s" % Codex.hint_poetic_name(focus))

	# 2. Second threshold → same focus recipe advances to stage 2.
	_fail_n_distinct(Codex.HINT_THRESHOLD, used)
	_check("after %d more fails → focus at stage 2" % Codex.HINT_THRESHOLD,
		Codex.hint_stage(focus) == 2, "stage=%d" % Codex.hint_stage(focus))
	var cats: Array = Codex.hint_categories(focus)
	_check("stage 2 exposes two ingredient categories", cats.size() == 2,
		"cats=%s" % str(cats))
	_check("stage 2 still hides the exact ingredient", Codex.hint_for_recipe(focus) == "")

	# 3. Third threshold → stage 3, one ingredient revealed.
	_fail_n_distinct(Codex.HINT_THRESHOLD, used)
	_check("after %d more fails → focus at stage 3" % Codex.HINT_THRESHOLD,
		Codex.hint_stage(focus) == 3, "stage=%d" % Codex.hint_stage(focus))
	_check("stage 3 reveals one ingredient", Codex.hint_for_recipe(focus) != "",
		"ing=%s" % Codex.hint_for_recipe(focus))

	# 4. Stage never exceeds max even with more fails.
	_fail_n_distinct(Codex.HINT_THRESHOLD, used)
	_check("stage caps at HINT_STAGE_MAX", Codex.hint_stage(focus) <= Codex.HINT_STAGE_MAX)

	# 5. Save → reset → load roundtrip preserves the staged hint.
	var snap := Codex.to_dict()
	var want_stage := Codex.hint_stage(focus)
	var want_ing := Codex.hint_for_recipe(focus)
	Codex.reset()
	_check("reset clears hints", Codex.hint_stage(focus) == 0)
	Codex.from_dict(snap)
	_check("load restores hint stage", Codex.hint_stage(focus) == want_stage,
		"got=%d want=%d" % [Codex.hint_stage(focus), want_stage])
	_check("load restores revealed ingredient", Codex.hint_for_recipe(focus) == want_ing)

	# 6. Legacy-save migration: a bare-String hint value loads as stage 3.
	Codex.reset()
	var legacy := {"items": [], "recipes": [], "hint_gauge": 0, "hints": {"R05": "I1"}, "attempted_pairs": []}
	Codex.from_dict(legacy)
	_check("legacy String hint migrates to stage 3", Codex.hint_stage("R05") == 3,
		"stage=%d" % Codex.hint_stage("R05"))
	_check("legacy hint keeps its ingredient", Codex.hint_for_recipe("R05") == "I1")

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)
