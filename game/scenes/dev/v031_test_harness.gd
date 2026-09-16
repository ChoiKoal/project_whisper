extends Node
## v0.3.1 acceptance harness — UX sprint (owner-feedback fixes).
##
## Covers (validation §2):
##   R1 UI-fit       — at 1280×720 (and 1920×1080) the fusion / inventory / character
##                     panels sit fully inside the viewport rect (owner's top pain: the
##                     fusion ingredient strip was below the window bottom).
##   Fix3 cursor     — the tile highlight is HIDDEN while the player is moving.
##   Fix4 hollow     — a gathered interior tile becomes the walkable HOLLOW (src 11),
##                     distinct from the unwalkable border VOID (src 0 with physics).
##   R3 semantics    — substantial R rock and tree have compact collision footprints;
##                     small s stone remains walkover with no StaticBody.
##   R4 affordance   — holding a combo-only item shows the dimmed "조합 재료" affordance;
##                     a placeable item shows the "놓을 수 있다" line.
##
## Instances the real starting_grove scene like the other grove harnesses. Window size is
## driven via get_window().size so the UIs' size_changed clamp runs for real.

const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v0.3.1 TEST HARNESS ===")
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

	await _test_ui_fit(map, Vector2i(1280, 720))
	await _test_ui_fit(map, Vector2i(1920, 1080))
	await _test_cursor_hidden_while_moving(map)
	_test_hollow_walkable_distinct(map, loader)
	_test_semantic_gatherable_collision(map, loader)
	_test_held_affordance(map)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- R1: UI fits the viewport at small + large window sizes ----------------

## A control's global rect must sit fully within `outer` (1px rounding tolerance).
func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 1.0 \
		and inner.position.y >= outer.position.y - 1.0 \
		and inner.position.x + inner.size.x <= outer.position.x + outer.size.x + 1.0 \
		and inner.position.y + inner.size.y <= outer.position.y + outer.size.y + 1.0


func _panel_rect(node: Node, field: String) -> Rect2:
	var p := node.get(field) as Control
	if p == null:
		return Rect2()
	return Rect2(p.global_position, p.size)


## The headless dummy display cannot actually resize the window (visible_rect is pinned at
## the project's 1600×900), so we drive each UI's clamp with an explicit target size and
## assert (a) the panel HEIGHT respects min(700, target*0.85) at that size and (b) the
## panel's real rect stays inside the live viewport (centering correctness).
func _test_ui_fit(map: Node, size: Vector2i) -> void:
	var target := Vector2(size)
	var cap: float = min(700.0, target.y * 0.85)
	var real_vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)

	var fusion := map.get_node("FusionUI")
	fusion.open()
	fusion.call("_clamp_to_viewport", target)
	await get_tree().process_frame
	await get_tree().process_frame
	var fr := _panel_rect(fusion, "_root")
	_check("[%dx%d] fusion panel height ≤ min(700, vp*0.85)" % [size.x, size.y],
		fr.size.y <= cap + 1.0, "h=%.0f cap=%.0f" % [fr.size.y, cap])
	_check("[%dx%d] fusion panel rect inside live viewport" % [size.x, size.y],
		fr.size != Vector2.ZERO and _rect_inside(fr, real_vp), "panel=%s" % fr)
	fusion.call("_set_visible", false)

	var inv := map.get_node("InventoryUI")
	inv.open()
	inv.call("_clamp_to_viewport", target)
	await get_tree().process_frame
	await get_tree().process_frame
	var ir := _panel_rect(inv, "_panel")
	_check("[%dx%d] inventory panel height ≤ min(700, vp*0.85)" % [size.x, size.y],
		ir.size.y <= cap + 1.0, "h=%.0f cap=%.0f" % [ir.size.y, cap])
	_check("[%dx%d] inventory panel rect inside live viewport" % [size.x, size.y],
		ir.size != Vector2.ZERO and _rect_inside(ir, real_vp), "panel=%s" % ir)
	inv.close()

	var chr := map.get_node("CharacterWindow")
	chr.open()
	chr.call("_clamp_to_viewport", target)
	await get_tree().process_frame
	await get_tree().process_frame
	var cr := _panel_rect(chr, "_root")
	_check("[%dx%d] character panel height ≤ min(700, vp*0.85)" % [size.x, size.y],
		cr.size.y <= cap + 1.0, "h=%.0f cap=%.0f" % [cr.size.y, cap])
	_check("[%dx%d] character panel rect inside live viewport" % [size.x, size.y],
		cr.size != Vector2.ZERO and _rect_inside(cr, real_vp), "panel=%s" % cr)
	chr.close()


# ---- Fix 3: highlight hidden while the player is moving ---------------------

func _test_cursor_hidden_while_moving(map: Node) -> void:
	var player := map.get_node("YSortLayer/Player") as Player
	var hl := map.get_node("TileHighlight") as TileHighlight
	var glow := map.get_node("TileGlow") as TileGlow
	var interaction := map.get_node("Interaction")
	# Force a deterministic "moving" state: queue a distant path waypoint (is_moving() is
	# true whenever the path is non-empty, independent of the physics tick). Then drive one
	# interaction-controller process tick and assert every idle affordance went hidden —
	# with NO physics frame in between, so the path can't drain before we read it.
	# (v0.4.0: the gather cursor is now object-brighten + soft tile glow; the violet diamond
	# survives only for held-item placement. All must be off while moving.)
	var far: Array[Vector2] = [player.global_position + Vector2(2000, 0)]
	player.set_path(far)
	_check("player.is_moving() true while pathing", player.is_moving())
	interaction._process(0.016)
	_check("placement diamond hidden while moving", not hl.is_active())
	_check("soft tile glow hidden while moving", not glow.is_active())
	player.clear_path()
	player.velocity = Vector2.ZERO


# ---- Fix 4: hollow walkable + distinct from border VOID --------------------

func _test_hollow_walkable_distinct(map: Node, loader: MapLoader) -> void:
	# Gather a real grass tile near spawn → it must become the walkable HOLLOW (src 11).
	var cell := _find_gatherable_tile(loader, loader.spawn_cell)
	_check("found a gatherable ground tile", cell != Vector2i(-1, -1))
	if cell == Vector2i(-1, -1):
		return
	var interaction := map.get_node("Interaction")
	interaction.interact_with_cell(cell)
	await get_tree().process_frame
	_check("gathered tile became HOLLOW (src 11)", loader.get_cell_source_id(cell) == 11,
		"src=%d" % loader.get_cell_source_id(cell))
	_check("HOLLOW is walkable (빈 자국 crossable)", loader.is_cell_walkable(cell))
	# Distinct from border VOID: find a base-VOID border cell (src 0) and confirm it is
	# NOT walkable — the hollow and the cliff-edge VOID must read differently.
	var border := _find_border_void(loader)
	_check("found a border VOID cell", border != Vector2i(-1, -1))
	if border != Vector2i(-1, -1):
		_check("border VOID (src 0) is NOT walkable", not loader.is_cell_walkable(border),
			"cell=%s src=%d" % [border, loader.get_cell_source_id(border)])


# ---- R3: semantic object footprints ---------------------------------------

func _test_semantic_gatherable_collision(map: Node, loader: MapLoader) -> void:
	var rock: Gatherable = null
	var stone: Gatherable = null
	var tree: Gatherable = null
	for node in get_tree().get_nodes_in_group(Gatherable.GROUP):
		if not (node is Gatherable) or node is BushDry or node is WorldTree:
			continue
		var g := node as Gatherable
		if g.item_id == "I6" and rock == null:
			rock = g
		elif g.item_id == "I8" and stone == null:
			stone = g
		elif g.item_id == "I4" and tree == null:
			tree = g
	_check("a substantial R rock gatherable exists", rock != null)
	if rock != null:
		_check("R rock uses the explicit 24px blocking footprint",
			rock.blocks_movement and is_equal_approx(rock.block_radius, 24.0)
				and _has_static_body(rock))
	_check("a small s stone gatherable exists", stone != null)
	if stone != null:
		_check("s stone remains walkover with no collision body",
			not stone.blocks_movement and not _has_static_body(stone))
		var scell := loader.world_to_cell(stone.target_point())
		_check("terrain beneath s remains walkable", loader.is_cell_walkable(scell),
			"cell=%s" % scell)
	_check("a blocking tree gatherable exists", tree != null)
	if tree != null:
		_check("tree keeps its existing collision body", tree.blocks_movement and _has_static_body(tree))


func _has_static_body(node: Node) -> bool:
	for child in node.get_children():
		if child is StaticBody2D:
			return true
	return false


# ---- R4: held-item affordance line -----------------------------------------

func _test_held_affordance(map: Node) -> void:
	var inv := map.get_node("InventoryUI")
	# Combo-only item (I2 풀 has no placeable_on/usable_on) → dimmed 조합 재료 line.
	Inventory.add("I2", 1)
	await get_tree().process_frame
	inv.call("_set_held", "I2")
	var aff := inv.get("_held_affordance") as Label
	_check("combo-only held shows 조합 재료 affordance",
		aff != null and aff.text.contains("조합 재료"), "text=%s" % (aff.text if aff else "<null>"))
	# Placeable item (D14 → T5A/T5B) shows the 놓을 수 있다 line.
	Inventory.add("D14", 1)
	await get_tree().process_frame
	inv.call("_set_held", "D14")
	_check("placeable held shows 놓을 수 있다 affordance",
		aff != null and aff.text.contains("놓을 수 있다"), "text=%s" % (aff.text if aff else "<null>"))
	inv.call("_set_held", "")


# ---- helpers ---------------------------------------------------------------

func _find_gatherable_tile(loader: MapLoader, near: Vector2i) -> Vector2i:
	# Spiral-ish scan outward from `near` for a gatherable ground tile.
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


func _find_border_void(loader: MapLoader) -> Vector2i:
	for r in range(loader.height):
		var row: String = loader._layout[r]
		for c in range(min(loader.width, row.length())):
			if row[c] == "V" and loader.get_cell_source_id(Vector2i(c, r)) == 0:
				return Vector2i(c, r)
	return Vector2i(-1, -1)
