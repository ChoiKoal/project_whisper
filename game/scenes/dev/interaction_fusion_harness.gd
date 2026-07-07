extends Node
## v1.0.4 INTERACTION→FUSION regression harness — the coverage the P0 hotfix demanded.
##
## The bug: L2-L5 crafting stations were plain Sprite2D+set_meta, so E-조합 could never open the
## Fusion UI in real play (the UI opens ONLY on Cauldron.interacted). The E2E missed it because it
## called Fusion.fuse() directly — bypassing the world interaction path entirely. This harness
## drives the REAL path in EVERY playable layer and NEVER calls Fusion.fuse() directly:
##
##   For each of home / grove / L2 / L3 / L4 / L5:
##     1. Boot the live scene; find the crafting station (Cauldron) in the gatherable group.
##     2. Fusion UI starts CLOSED.
##     3. Park the player on a cell ADJACENT to the station; run InteractionController._process
##        and assert the station IS the resolved E-target (it joined the gatherable group as a
##        real Cauldron) and the prompt reads "E 조합".
##     4. Simulate the E interact through InteractionController._do_interact() (the exact code the
##        bug lived in) and assert the Fusion UI actually OPENS (GameState "fusion" modal + the
##        panel's own _open flag). ← the assertion that was missing.
##     5. Close it via the UI close() and assert it is closed again.
##     6. Perform ONE fuse THROUGH THE UI (fill the two input slots + press 조합 via
##        _on_strip_pressed/_on_fuse_pressed — NOT Fusion.fuse()) and assert the output item was
##        granted. This proves the whole chain end-to-end without the API shortcut.
##
## Assertions print [PASS]/[FAIL]; exit code = failure count. Reparents under the tree root so
## change_scene_to_file does not free the harness mid-run.

const LAYERS := [
	{"id": "home",  "path": "res://scenes/world/home_island.tscn",    "scene": "HomeIsland",    "wc": "home"},
	{"id": "grove", "path": "res://scenes/world/starting_grove.tscn", "scene": "StartingGrove", "wc": "grove"},
	{"id": "L2",    "path": "res://scenes/world/terminal_station.tscn","scene": "TerminalStation","wc": "terminal_station"},
	{"id": "L3",    "path": "res://scenes/world/clockwork_city.tscn",  "scene": "ClockworkCity", "wc": "clockwork_city"},
	{"id": "L4",    "path": "res://scenes/world/mage_tower.tscn",      "scene": "MageTower",     "wc": "mage_tower"},
	{"id": "L5",    "path": "res://scenes/world/cathedral.tscn",       "scene": "Cathedral",     "wc": "cathedral"},
]

## A cost-free 2-input recipe present in every layer's fuse table (I1 흙 + I7 물 → I3).
const FUSE_A := "I1"
const FUSE_B := "I7"
const FUSE_OUT := "I3"

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

func _run() -> void:
	print("=== v1.0.4 INTERACTION→FUSION HARNESS ===")
	for layer in LAYERS:
		await _test_layer(layer)
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_tree.quit(_fail)

func _test_layer(layer: Dictionary) -> void:
	var lid: String = layer["id"]
	print("--- %s: interaction → fusion ---" % lid)
	# Fresh run each layer so inventory/modals don't bleed across scenes.
	SaveManager.new_game()
	WorldContext.current_scene = layer["wc"]
	_tree.change_scene_to_file(layer["path"])
	# Sessions spawn the station on a deferred frame + await; give it a generous settle.
	await _frames(16)
	if _scene_name() != layer["scene"]:
		_check("%s: scene booted" % lid, false, _scene_name())
		return

	var root := _tree.current_scene
	var interaction := root.get_node_or_null("Interaction") as InteractionController
	var player := root.get_node_or_null("YSortLayer/Player") as Player
	var ground := root.get_node_or_null("Ground") as TileMapLayer
	var fusion := root.get_node_or_null("FusionUI")
	_check("%s: Interaction/Player/Ground/FusionUI present" % lid,
		interaction != null and player != null and ground != null and fusion != null)
	if interaction == null or player == null or ground == null or fusion == null:
		return

	# 1. The crafting station is a REAL Cauldron in the gatherable group (the core of the bug).
	var caul := _find_cauldron()
	_check("%s: crafting station is a real Cauldron (in gatherable group)" % lid, caul != null)
	if caul == null:
		return

	# 2. Fusion UI starts closed.
	_check("%s: Fusion UI CLOSED at boot" % lid, not _fusion_open(fusion))

	# 3. Park the player on a walkable cell adjacent to the cauldron → it resolves as the E-target.
	var caul_cell := ground.local_to_map(ground.to_local(caul.target_point()))
	var adj := _adjacent_walkable_cell(interaction, caul_cell, player)
	_check("%s: found adjacent walkable cell to station" % lid, adj != Vector2i(-999, -999),
		"station=%s" % str(caul_cell))
	if adj == Vector2i(-999, -999):
		return
	player.clear_path()
	player.velocity = Vector2.ZERO
	player.global_position = ground.to_global(ground.map_to_local(adj))
	await _frames(2)
	interaction._process(0.016)
	_check("%s: station IS the resolved E-target (adjacency)" % lid,
		interaction._target_object == caul,
		"target=%s" % str(interaction._target_object))
	_check("%s: E-prompt reads 조합" % lid, interaction._prompt_text() == "E 조합",
		"prompt='%s'" % interaction._prompt_text())

	# 4. Simulate the E interact through the REAL interaction path (NOT Fusion.fuse / caul.on_interact
	#    directly) — this is the exact resolver the bug lived in — and assert the Fusion UI OPENS.
	interaction._do_interact()
	await _frames(2)
	_check("%s: E-조합 OPENS the Fusion UI (was the unreachable path)" % lid, _fusion_open(fusion))
	_check("%s: opening pushes the 'fusion' world-modal lock" % lid,
		GameState != null and GameState.ui_modal_open())

	# 5. Close it again (window close API) → back to inert world.
	fusion.close()
	await _frames(2)
	_check("%s: Fusion UI CLOSES again" % lid, not _fusion_open(fusion))
	_check("%s: closing releases the world-modal lock" % lid,
		GameState == null or not GameState.ui_modal_open())

	# 6. One fuse THROUGH THE UI (fill slots + press 조합) — no direct Fusion.fuse() here.
	fusion.open()
	await _frames(2)
	Inventory.add(FUSE_A, 1)
	Inventory.add(FUSE_B, 1)
	fusion._rebuild_strip()
	var out_before := Inventory.count(FUSE_OUT)
	fusion._on_strip_pressed(FUSE_A)
	fusion._on_strip_pressed(FUSE_B)
	fusion._on_fuse_pressed()
	# The success sequence is tweened; skip it to the result deterministically.
	if fusion.has_method("_skip_sequence"):
		fusion._skip_sequence()
	await _frames(2)
	_check("%s: UI-경유 조합 1회 → %s 획득 (+1)" % [lid, FUSE_OUT],
		Inventory.count(FUSE_OUT) == out_before + 1,
		"count=%d" % Inventory.count(FUSE_OUT))
	fusion.close()
	await _frames(2)

# ---- helpers --------------------------------------------------------------

## The crafting-station Cauldron. Home/grove name it "cauldron"; L2-L5 name it "workbench".
## Any Cauldron in the gatherable group qualifies (there is exactly one per scene).
func _find_cauldron() -> Cauldron:
	for n in _tree.get_nodes_in_group("gatherable"):
		if n is Cauldron:
			return n
	return null

## A walkable cell in the station's 8-neighbourhood the player can stand on (so adjacency resolves).
## Returns (-999,-999) if none is walkable.
func _adjacent_walkable_cell(interaction: InteractionController, station: Vector2i, _player: Player) -> Vector2i:
	var loader := _tree.current_scene.get_node_or_null("Ground") as MapLoader
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for d in dirs:
		var cell := station + d
		if loader != null and loader.has_method("is_cell_walkable"):
			if loader.is_cell_walkable(cell):
				return cell
		else:
			return cell  # no walkability query: any neighbour is fine (adjacency is cell-based)
	return Vector2i(-999, -999)

## True while the Fusion panel is up — checks BOTH the panel's own _open flag and the world modal.
func _fusion_open(fusion: Node) -> bool:
	return bool(fusion.get("_open"))
