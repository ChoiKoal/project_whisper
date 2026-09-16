extends Node
const GUARD = preload("res://scenes/dev/isolated_harness_guard.gd")
const EP := "WH-L1H-01"
var failures := 0
func check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok: failures += 1
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	if not GUARD.require_isolated_user_data("l1_home_story_state_harness"):
		get_tree().quit(86)
		return
	SaveManager.new_game()
	check("run state API exists", GameState.has_method("story_record_experiment"))
	if not GameState.has_method("story_record_experiment"):
		get_tree().quit(1)
		return
	check("first nest records one response", GameState.call("story_record_experiment", "D10"))
	var expected: Dictionary = GameState.call("story_episode")
	check("nest saves canonical outcome and item", expected.get("active_outcome")=="nest" and expected.get("active_item_id")=="D10")
	check("disk write succeeds", SaveManager.save_game())
	GameState.set("story_state", {})
	check("disk reload succeeds", not SaveManager.load_game().is_empty())
	check("episode survives real disk roundtrip", GameState.call("story_episode")==expected)
	check("same outcome is not a new response", not GameState.call("story_record_experiment", "D10"))
	SaveManager.new_game()
	check("new game resets run episode", (GameState.get("story_state") as Dictionary).is_empty())
	GameState.call("story_record_experiment", "D10")
	SaveManager.start_ng_plus([])
	check("NG+ resets run episode", (GameState.get("story_state") as Dictionary).is_empty())
	check("sanitizer API exists", GameState.has_method("sanitize_story_state"))
	if GameState.has_method("sanitize_story_state"):
		for raw in [null, [], "bad", 7, {EP: null}, {EP: []}, {EP: {"revision": 999}}]:
			check("invalid episode defaults safely " + str(raw), GameState.call("sanitize_story_state", raw)=={})
		var dirty := {EP: {"revision": 1, "active_outcome": "nest", "active_item_id": "D08", "perch_inspected": "false", "outcomes_seen": {"nest": true, "hack": true, "moss": "true"}, "cairn_seen": [], "home_line_seen": 1}}
		var clean: Dictionary = GameState.call("sanitize_story_state", dirty)
		check("contradictory item/outcome rejected", clean[EP].get("active_outcome")=="" and clean[EP].get("active_item_id")=="")
		check("strict bool and whitelisted outcome keys", clean[EP].get("perch_inspected")==false and clean[EP].get("home_line_seen")==false and clean[EP].get("outcomes_seen")=={"nest":true} and clean[EP].get("cairn_seen")=={})
		var old := SaveManager.build_save_dict()
		old.erase("story_state")
		var worlds: Dictionary = old["worlds"].duplicate(true)
		SaveManager.call("_apply_core_state", old)
		check("old v2 has empty story without touching worlds", GameState.get("story_state")=={} and SaveManager.build_save_dict()["worlds"]==worlds)
	GameState.call("story_record_experiment", "D10")
	check("bouquet new reaction", GameState.call("story_record_experiment", "D18"))
	check("moss new reaction", GameState.call("story_record_experiment", "D55"))
	check("generic new reaction", GameState.call("story_record_experiment", "D08"))
	check("latest generic beats prior special", (GameState.call("story_episode") as Dictionary).get("active_outcome")=="other")
	check("previous outcome remains selectable without replay", not GameState.call("story_record_experiment", "D10") and (GameState.call("story_episode") as Dictionary).get("active_outcome")=="nest")
	var before: Dictionary = GameState.call("story_episode")
	for bad in ["unknown", "I1", "D22", "D14"]:
		check("non-decor/structure rejected " + bad, not GameState.call("story_record_experiment", bad) and GameState.call("story_episode")==before)
	print("L1_HOME_STATE failures=", failures)
	get_tree().quit(1 if failures else 0)
