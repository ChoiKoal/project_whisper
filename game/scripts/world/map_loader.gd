extends TileMapLayer
class_name MapLoader
## Builds the 시작의 숲 map from data/map_layout.txt + data/map_legend.json.
## Replaces the hand-coded MapBuilder for the real game map (test_map keeps
## MapBuilder). 기획 수정 = 텍스트 수정: edit the two data files, not this script.
##
## Responsibilities:
##   - parse the 40×40 layout, set_cell for every tile per the legend
##   - spawn object scenes (trees/flowers/rocks/stones, cauldron, stump, bush,
##     night gate, world tree, mystic water) into `ysort_layer`
##   - remember spawn / landmark cells and expose query helpers for wiring + tests
##   - deterministic variant selection by cell hash (save reproducibility)
##
## Object instances are built in code (no fragile hand-authored .tscn per object).

const LAYOUT_PATH := "res://data/map_layout.txt"
const LEGEND_PATH := "res://data/map_legend.json"
const ATLAS := Vector2i(0, 0)

## Where object instances are added (must be Y-sorted).
@export var ysort_layer_path: NodePath
## Where floating labels / fade spawn for gate feedback.
@export var feedback_layer_path: NodePath
## Player to reposition onto the spawn cell after the map is built.
@export var player_path: NodePath
## Full-screen fade ColorRect handed to the Rest Stump.
@export var fade_rect_path: NodePath

var _ysort: Node2D
var _feedback: Node

var _layout: Array[String] = []
var _legend: Dictionary = {}
var width: int = 0
var height: int = 0

## Resolved cells (col,row) of interest.
var spawn_cell: Vector2i = Vector2i(-1, -1)
var cauldron_cell: Vector2i = Vector2i(-1, -1)
var stump_cell: Vector2i = Vector2i(-1, -1)
var bush_cell: Vector2i = Vector2i(-1, -1)
var world_tree_cells: Array[Vector2i] = []
var night_gate_cells: Array[Vector2i] = []
var stepping_slot_cells: Array[Vector2i] = []

## symbol -> count of tiles laid (for harness assertions).
var tile_counts: Dictionary = {}
## Spawned gatherable object cells, for the respawn manager.
var object_spawns: Array = []  # [{cell, symbol}]

var rest_stump: RestStump


func _ready() -> void:
	_ysort = get_node_or_null(ysort_layer_path) as Node2D
	_feedback = get_node_or_null(feedback_layer_path)
	_load_data()
	_build_tiles()
	_build_objects()
	_place_player()
	_wire_stump_fade()


func _place_player() -> void:
	if spawn_cell == Vector2i(-1, -1):
		return
	var p := get_node_or_null(player_path) as Node2D
	if p != null:
		p.global_position = cell_center_world(spawn_cell)


func _wire_stump_fade() -> void:
	if rest_stump == null:
		return
	var fr := get_node_or_null(fade_rect_path) as ColorRect
	if fr != null:
		rest_stump.fade_rect = fr


# ---- data ----------------------------------------------------------------

func _load_data() -> void:
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	assert(f != null, "map_layout.txt missing")
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges(false, true) == "" and f.eof_reached():
			break
		if line.length() == 0:
			continue
		_layout.append(line)
	f.close()
	height = _layout.size()
	width = _layout[0].length() if height > 0 else 0

	var lf := FileAccess.open(LEGEND_PATH, FileAccess.READ)
	assert(lf != null, "map_legend.json missing")
	var parsed = JSON.parse_string(lf.get_as_text())
	lf.close()
	assert(parsed is Dictionary, "map_legend.json parse failed")
	_legend = parsed


# ---- tiles ---------------------------------------------------------------

func _build_tiles() -> void:
	var tiles: Dictionary = _legend.get("tiles", {})
	for r in range(height):
		var row := _layout[r]
		for c in range(min(width, row.length())):
			var sym := row[c]
			var spec: Dictionary = tiles.get(sym, {})
			if spec.is_empty():
				# Unknown symbol: fall back to grass so the map never has holes.
				set_cell(Vector2i(c, r), 2, ATLAS)
				continue
			var src := int(spec.get("source", 2))
			# g variant: deterministic pick among variant sources by cell hash.
			if bool(spec.get("variant_random", false)):
				src = _variant_source(c, r)
			set_cell(Vector2i(c, r), src, ATLAS)
			tile_counts[sym] = int(tile_counts.get(sym, 0)) + 1
			if bool(spec.get("spawn", false)):
				spawn_cell = Vector2i(c, r)


## Grass variant sources for `g` (T2A/T2B/T2C/T2D = 2/3/4/5), deterministic.
func _variant_source(c: int, r: int) -> int:
	var h := (c * 73856093) ^ (r * 19349663)
	h = (h >> 3) & 0xff
	if h < 40:
		return 3
	elif h < 80:
		return 4
	elif h < 110:
		return 5
	return 2


# ---- objects -------------------------------------------------------------

func _build_objects() -> void:
	var objects: Dictionary = _legend.get("objects", {})
	for r in range(height):
		var row := _layout[r]
		for c in range(min(width, row.length())):
			var sym := row[c]
			var cell := Vector2i(c, r)
			# landmark bookkeeping regardless of object presence
			match sym:
				"S": spawn_cell = cell
				"K": stepping_slot_cells.append(cell)
				"N": night_gate_cells.append(cell)
			if not objects.has(sym):
				continue
			_spawn_object(sym, cell, objects[sym])


func _spawn_object(sym: String, cell: Vector2i, spec: Dictionary) -> void:
	var world := cell_center_world(cell)
	match sym:
		"C":
			cauldron_cell = cell
			var caul := Sprite2D.new()
			caul.set_script(load("res://scripts/world/cauldron.gd"))
			caul.texture = load("res://assets/objects/cauldron.png")
			caul.offset = Vector2(0, -64)
			caul.set("object_id", "cauldron")
			_place(caul, world)
		"U":
			stump_cell = cell
			rest_stump = RestStump.new()
			_place(rest_stump, world)
		"B":
			bush_cell = cell
			var bush := BushDry.new()
			_place(bush, world)
		"N":
			var gate := NightGate.new()
			_place(gate, world)
		"O":
			# One world tree centered on the O cluster; only spawn for the first
			# O cell encountered, positioned at the cluster centroid.
			world_tree_cells.append(cell)
			if world_tree_cells.size() == 1:
				var tree := WorldTree.new()
				# centroid of the 2×2 O block: this cell + (1,0)+(0,1)+(1,1)
				var centroid := cell_center_world(cell)
				centroid += Vector2(0, 32)  # nudge into the block center
				_place(tree, centroid)
		"m":
			var mw := MysticWater.new()
			_place(mw, world)
		"T":
			_place(_gatherable(spec, cell, "res://assets/objects/tree_a.png", Vector2(0, -120)), world)
			object_spawns.append({"cell": cell, "symbol": sym})
		"F":
			_place(_gatherable(spec, cell, "res://assets/objects/flower.png", Vector2(0, -24)), world)
			object_spawns.append({"cell": cell, "symbol": sym})
		"R":
			_place(_gatherable(spec, cell, "res://assets/objects/rock.png", Vector2(0, -24)), world)
			object_spawns.append({"cell": cell, "symbol": sym})
		"s":
			_place(_gatherable(spec, cell, "res://assets/objects/stone.png", Vector2(0, -24)), world)
			object_spawns.append({"cell": cell, "symbol": sym})


func _gatherable(spec: Dictionary, cell: Vector2i, tex_path: String, off: Vector2) -> Gatherable:
	var g := Gatherable.new()
	var gth: Dictionary = spec.get("gatherable", {})
	g.item_id = String(gth.get("item_id", ""))
	g.unique = bool(gth.get("unique", false))
	# tree variant: alternate a/b texture deterministically
	var tex := tex_path
	if spec.has("variants") and tex_path.ends_with("tree_a.png"):
		var h := (cell.x * 2654435761) ^ (cell.y * 40503)
		if (h & 1) == 0:
			tex = "res://assets/objects/tree_b.png"
	g.texture = load(tex)
	g.offset = off
	return g


func _place(node: Node2D, world: Vector2) -> void:
	node.position = world
	node.y_sort_enabled = true
	if _ysort != null:
		_ysort.add_child(node)
	else:
		add_child(node)


# ---- queries -------------------------------------------------------------

func cell_center_world(cell: Vector2i) -> Vector2:
	return to_global(map_to_local(cell))

func world_to_cell(world: Vector2) -> Vector2i:
	return local_to_map(to_local(world))
