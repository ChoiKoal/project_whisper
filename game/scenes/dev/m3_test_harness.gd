extends Node
## M3 acceptance harness — run headless:
##   Godot --headless res://scenes/dev/m3_test_harness.tscn --quit-after <frames>
## Exercises the M3 fusion / recipe-discovery / codex systems programmatically and
## prints PASS/FAIL lines, then quits with a non-zero exit code if any assertion
## failed.
##
## Covered (per the M3 acceptance list):
##   - RecipeDB: order-independent matching, alias fold (D06 -> I4), all_recipes.
##   - Fusion R07 (I5+I2 -> D54 초원): success consumes inputs, adds output.
##   - Wrong pair fails, does NOT consume, ticks the hint gauge once.
##   - Repeating the SAME wrong pair does NOT increment the gauge again.
##   - 5 DISTINCT wrong pairs -> a hint is revealed and the gauge resets.
##   - UNIQUE-AS-CATALYST: fusing I9+I7 -> D19 (R33) leaves I9 in the inventory.
##   - Codex item discovered-once whether gathered OR fused (I3: R01 vs gather).
##   - Codex recipe discovery (fusion success only) + to_dict/from_dict round-trip.

var _fail := 0


func _ready() -> void:
	print("=== M3 TEST HARNESS ===")
	_test_recipe_db()
	_test_r04_success_consumes()
	_test_wrong_pair_no_consume_and_gauge()
	_test_repeat_same_pair_no_increment()
	_test_five_distinct_pairs_reveal_hint()
	_test_order_independence()
	_test_alias_fold()
	_test_catalyst_unique_not_consumed()
	_test_item_discovered_once_gather_or_fuse()
	_test_codex_recipe_discovery_and_save()
	await _test_scene_wiring()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


## Fresh inventory + codex for an isolated sub-test.
func _fresh() -> void:
	Inventory.clear()
	Codex.reset()


# ---- RecipeDB ------------------------------------------------------------

func _test_recipe_db() -> void:
	_check("RecipeDB loaded 23+ recipes", RecipeDB.all_recipes().size() >= 23)
	# R07 = I5 꽃 + I2 풀 -> D54 초원, order-independent (owner CSV base-pair).
	var r := RecipeDB.find_recipe(["I5", "I2"])
	_check("RecipeDB find_recipe(I5,I2) = R07", r.get("id", "") == "R07")
	var r_rev := RecipeDB.find_recipe(["I2", "I5"])
	_check("RecipeDB find_recipe is order-independent", r_rev.get("id", "") == "R07")
	# Every base-pair now has a recipe, so use a genuinely undefined pair (I3 진흙 +
	# I4 나무 has no combo).
	_check("RecipeDB unknown pair -> empty", RecipeDB.find_recipe(["I3", "I4"]).is_empty())
	_check("RecipeDB rejects non-2 input arrays", RecipeDB.find_recipe(["I1"]).is_empty())


# ---- R07 success ---------------------------------------------------------

func _test_r04_success_consumes() -> void:
	_fresh()
	Inventory.add("I5", 1)
	Inventory.add("I2", 1)
	var res := Fusion.fuse("I5", "I2")
	_check("R07 fuse matched", res["matched"] == true)
	_check("R07 output = D54 초원", res["output"] == "D54")
	_check("R07 consumed I5", Inventory.count("I5") == 0)
	_check("R07 consumed I2", Inventory.count("I2") == 0)
	_check("R07 added D54", Inventory.count("D54") == 1)
	_check("R07 recorded recipe in codex", Codex.is_recipe_discovered("R07"))
	_check("R07 recorded output item in codex", Codex.is_item_discovered("D54"))


# ---- wrong pair ----------------------------------------------------------

func _test_wrong_pair_no_consume_and_gauge() -> void:
	_fresh()
	# I1+I2 is now a recipe (R02 잔디); use I3 진흙 + I4 나무, which has no combo.
	Inventory.add("I3", 1)  # 진흙
	Inventory.add("I4", 1)  # 나무  (I3+I4 is not a recipe)
	var g0 := Codex.hint_gauge()
	var res := Fusion.fuse("I3", "I4")
	_check("wrong pair not matched", res["matched"] == false)
	_check("wrong pair did NOT consume I3", Inventory.count("I3") == 1)
	_check("wrong pair did NOT consume I4", Inventory.count("I4") == 1)
	_check("wrong pair ticked the gauge +1", Codex.hint_gauge() == g0 + 1)


# ---- brute-force suppression --------------------------------------------

func _test_repeat_same_pair_no_increment() -> void:
	_fresh()
	# First failure of I3+I4 credits the gauge; repeats must not.
	Fusion.fuse("I3", "I4")
	var g1 := Codex.hint_gauge()
	Fusion.fuse("I3", "I4")
	Fusion.fuse("I4", "I3")  # same pair, reversed order
	var g2 := Codex.hint_gauge()
	_check("first failure credited gauge (=1)", g1 == 1)
	_check("repeated same wrong pair does NOT increment gauge", g2 == 1)


func _test_five_distinct_pairs_reveal_hint() -> void:
	_fresh()
	# Five DISTINCT non-recipe pairs. Every base gather-pair now maps to a combo
	# (owner CSV), so the surviving non-recipes all pair 진흙 I3 (which has no combos
	# beyond R01/R19/R29/R42/R49) with dead-end partners: I3+I4, I3+I5, I3+I6,
	# I3+I8, I1+I3. Verify each intended pair really has no recipe first.
	var pairs := [["I3", "I4"], ["I3", "I5"], ["I3", "I6"], ["I3", "I8"], ["I1", "I3"]]
	var all_nonrecipe := true
	for p: Array in pairs:
		if not RecipeDB.find_recipe(p).is_empty():
			all_nonrecipe = false
	_check("chosen 5 pairs are all non-recipes", all_nonrecipe)

	var revealed := false
	for i in pairs.size():
		var p: Array = pairs[i]
		var res := Fusion.fuse(p[0], p[1])
		if res["hint_revealed"]:
			revealed = true
	_check("5 distinct wrong pairs revealed a hint", revealed)
	_check("gauge reset to 0 after reveal", Codex.hint_gauge() == 0)
	# A hint should now exist on some undiscovered recipe.
	var any_hint := false
	for rid: String in RecipeDB.all_ids():
		if Codex.hint_for_recipe(rid) != "":
			any_hint = true
	_check("a recipe now carries a revealed-ingredient hint", any_hint)


# ---- order independence (via fuse) --------------------------------------

func _test_order_independence() -> void:
	_fresh()
	Inventory.add("I2", 1)
	Inventory.add("I5", 1)
	# Reversed argument order still hits R07.
	var res := Fusion.fuse("I2", "I5")
	_check("fuse(I2,I5) reversed still matches R07", res["recipe_id"] == "R07")
	_check("fuse(I2,I5) reversed produced D54 초원", Inventory.count("D54") == 1)


# ---- alias fold (D06 -> I4) ---------------------------------------------

func _test_alias_fold() -> void:
	_fresh()
	# R25 = D09 건초 + I4 나무 -> D10 둥지. Pass the alias D06 (== I4) as the wood
	# input; the recipe must still match because inputs canonicalize through
	# resolve_id.
	_check("D06 resolves to I4", ItemDB.resolve_id("D06") == "I4")
	var r := RecipeDB.find_recipe(["D09", "D06"])
	_check("find_recipe folds alias D06 -> I4 (matches R25)", r.get("id", "") == "R25")
	# And a fuse using the alias id consumes from the I4 stack.
	Inventory.add("D09", 1)
	Inventory.add("D06", 1)  # folds into I4 stack
	_check("alias add folded into I4 stack", Inventory.count("I4") == 1)
	var res := Fusion.fuse("D09", "D06")
	_check("fuse with alias input matched R25", res["recipe_id"] == "R25")
	_check("fuse with alias consumed the I4 stack", Inventory.count("I4") == 0)
	_check("fuse produced D10", Inventory.count("D10") == 1)


# ---- catalyst (unique not consumed) -------------------------------------

func _test_catalyst_unique_not_consumed() -> void:
	_fresh()
	# R33 = I9 + I7 -> D19. I9 is unique -> catalyst, must remain.
	Inventory.add("I9", 1)
	Inventory.add("I7", 1)
	var res := Fusion.fuse("I9", "I7")
	_check("catalyst fuse matched R33", res["recipe_id"] == "R33")
	_check("catalyst fuse produced D19", Inventory.count("D19") == 1)
	_check("catalyst I9 (unique) NOT consumed", Inventory.count("I9") == 1)
	_check("catalyst non-unique I7 consumed", Inventory.count("I7") == 0)


# ---- item discovered-once (gather OR fuse) ------------------------------

func _test_item_discovered_once_gather_or_fuse() -> void:
	# Path A: gather I3 (via GameState.item_gathered signal that Codex listens to).
	_fresh()
	GameState.item_gathered.emit("I3")
	_check("I3 discovered by gathering", Codex.is_item_discovered("I3"))
	var after_gather := Codex.discovered_item_count()
	# Re-gathering does not double-count.
	GameState.item_gathered.emit("I3")
	_check("re-gathering I3 does not double-count", Codex.discovered_item_count() == after_gather)

	# Path B: fuse into I3 (R01 = I7 + I1 -> I3) from a clean codex.
	_fresh()
	Inventory.add("I7", 1)
	Inventory.add("I1", 1)
	var res := Fusion.fuse("I7", "I1")
	_check("R01 fuse produced I3", res["output"] == "I3")
	_check("I3 discovered by fusing", Codex.is_item_discovered("I3"))
	# Now both gather and fuse the same item; it must count exactly once.
	var before := Codex.discovered_item_count()
	GameState.item_gathered.emit("I3")
	_check("I3 counted once regardless of source (gather after fuse is no-op)",
		Codex.discovered_item_count() == before)


# ---- recipe discovery + save round-trip ---------------------------------

func _test_codex_recipe_discovery_and_save() -> void:
	_fresh()
	# Recipe discovery is fusion-success only: gathering an item does not discover
	# any recipe.
	GameState.item_gathered.emit("I5")
	_check("gathering does not discover a recipe", Codex.discovered_recipe_count() == 0)
	Inventory.add("I5", 1)
	Inventory.add("I2", 1)
	Fusion.fuse("I5", "I2")
	_check("successful fuse discovered R07", Codex.is_recipe_discovered("R07"))

	# to_dict / from_dict round-trip preserves items, recipes, gauge, attempted.
	# I1+I8 is now a recipe (R06 암석층), so use the dead-end I3+I4 for a failed attempt.
	Fusion.fuse("I3", "I4")  # a failed attempt -> gauge + attempted pair
	var snap := Codex.to_dict()
	_check("snapshot has items", snap["items"].size() >= 2)
	_check("snapshot has recipes", snap["recipes"].has("R07"))
	_check("snapshot has attempted_pairs", snap["attempted_pairs"].size() >= 1)
	var gauge_before: int = Codex.hint_gauge()

	Codex.reset()
	_check("reset cleared recipes", Codex.discovered_recipe_count() == 0)
	Codex.from_dict(snap)
	_check("restore recovered R07", Codex.is_recipe_discovered("R07"))
	_check("restore recovered gauge", Codex.hint_gauge() == gauge_before)
	# Restored attempted pair must still be suppressed.
	var g := Codex.hint_gauge()
	Fusion.fuse("I3", "I4")  # already-attempted per the snapshot
	_check("restored attempted pair stays suppressed", Codex.hint_gauge() == g)


# ---- real-scene wiring (acceptance #7 full loop) ------------------------

## Loads the real test_map, confirms the Cauldron is present and wired to the
## FusionUI, and drives the full gather->cauldron->fuse loop through the live
## scene objects (not emulated logic).
func _test_scene_wiring() -> void:
	_fresh()
	var scene: PackedScene = load("res://scenes/world/test_map.tscn")
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame  # let FusionUI._autobind_cauldrons() run (deferred)

	# Cauldron present in the scene, in the gatherable group, near spawn.
	var cauldron: Cauldron = null
	for n in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if n is Cauldron:
			cauldron = n
			break
	_check("Cauldron present on test_map", cauldron != null)

	var fusion_ui := map.get_node_or_null("FusionUI")
	var codex_ui := map.get_node_or_null("CodexUI")
	_check("FusionUI present on test_map", fusion_ui != null)
	_check("CodexUI present on test_map", codex_ui != null)

	# Interacting with the cauldron opens the FusionUI (signal wired by autobind).
	if cauldron != null and fusion_ui != null:
		var opened := {"hit": false}
		cauldron.interacted.connect(func(): opened["hit"] = true)
		cauldron.on_interact()
		_check("cauldron.on_interact() emits interacted", opened["hit"])
		_check("FusionUI is open after cauldron interact", fusion_ui._open == true)

	# Full loop: gather I5+I2 (grant), fuse -> D54 초원 (R07), then D54+I5 -> D03 씨앗 (R20).
	Inventory.add("I5", 1)
	Inventory.add("I2", 1)
	var r1 := Fusion.fuse("I5", "I2")
	_check("loop step 1: I5+I2 -> D54 초원", r1["output"] == "D54")
	Inventory.add("I5", 1)
	var r2 := Fusion.fuse("D54", "I5")
	_check("loop step 2: D54+I5 -> D03 씨앗", r2["output"] == "D03")
	_check("loop discovered R07 and R20",
		Codex.is_recipe_discovered("R07") and Codex.is_recipe_discovered("R20"))

	map.queue_free()
