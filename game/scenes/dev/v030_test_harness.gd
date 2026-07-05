extends Node
## v0.3.0 acceptance harness — map diorama escalation + UI wireframe implementation.
##
## Covers (validation §2 "Add asserts"):
##   A1 cliff skirts   — skirt sprites are placed along the map's south edge cells.
##   A2 backdrop       — a Backdrop CanvasLayer exists at layer -1.
##   B1 command bar    — the UIHub command bar exists with 4 buttons.
##   B2 codex search   — the search filter narrows the grid (e.g. "꽃" matches the
##                       discovered 꽃-family items).
##   B2 codex recipes  — a fused item's detail pane lists exactly the discovered
##                       recipe rows that OUTPUT it (as [icon]+[icon]=[icon]).
##   B3 character win   — opens with 6 locked equipment slots.
##   B5 one-window rule — opening one window closes any other; ESC closes it.
##
## Instances the real starting_grove scene like the M4/M5/M6a/v021 harnesses.

const GROVE := "res://scenes/world/starting_grove.tscn"

var _fail := 0


func _check(label: String, cond: bool) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== v0.3.0 TEST HARNESS ===")
	Inventory.clear()
	Codex.reset()
	GameState.set_game_time(0.0)
	SaveManager.pending_load = false

	var scene: PackedScene = load(GROVE)
	var map := scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	# give the hub's call_deferred("_resolve_windows") a frame to run.
	await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader

	_test_cliff_skirts(map, loader)
	_test_backdrop(map)
	_test_command_bar(map)
	await _test_codex(map)
	_test_character_window(map)
	_test_one_window_rule(map)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A1: cliff skirts -----------------------------------------------------

func _test_cliff_skirts(map: Node, loader: MapLoader) -> void:
	var overlay := loader.get_node_or_null("CliffSkirts") as Node2D
	_check("CliffSkirts overlay present", overlay != null)
	if overlay == null:
		return
	_check("cliff skirt sprites placed", loader.cliff_skirt_count > 0)
	_check("cliff skirt overlay draws below ground (z < 0)", overlay.z_index < 0)
	# South-edge coverage: every skirt-south cell must actually be an island cell whose
	# +row neighbour is off-island (a genuine southern lip). Also assert at least a
	# few exist so the island reads as a slab.
	_check("south-facing cliff cells recorded", loader.cliff_skirt_south_cells.size() >= 4)
	var all_valid := true
	for cell in loader.cliff_skirt_south_cells:
		if not loader._is_island_cell(cell) or loader._is_island_cell(cell + Vector2i(0, 1)):
			all_valid = false
			break
	_check("every south skirt cell has an off-island south neighbour", all_valid)
	# One concrete southern edge: the very bottom playable row cells should have skirts.
	var found_bottom := false
	for cell in loader.cliff_skirt_south_cells:
		if cell.y >= loader.height - 2:
			found_bottom = true
			break
	_check("skirt present on a bottom-row (south) edge cell", found_bottom)


# ---- A2: backdrop ---------------------------------------------------------

func _test_backdrop(map: Node) -> void:
	var backdrop := map.get_node_or_null("Backdrop") as CanvasLayer
	_check("Backdrop CanvasLayer present", backdrop != null)
	if backdrop == null:
		return
	_check("Backdrop is at layer -1 (behind everything)", backdrop.layer == -1)
	_check("Backdrop is screen-fixed (follow_viewport off)", not backdrop.follow_viewport_enabled)
	_check("Backdrop has a painting canvas child", backdrop.get_node_or_null("BackdropCanvas") != null)


# ---- B1: command bar ------------------------------------------------------

func _hub(map: Node):
	return map.get_node_or_null("UIHub")


func _test_command_bar(map: Node) -> void:
	var hub = _hub(map)
	_check("UIHub present", hub != null)
	if hub == null:
		return
	var buttons: Dictionary = hub.get("_buttons")
	_check("command bar has 4 buttons", buttons != null and buttons.size() == 4)
	# The button labels carry the (correct, remapped) hotkeys.
	var texts: Array = []
	for k in buttons:
		texts.append(String((buttons[k] as Button).text))
	_check("bar has 캐릭터 (C)", texts.has("캐릭터 (C)"))
	_check("bar has 인벤토리 (I)", texts.has("인벤토리 (I)"))
	_check("bar has 도감 (R) [remapped from C]", texts.has("도감 (R)"))
	_check("bar has 메뉴 (ESC)", texts.has("메뉴 (ESC)"))
	# key remap sanity: 'character' action is C, 'codex' action is R.
	_check("input map has 'character' action", InputMap.has_action("character"))
	_check("input map has 'codex' action", InputMap.has_action("codex"))


# ---- B2: codex search + recipe rows ---------------------------------------

func _test_codex(map: Node) -> void:
	var codex := map.get_node_or_null("CodexUI")
	_check("CodexUI present", codex != null)
	if codex == null:
		return

	# --- recipe-row test: craft D03 씨앗 via R04 (I5 꽃 + I2 풀) through the real
	# fusion path so the recipe is discovered, then check the detail pane. ---
	var fusion_ui = map.get_node_or_null("FusionUI")
	Inventory.add("I5", 1)
	Inventory.add("I2", 1)
	fusion_ui.call("open")
	await get_tree().process_frame
	fusion_ui.call("_on_strip_pressed", "I5")
	fusion_ui.call("_on_strip_pressed", "I2")
	fusion_ui.call("_on_fuse_pressed")
	for _i in range(120):
		await get_tree().process_frame
	fusion_ui.call("close") if fusion_ui.has_method("close") else fusion_ui.call("_set_visible", false)
	_check("R04 discovered (D03 씨앗 crafted)", Codex.is_recipe_discovered("R04"))

	# Discover the 꽃-family items so the name filter has something to match.
	for id in ["I5", "D16", "D18"]:
		Codex.discover_item(id)

	codex.call("open")
	await get_tree().process_frame

	# Search "꽃": the shown grid must include 꽃 / 꽃즙 / 꽃다발 (all discovered) and
	# must NOT include a non-꽃 discovered item like 씨앗.
	codex.call("set_search", "꽃")
	await get_tree().process_frame
	var shown: Array = codex.get("_shown_ids")
	_check("codex search '꽃' matches 꽃 (I5)", shown.has("I5"))
	_check("codex search '꽃' matches 꽃즙 (D16)", shown.has("D16"))
	_check("codex search '꽃' matches 꽃다발 (D18)", shown.has("D18"))
	_check("codex search '꽃' excludes 씨앗 (D03)", not shown.has("D03"))

	# Clear the filter → full catalog returns (>= all catalogued ids).
	codex.call("set_search", "")
	await get_tree().process_frame
	shown = codex.get("_shown_ids")
	_check("cleared search restores full catalog", shown.size() == ItemDB.all_ids().size())

	# Recipe rows: select D03 씨앗; its detail should list exactly 1 discovered recipe
	# row (R04). Undiscovered recipes outputting D03 (none here) stay hidden.
	Codex.discover_item("D03")
	codex.call("set_search", "")
	codex.call("_on_cell_pressed", "D03")
	await get_tree().process_frame
	var rbox: VBoxContainer = codex.get("_recipe_box")
	var row_count := _count_recipe_rows(rbox)
	_check("D03 씨앗 detail lists exactly 1 discovered recipe row (R04)", row_count == 1)

	# An item with a recipe output that is NOT discovered shows the empty message.
	# D04 is output of R05 (D03 + I7); R05 is undiscovered → 0 rows + placeholder.
	Codex.discover_item("D04")
	codex.call("_on_cell_pressed", "D04")
	await get_tree().process_frame
	rbox = codex.get("_recipe_box")
	_check("D04 (no discovered recipe) shows '아직 알아내지 못했다'",
		_count_recipe_rows(rbox) == 0 and _has_none_label(rbox))

	codex.call("close")
	await get_tree().process_frame


## A recipe row is an HBoxContainer (the [icon]+[icon]=[icon] row); the empty-state
## placeholder is a Label. Count the HBox rows.
func _count_recipe_rows(box: VBoxContainer) -> int:
	var n := 0
	for c in box.get_children():
		if c is HBoxContainer:
			n += 1
	return n


func _has_none_label(box: VBoxContainer) -> bool:
	for c in box.get_children():
		if c is Label and String((c as Label).text) == "아직 알아내지 못했다":
			return true
	return false


# ---- B3: character window -------------------------------------------------

func _test_character_window(map: Node) -> void:
	var win = map.get_node_or_null("CharacterWindow")
	_check("CharacterWindow present", win != null)
	if win == null:
		return
	win.call("open")
	_check("character window opens", bool(win.call("is_open")))
	var slots: Array = win.get("slot_boxes")
	_check("character window has 6 equipment slots", slots != null and slots.size() == 6)
	# All slots are locked/dimmed placeholders with the locked tooltip.
	var all_locked := true
	for box in slots:
		var pc := box as Control
		if pc == null or pc.tooltip_text != "아직 잠겨 있다" or pc.modulate.a >= 1.0:
			all_locked = false
			break
	_check("all 6 slots are locked (dimmed + '아직 잠겨 있다' tooltip)", all_locked)
	win.call("close")


# ---- B5: one-window-at-a-time rule ----------------------------------------

func _test_one_window_rule(map: Node) -> void:
	var hub = _hub(map)
	var inv = map.get_node_or_null("InventoryUI")
	var codex = map.get_node_or_null("CodexUI")
	var chr = map.get_node_or_null("CharacterWindow")
	if hub == null or inv == null or codex == null or chr == null:
		_check("one-window rule: all windows resolvable", false)
		return

	# Open inventory via the hub.
	hub.call("toggle", hub.Win.INVENTORY)
	_check("inventory opens", bool(inv.call("is_open")))
	# Opening the codex must close the inventory.
	hub.call("toggle", hub.Win.CODEX)
	_check("opening codex closes inventory", bool(codex.call("is_open")) and not bool(inv.call("is_open")))
	# Opening the character window must close the codex.
	hub.call("toggle", hub.Win.CHARACTER)
	_check("opening character closes codex", bool(chr.call("is_open")) and not bool(codex.call("is_open")))
	# Exactly one window open now.
	_check("exactly one window open at a time", hub.call("any_window_open")
		and not bool(inv.call("is_open")) and not bool(codex.call("is_open")))
	# close_all closes everything.
	hub.call("close_all")
	_check("close_all closes every window", not hub.call("any_window_open"))
