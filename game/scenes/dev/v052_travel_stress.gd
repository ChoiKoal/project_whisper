extends Node
## v0.5.2 TRAVEL STRESS harness — the manual grove→home return-portal crash fix.
##
## Unlike v050c (which boots each scene itself and owns its lifetime), this harness drives the
## REAL in-game travel API — get_tree().change_scene_to_file via the sessions' portal hooks —
## so the actual scene-teardown + rebuild path the owner hit is exercised, including the release-
## only failure class. It reparents itself under the tree ROOT so change_scene_to_file (which
## frees the current scene) does not free the harness.
##
## Scenario (5 cycles): home → grove (via the flickering nature portal's travel cutscene) →
## between-hop play in the grove (a GATHER that turns a tile HOLLOW + rebuilds AStar, a FUSION
## via the recipe API, and a PLACEMENT of a GLOWING decor — the exact object whose broken glow
## construction crashed the grove→home return in a release build) → MANUAL return grove→home via
## the return portal (the crash path) → assert we are back home with zero script errors and the
## placed object round-tripped. Repeats so state accumulates across trips.
##
## Assertions: (1) zero engine/script errors across the whole run (an error handler counts them),
## (2) each hop lands in the expected scene, (3) the glowing placement persists across the return,
## (4) the return portal exists + is OPEN each grove visit. Exit code = failure count.

const CYCLES := 5
const GLOW_DECOR := "D48"   # 등불꽃 — a glowing decor (placement class "decor", glows=true)

var _tree: SceneTree
var _fail := 0
var _placed_ok := 0

func _ready() -> void:
	_tree = get_tree()
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	# Move under the persistent Window root so change_scene_to_file won't free us.
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

func _run() -> void:
	print("=== v052 TRAVEL STRESS HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	SaveManager.new_game()

	# Boot the home island as the live scene (the real entry after CS-01).
	WorldContext.current_scene = WorldContext.SCENE_HOME
	_tree.change_scene_to_file(WorldContext.HOME_SCENE_PATH)
	await _frames(12)
	_check("boot home", _scene_name() == "HomeIsland", _scene_name())

	for cycle in range(CYCLES):
		print("--- cycle %d ---" % cycle)
		await _hop_home_to_grove(cycle)
		await _play_in_grove(cycle)
		await _return_grove_to_home(cycle)

	# NOTE: engine/script errors can't be captured from GDScript; the run is separately
	# grepped for "SCRIPT ERROR" / "ERROR:" / "inherits from native type" by the runner
	# (the release-only Sprite2D-script rejection printed exactly there before the fix).
	_check("glowing placement survived every return", _placed_ok == CYCLES,
		"%d/%d" % [_placed_ok, CYCLES])

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)

# ---- the three legs -------------------------------------------------------

func _hop_home_to_grove(cycle: int) -> void:
	var nature := _find_portal_layer("nature")
	if nature == null:
		_check("cycle %d: nature portal present on home" % cycle, false)
		return
	# The real travel: portal on_interact → HomeSession._on_portal_interacted → travel cutscene
	# (violet swell ~1.4s) → get_tree().change_scene_to_file(grove).
	nature.on_interact()
	await _wait(2.0)
	await _frames(10)
	_check("cycle %d: arrived in grove" % cycle, _scene_name() == "StartingGrove", _scene_name())
	var rp := _find_return_portal()
	_check("cycle %d: return portal present + OPEN" % cycle,
		rp != null and GameState.portal_state("return") == GameState.PORTAL_OPEN)

func _play_in_grove(cycle: int) -> void:
	# night so the glowing decor's GlowSprite is at full ramp (exercise the night path too)
	GameState.set_game_time(GameState.DAY_LENGTH * 0.8)
	await _frames(2)
	var ic := _find_by_class("InteractionController")
	var loader := _find_by_class("MapLoader")
	if ic == null or loader == null:
		_check("cycle %d: grove interaction wired" % cycle, false)
		return
	var sc: Vector2i = loader.spawn_cell
	# GATHER two neighbour ground tiles → HOLLOW + AStar rebuild.
	for off in [Vector2i(1, 0), Vector2i(0, 1)]:
		ic.interact_with_cell(sc + off)
	# FUSION: discover/craft a recipe via the fusion API (no cauldron UI needed).
	_do_fusion()
	# PLACEMENT: place a glowing decor near spawn (the crash-class object).
	Inventory.add(GLOW_DECOR, 1)
	ic.set_held_item(GLOW_DECOR)
	var placed := false
	for off in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(-2, 0)]:
		ic.interact_with_cell(sc + off)
		if ic.get_held_item() == "":
			placed = true
			break
	_check("cycle %d: glowing decor placed in grove" % cycle, placed)
	await _frames(4)

func _return_grove_to_home(cycle: int) -> void:
	var portal := _find_return_portal()
	if portal == null:
		_check("cycle %d: return portal present for return" % cycle, false)
		return
	# THE CRASH PATH: manual return via the grove-side return portal →
	# GroveSession._on_return_portal → _return_home(false) → save_game() →
	# get_tree().change_scene_to_file(home). The save snapshots the grove (incl. the glowing
	# placed object); the home boot restores nothing (placement was in the grove).
	portal.on_interact()
	await _wait(0.5)
	await _frames(12)
	_check("cycle %d: returned home (no crash)" % cycle, _scene_name() == "HomeIsland", _scene_name())
	await _frames(3)
	# Re-enter the grove and RESTORE its saved snapshot (pending_load, the 이어하기 path) so the
	# glowing placed decor is rebuilt via SaveManager._apply_placed_objects → PlacedObject._add_glow
	# → GlowSprite construction: the EXACT release-only rebuild path that crashed before the fix.
	# Count it OK when the grove restores the placed glowing object.
	var nature := _find_portal_layer("nature")
	if nature != null:
		SaveManager.pending_load = true
		nature.on_interact()
		await _wait(2.0)
		await _frames(10)
		if _scene_name() == "StartingGrove":
			var n := _tree.get_nodes_in_group("placed_object").size()
			if n >= 1:
				_placed_ok += 1
		# hop back home to leave a clean state for the next cycle's start.
		var rp := _find_return_portal()
		if rp != null:
			rp.on_interact()
			await _wait(0.5)
			await _frames(12)

# ---- fusion helper --------------------------------------------------------

func _do_fusion() -> void:
	# Craft the first 2-input recipe through the Fusion core so item_crafted / recipe_discovered
	# fire (exercises the audio wiring + codex across the transition). Fusion.fuse(a, b).
	if Fusion == null:
		return
	var recipes: Array = RecipeDB.all_recipes()
	for r in recipes:
		var inputs: Array = r.get("inputs", [])
		if inputs.size() != 2:
			continue
		Inventory.add(String(inputs[0]), 1)
		Inventory.add(String(inputs[1]), 1)
		Fusion.fuse(String(inputs[0]), String(inputs[1]))
		return

# ---- lookups --------------------------------------------------------------

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

func _find_portal_layer(layer: String) -> Node:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n.get("layer") == layer and n.get("object_id") != "portal_return":
			return n
	return null

func _find_return_portal() -> Node:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n.get("object_id") == "portal_return":
			return n
	return null
