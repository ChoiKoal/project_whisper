extends Node
## SaveManager — global autoload. Persists a whole run to user://save1.json and
## restores it, and owns the NG+ (New Game Plus) carryover flow.
##
## Design (M5):
##   - Serialize inventory stacks, held item, Codex.to_dict(), a *tile diff*
##     against the deterministic base layout (VOID gathered cells + D14 stepping
##     stones), object gathered/respawn state, gate flags (bush bloomed / stepping
##     stones / world tree gathered / cleared), GameState.game_time, player world
##     position, and NG+ meta (run number + lifetime discovery history + carried
##     recipe ids).
##   - The map layout is deterministic (MapLoader rebuilds the base map on load),
##     so we only store the DIFF from map_layout.txt: which cells became T0 VOID
##     and which K water cells became walkable stepping stones. g/tree variants are
##     cell-hash deterministic — never saved.
##   - Load reconstructs the live starting_grove scene in place: re-applies the
##     tile diff, removes/restores objects per their respawn timers, re-blooms the
##     bush, repositions the player, and restores time (which re-derives the G3
##     night gate — no separate save).
##
## The scene wires itself to this singleton via `register_world(...)`; SaveManager
## never hard-depends on a scene existing (headless save of pure autoload state
## still works — map/player sections are simply omitted).

const SAVE_PATH := "user://save1.json"
## Bump when the schema changes in a backwards-incompatible way.
const SAVE_VERSION := 1

## Source id a gathered tile becomes (T0 VOID) — mirrors InteractionController.
const VOID_SOURCE := 0
## (v0.3.1 Fix 4) Source id a gathered interior tile becomes now: the walkable HOLLOW
## (빈 자국). Mirrors InteractionController.HOLLOW_SOURCE. The save schema is UNCHANGED
## — the diff key is still "void_cells" — but a gathered cell now reads as HOLLOW and
## reloads as HOLLOW. Older saves that stored real VOID (0) gathered cells also reload
## as HOLLOW (walkable), matching the new "빈 자국 = walkable" decision.
const HOLLOW_SOURCE := 11
## Source id a K water cell becomes when a D14 stepping stone is placed.
const STEPPING_STONE_SOURCE := 1
const ATLAS := Vector2i(0, 0)

signal game_saved
signal game_loaded
signal ng_plus_started(run_number: int, carried: Array)

# ---- NG+ meta (lives across a save; persisted in the file) ----------------
## 1-based run counter. Run 1 = the very first playthrough.
var run_number: int = 1
## Recipe ids carried into the CURRENT run (already-discovered on a fresh NG+).
var carried_recipes: Array = []
## Lifetime union of every recipe ever discovered across all runs (honor record).
var lifetime_recipes: Dictionary = {}   # recipe_id -> true
## Whether the current run has reached the clear (world tree planted) state.
var cleared: bool = false
## How many recipes NG+ carries forward from the finished run.
const NG_PLUS_CARRY := 3

# ---- live-world registration (set by the scene) ---------------------------
var _loader: MapLoader = null
var _player: Node2D = null
var _respawn: ObjectRespawn = null

## When true, the next grove scene to register should load save data into itself
## (set by the title's "이어하기"). Cleared after the load is applied.
var pending_load: bool = false


func _ready() -> void:
	# Track discovered recipes into the lifetime honor record as they happen.
	GameState.recipe_discovered.connect(_on_recipe_discovered)
	# Autosave on window close (NOTIFICATION_WM_CLOSE_REQUEST).
	get_tree().set_auto_accept_quit(false)


func _on_recipe_discovered(recipe_id: String) -> void:
	if recipe_id != "":
		lifetime_recipes[recipe_id] = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Autosave-on-quit (only if a world is live to snapshot).
		if _loader != null:
			save_game()
		get_tree().quit()


## Called by the world scene so SaveManager can snapshot / restore it.
func register_world(loader: MapLoader, player: Node2D, respawn: ObjectRespawn) -> void:
	_loader = loader
	_player = player
	_respawn = respawn


func unregister_world() -> void:
	_loader = null
	_player = null
	_respawn = null


# ==== SAVE =================================================================

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		# globalize may fail on user://; fall back to DirAccess on the user dir.
		if has_save():
			var d := DirAccess.open("user://")
			if d != null:
				d.remove("save1.json")


## Build the full save dictionary from current autoload + live-world state.
func build_save_dict() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"inventory": _inventory_dict(),
		"held_item": _held_item(),
		"codex": Codex.to_dict(),
		"time": {
			"game_time": GameState.game_time,
			"day_index": GameState.day_index(),
		},
		"ngplus": {
			"run_number": run_number,
			"carried_recipes": carried_recipes.duplicate(),
			"lifetime_recipes": lifetime_recipes.keys(),
			"cleared": cleared,
		},
		"quests": QuestManager.to_dict(),
	}
	if _loader != null:
		data["map"] = _map_dict()
	if _player != null:
		data["player"] = {"x": _player.global_position.x, "y": _player.global_position.y}
	return data


func save_game() -> bool:
	var data := build_save_dict()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s for write" % SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	game_saved.emit()
	return true


func _inventory_dict() -> Dictionary:
	var out := {}
	for id in Inventory.ids():
		out[id] = Inventory.count(id)
	return out


func _held_item() -> String:
	# The held item lives on the InteractionController; find it via the scene.
	if _loader != null:
		var ic := _find_interaction()
		if ic != null:
			return ic.get_held_item()
	return ""


func _find_interaction() -> InteractionController:
	return _search_class(_scene_root(), InteractionController) as InteractionController


## Depth-first search for the first node that `is` the given (global class_name)
## type. Robust to code-built subtrees (map objects spawned at runtime).
func _search_class(node: Node, cls) -> Node:
	if node == null:
		return null
	if is_instance_of(node, cls):
		return node
	for c in node.get_children():
		var r := _search_class(c, cls)
		if r != null:
			return r
	return null


# ---- map serialization (diff from the deterministic base layout) ----------

func _map_dict() -> Dictionary:
	var void_cells: Array = []
	var stone_cells: Array = []
	# Compare each cell's current source against its base (layout) source.
	for r in range(_loader.height):
		var row: String = _loader._layout[r]
		for c in range(min(_loader.width, row.length())):
			var cell := Vector2i(c, r)
			var cur := _loader.get_cell_source_id(cell)
			var base := _base_source(row[c])
			if cur == base:
				continue
			if cur == HOLLOW_SOURCE or cur == VOID_SOURCE:
				# Cell became HOLLOW (빈 자국 — tile gathered) or VOID. Recorded under the
				# unchanged "void_cells" key; reloads as HOLLOW. Authored-VOID cells are
				# base==0 so they never diff here (cur==base skipped above).
				void_cells.append([c, r])
			elif cur == STEPPING_STONE_SOURCE and _is_stepping_slot(cell):
				stone_cells.append([c, r])
	return {
		"void_cells": void_cells,
		"stepping_stones": stone_cells,
		"objects": _object_states(),
		"placed_objects": _placed_object_states(),
		"gates": {
			"bush_bloomed": _bush_bloomed(),
			"world_tree_gathered": _world_tree_gathered(),
		},
	}


## (v0.4.0-C) Serialize every persistent PlacedObject (structure/decor the player built).
## Each entry is that object's own to_dict() ({item_id, cell:[x,y]}). Functional placeables
## (디딤돌 tile swaps, 어린 세계수) are NOT PlacedObjects — they live in the tile diff.
func _placed_object_states() -> Array:
	var out: Array = []
	var root := _scene_root()
	if root == null:
		return out
	for node in root.get_tree().get_nodes_in_group("placed_object"):
		if node.has_method("to_dict"):
			out.append(node.to_dict())
	return out


## Base source id for a layout symbol (mirror of MapLoader/legend, minus the
## deterministic g variant which we never diff on).
func _base_source(sym: String) -> int:
	var tiles: Dictionary = _loader._legend.get("tiles", {})
	var spec: Dictionary = tiles.get(sym, {})
	if spec.is_empty():
		return 2
	return int(spec.get("source", 2))


func _is_stepping_slot(cell: Vector2i) -> bool:
	return cell in _loader.stepping_slot_cells


func _object_states() -> Array:
	# For each tracked spawn cell: whether it's currently present, and if gone,
	# the respawn timer (absolute game_time) so load can restore mid-respawn.
	var out: Array = []
	if _respawn == null:
		return out
	for entry: Dictionary in _respawn._tracked:
		var cell: Vector2i = entry["cell"]
		var node = entry["node"]
		var present := node != null and is_instance_valid(node)
		out.append({
			"cell": [cell.x, cell.y],
			"symbol": entry["symbol"],
			"present": present,
			"respawn_at": float(entry["respawn_at"]),
		})
	return out


func _bush_bloomed() -> bool:
	var b := _search_class(_scene_root(), BushDry) as BushDry
	return b != null and b.is_bloomed()


func _world_tree_gathered() -> bool:
	var wt := _search_class(_scene_root(), WorldTree)
	if wt == null:
		return false
	return bool(wt.get("_spent"))


func _scene_root() -> Node:
	if _loader == null:
		return null
	var root := _loader.get_tree().current_scene
	return root if root != null else _loader.get_parent()


# ==== LOAD =================================================================

## Load the autoload-level state (inventory, codex, time, NG+ meta). Returns the
## parsed save dict (empty if none). Map/player restoration is a separate step
## the scene triggers once its nodes exist (`apply_world_state`).
func load_game() -> Dictionary:
	var data := _read_save()
	if data.is_empty():
		return {}
	_apply_core_state(data)
	if _loader != null:
		apply_world_state(data)
	game_loaded.emit()
	return data


func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: malformed save file")
		return {}
	return _migrate(parsed)


## Version migration hook. v1 is current; older/unknown versions pass through
## best-effort. Returns the (possibly upgraded) dict.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v > SAVE_VERSION:
		push_warning("SaveManager: save version %d newer than supported %d" % [v, SAVE_VERSION])
	# No breaking migrations yet.
	return data


func _apply_core_state(data: Dictionary) -> void:
	# Inventory
	Inventory.clear()
	var inv: Dictionary = data.get("inventory", {})
	for id in inv:
		Inventory.add(id, int(inv[id]))
	# Codex
	if data.has("codex"):
		Codex.from_dict(data["codex"])
	# Time
	var t: Dictionary = data.get("time", {})
	GameState.set_game_time(float(t.get("game_time", 0.0)))
	# NG+ meta
	var ng: Dictionary = data.get("ngplus", {})
	run_number = int(ng.get("run_number", 1))
	carried_recipes = (ng.get("carried_recipes", []) as Array).duplicate()
	cleared = bool(ng.get("cleared", false))
	lifetime_recipes.clear()
	for rid in ng.get("lifetime_recipes", []):
		lifetime_recipes[rid] = true
	# (v0.4.0-C) Quest line state.
	if data.has("quests"):
		QuestManager.from_dict(data["quests"])
	# Held item is applied in apply_world_state (needs the InteractionController).


## Re-apply the map/object/gate/player state to a LIVE, already-built scene.
## The MapLoader has rebuilt the deterministic base map; we overlay the diff.
func apply_world_state(data: Dictionary) -> void:
	if _loader == null:
		return
	var m: Dictionary = data.get("map", {})
	# Gathered tiles reload as the walkable HOLLOW (빈 자국). The key is still
	# "void_cells" (no schema change); older saves with true-VOID gathered cells also
	# come back as HOLLOW so the emptied spots are walkable per the v0.3.1 decision.
	for pair in m.get("void_cells", []):
		_loader.set_cell(Vector2i(int(pair[0]), int(pair[1])), HOLLOW_SOURCE, ATLAS)
	# Stepping stones (D14 placed on K water).
	for pair in m.get("stepping_stones", []):
		_loader.set_cell(Vector2i(int(pair[0]), int(pair[1])), STEPPING_STONE_SOURCE, ATLAS)
	# Objects: remove ones recorded absent, restore respawn timers.
	_apply_object_states(m.get("objects", []))
	# (v0.4.0-C) Persistent placed structures/decor.
	_apply_placed_objects(m.get("placed_objects", []))
	# Gates
	var gates: Dictionary = m.get("gates", {})
	if bool(gates.get("bush_bloomed", false)):
		var b := _search_class(_scene_root(), BushDry) as BushDry
		if b != null:
			b.bloom()
	if bool(gates.get("world_tree_gathered", false)):
		var wt := _search_class(_scene_root(), WorldTree)
		if wt != null:
			wt.set("_spent", true)
	# Player position
	if _player != null and data.has("player"):
		var p: Dictionary = data["player"]
		_player.global_position = Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	# Held item
	var ic := _find_interaction()
	if ic != null:
		ic.set_held_item(String(data.get("held_item", "")))


## (v0.4.0-C) Rebuild persistent PlacedObjects from the save. Parents them under the
## scene's YSortLayer (so they sort with the player) and refreshes pathfinding for any
## blocking structure. Does NOT emit placed_object_placed (loading is not a play action,
## so quests/audio must not re-fire).
func _apply_placed_objects(states: Array) -> void:
	if states.is_empty():
		return
	var ysort := _find_ysort_layer()
	var parent: Node = ysort if ysort != null else _scene_root()
	if parent == null:
		return
	for st: Dictionary in states:
		var item_id := String(st.get("item_id", ""))
		var arr: Array = st.get("cell", [])
		if item_id == "" or arr.size() != 2:
			continue
		var cell := Vector2i(int(arr[0]), int(arr[1]))
		var obj := PlacedObject.new()
		obj.setup(item_id, cell)
		parent.add_child(obj)
		obj.global_position = _loader.cell_center_world(cell)
		if ItemDB.placement_blocks(item_id):
			GameState.tile_walkable_changed.emit(cell)


## Find the YSortLayer node (placed objects' parent) in the live scene, or null.
func _find_ysort_layer() -> Node:
	var root := _scene_root()
	if root == null:
		return null
	return root.find_child("YSortLayer", true, false)


func _apply_object_states(states: Array) -> void:
	if _respawn == null:
		return
	for st: Dictionary in states:
		var arr: Array = st.get("cell", [])
		if arr.size() != 2:
			continue
		var cell := Vector2i(int(arr[0]), int(arr[1]))
		var entry: Variant = _respawn_entry_for(cell)
		if entry == null:
			continue
		var present := bool(st.get("present", true))
		var respawn_at := float(st.get("respawn_at", -1.0))
		if not present:
			# Remove the currently-live object at this cell (it was gathered).
			var node = entry["node"]
			if node != null and is_instance_valid(node):
				node.free()
			entry["node"] = null
			entry["respawn_at"] = respawn_at
		else:
			entry["respawn_at"] = -1.0


func _respawn_entry_for(cell: Vector2i):
	# O(1) via the respawn manager's index (dense object maps in M6a).
	if _respawn.has_method("entry_for_cell"):
		return _respawn.entry_for_cell(cell)
	for entry: Dictionary in _respawn._tracked:
		if entry["cell"] == cell:
			return entry
	return null


# ==== NG+ (New Game Plus) ==================================================

## Mark the current run as cleared (called after the clear sequence). Persists so
## the title screen can offer "NG+ 시작".
func mark_cleared() -> void:
	cleared = true


## Start New Game Plus. Picks up to NG_PLUS_CARRY (3) random recipes from the
## recipes discovered in the just-finished run, resets the world (map/inventory/
## time), bumps the run number, and seeds the codex so exactly those carried
## recipes start discovered ("세계가 기억해 준 속삭임"). Lifetime discovery
## history is preserved as the honor record. Returns the carried recipe ids.
##
## `finished_run_recipes` = the recipe ids discovered in the run being left
## (defaults to the codex's current discovered recipes).
func start_ng_plus(finished_run_recipes: Array = []) -> Array:
	var pool: Array = finished_run_recipes.duplicate()
	if pool.is_empty():
		var d := Codex.to_dict()
		pool = (d.get("recipes", []) as Array).duplicate()
	# Fold the finished run's discoveries into the lifetime honor record.
	for rid in pool:
		lifetime_recipes[rid] = true

	# Pick min(3, N) distinct recipes at random.
	var carry: Array = _pick_random(pool, NG_PLUS_CARRY)

	# Reset the world.
	Inventory.clear()
	GameState.set_game_time(0.0)
	Codex.reset()
	QuestManager.reset()   # (v0.4.0-C) fresh 속삭임 line on NG+
	cleared = false
	run_number += 1
	carried_recipes = carry.duplicate()

	# Seed the carried recipes as already-discovered in the fresh codex.
	for rid: String in carry:
		Codex.discover_recipe(rid)

	ng_plus_started.emit(run_number, carried_recipes)
	return carried_recipes


## Pick up to `n` distinct random elements from `pool`.
func _pick_random(pool: Array, n: int) -> Array:
	var copy: Array = pool.duplicate()
	copy.shuffle()
	if copy.size() <= n:
		return copy
	return copy.slice(0, n)


## Recipe ids that should render with the "세계가 기억해 준 속삭임" carryover
## marker in the codex (the ones NG+ carried into this run).
func is_carried_recipe(recipe_id: String) -> bool:
	return recipe_id in carried_recipes


## Whether a recipe is in the lifetime honor record (discovered in ANY run).
func is_lifetime_recipe(recipe_id: String) -> bool:
	return lifetime_recipes.has(recipe_id)


## Reset all NG+ meta + a fresh world (used by "새로 시작" from the title).
func new_game() -> void:
	Inventory.clear()
	GameState.set_game_time(0.0)
	Codex.reset()
	QuestManager.reset()   # (v0.4.0-C) fresh 속삭임 line on 새로 시작
	run_number = 1
	carried_recipes = []
	lifetime_recipes.clear()
	cleared = false
