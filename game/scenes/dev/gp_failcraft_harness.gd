extends Node
## v1.1.0 GP-2 §2.3 실패 조합 harness — 실패작 시스템 검증.
##
## A "그럴듯한 오답" pair authored into recipes.json `fail_recipes` now yields a 실패작 아이템 instead
## of a bare no-op: the two inputs ARE consumed, the junk output is granted + recorded in the 도감
## ("실패도 수집"). Non-mapped no-match pairs still just tick the hint gauge; real recipes are never
## shadowed by a fail mapping.
##
## Drives the REAL Fusion.fuse() transaction with real inventory. Asserts:
##   1. A mapped fail pair returns fail_output (+ swamp-tone flavor), NOT a matched recipe.
##   2. The 실패작 lands in the inventory and is discovered in the 도감.
##   3. The two inputs were consumed (a real transaction, no free farming).
##   4. A real recipe pair is unaffected (matched, no fail_output).
##   5. A non-mapped wrong pair yields neither a match nor a fail_output (gauge-only).
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

func _fresh() -> void:
	Inventory.clear()
	Codex.reset()

func _run() -> void:
	print("=== v1.1.0 GP-2 §2.3 실패 조합 HARNESS ===")

	# --- 1-3. Mapped fail pair: F01 = I2 풀 + I4 나무 → D219 미지근한 진흙 ---
	_fresh()
	Inventory.add("I2", 1)
	Inventory.add("I4", 1)
	var res := Fusion.fuse("I2", "I4")
	_check("mapped fail pair does NOT match a real recipe", not bool(res["matched"]))
	var fout := String(res.get("fail_output", ""))
	_check("mapped fail pair returns a fail_output", fout != "", "fail_output=%s" % fout)
	_check("fail_output carries a swamp-tone flavor", String(res.get("fail_flavor", "")) != "",
		"flavor='%s'" % String(res.get("fail_flavor", "")))
	_check("실패작 granted to inventory", Inventory.count(fout) == 1,
		"count=%d" % Inventory.count(fout))
	_check("실패작 recorded in 도감", Codex.is_item_discovered(fout))
	_check("both inputs consumed (I2)", Inventory.count("I2") == 0)
	_check("both inputs consumed (I4)", Inventory.count("I4") == 0)

	# --- 4. Real recipe pair unaffected: R01 = I1 흙 + I7 물 → I3 ---
	_fresh()
	Inventory.add("I1", 1)
	Inventory.add("I7", 1)
	var res2 := Fusion.fuse("I1", "I7")
	_check("real recipe still matches", bool(res2["matched"]), "rid=%s" % String(res2.get("recipe_id","")))
	_check("real recipe has NO fail_output", String(res2.get("fail_output", "")) == "")

	# --- 5. Non-mapped wrong pair: gauge-only, no fail item ---
	_fresh()
	# I3 진흙 + I6 바위 — confirm it is neither a real recipe nor a fail mapping first.
	var is_recipe := not RecipeDB.find_recipe(["I3", "I6"]).is_empty()
	var is_fail := not RecipeDB.find_fail_recipe(["I3", "I6"]).is_empty()
	_check("chosen non-mapped pair is neither recipe nor fail", not is_recipe and not is_fail)
	Inventory.add("I3", 1)
	Inventory.add("I6", 1)
	var res3 := Fusion.fuse("I3", "I6")
	_check("non-mapped pair does not match", not bool(res3["matched"]))
	_check("non-mapped pair has no fail_output", String(res3.get("fail_output", "")) == "")
	_check("non-mapped pair leaves inputs intact", Inventory.count("I3") == 1 and Inventory.count("I6") == 1)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)
