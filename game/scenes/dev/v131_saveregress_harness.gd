extends Node
## v1.3.1 hotfix reproduction + acceptance harness. Covers the two live-play save
## regressions KOAL reported on v1.3.0:
##
##   BUG A (science 재잠금) — L1 cleared + L2(science) cleared → science 포탈 OPEN. Then the
##     player revisits L1 (grove), returns home, and the science portal must STILL be OPEN.
##     v1.3.0 regressed: something recomputed/overwrote portal_states off a stale/미클리어
##     baseline on the L1 round-trip, re-locking science.
##
##   BUG B (덤불 리셋) — a bush the player watered (bloom) in L1 must survive leaving the grove
##     and coming back (scene re-entry). v1.3.0 regressed: the bloom was not restored on re-entry.
##
##   AUTO-RECOVER — an ALREADY-BROKEN save (science stored dormant even though every purified
##     flag / SaveManager.cleared says it should be open) must self-heal on load: loading the
##     save recomputes the portal line from the purification flags exactly once, so KOAL's
##     already-locked save comes back OPEN without a re-clear.
##
## Each section prints PASS/FAIL; process exit code = failure count.
## Drives the REAL SaveManager save/load + scene boot path (same mechanics as e2e_playthrough).

const HOME := "res://scenes/world/home_island.tscn"
const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0
var _scene: Node = null


func _ready() -> void:
	print("=== v131 SAVE-REGRESSION HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	call_deferred("_run")


func _run() -> void:
	await _frames(1)
	await _a_science_survives_l1_revisit()
	await _b_bush_survives_grove_reentry()
	await _c_broken_save_autorecovers_on_load()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ==== infra ================================================================

func _check(label: String, cond: bool, detail: String = "") -> bool:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1
	return cond


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _find(node: Node, cls) -> Node:
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


func _boot(path: String) -> Node:
	var s: Node = load(path).instantiate()
	add_child(s)
	await _frames(4)
	return s


func _register(scene: Node) -> void:
	SaveManager.register_world(scene.get_node("Ground"), scene.get_node("YSortLayer/Player"),
		scene.get_node("ObjectRespawn"))


func _teardown() -> void:
	SaveManager.unregister_world()
	if _scene != null:
		_scene.queue_free()
		_scene = null
	await _frames(2)


## Put the run into the state KOAL was in: L1 cleared + L2 cleared, so both nature and science
## portals are OPEN, all five-layer flags NOT complete (only L1+L2 done).
func _seed_l1_l2_cleared() -> void:
	SaveManager.new_game()
	SaveManager.mark_cleared()                          # L1 clear
	GameState.set_portal_state("nature", GameState.PORTAL_OPEN)
	GameState.layer2_purified_flag = true               # L2 clear
	GameState.set_portal_state("science", GameState.PORTAL_OPEN)
	GameState.set_portal_state("machine", GameState.PORTAL_FLICKERING)


# ==== A. science portal survives an L1 (grove) revisit round-trip ==========

func _a_science_survives_l1_revisit() -> void:
	print("--- A. science OPEN survives L1 revisit → home return (BUG A) ---")
	GameState.time_running = false
	_seed_l1_l2_cleared()

	# Boot the home island (the hub). No pending_load — this is a live session.
	WorldContext.current_scene = WorldContext.SCENE_HOME
	WorldContext.arrival_mode = ""
	SaveManager.pending_load = false
	_scene = await _boot(HOME)
	_register(_scene)
	await _frames(2)
	_check("precondition: science portal OPEN before L1 revisit",
		GameState.portal_state("science") == GameState.PORTAL_OPEN,
		"science=%s" % GameState.portal_state("science"))

	# --- Travel into L1 (grove) exactly as HomeSession._travel_to_layer does: snapshot the home
	#     world (current_scene=home) + save, then flip to grove + change scene. ---
	WorldContext.travel_layer = "nature"
	WorldContext.arrival_mode = "portal_arrival"
	SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	await _teardown()

	# Boot the grove as a portal arrival (already cleared → CS-02 landing skipped).
	SaveManager.pending_load = false
	_scene = await _boot(GROVE)
	_register(_scene)
	await _frames(2)

	# --- Return home exactly as GroveSession._return_home(false) does: snapshot grove-as-grove,
	#     then flip to home + change scene. ---
	WorldContext.arrival_mode = "portal_arrival"
	SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	await _teardown()

	SaveManager.pending_load = false
	_scene = await _boot(HOME)
	_register(_scene)
	await _frames(2)

	# The regression assertion: science must still be OPEN after the L1 round-trip.
	_check("BUG A: science portal STILL OPEN after L1 revisit → home return",
		GameState.portal_state("science") == GameState.PORTAL_OPEN,
		"science=%s" % GameState.portal_state("science"))
	# And the live home science portal node reflects it (enterable).
	var science := _home_portal("science")
	_check("BUG A: home science portal node open + enterable after revisit",
		science != null and science.state() == GameState.PORTAL_OPEN and science.is_enterable(),
		"node_state=%s" % (science.state() if science != null else "<null>"))

	await _teardown()


func _home_portal(layer: String) -> Portal:
	for n in get_tree().get_nodes_in_group("gatherable"):
		if n is Portal and (n as Portal).layer == layer:
			return n
	return null


# ==== B. watered bush survives leaving + re-entering the grove =============

func _b_bush_survives_grove_reentry() -> void:
	print("--- B. watered bush survives grove leave → re-enter (BUG B) ---")
	GameState.time_running = false
	_seed_l1_l2_cleared()

	# Boot the grove, bloom the bush (simulate watering), then leave + come back.
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	WorldContext.arrival_mode = "portal_arrival"
	SaveManager.pending_load = false
	_scene = await _boot(GROVE)
	_register(_scene)
	await _frames(2)

	var bush := _find(_scene, BushDry) as BushDry
	_check("grove bush present", bush != null)
	if bush != null:
		bush.bloom()
		await _frames(1)
		_check("bush bloomed (watered) before leaving", bush.is_bloomed())

	# Leave the grove for home (GroveSession._return_home path: snapshot the grove-as-grove FIRST,
	# then flip current_scene to home + change scene — mirrors grove_session.gd ordering).
	WorldContext.arrival_mode = "portal_arrival"
	SaveManager.save_game()                                   # grove snapshot (current_scene=grove)
	WorldContext.current_scene = WorldContext.SCENE_HOME
	await _teardown()
	_scene = await _boot(HOME)
	_register(_scene)
	await _frames(1)
	# Home → back into the grove (HomeSession._travel_to_layer path: snapshot home-as-home, then
	# flip current_scene to grove + change scene).
	WorldContext.travel_layer = "nature"
	WorldContext.arrival_mode = "portal_arrival"
	SaveManager.save_game()                                   # home snapshot (current_scene=home)
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	await _teardown()

	SaveManager.pending_load = false
	_scene = await _boot(GROVE)
	_register(_scene)
	await _frames(2)

	var bush2 := _find(_scene, BushDry) as BushDry
	_check("BUG B: bush STILL bloomed after grove re-entry",
		bush2 != null and bush2.is_bloomed(),
		"bloomed=%s" % (bush2.is_bloomed() if bush2 != null else "<null>"))

	await _teardown()


# ==== C. an already-broken save self-heals on load =========================

func _c_broken_save_autorecovers_on_load() -> void:
	print("--- C. already-locked save auto-recovers science on load (migration) ---")
	GameState.time_running = false
	# Craft KOAL's broken save on disk: cleared + L2 purified, but science stored DORMANT
	# (the regression's corrupt state) and nature stored dormant too.
	_seed_l1_l2_cleared()
	GameState.portal_states["science"] = GameState.PORTAL_DORMANT
	GameState.portal_states["nature"] = GameState.PORTAL_DORMANT
	WorldContext.current_scene = WorldContext.SCENE_HOME
	SaveManager.save_game()   # persists the corrupt portal_states to disk
	await _frames(1)

	# Corrupt the in-memory copy further to be sure the recovery comes from LOAD, not memory.
	GameState.reset_portals()
	GameState.layer2_purified_flag = false
	SaveManager.cleared = false

	# Boot home + load the broken save (이어하기).
	WorldContext.current_scene = WorldContext.SCENE_HOME
	WorldContext.arrival_mode = ""
	SaveManager.pending_load = true
	_scene = await _boot(HOME)
	# HomeSession consumes pending_load and calls load_game() itself during _setup.
	await _frames(3)

	_check("AUTO-RECOVER: cleared + layer2_purified restored from save",
		SaveManager.cleared and GameState.layer2_purified_flag)
	_check("AUTO-RECOVER: science portal recomputed to OPEN on load (was DORMANT on disk)",
		GameState.portal_state("science") == GameState.PORTAL_OPEN,
		"science=%s" % GameState.portal_state("science"))
	_check("AUTO-RECOVER: nature portal recomputed to OPEN on load (L1 cleared)",
		GameState.portal_state("nature") == GameState.PORTAL_OPEN,
		"nature=%s" % GameState.portal_state("nature"))

	await _teardown()
