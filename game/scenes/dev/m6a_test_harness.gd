extends Node
## M6a acceptance harness — map visual polish (seamless ground + density) + touch.
##
## Covers (per M6a acceptance §2):
##   - object count in the target range & none on path/gate/spawn cells
##   - scatter determinism: two independent loads → identical object positions
##   - edge-overlay sprites appear where grass borders water / dirt / mud
##   - AStar path from spawn to a reachable hill/home cell exists
##   - G1 water cell becomes pathable after a D14 stepping stone (grid refresh)
##   - tap-to-move: call move_to(cell) → player arrives within N frames
##
## Instances the real starting_grove scene (deterministic base map) like the M4/M5
## harnesses. Prints PASS/FAIL and quits with the failure count as exit code.

const GROVE := "res://scenes/world/starting_grove.tscn"
const TARGET_MIN := 150
const TARGET_MAX := 180

var _fail := 0


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== M6a TEST HARNESS ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var touch := map.get_node("TouchController") as TouchController

	_test_object_count(loader)
	_test_no_blocking_cells(loader)
	await _test_determinism(loader)
	_test_edge_overlays(loader)
	_test_astar_reachable(loader, touch)
	await _test_g1_refresh(map, loader, touch)
	await _test_tap_to_move(loader, touch)
	await _test_slot_hint(map, loader)
	_test_glow_layer_separation(map)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A/B: object density + safety ----------------------------------------

func _test_object_count(loader: MapLoader) -> void:
	var n := loader.object_spawns.size()
	print("    object_spawns = %d (target %d..%d)" % [n, TARGET_MIN, TARGET_MAX])
	_check("object count in target range", n >= TARGET_MIN and n <= TARGET_MAX)


func _test_no_blocking_cells(loader: MapLoader) -> void:
	# No scattered/authored gatherable may sit on a D path tile, a gate cell, the
	# spawn 3×3, or on a non-ground tile.
	var ok := true
	var spawn := loader.spawn_cell
	for entry in loader.object_spawns:
		var cell: Vector2i = entry["cell"]
		var sym := _layout_sym(loader, cell)
		# authored objects (T/F/R/s in the layout) sit on their own G/g cell too;
		# scatter adds only on plain ground. Assert every spawn is on ground and
		# not on a path/gate/spawn-safe cell.
		if sym != "G" and sym != "g" and sym != "T" and sym != "F" \
				and sym != "R" and sym != "s":
			ok = false
			print("    object on non-ground cell %s '%s'" % [cell, sym])
		if _layout_sym(loader, cell) == "D":
			ok = false
		if absi(cell.x - spawn.x) <= 1 and absi(cell.y - spawn.y) <= 1:
			ok = false
			print("    object inside spawn 3x3 at %s" % cell)
	# Also: no scatter within 1 cell of a D path / gate (topology safety) — check a
	# representative set (all scattered symbols t/h are pure scatter).
	for entry in loader.object_spawns:
		var cell: Vector2i = entry["cell"]
		if entry["symbol"] != "t" and entry["symbol"] != "h":
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var s := _layout_sym(loader, cell + Vector2i(dx, dy))
				if s == "D" or s == "K" or s == "N" or s == "B" or s == "O" \
						or s == "C" or s == "U" or s == "S" or s == "m":
					ok = false
					print("    scatter %s too close to '%s'" % [cell, s])
	_check("no objects on path/gate/spawn/topology cells", ok)


func _layout_sym(loader: MapLoader, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= loader._layout.size():
		return ""
	var row: String = loader._layout[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


func _test_determinism(loader: MapLoader) -> void:
	# Instance a second fresh grove; its scatter must land on identical cells.
	var scene: PackedScene = load(GROVE)
	var map2 := scene.instantiate()
	add_child(map2)
	await get_tree().process_frame
	await get_tree().process_frame
	var loader2 := map2.get_node("Ground") as MapLoader

	var a := _spawn_set(loader)
	var b := _spawn_set(loader2)
	var identical := a.size() == b.size()
	if identical:
		for key in a:
			if not b.has(key) or b[key] != a[key]:
				identical = false
				break
	_check("scatter deterministic (two loads identical)", identical)
	map2.queue_free()
	await get_tree().process_frame


func _spawn_set(loader: MapLoader) -> Dictionary:
	# cell "c,r" -> symbol, order-independent.
	var out := {}
	for entry in loader.object_spawns:
		var cell: Vector2i = entry["cell"]
		out["%d,%d" % [cell.x, cell.y]] = entry["symbol"]
	return out


# ---- A: edge overlays ----------------------------------------------------

func _test_edge_overlays(loader: MapLoader) -> void:
	var overlay := loader.get_node_or_null("EdgeOverlay")
	_check("edge overlay node present", overlay != null)
	if overlay == null:
		return
	_check("edge overlay has sprites", overlay.get_child_count() > 0)

	# For each material, assert at least one overlay sits on a grass cell that
	# actually borders that material — the "seamless border" guarantee.
	var found := {"water": false, "dirt": false, "mud": false}
	for s in overlay.get_children():
		if not (s is Sprite2D):
			continue
		var cell: Vector2i = loader.local_to_map((s as Sprite2D).position)
		if not (loader.get_cell_source_id(cell) >= 2 and loader.get_cell_source_id(cell) <= 5):
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			match loader.get_cell_source_id(cell + d):
				1: found["dirt"] = true
				7: found["mud"] = true
				8, 9: found["water"] = true
	_check("edge overlays present at grass↔water border", found["water"])
	_check("edge overlays present at grass↔dirt border", found["dirt"])
	_check("edge overlays present at grass↔mud border", found["mud"])

	# Spot-check a known border coord from the layout: grass (4,23) sits directly
	# above the pond water row (4,24 = 'W').
	_check("known coord (4,23) is grass over water (4,24)",
		_layout_sym(loader, Vector2i(4, 23)) in ["G", "g"]
		and _layout_sym(loader, Vector2i(4, 24)) == "W")
	_check("overlay exists at known border cell (4,23)",
		_has_overlay_at(loader, overlay, Vector2i(4, 23)))


func _has_overlay_at(loader: MapLoader, overlay: Node, cell: Vector2i) -> bool:
	for s in overlay.get_children():
		if s is Sprite2D and loader.local_to_map((s as Sprite2D).position) == cell:
			return true
	return false


# ---- C: pathfinding + tap-to-move ----------------------------------------

func _test_astar_reachable(loader: MapLoader, touch: TouchController) -> void:
	# A reachable home-zone cell near spawn: pick a walkable grass cell a few tiles
	# away and assert AStar finds a path from spawn to it.
	var dest := _find_walkable_near(loader, loader.spawn_cell, 6)
	_check("found a reachable test cell", dest != Vector2i(-1, -1))
	if dest == Vector2i(-1, -1):
		return
	var path: bool = touch.call("_path_to_cell", dest)
	_check("AStar path spawn→reachable cell exists", path and loader.get_node("../YSortLayer/Player") != null)
	# player begins pathing toward it
	var player := loader.get_node("../YSortLayer/Player") as Player
	_check("player has a queued path after path request", player.is_pathing())
	player.clear_path()


func _find_walkable_near(loader: MapLoader, origin: Vector2i, radius: int) -> Vector2i:
	# spiral out from origin for a walkable grass cell (source 2..5) at distance >=3.
	for rad in range(3, radius + 1):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if absi(dx) + absi(dy) != rad:
					continue
				var cell: Vector2i = origin + Vector2i(dx, dy)
				var src := loader.get_cell_source_id(cell)
				if src >= 2 and src <= 5 and loader.is_cell_walkable(cell):
					return cell
	return Vector2i(-1, -1)


func _test_g1_refresh(map: Node, loader: MapLoader, touch: TouchController) -> void:
	# A K stepping-stone slot is water (non-walkable) → AStar treats it solid.
	var k: Vector2i = loader.stepping_slot_cells[0]
	_check("G1 slot starts non-walkable", not loader.is_cell_walkable(k))
	# Place D14 (swap to walkable source 1) via the interaction effect, exactly as
	# the real placement path does; this emits stepping_stone_placed → grid refresh.
	var interaction := map.get_node("Interaction") as InteractionController
	Inventory.add("D14", 1)
	interaction.set_held_item("D14")
	var placed: bool = interaction.call("_try_place_on_tile", k)
	await get_tree().process_frame  # let the deferred/immediate refresh run
	touch.refresh_grid()            # explicit (the signal also triggers it)
	_check("G1 slot walkable after D14", placed and loader.is_cell_walkable(k))
	# Now the AStar grid should route THROUGH the stone: a path onto the K cell.
	var onto: bool = touch.call("_path_to_cell", k)
	_check("AStar routes onto the placed stepping stone", onto)
	(loader.get_node("../YSortLayer/Player") as Player).clear_path()


func _test_tap_to_move(loader: MapLoader, touch: TouchController) -> void:
	var player := loader.get_node("../YSortLayer/Player") as Player
	# Reset player to spawn.
	player.global_position = loader.cell_center_world(loader.spawn_cell)
	player.clear_path()
	await get_tree().process_frame

	var dest := _find_walkable_near(loader, loader.spawn_cell, 5)
	_check("tap target cell found", dest != Vector2i(-1, -1))
	if dest == Vector2i(-1, -1):
		return
	var target_world := loader.cell_center_world(dest)
	var ok: bool = touch.move_to(dest)
	_check("move_to(cell) queued a path", ok and player.is_pathing())

	# Simulate frames until arrival (bounded).
	var arrived := false
	for i in range(600):
		await get_tree().physics_frame
		if player.global_position.distance_to(target_world) <= 10.0:
			arrived = true
			break
	print("    arrived within-tolerance: dist=%.1f" % player.global_position.distance_to(target_world))
	_check("tap-to-move: player arrives within N frames", arrived)


# ---- M6c QA polish: G1 slot hint + glow-layer separation -----------------

func _test_slot_hint(map: Node, loader: MapLoader) -> void:
	# (Fix 1a) Holding D14 pulses a diamond over every un-filled (still-water)
	# stepping slot; releasing D14 clears them.
	var interaction := map.get_node("Interaction") as InteractionController
	var hint := map.get_node("SteppingSlotHint")
	_check("SteppingSlotHint node present", hint != null)
	if hint == null:
		return

	# Count remaining water slots so the highlight count is meaningful.
	var water_slots := 0
	for cell in loader.stepping_slot_cells:
		var src := loader.get_cell_source_id(cell)
		if src == 8 or src == 9 or src == 10:
			water_slots += 1

	# Not holding D14 → no hint diamonds.
	interaction.set_held_item("")
	await get_tree().process_frame
	_check("slot hint hidden when D14 not held", hint.call("get_highlight_count") == 0)

	# Hold D14 → one diamond per remaining water slot (> 0).
	Inventory.add("D14", 1)
	interaction.set_held_item("D14")
	await get_tree().process_frame
	var n: int = hint.call("get_highlight_count")
	print("    slot-hint diamonds while holding D14 = %d (water slots = %d)" % [n, water_slots])
	_check("slot hint appears when D14 held (count > 0)", n > 0 and n == water_slots)

	# Release again → cleared.
	interaction.set_held_item("")
	await get_tree().process_frame
	_check("slot hint clears when D14 released", hint.call("get_highlight_count") == 0)
	Inventory.clear()


func _test_glow_layer_separation(map: Node) -> void:
	# (Fix 2) Glow sprites must NOT sit under the CanvasModulate-affected canvas.
	# The DayNight CanvasModulate lives on the root (layer-0) canvas; glow sprites
	# reparent onto the GlowLayer CanvasLayer (layer 1), so the day/night tint can't
	# dim them. Assert: a glow layer exists, holds glows, and no GlowSprite is a
	# descendant of the DayNight canvas (i.e. its nearest CanvasLayer ancestor is the
	# GlowLayer, not the default root canvas the CanvasModulate tints).
	var daynight := map.get_node_or_null("DayNight")
	var glow_layer := map.get_node_or_null("GlowLayer")
	_check("DayNight CanvasModulate present", daynight != null)
	_check("GlowLayer CanvasLayer present", glow_layer != null)
	if glow_layer == null:
		return
	_check("GlowLayer is layer 1 (above ground, own canvas)", glow_layer.layer == 1)

	var glows := _find_glow_sprites(map)
	print("    glow sprites found = %d" % glows.size())
	_check("glow sprites exist in scene", glows.size() > 0)

	var all_on_glow_layer := true
	for g in glows:
		if _nearest_canvas_layer(g) != glow_layer:
			all_on_glow_layer = false
			print("    glow NOT on GlowLayer: %s" % g.get_path())
	_check("no GlowSprite descends the CanvasModulate canvas (all on GlowLayer)",
		all_on_glow_layer)


func _find_glow_sprites(node: Node) -> Array:
	var out: Array = []
	if node is GlowSprite:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_glow_sprites(c))
	return out


## Nearest CanvasLayer ancestor of a node (the canvas it actually renders on), or
## null if it renders on the viewport's default/root canvas (the one CanvasModulate
## on the root tints).
func _nearest_canvas_layer(node: Node) -> CanvasLayer:
	var p := node.get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null
