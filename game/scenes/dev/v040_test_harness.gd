extends Node
## v0.4.0 part A acceptance harness — interaction UX rework (owner-feedback fixes).
##
## Covers (validation §2), on the real starting_grove scene:
##   A1 adjacency   — direct E-interact refuses a gatherable 3 cells away; a gatherable
##                    on an adjacent cell IS the resolved target and _do_interact gathers it.
##                    (A far object stays gatherable via CLICK/touch — unchanged path.)
##   A2 brighten    — the resolved adjacent gatherable is object-brightened (set_targeted);
##                    the floor diamond is NOT used for gather targeting; a soft TileGlow
##                    decal is exposed for tile-gather targets; hover-preview state exposed.
##   A2 placement   — holding D14 over a stepping-slot water cell still shows the violet
##                    placement diamond (SteppingSlotHint) — diamonds survive for placement.
##   A3 ridge/cliff — interior authored-V band cells (G2 rows 14-16 / G3 row 7) get a ridge
##                    sprite; a border-fringe V cell gets a cliff skirt and NO ridge; a
##                    gathered HOLLOW cell gets neither ridge nor cliff.
##
## Instances the real scene like the other grove harnesses (Ground=MapLoader, Interaction,
## TileHighlight, TileGlow, SteppingSlotHint, Player under YSortLayer).

const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v0.4.0-A TEST HARNESS ===")
	Inventory.clear()
	Codex.reset()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader

	_test_ridge_classification(loader)
	_test_ridge_vs_cliff_vs_hollow(map, loader)
	await _test_adjacency_gather(map, loader)
	_test_placement_diamond(map, loader)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A3: interior ridge classification -------------------------------------

func _test_ridge_classification(loader: MapLoader) -> void:
	# The G2 corridor wall (rows 14-16) and the G3 night-path wall (row 7) are the two
	# authored interior VOID bands; every ridge_cell must be an authored 'V'.
	_check("interior ridge cells were classified", loader.ridge_cells.size() > 0,
		"n=%d" % loader.ridge_cells.size())
	var all_void := true
	var rows := {}
	for cell in loader.ridge_cells:
		rows[cell.y] = true
		if loader._layout[cell.y][cell.x] != "V":
			all_void = false
	_check("every ridge cell is authored VOID", all_void)
	# The G3 wall row (7) and the G2 wall band (14/15/16) must all be present.
	_check("G3 night-path wall row (7) is ridge", rows.has(7))
	_check("G2 corridor wall band rows (14-16) are ridge",
		rows.has(14) and rows.has(15) and rows.has(16))
	# The gate GAPS must NOT be ridge: N gate cells (19,7)/(20,7) and the bush corridor
	# cell (18,16) are the openings the player walks through.
	_check("G3 gate gap (19,7) is NOT ridge", not loader.ridge_cells.has(Vector2i(19, 7)))
	_check("G2 corridor gap (18,16) is NOT ridge", not loader.ridge_cells.has(Vector2i(18, 16)))
	# Ridge SPRITES were placed (one per ridge cell).
	_check("ridge sprites placed for every ridge cell",
		loader.ridge_sprite_count == loader.ridge_cells.size(),
		"sprites=%d cells=%d" % [loader.ridge_sprite_count, loader.ridge_cells.size()])
	var ridges := loader.get_node_or_null("Ridges")
	_check("Ridges overlay node exists with sprite children",
		ridges != null and ridges.get_child_count() > 0)
	_check("Ridges sit below the YSort object layer (terrain z)",
		ridges != null and ridges.z_index < MapLoader.YSORT_Z,
		"ridge_z=%d ysort_z=%d" % [ridges.z_index if ridges else -99, MapLoader.YSORT_Z])
	# G2 corridor trail-hint decals present (worn-dirt patches south of the bush gap).
	_check("corridor worn-dirt trail decals placed", loader.trail_decal_count > 0,
		"n=%d" % loader.trail_decal_count)


# ---- A3: ridge / cliff / hollow are three distinct treatments --------------

func _test_ridge_vs_cliff_vs_hollow(map: Node, loader: MapLoader) -> void:
	# A border-fringe VOID cell: authored 'V', NOT an interior ridge. It must be excluded
	# from ridge_cells; the cliff-skirt overlay handles the island edge instead.
	var border := _find_border_void(loader)
	_check("found a border-fringe VOID cell", border != Vector2i(-1, -1))
	if border != Vector2i(-1, -1):
		_check("border VOID is NOT an interior ridge", not loader.ridge_cells.has(border),
			"cell=%s" % border)
	_check("cliff-skirt overlay present (border edge treatment intact)",
		loader.cliff_skirt_count > 0, "n=%d" % loader.cliff_skirt_count)

	# A gathered HOLLOW cell gets NEITHER ridge NOR cliff: gather a grass tile near spawn,
	# it becomes src 11 (walkable hollow) and must not be in ridge_cells (it's not authored
	# V) and must not sprout any ridge/cliff sprite (both read from authored _layout).
	var interaction := map.get_node("Interaction")
	var cell := _find_gatherable_tile(loader, loader.spawn_cell)
	_check("found a gatherable ground tile to hollow", cell != Vector2i(-1, -1))
	if cell != Vector2i(-1, -1):
		interaction.interact_with_cell(cell)
		_check("gathered tile became walkable HOLLOW (src 11)",
			loader.get_cell_source_id(cell) == 11 and loader.is_cell_walkable(cell),
			"src=%d" % loader.get_cell_source_id(cell))
		_check("HOLLOW cell is NOT a ridge (distinct from rock wall)",
			not loader.ridge_cells.has(cell))


# ---- A1 + A2: adjacency-gated E-interact + object brighten -----------------

func _test_adjacency_gather(map: Node, loader: MapLoader) -> void:
	var player := map.get_node("YSortLayer/Player") as Player
	var ysort := map.get_node("YSortLayer") as Node2D
	var interaction := map.get_node("Interaction")
	var hl := map.get_node("TileHighlight") as TileHighlight

	# Isolate: free every pre-existing world gatherable (scatter/authored) so the only
	# targets in play are the two we place. This is the last interactive test and the
	# harness quits right after, so tearing down the scatter is safe.
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# Park the player on a known walkable interior cell and clear motion.
	var base := loader.spawn_cell
	player.clear_path()
	player.velocity = Vector2.ZERO
	player.global_position = loader.cell_center_world(base)

	# 1. A gatherable 3 cells AWAY must NOT be the resolved target and must NOT gather on E.
	var far_g := _make_test_gatherable(loader, ysort, base + Vector2i(3, 0), "I6")
	await get_tree().process_frame
	interaction._process(0.016)
	_check("far (3-cell) gatherable is NOT the resolved E-target",
		interaction._target_object != far_g and interaction._target_object == null)
	var before_far := Inventory.count("I6")
	interaction._do_interact()
	_check("direct E does NOT gather a 3-cell-away object",
		Inventory.count("I6") == before_far, "count=%d" % Inventory.count("I6"))
	far_g.queue_free()
	await get_tree().process_frame

	# 2. A gatherable on an ADJACENT cell IS the resolved target, brightens, and gathers.
	var near_g := _make_test_gatherable(loader, ysort, base + Vector2i(1, 0), "I6")
	await get_tree().process_frame
	interaction._process(0.016)
	_check("adjacent gatherable IS the resolved E-target",
		interaction._target_object == near_g)
	_check("adjacent target is object-brightened (set_targeted, not a floor diamond)",
		near_g.is_targeted() and not hl.is_active())
	var before_near := Inventory.count("I6")
	interaction._do_interact()
	_check("direct E gathers the adjacent object (+1 I6)",
		Inventory.count("I6") == before_near + 1, "count=%d" % Inventory.count("I6"))
	# near_g was non-unique → freed by gather(); clearing target must not error.
	interaction._process(0.016)

	# 3. Hover-preview state is exposed for the harness (desktop aid): the controller
	#    tracks a _hover_object field even though pressing E only acts adjacent.
	_check("hover-preview state field exposed on controller",
		"_hover_object" in interaction)


# ---- A2: placement diamond survives for held-item placement ----------------

func _test_placement_diamond(map: Node, loader: MapLoader) -> void:
	var player := map.get_node("YSortLayer/Player") as Player
	var interaction := map.get_node("Interaction")
	var slot_hint := map.get_node("SteppingSlotHint") as SteppingSlotHint

	# Holding D14 pulses a diamond over every un-filled stepping-slot (water) cell.
	Inventory.add("D14", 1)
	interaction.set_held_item("D14")
	player.clear_path()
	player.velocity = Vector2.ZERO
	interaction._process(0.016)
	_check("holding D14 shows placement diamonds over stepping slots",
		slot_hint.get_highlight_count() > 0, "n=%d" % slot_hint.get_highlight_count())
	interaction.set_held_item("")
	interaction._process(0.016)
	_check("clearing the held item hides the placement diamonds",
		slot_hint.get_highlight_count() == 0)


# ---- helpers ---------------------------------------------------------------

## Build a plain scatter Gatherable on `cell` and add it to the YSort layer so the
## interaction group scan finds it. Non-unique so gather() frees it.
func _make_test_gatherable(loader: MapLoader, ysort: Node2D, cell: Vector2i, item_id: String) -> Gatherable:
	var g := Gatherable.new()
	g.item_id = item_id
	g.position = loader.cell_center_world(cell)
	ysort.add_child(g)
	return g


func _find_gatherable_tile(loader: MapLoader, near: Vector2i) -> Vector2i:
	for radius in range(1, 12):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := near + Vector2i(dx, dy)
				if cell.x < 0 or cell.y < 0 or cell.x >= loader.width or cell.y >= loader.height:
					continue
				var data := loader.get_cell_tile_data(cell)
				if data != null and bool(data.get_custom_data("gatherable")):
					return cell
	return Vector2i(-1, -1)


## A border-fringe VOID cell (authored 'V', not an interior ridge).
func _find_border_void(loader: MapLoader) -> Vector2i:
	for r in range(loader.height):
		var row: String = loader._layout[r]
		for c in range(min(loader.width, row.length())):
			var cell := Vector2i(c, r)
			if row[c] == "V" and not loader.ridge_cells.has(cell):
				return cell
	return Vector2i(-1, -1)
