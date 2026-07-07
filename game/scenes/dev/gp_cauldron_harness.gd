extends Node
## v1.1.0 GP-1 UNIFIED CAULDRON harness — §5 「어디서나 솥단지」 스킨 통일 검증.
##
## v1.0.4 already made every L2-L5 crafting station a REAL Cauldron (interaction_fusion_harness
## covers that E-조합 path). GP-1 is the VISUAL unification: the layer stations must now wear the
## SHARED cauldron art with the live brew animation (not the per-layer l*_workbench skin), and the
## only per-layer identity is the FLAME (light pool) color:
##   home/L1 = violet · L2 = cyan · L3 = orange · L4 = gold · L5 = amber
##
## For each layer this harness boots the live scene and asserts:
##   1. The station is a Cauldron in the gatherable group (interaction contract intact).
##   2. It is NOT a static skin (_static_skin == false) → brew animation is live (shared cauldron).
##   3. Its texture is the shared cauldron.png (not l*_workbench.png).
##   4. A light pool with the EXPECTED per-layer color texture is present near the station.
##
## No Fusion.fuse()/on_interact() shortcuts — pure world-state inspection. Exit code = fail count.

const LAYERS := [
	{"id": "home",  "path": "res://scenes/world/home_island.tscn",     "scene": "HomeIsland",     "wc": "home",             "pool": "light_pool_violet.png"},
	{"id": "L1",    "path": "res://scenes/world/starting_grove.tscn",  "scene": "StartingGrove",  "wc": "grove",            "pool": "light_pool_violet.png"},
	{"id": "L2",    "path": "res://scenes/world/terminal_station.tscn","scene": "TerminalStation","wc": "terminal_station", "pool": "light_pool_cyan.png"},
	{"id": "L3",    "path": "res://scenes/world/clockwork_city.tscn",  "scene": "ClockworkCity",  "wc": "clockwork_city",   "pool": "light_pool_orange.png"},
	{"id": "L4",    "path": "res://scenes/world/mage_tower.tscn",      "scene": "MageTower",      "wc": "mage_tower",       "pool": "light_pool_gold.png"},
	{"id": "L5",    "path": "res://scenes/world/cathedral.tscn",       "scene": "Cathedral",      "wc": "cathedral",        "pool": "light_pool_amber.png"},
]

const SHARED_TEX := "cauldron.png"

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

func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1

func _scene_name() -> String:
	return _tree.current_scene.name if _tree.current_scene != null else "<null>"

func _run() -> void:
	print("=== v1.1.0 GP-1 UNIFIED CAULDRON HARNESS ===")
	for layer in LAYERS:
		await _test_layer(layer)
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)

func _test_layer(layer: Dictionary) -> void:
	var lid: String = layer["id"]
	print("--- %s: unified cauldron ---" % lid)
	SaveManager.new_game()
	WorldContext.current_scene = layer["wc"]
	_tree.change_scene_to_file(layer["path"])
	await _frames(16)  # sessions spawn the station on deferred frames
	if _scene_name() != layer["scene"]:
		_check("%s: scene booted" % lid, false, _scene_name())
		return

	var caul := _find_cauldron()
	_check("%s: crafting station is a Cauldron (gatherable)" % lid, caul != null)
	if caul == null:
		return

	# The shared cauldron keeps the live brew animation (NOT a static workbench skin).
	_check("%s: NOT static skin → live brew animation" % lid,
		not bool(caul.get("_static_skin")))

	# Texture is the shared cauldron art, not a l*_workbench skin.
	var tex_path := ""
	if caul.texture != null:
		tex_path = caul.texture.resource_path
	_check("%s: wears the SHARED cauldron art" % lid,
		tex_path.ends_with(SHARED_TEX),
		"tex='%s'" % tex_path)

	# A light pool with the expected per-layer flame color is present (it reparents to the glow
	# layer on a deferred call, so we scan ALL LightPool nodes in the tree by texture path).
	var want: String = layer["pool"]
	_check("%s: flame color = %s" % [lid, want], _has_pool_with_texture(want),
		"want='%s'" % want)

# ---- helpers --------------------------------------------------------------

func _find_cauldron() -> Cauldron:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n is Cauldron:
			return n
	return null

## True if any LightPool anywhere in the current scene tree uses the given texture filename.
## (LightPool reparents onto the glow_layer CanvasLayer, so we search the whole scene.)
func _has_pool_with_texture(tex_name: String) -> bool:
	return _scan_pool(_tree.current_scene, tex_name)

func _scan_pool(node: Node, tex_name: String) -> bool:
	if node == null:
		return false
	if node is LightPool:
		var t := (node as LightPool).texture
		if t != null and t.resource_path.ends_with(tex_name):
			return true
	for c in node.get_children():
		if _scan_pool(c, tex_name):
			return true
	return false
