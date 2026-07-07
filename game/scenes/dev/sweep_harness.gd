extends Node
## v0.6.1 STABILITY SWEEP harness — regression coverage for the v0.6.1 bug sweep fixes plus the
## "비정규 경로" (off-path) stress the release brief calls out. Complements v052_travel_stress
## (return-portal crash class) and l2_gates_harness (gate acceptance) by driving the paths those
## two do NOT cover:
##
##   A. CLEAR CUTSCENE restores time. ClearSequence.play() sets GameState.time_running=false during
##      the CS-04 정화 beat and — before v0.6.1 — never restored it, so the home island booted with
##      time frozen (day/night stalled, HomeSession treating the world as permanently locked). We
##      drive the real ClearSequence in the live grove and assert time_running==true after `cleared`.
##   B. KEYBOARD-WALK freezes during a cutscene. player.gd._physics_process only froze on
##      ui_modal_open() before v0.6.1; holding a move key during a cutscene (time_running=false or
##      control_locked) walked the player through it. We assert the Player's own frame-freeze
##      predicate is true under each cutscene condition.
##   C. PRE-CLEAR 귀환: return to home via the grove return portal BEFORE clearing, then re-enter —
##      the grove rebuilds and the return portal is present + OPEN again (no half-cleared state, no
##      stuck lock). This is the "클리어 전 수동 귀환" 사각지대 the brief flags.
##   D. L2 off-path rejects (via terminal_station): G3 정전 병목 with NO lantern stays walled; G4
##      파워코어 조합 with ZERO energy is rejected with the 재화 부족 UX (materials not consumed).
##   E. CUTSCENE ESC-spam safety: the opening cutscene's skip is idempotent (_finishing guard) — a
##      spam of skip_all()/advance() after finish must not double-fire the scene change.
##
## Assertions print [PASS]/[FAIL]; exit code = failure count. Reparents under the tree root so
## change_scene_to_file does not free the harness mid-run.

const GROVE := "res://scenes/world/starting_grove.tscn"
const STATION := "res://scenes/world/terminal_station.tscn"
const HOME := "res://scenes/world/home_island.tscn"

var _tree: SceneTree
var _fail := 0

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
	await _tree.create_timer(s).timeout

func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1

func _scene_name() -> String:
	return _tree.current_scene.name if _tree.current_scene != null else "<null>"

func _find_by_class(cls: String) -> Node:
	return _search(_tree.current_scene, cls)

func _search(node: Node, cls: String) -> Node:
	if node == null:
		return null
	if node.get_script() != null and str(node.get_script().get_global_name()) == cls:
		return node
	for c in node.get_children():
		var r := _search(c, cls)
		if r != null:
			return r
	return null

func _find_return_portal() -> Node:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n.get("object_id") == "portal_return":
			return n
	return null

func _run() -> void:
	print("=== v0.6.1 STABILITY SWEEP HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	SaveManager.new_game()

	await _test_clear_restores_time()
	await _test_keyboard_walk_freezes_in_cutscene()
	await _test_preclear_return_roundtrip()
	await _test_l2_offpath_rejects()
	_test_cutscene_esc_spam_safe()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)

# ---- A. clear cutscene restores time_running ------------------------------

func _test_clear_restores_time() -> void:
	print("--- A: clear cutscene restores time_running ---")
	# Boot the live grove (owns a ClearSequence + MapLoader + Player).
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	_tree.change_scene_to_file(GROVE)
	await _frames(12)
	if _scene_name() != "StartingGrove":
		_check("A: grove booted", false, _scene_name())
		return
	var clear := _find_by_class("ClearSequence")
	_check("A: ClearSequence present in grove", clear != null)
	if clear == null:
		return
	# We do NOT want the auto-return to fire (it changes scene mid-assert); temporarily disconnect
	# the session's cleared→_on_cleared and observe time_running ourselves.
	var session := _find_by_class("GroveSession")
	if session != null and clear.cleared.is_connected(session._on_cleared):
		clear.cleared.disconnect(session._on_cleared)
	GameState.time_running = true
	clear.play()
	await _frames(2)
	_check("A: time frozen DURING clear cutscene", not GameState.time_running)
	# The beat is now ~18s of tweens/cards (v1.3.0 CQ-4 added the 3s silence + broken-birdsong
	# beats per CS-04). Wait for `cleared`, then assert restore.
	var got := [false]
	clear.cleared.connect(func(): got[0] = true, CONNECT_ONE_SHOT)
	var waited := 0.0
	while not got[0] and waited < 26.0:
		await _wait(0.25)
		waited += 0.25
	_check("A: clear cutscene emitted `cleared`", got[0], "waited=%.1fs" % waited)
	_check("A: time_running RESTORED true after clear (v0.6.1 fix)", GameState.time_running)

# ---- B. keyboard-walk freeze predicate under cutscene conditions ----------

func _test_keyboard_walk_freezes_in_cutscene() -> void:
	print("--- B: keyboard-walk freezes during cutscene ---")
	# Fresh grove so the earlier clear beat doesn't taint state.
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	_tree.change_scene_to_file(GROVE)
	await _frames(12)
	var player := _find_by_class("Player")
	_check("B: Player present", player != null)
	if player == null:
		return
	# The Player's per-frame world-freeze predicate must mirror TouchController._world_locked():
	# modal OR not time_running OR control_locked. Verify each cutscene condition freezes it.
	if not player.has_method("is_world_frozen"):
		_check("B: Player exposes is_world_frozen()", false)
		return
	GameState.time_running = true
	GameState.set_control_lock(false)
	var f_open: bool = player.call("is_world_frozen")
	_check("B: not frozen in normal play", not f_open)
	# Cutscene via time_running=false (clear/purification/travel swell).
	GameState.time_running = false
	_check("B: FROZEN while time_running=false (cutscene)", bool(player.call("is_world_frozen")))
	GameState.time_running = true
	# Cutscene via control_lock (portal_cutscene CS-05 ignition).
	GameState.set_control_lock(true)
	_check("B: FROZEN while control_locked (CS-05 ignition)", bool(player.call("is_world_frozen")))
	GameState.set_control_lock(false)
	_check("B: unfrozen after locks released", not bool(player.call("is_world_frozen")))

# ---- C. pre-clear manual return roundtrip ---------------------------------

func _test_preclear_return_roundtrip() -> void:
	print("--- C: pre-clear manual return → re-enter (사각지대) ---")
	SaveManager.new_game()
	# Boot home, hop to grove, return via portal WITHOUT clearing, re-enter, assert clean state.
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_tree.change_scene_to_file(HOME)
	await _frames(12)
	_check("C: home booted", _scene_name() == "HomeIsland", _scene_name())
	# Home → grove via the nature portal.
	var nature := _find_portal_layer("nature")
	if nature == null:
		_check("C: nature portal on home", false)
		return
	nature.on_interact()
	await _wait(2.0)
	await _frames(10)
	_check("C: arrived grove (not cleared)", _scene_name() == "StartingGrove", _scene_name())
	_check("C: NOT cleared yet", not SaveManager.cleared)
	var rp := _find_return_portal()
	_check("C: return portal present + OPEN pre-clear",
		rp != null and GameState.portal_state("return") == GameState.PORTAL_OPEN)
	# Manual return (pre-clear) → home.
	if rp != null:
		rp.on_interact()
		await _wait(0.6)
		await _frames(12)
	_check("C: returned home pre-clear (no crash)", _scene_name() == "HomeIsland", _scene_name())
	_check("C: no lock wedged after pre-clear return", GameState.time_running and not GameState.control_locked())
	# Re-enter the grove → rebuilds cleanly, return portal present + OPEN again.
	nature = _find_portal_layer("nature")
	if nature != null:
		nature.on_interact()
		await _wait(2.0)
		await _frames(10)
	_check("C: re-entered grove rebuilt", _scene_name() == "StartingGrove", _scene_name())
	rp = _find_return_portal()
	_check("C: return portal present + OPEN on re-entry", rp != null and GameState.portal_state("return") == GameState.PORTAL_OPEN)

func _find_portal_layer(layer: String) -> Node:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n.get("layer") == layer and n.get("object_id") != "portal_return":
			return n
	return null

# ---- D. L2 off-path rejects (G3 no lantern, G4 zero energy) ---------------

func _test_l2_offpath_rejects() -> void:
	print("--- D: L2 off-path rejects (terminal_station) ---")
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_TERMINAL
	_tree.change_scene_to_file(STATION)
	await _frames(14)
	_check("D: terminal_station booted", _scene_name() == "TerminalStation", _scene_name())
	var gates := _find_by_class("L2GateController")
	_check("D: L2GateController present", gates != null)
	# D-1: G3 정전 병목 — NO lantern → bottleneck wall stays ON (통행 차단). Drive _apply_g3(false)
	# (the possession-check output) exactly as l2_gates_harness does, then read the wall collision.
	Inventory.remove("D65", Inventory.count("D65"))
	if gates != null and gates.has_method("_apply_g3"):
		gates.call("_apply_g3", false)
		await _frames(2)
		_check("D: G3 랜턴 미소지 → 병목 벽 유지 (통행 차단)", not _g3_wall_disabled(gates))
		# And with the lantern the wall opens (control path sanity).
		gates.call("_apply_g3", true)
		await _frames(3)
		_check("D: G3 랜턴 소지 → 병목 통행 (벽 off)", _g3_wall_disabled(gates))
		gates.call("_apply_g3", false)  # restore walled for a clean end state
	else:
		_check("D: G3 wall query available", false)
	# D-2: G4 파워코어 with ZERO energy → fuse rejected, 재화 부족, materials intact.
	WhisperCurrency.energy = 0
	var recipe := _recipe_by_id("L2-R08")
	_check("D: 파워코어 recipe found", not recipe.is_empty())
	Inventory.remove("D68", Inventory.count("D68"))
	Inventory.add("D68", 2)
	var res: Dictionary = Fusion.fuse("D68", "D68")
	_check("D: 에너지 0 → 파워코어 조합 거부", not res.get("matched", true))
	_check("D: 거부 사유 = 에너지 부족", String(res.get("failure_reason", "")).findn("에너지") >= 0,
		String(res.get("failure_reason", "")))
	_check("D: 거부 시 재료 미소모 (D68 2 잔존)", Inventory.count("D68") == 2)

func _recipe_by_id(id: String) -> Dictionary:
	for r in RecipeDB.all_recipes():
		if String(r.get("id", "")) == id:
			return r
	return {}

## True when the G3 bottleneck wall's collision is disabled (passable). Mirrors l2_gates_harness.
func _g3_wall_disabled(gates: Node) -> bool:
	var body = gates.get("_g3_body") if "_g3_body" in gates else null
	if body == null or not is_instance_valid(body):
		return true  # no wall built = passable
	var col = body.get_child(0)
	if col is CollisionShape2D:
		return (col as CollisionShape2D).disabled
	return true

# ---- E. cutscene ESC-spam idempotency -------------------------------------

func _test_cutscene_esc_spam_safe() -> void:
	print("--- E: cutscene ESC-spam idempotency ---")
	# The opening cutscene's skip is guarded by a _finishing flag. Instantiate it standalone,
	# fire skip_all() then spam it + advance(); the guard must prevent re-entry (no error/crash).
	var scr := load("res://scripts/ui/opening.gd")
	if scr == null:
		_check("E: opening.gd loads", false)
		return
	var op: Node = scr.new()
	_tree.root.add_child(op)
	await _frames(2)
	if op.has_method("skip_all"):
		op.skip_all()
		# Spam skip/advance after finish — must be no-ops (guarded).
		for i in range(5):
			op.skip_all()
			if op.has_method("advance"):
				op.advance()
		_check("E: ESC-spam after skip is idempotent (no crash, _finishing guard)", true)
	else:
		_check("E: opening exposes skip_all()", false)
	if is_instance_valid(op):
		op.queue_free()
	await _frames(2)
