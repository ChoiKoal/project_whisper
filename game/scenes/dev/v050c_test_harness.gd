extends Node
## v0.5.0 phase C acceptance harness. Covers the Layer-0 home island + portal travel +
## multi-scene save + the CS-04/CS-05 flow + the object-embedding PRE-FIX.
##
## Sections (each prints PASS/FAIL; exit code = failure count):
##   A. PRE-FIX      — no scatter on cliff-RIM cells (grove); every object node's Y matches
##                     its cell height offset (apply_height_lift is the single lift path).
##   B. HOME         — home island boots; 5 portals in a semicircle; nature flickering, rest
##                     dormant; cauldron + dais spawn; barren (no scatter).
##   C. PORTAL SM    — dormant→flickering→open state machine + is_enterable + saved states.
##   D. QUESTS       — P0 (leave dais) → P1 (portal_reached) → Q1 chain head; advance_to.
##   E. TRAVEL       — home→grove→home roundtrip preserves each world's placed-object state
##                     (scene-keyed save); portal_states persist.
##   F. CS-04/05     — world_tree_planted drives ClearSequence (CS-04); CS-05 opens nature +
##                     flickers science + opens P2 (driven via the cutscene API / signals).
##   G. SAVE         — scene-keyed worlds round-trip; v1 (old) save rejected as 구버전.

const HOME := "res://scenes/world/home_island.tscn"
const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0
var _scene: Node = null


func _ready() -> void:
	print("=== v050c PHASE-C HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	GameState.time_running = false
	call_deferred("_run")


func _run() -> void:
	await _frames(1)
	await _a_prefix()
	await _b_home()
	await _c_portal_sm()
	await _d_quests()
	await _e_travel()
	await _f_cutscenes()
	await _g_save()
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


func _boot(path: String) -> Node:
	var s: Node = load(path).instantiate()
	add_child(s)
	await _frames(4)
	return s


func _teardown() -> void:
	SaveManager.unregister_world()
	if _scene != null:
		_scene.queue_free()
		_scene = null
	await _frames(2)


## True if the portal's floating SIGIL stone glyph is LIT (v0.5d: the monumental gate carries a
## carved layer-motif sigil stone above the lintel; its glyph glow ignites only when the gate
## is non-dormant). The stone itself is always present; only the glow is state-driven.
func _portal_sigil_lit(portal: Node) -> bool:
	if portal == null:
		return false
	if portal.has_method("is_sigil_lit"):
		return portal.is_sigil_lit()
	return false


func _find(node: Node, cls) -> Node:
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


# ==== A. PRE-FIX (grove) ===================================================

func _a_prefix() -> void:
	print("--- A. PRE-FIX: no rim scatter + object height lift (grove) ---")
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	SaveManager.pending_load = false
	_scene = await _boot(GROVE)
	var loader := _scene.get_node("Ground") as MapLoader
	var ysort := _scene.get_node("YSortLayer") as Node2D

	# No scattered object sits on a cliff-rim cell (raised cell with a downhill face).
	var rim_hits := 0
	for entry in loader.object_spawns:
		var cell: Vector2i = entry["cell"]
		if loader._is_rim_cell(cell):
			rim_hits += 1
	_check("no scatter/authored gatherable on a cliff-rim cell", rim_hits == 0,
		"rim_hits=%d" % rim_hits)

	# Every lifted object's applied offset matches its cell's authoritative height offset — the
	# invariant "every object node's y matches its cell height offset". The lift records the cell
	# + offset it used in meta, so we verify against the loader's height_offset for that cell.
	var mismatches := 0
	var checked := 0
	for child in ysort.get_children():
		if not (child is Node2D) or child is Player:
			continue
		var n := child as Node2D
		if not n.get_meta("_height_lifted", false):
			continue
		checked += 1
		var lift_cell: Vector2i = n.get_meta("_lift_cell", Vector2i.ZERO)
		var applied: float = n.get_meta("_lift_offset", 0.0)
		if absf(applied - loader.height_offset(lift_cell)) > 0.5:
			mismatches += 1
	_check("every lifted object's offset == its cell height offset", mismatches == 0,
		"checked=%d mismatches=%d" % [checked, mismatches])

	await _teardown()


# ==== B. HOME island =======================================================

func _b_home() -> void:
	print("--- B. HOME island: portals, dais, barren ---")
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	SaveManager.pending_load = false
	_scene = await _boot(HOME)
	var loader := _scene.get_node("Ground") as MapLoader

	# (v1.4.2) 홈 섬 staggered 재저작 → 21×17 (포탈 아치 구도).
	_check("home map built (21×17)", loader.width == 21 and loader.height == 17,
		"%d×%d" % [loader.width, loader.height])
	_check("home has a spawn (dais) cell", loader.spawn_cell != Vector2i(-1, -1),
		"spawn=%s" % loader.spawn_cell)
	_check("home has a cauldron (crafting at home)", loader.cauldron_cell != Vector2i(-1, -1))

	var portals: Array = []
	for n in get_tree().get_nodes_in_group("gatherable"):
		if n is Portal:
			portals.append(n)
	_check("5 portals spawned", portals.size() == 5, "n=%d" % portals.size())

	# Portals sit in a rough semicircle around the dais (all above/around the spawn row).
	var all_around := true
	for p in portals:
		var pc := loader.world_to_cell((p as Portal).global_position)
		if pc.y > loader.spawn_cell.y:  # every portal is north of / level with the dais
			all_around = false
	_check("portals arc around the dais (north half)", all_around)

	# Barren: no procedural scatter (only the authored portals/cauldron).
	_check("home is barren (no scatter objects)", loader.object_spawns.is_empty(),
		"scatter=%d" % loader.object_spawns.size())

	# (v0.5d) Floating rock-shard silhouette: full-perimeter aprons + tapering underside +
	# drifting debris islets all built on the (flat) home island.
	_check("home built full-perimeter cliff aprons (floating shard)", loader.shard_apron_count > 0,
		"aprons=%d" % loader.shard_apron_count)
	_check("home built a tapering rocky underside", loader.shard_underside_present)
	_check("home built drifting debris islets", loader.debris_islet_count >= 3,
		"debris=%d" % loader.debris_islet_count)

	# (v0.5d) The monumental gate carries a carved layer-motif SIGIL stone above the lintel; its
	# glyph glow ignites only when non-dormant. The nature gate is flickering at start, so its
	# sigil is lit; a dormant gate's sigil is unlit.
	var nature_gate: Portal = null
	var dormant_gate: Portal = null
	for p in portals:
		if (p as Portal).layer == "nature":
			nature_gate = p
		elif (p as Portal).layer == "science":
			dormant_gate = p
	var nature_sigil_lit := _portal_sigil_lit(nature_gate)
	var dormant_sigil_lit := _portal_sigil_lit(dormant_gate)
	_check("flickering gate lights its layer-motif sigil", nature_sigil_lit)
	_check("dormant gate keeps its sigil unlit", not dormant_sigil_lit)

	# Layer-1 (nature) flickering; the rest dormant.
	_check("nature portal flickering at start", GameState.portal_state("nature") == GameState.PORTAL_FLICKERING)
	var dormant_ok := true
	for lay in ["science", "machine", "magic", "divinity"]:
		if GameState.portal_state(lay) != GameState.PORTAL_DORMANT:
			dormant_ok = false
	_check("portals 2-5 dormant at start", dormant_ok)

	await _teardown()


# ==== C. Portal state machine ==============================================

func _c_portal_sm() -> void:
	print("--- C. Portal state machine ---")
	GameState.reset_portals()
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_scene = await _boot(HOME)

	var nature: Portal = null
	var science: Portal = null
	for n in get_tree().get_nodes_in_group("gatherable"):
		if n is Portal and n.layer == "nature": nature = n
		if n is Portal and n.layer == "science": science = n

	_check("nature adopts flickering state", nature != null and nature.state() == GameState.PORTAL_FLICKERING)
	_check("flickering portal is enterable", nature != null and nature.is_enterable())
	_check("dormant portal is NOT enterable", science != null and not science.is_enterable())

	# Drive dormant→flickering→open on science and confirm the node follows GameState.
	GameState.set_portal_state("science", GameState.PORTAL_FLICKERING)
	await _frames(1)
	_check("science → flickering follows GameState", science.state() == GameState.PORTAL_FLICKERING)
	GameState.set_portal_state("science", GameState.PORTAL_OPEN)
	await _frames(1)
	_check("science → open follows GameState + enterable", science.state() == GameState.PORTAL_OPEN and science.is_enterable())

	await _teardown()


# ==== D. Quests P0 → P1 → Q1 ================================================

func _d_quests() -> void:
	print("--- D. Home quests P0 → P1 → Q1 ---")
	SaveManager.new_game()   # resets quests to head (P0)
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_scene = await _boot(HOME)
	var loader := _scene.get_node("Ground") as MapLoader
	var player := _scene.get_node("YSortLayer/Player") as Node2D

	_check("line begins at P0 on the home island", QuestManager.active_id == "P0",
		"active=%s" % QuestManager.active_id)

	# P0 completes when the player leaves the dais (the QuestAreaWatcher in leave_spawn mode).
	player.global_position = loader.cell_center_world(loader.spawn_cell + Vector2i(0, 3))
	await _frames(3)
	_check("P0 → P1 after leaving the dais edge", QuestManager.active_id == "P1",
		"active=%s" % QuestManager.active_id)

	# P1 completes on portal_reached(nature) (HomeSession emits it on interacting the portal).
	GameState.portal_reached.emit("nature")
	await _frames(2)
	_check("P1 → Q1 after reaching the nature portal", QuestManager.active_id == "Q1",
		"active=%s" % QuestManager.active_id)

	await _teardown()


# ==== E. Travel roundtrip (home ↔ grove) preserves both worlds =============

func _e_travel() -> void:
	print("--- E. Travel roundtrip preserves each world's placed objects ---")
	SaveManager.new_game()

	# 1) Home: place a marker object, snapshot.
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_scene = await _boot(HOME)
	var hloader := _scene.get_node("Ground") as MapLoader
	var hplayer := _scene.get_node("YSortLayer/Player") as Node2D
	var hrespawn := _scene.get_node("ObjectRespawn")
	SaveManager.register_world(hloader, hplayer, hrespawn)
	# Place a decor object on the home island via the interaction controller.
	var hic := _find(_scene, InteractionController) as InteractionController
	Inventory.add("D29", 1)
	hic.set_held_item("D29")
	var hcell := hloader.spawn_cell + Vector2i(2, 0)
	hic.interact_with_cell(hcell)
	await _frames(2)
	var home_placed := get_tree().get_nodes_in_group(PlacedObject.GROUP).size()
	_check("placed a decor object on the home island", home_placed >= 1, "n=%d" % home_placed)
	SaveManager.save_game()   # snapshots the "home" world
	await _teardown()

	# 2) Grove: boot as a portal arrival, place a different object, snapshot.
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	WorldContext.arrival_mode = "portal_arrival"
	SaveManager.pending_load = true    # grove session loads the (empty grove) world
	_scene = await _boot(GROVE)
	var gloader := _scene.get_node("Ground") as MapLoader
	var gplayer := _scene.get_node("YSortLayer/Player") as Node2D
	var grespawn := _scene.get_node("ObjectRespawn")
	SaveManager.register_world(gloader, gplayer, grespawn)
	var grove_placed_before := get_tree().get_nodes_in_group(PlacedObject.GROUP).size()
	_check("grove starts with no placed decor (home's object not leaked here)",
		grove_placed_before == 0, "n=%d" % grove_placed_before)
	SaveManager.save_game()
	await _teardown()

	# 3) Back home: the home decor object is restored from the "home" snapshot.
	WorldContext.current_scene = WorldContext.SCENE_HOME
	SaveManager.pending_load = true
	_scene = await _boot(HOME)
	SaveManager.register_world(_scene.get_node("Ground"), _scene.get_node("YSortLayer/Player"), _scene.get_node("ObjectRespawn"))
	await _frames(2)
	var home_restored := get_tree().get_nodes_in_group(PlacedObject.GROUP).size()
	_check("returning home restores the home world's placed object", home_restored >= 1,
		"n=%d" % home_restored)
	await _teardown()


# ==== F. CS-04 / CS-05 =====================================================

func _f_cutscenes() -> void:
	print("--- F. CS-04 purification + CS-05 return ignition ---")
	SaveManager.new_game()
	QuestManager.advance_to("Q9")   # sit on the plant quest
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	SaveManager.pending_load = false
	_scene = await _boot(GROVE)
	var clear := _find(_scene, ClearSequence) as ClearSequence
	# Detach the grove session's auto-return so the scene stays up for the assert.
	var session := _find(_scene, GroveSession)
	if session != null and clear.cleared.is_connected(session._on_cleared):
		clear.cleared.disconnect(session._on_cleared)

	# CS-04 fires on world_tree_planted.
	var cleared_fired := [false]
	clear.cleared.connect(func(): cleared_fired[0] = true, CONNECT_ONE_SHOT)
	GameState.world_tree_planted.emit(Vector2i(10, 10))
	await _frames(2)
	_check("CS-04 purification active on plant", clear.is_active())
	# Let the tween-driven CS-04 sequence run to completion (~18s of tweens now: flash + ring +
	# dim + 3 cards + v1.3.0 CQ-4 broken-birdsong + 3s silence + rising light). Advance
	# generously so headless frame timing can't clip the tail.
	var budget := 3000
	while not cleared_fired[0] and budget > 0:
		await _frames(1)
		budget -= 1
	_check("CS-04 completes → cleared signal", cleared_fired[0])
	await _teardown()

	# CS-05: drive the PortalCutscene ignition directly and assert its effects.
	GameState.reset_portals()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_scene = await _boot(HOME)
	var pcs := _find(_scene, PortalCutscene) as PortalCutscene
	_check("PortalCutscene present on home", pcs != null)
	QuestManager.advance_to("Q9")   # pretend we just finished the grove
	QuestManager._complete("Q9")    # Q9.next="" → all_quests_completed (as in-game)
	await pcs.play_return_ignition()
	_check("CS-05 opens the nature portal", GameState.portal_state("nature") == GameState.PORTAL_OPEN)
	_check("CS-05 sets science flickering (tease)", GameState.portal_state("science") == GameState.PORTAL_FLICKERING)
	_check("CS-05 opens quest P2 (place on home)", QuestManager.active_id == "P2",
		"active=%s" % QuestManager.active_id)
	await _teardown()


# ==== G. Save schema =======================================================

func _g_save() -> void:
	print("--- G. Scene-keyed save + 구버전 rejection ---")
	SaveManager.new_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	GameState.set_portal_state("nature", GameState.PORTAL_OPEN)
	var d := SaveManager.build_save_dict()
	_check("save version is 2", int(d.get("version", 0)) == 2)
	_check("save has a `worlds` map", d.has("worlds"))
	_check("save records portal_states", d.get("portal_states", {}).get("nature", "") == GameState.PORTAL_OPEN)
	_check("save records world_context.current_scene", d.get("world_context", {}).get("current_scene", "") == WorldContext.SCENE_HOME)

	# A v1 (old) save is rejected as 구버전 (breaking bump).
	var migrated := SaveManager._migrate({"version": 1, "inventory": {}})
	_check("v1 (구버전) save is rejected → fresh start", migrated.is_empty())
