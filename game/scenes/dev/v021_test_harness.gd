extends Node
## v0.2.1 acceptance harness — the two bug fixes + fusion-juice smoke.
##
## Covers (validation §2 "Plus new asserts"):
##   Bug A (draw order): the ground treatment (edge overlays + brightness jitter)
##     must render BELOW the YSortLayer (player + objects). Checked programmatically
##     via tree order + effective z_index comparison (no rendering needed):
##       - EdgeOverlay / BrightnessJitter are children of the Ground tilemap with
##         z values EDGE_OVERLAY_Z / JITTER_Z (z_as_relative → effective 0+z).
##       - YSortLayer.z_index (YSORT_Z) is strictly GREATER, so the player wins.
##       - Assert the jitter node is NOT drawn after the YSortLayer.
##   Bug B (border containment): a StaticBody2D border seals the map. A physics
##     motion test at each of the 4 border midpoints, pushing outward, cannot exit
##     the playable area (the border blocks it).
##   Fusion juice: opening the FusionUI + pressing 조합 on a valid recipe runs the
##     ~1.2s success sequence to a popped result WITHOUT error and with the logic
##     result intact (output added to inventory, codex recipe recorded).
##
## Instances the real starting_grove scene like the M4/M5/M6a harnesses. Prints
## PASS/FAIL and quits with the failure count as exit code.

const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v0.2.1 TEST HARNESS ===")
	Inventory.clear()
	Codex.reset()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var ysort := map.get_node("YSortLayer") as Node2D

	_test_draw_order(map, loader, ysort)
	_test_border_containment(map, loader)
	await _test_fusion_juice(map)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- Bug A: draw order ----------------------------------------------------

func _test_draw_order(map: Node, loader: MapLoader, ysort: Node2D) -> void:
	var edge := loader.get_node_or_null("EdgeOverlay") as Node2D
	# v0.5: BrightnessJitter retired (real CC0 tiles carry their own variation). The
	# Elevation overlay is the new ground-treatment layer; assert its draw order stays
	# below the YSort object layer, preserving the Bug-A invariant.
	var jitter := loader.get_node_or_null("Elevation") as Node2D
	_check("EdgeOverlay present", edge != null)
	_check("Elevation overlay present (jitter retired)", jitter != null)
	_check("YSortLayer present", ysort != null)
	if edge == null or jitter == null or ysort == null:
		return

	# Effective z of the overlays (children of the tilemap, z_as_relative default true)
	# = ground z (0) + their own z_index.
	var ground_z := loader.z_index                      # 0
	var edge_eff := ground_z + edge.z_index             # 0 + 1
	var jitter_eff := ground_z + jitter.z_index         # 0 + HILL_Z
	var ysort_z := ysort.z_index                        # 5

	_check("edge overlay z == EDGE_OVERLAY_Z", edge.z_index == MapLoader.EDGE_OVERLAY_Z)
	_check("elevation z == HILL_Z", jitter.z_index == MapLoader.HILL_Z)
	_check("YSortLayer z == YSORT_Z (%d)" % MapLoader.YSORT_Z, ysort_z == MapLoader.YSORT_Z)

	# The required ordering: ground < edge <= elevation < YSortLayer.
	_check("ground tiles below edge overlays", ground_z < edge_eff)
	_check("edge overlays at/below elevation overlay", edge_eff <= jitter_eff)
	_check("elevation overlay below YSortLayer (player+objects)", jitter_eff < ysort_z)

	# Explicit bug-A assertion: the ground-treatment overlay is NOT drawn after the
	# YSortLayer (so darkened ground can never cover the player).
	_check("elevation overlay NOT drawn after YSortLayer", not (jitter_eff > ysort_z))

	# Glow is on a separate CanvasLayer (always above the root canvas), and the
	# DayNight CanvasModulate tints only the root canvas — so darkened ground can no
	# longer cover the player.
	var glow_layer := map.get_node_or_null("GlowLayer") as CanvasLayer
	_check("GlowLayer is a CanvasLayer above root canvas", glow_layer != null and glow_layer.layer >= 1)


# ---- Bug B: border containment --------------------------------------------

func _test_border_containment(map: Node, loader: MapLoader) -> void:
	var border := loader.get_node_or_null("BorderCollision") as StaticBody2D
	_check("BorderCollision StaticBody2D present", border != null)
	if border == null:
		return
	_check("border has collision children", border.get_child_count() > 0)

	var player := map.get_node("YSortLayer/Player") as CharacterBody2D
	_check("player is a CharacterBody2D", player != null)
	if player == null:
		return

	# Four border midpoints: push the player from just inside each edge toward the
	# outside and assert a physics motion test is blocked (can't exit the map).
	# Interior edge cells (one step inside the VOID band on each side).
	var w := loader.width
	var h := loader.height
	# find a walkable interior cell near each edge midpoint, then test-move outward.
	var mids := [
		{"cell": _inner_edge_cell(loader, Vector2i(w / 2, 0), Vector2i(0, 1)), "dir": Vector2(0, -1), "name": "north"},
		{"cell": _inner_edge_cell(loader, Vector2i(w / 2, h - 1), Vector2i(0, -1), true), "dir": Vector2(0, 1), "name": "south"},
		{"cell": _inner_edge_cell(loader, Vector2i(0, h / 2), Vector2i(1, 0)), "dir": Vector2(-1, 0), "name": "west"},
		{"cell": _inner_edge_cell(loader, Vector2i(w - 1, h / 2), Vector2i(-1, 0), true), "dir": Vector2(1, 0), "name": "east"},
	]
	for m in mids:
		var cell: Vector2i = m["cell"]
		if cell == Vector2i(-1, -1):
			_check("border %s: found an inner edge cell" % m["name"], false)
			continue
		player.global_position = loader.cell_center_world(cell)
		player.velocity = Vector2.ZERO
		# Physics test_move outward by a big step; a collision (return true) means the
		# border blocks exit at this midpoint.
		var dir: Vector2 = m["dir"]
		var motion := dir * 400.0
		var xform := Transform2D(0.0, player.global_position)
		var blocked := player.test_move(xform, motion)
		# Belt-and-suspenders: the target world point outside is inside the border.
		var outside_pt: Vector2 = player.global_position + dir * 260.0
		var in_border := loader.point_in_border(outside_pt)
		_check("border %s midpoint cannot exit the map" % m["name"], blocked or in_border)


## Walk inward from an edge cell (stepping by `step`) until a walkable cell is found;
## that is the cell just inside the playable area at that edge. Returns (-1,-1) if
## none found. `from_far` steps the other way for the far (south/east) edges.
func _inner_edge_cell(loader: MapLoader, start: Vector2i, step: Vector2i, _from_far := false) -> Vector2i:
	var cell := start
	for _i in range(loader.width + loader.height):
		if loader.is_cell_walkable(cell):
			return cell
		cell += step
	return Vector2i(-1, -1)


# ---- Fusion juice smoke ---------------------------------------------------

func _test_fusion_juice(map: Node) -> void:
	var fusion_ui := map.get_node_or_null("FusionUI")
	_check("FusionUI present", fusion_ui != null)
	if fusion_ui == null:
		return

	# Give the two ingredients for a known recipe (R07: I5 꽃 + I2 풀 → D54 초원) and
	# drive the UI's real fuse path so the juice sequence runs end-to-end.
	Inventory.add("I5", 2)
	Inventory.add("I2", 2)
	var recipes_before := Codex.discovered_recipe_count()

	fusion_ui.call("open")
	await get_tree().process_frame
	# Fill both input slots via the real strip handler, then press 조합.
	fusion_ui.call("_on_strip_pressed", "I5")
	fusion_ui.call("_on_strip_pressed", "I2")
	fusion_ui.call("_on_fuse_pressed")

	# Let the ~1.2s sequence run to completion (plus margin) without error.
	for _i in range(120):
		await get_tree().process_frame

	_check("fusion logic intact: D54 초원 crafted", Inventory.count("D54") >= 1)
	_check("fusion logic intact: recipe recorded in codex",
		Codex.discovered_recipe_count() > recipes_before)
	_check("juice sequence finished (not stuck animating)",
		not bool(fusion_ui.get("_animating")))
	# The result slot popped in with the crafted item's name.
	var rname: Label = fusion_ui.get("_result_name")
	_check("result card shows the crafted item",
		rname != null and String(rname.text) == ItemDB.item_name("D54"))

	# Skip-by-click path: run a second fuse and immediately skip.
	Inventory.add("I5", 2)
	Inventory.add("I2", 2)
	fusion_ui.call("_on_strip_pressed", "I5")
	fusion_ui.call("_on_strip_pressed", "I2")
	fusion_ui.call("_on_fuse_pressed")
	# Immediately request a skip (as a mid-sequence click would).
	if bool(fusion_ui.get("_animating")):
		fusion_ui.call("_skip_sequence")
	await get_tree().process_frame
	_check("click-skip jumps straight to result (not animating)",
		not bool(fusion_ui.get("_animating")) and Inventory.count("D54") >= 2)
