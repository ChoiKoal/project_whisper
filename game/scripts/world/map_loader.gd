extends TileMapLayer
class_name MapLoader
## Builds the 시작의 숲 map from data/map_layout.txt + data/map_legend.json.
## Replaces the hand-coded MapBuilder for the real game map (test_map keeps
## MapBuilder). 기획 수정 = 텍스트 수정: edit the two data files, not this script.
##
## Responsibilities:
##   - parse the 40×40 layout, set_cell for every tile per the legend
##   - (M6a) seamless ground: cluster-based grass variant placement, edge-overlay
##     sprites where grass borders dirt/water/mud, subtle per-cell brightness jitter
##   - spawn object scenes (trees/flowers/rocks/stones, cauldron, stump, bush,
##     night gate, world tree, mystic water) into `ysort_layer`
##   - (M6a) procedural object-density scatter (deterministic) on eligible ground
##   - remember spawn / landmark cells and expose query helpers for wiring + tests
##   - deterministic variant selection by cell hash (save reproducibility)
##
## Object instances are built in code (no fragile hand-authored .tscn per object).
##
## M6a save-compatibility contract: base tilemap cells are UNCHANGED (edge treatment
## is separate overlay sprites, brightness is a separate draw layer) so M4 tile
## counts stay exact; scatter is fully deterministic by cell hash so saved
## removed-object coords still line up after a reload.

const LAYOUT_PATH := "res://data/map_layout.txt"
const LEGEND_PATH := "res://data/map_legend.json"
const ATLAS := Vector2i(0, 0)

## Deterministic global seed mixed into every procedural hash (map coords → value).
const MAP_SEED := 0x9E3779B9

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

## symbol -> count of tiles laid (for harness assertions). Base tiles only.
var tile_counts: Dictionary = {}
## Spawned gatherable object cells, for the respawn manager. Includes both the
## authored (layout) objects and the M6a procedural scatter.
var object_spawns: Array = []  # [{cell, symbol}]

## Cells occupied by an authored/scattered object (so scatter never doubles up).
var _occupied: Dictionary = {}   # Vector2i -> true

var rest_stump: RestStump

## Overlay node holding the edge-transition sprites (drawn above ground tiles,
## below Y-sorted objects). Created in code.
var _edge_overlay: Node2D
## Custom-draw node for the subtle per-cell grass brightness jitter.
var _bright_overlay: Node2D

## ---- M6a scatter tuning ---------------------------------------------------
## Target object count in the level-design density table is ~4-6 trees / 6-8
## flowers / 1-2 rocks / 2-3 stones / 8-10 tufts per 100 tiles. On ~734 walkable
## cells that lands the whole map in the ~150-180 total range. The authored map
## already has ~60, so scatter fills the remainder.
const SCATTER_TARGET_TOTAL := 165

## Materials whose border with grass gets an edge overlay, keyed by source id.
const EDGE_MATERIAL := {1: "dirt", 7: "mud", 8: "water", 9: "water"}
## The four iso-grid neighbour directions → diamond-edge overlay direction code.
const EDGE_DIRS := [
	[Vector2i(1, 0), "br"],
	[Vector2i(0, 1), "bl"],
	[Vector2i(-1, 0), "tl"],
	[Vector2i(0, -1), "tr"],
]


func _ready() -> void:
	_ysort = get_node_or_null(ysort_layer_path) as Node2D
	_feedback = get_node_or_null(feedback_layer_path)
	_load_data()
	_build_tiles()
	_build_objects()
	_scatter_objects()
	_build_edge_overlays()
	_build_brightness_jitter()
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


## Deterministic 32-bit hash of a cell (+ optional channel salt). Stable across
## loads → the whole procedural layer reproduces exactly for save compatibility.
func _cell_hash(c: int, r: int, salt: int = 0) -> int:
	var h := (c * 73856093) ^ (r * 19349663) ^ (salt * 83492791) ^ MAP_SEED
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7fffffff


## Smooth value-noise in [0,1] from bilinear interpolation of a coarse hash grid.
## Used for organic grass-variant clusters (patches instead of per-cell noise).
func _value_noise(c: int, r: int, cell_size: int, salt: int) -> float:
	var gx := float(c) / float(cell_size)
	var gy := float(r) / float(cell_size)
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := gx - float(x0)
	var fy := gy - float(y0)
	# smoothstep the fractional parts for rounded blobs
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var n00 := float(_cell_hash(x0, y0, salt) & 0xffff) / 65535.0
	var n10 := float(_cell_hash(x0 + 1, y0, salt) & 0xffff) / 65535.0
	var n01 := float(_cell_hash(x0, y0 + 1, salt) & 0xffff) / 65535.0
	var n11 := float(_cell_hash(x0 + 1, y0 + 1, salt) & 0xffff) / 65535.0
	var nx0: float = lerp(n00, n10, fx)
	var nx1: float = lerp(n01, n11, fx)
	return lerp(nx0, nx1, fy)


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
			# g variant: deterministic cluster pick among variant sources.
			if bool(spec.get("variant_random", false)):
				src = _variant_source(c, r)
			set_cell(Vector2i(c, r), src, ATLAS)
			tile_counts[sym] = int(tile_counts.get(sym, 0)) + 1
			if bool(spec.get("spawn", false)):
				spawn_cell = Vector2i(c, r)


## Grass variant sources for `g` (T2A/T2B/T2C/T2D = 2/3/4/5). M6a: cluster-based
## via two-octave value noise so variants form organic patches instead of a
## per-cell checkerboard. Fully deterministic (same seed → same map).
func _variant_source(c: int, r: int) -> int:
	# Large blobs decide the dominant variant; a smaller octave adds edge break-up.
	var n := _value_noise(c, r, 5, 11) * 0.7 + _value_noise(c, r, 2, 29) * 0.3
	# Keep plain T2A (source 2) dominant; the decorated variants form patches.
	if n < 0.52:
		return 2            # T2A plain grass (majority ground)
	elif n < 0.68:
		return 4            # T2C clover patch
	elif n < 0.84:
		return 3            # T2B flowered patch
	return 5                # T2D bright flower-grass (rare highlights)


# ---- edge / transition overlays ------------------------------------------

## Overlay a neighbour-material bleed sprite on every grass cell that borders
## dirt / water / mud, one per bordering edge. Base tiles are untouched — these
## are separate Sprite2Ds parented under the tilemap (above ground, below the
## Y-sorted object layer), so M4 tile counts stay exact and Y-sort is preserved.
func _build_edge_overlays() -> void:
	_edge_overlay = Node2D.new()
	_edge_overlay.name = "EdgeOverlay"
	# z_index 0 relative to the tilemap draws it right on top of the ground cells;
	# the sibling YSortLayer is drawn afterwards, so objects stay above overlays.
	_edge_overlay.z_index = 1
	add_child(_edge_overlay)
	for r in range(height):
		var row := _layout[r]
		for c in range(min(width, row.length())):
			var cell := Vector2i(c, r)
			if not _is_grass_cell(cell):
				continue
			for pair in EDGE_DIRS:
				var nb: Vector2i = cell + pair[0]
				var mat := _edge_material_at(nb)
				if mat == "":
					continue
				var tex := load("res://assets/tiles/edge_%s_%s.png" % [mat, pair[1]])
				if tex == null:
					continue
				var s := Sprite2D.new()
				s.texture = tex
				s.centered = true
				s.position = map_to_local(cell)
				_edge_overlay.add_child(s)


## True if the cell's current base tile is one of the grass sources (2..5).
func _is_grass_cell(cell: Vector2i) -> bool:
	var src := get_cell_source_id(cell)
	return src >= 2 and src <= 5


## Edge-material name ("dirt"/"water"/"mud") if the cell is one of those, else "".
func _edge_material_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return ""
	return EDGE_MATERIAL.get(get_cell_source_id(cell), "")


# ---- brightness jitter ---------------------------------------------------

## A single custom-draw node painting a faint ±3% brightness diamond over each
## grass cell (deterministic per cell) to break up the flat colour fields.
## Cheaper and simpler than per-cell TileMapLayer modulate (unsupported), and it
## does not touch the base tiles.
func _build_brightness_jitter() -> void:
	_bright_overlay = Node2D.new()
	_bright_overlay.name = "BrightnessJitter"
	_bright_overlay.z_index = 2
	_bright_overlay.set_script(load("res://scripts/world/ground_jitter.gd"))
	add_child(_bright_overlay)
	_bright_overlay.call("setup", self)


## Public: brightness jitter factor for a grass cell (used by the jitter node).
## Returns a signed value in roughly [-0.03, 0.03].
func brightness_jitter(cell: Vector2i) -> float:
	if not _is_grass_cell(cell):
		return 0.0
	var n := float(_cell_hash(cell.x, cell.y, 53) & 0xffff) / 65535.0
	return (n - 0.5) * 0.06


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
			_occupied[cell] = true
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
		"T", "F", "R", "s", "t", "h":
			_place(rebuild_gatherable(sym, cell), world)
			object_spawns.append({"cell": cell, "symbol": sym})


## Deterministic texture path + sprite offset for a scatter/authored gatherable
## symbol at a cell. Centralised so ObjectRespawn reproduces the exact same
## variant when it rebuilds (save/respawn determinism).
func _object_texture(sym: String, cell: Vector2i) -> Array:  # [path, offset]
	var h := _cell_hash(cell.x, cell.y, 7)
	match sym:
		"T":
			# trees: a/b/c deterministic split.
			var pick := h % 3
			if pick == 0:
				return ["res://assets/objects/tree_a.png", Vector2(0, -120)]
			elif pick == 1:
				return ["res://assets/objects/tree_b.png", Vector2(0, -120)]
			return ["res://assets/objects/tree_c.png", Vector2(0, -120)]
		"F":
			var pick := h % 3
			if pick == 0:
				return ["res://assets/objects/flower.png", Vector2(0, -24)]
			elif pick == 1:
				return ["res://assets/objects/flower_violet.png", Vector2(0, -24)]
			return ["res://assets/objects/flower_pink.png", Vector2(0, -24)]
		"R":
			return ["res://assets/objects/rock.png", Vector2(0, -24)]
		"s":
			return ["res://assets/objects/stone.png", Vector2(0, -24)]
		"t":
			return ["res://assets/objects/grass_tuft.png", Vector2(0, -24)]
		"h":
			return ["res://assets/objects/bush_green.png", Vector2(0, -40)]
	return ["res://assets/objects/rock.png", Vector2(0, -24)]


## Build a Gatherable for a symbol at a cell (used by initial spawn, scatter, and
## ObjectRespawn). Reads the item_id from the legend's object spec.
func rebuild_gatherable(sym: String, cell: Vector2i) -> Gatherable:
	var spec: Dictionary = _legend.get("objects", {}).get(sym, {})
	var tex_off := _object_texture(sym, cell)
	return _gatherable(spec, cell, tex_off[0], tex_off[1])


func _gatherable(spec: Dictionary, cell: Vector2i, tex_path: String, off: Vector2) -> Gatherable:
	var g := Gatherable.new()
	var gth: Dictionary = spec.get("gatherable", {})
	g.item_id = String(gth.get("item_id", ""))
	g.unique = bool(gth.get("unique", false))
	g.texture = load(tex_path)
	g.offset = off
	return g


# ---- procedural density scatter (M6a) ------------------------------------

## Deterministically scatter extra decorative/gatherable objects on eligible
## plain-ground cells to hit the level-design density table. Eligible = plain
## G/g cell, ≥1 cell away from the D path, gates, landmarks and the spawn 3×3,
## and not already occupied. Three zone bands weight the flavour (approach zone
## = more flowers, hills = more trees, mid = reeds/tufts). Fully deterministic.
func _scatter_objects() -> void:
	var eligible: Array[Vector2i] = []
	for r in range(height):
		var row := _layout[r]
		for c in range(min(width, row.length())):
			var cell := Vector2i(c, r)
			if _is_scatter_eligible(cell):
				eligible.append(cell)

	var already := object_spawns.size()
	var want := SCATTER_TARGET_TOTAL - already
	if want <= 0 or eligible.is_empty():
		return

	# Deterministic ordering + selection: sort eligible cells by their hash so the
	# chosen subset is stable regardless of iteration order, then take the first
	# `want`. (Cells keep their (c,r) identity so respawn/save still line up.)
	eligible.sort_custom(func(a, b):
		return _cell_hash(a.x, a.y, 101) < _cell_hash(b.x, b.y, 101))
	var n: int = min(want, eligible.size())
	for i in range(n):
		var cell: Vector2i = eligible[i]
		var sym := _scatter_symbol(cell)
		var spec: Dictionary = _legend.get("objects", {}).get(sym, {})
		_occupied[cell] = true
		_spawn_object(sym, cell, spec)


## Eligibility: plain grass ground, not occupied, not on/adjacent to a D path
## tile, not a gate/landmark/void/water, and outside the spawn 3×3 safe area.
func _is_scatter_eligible(cell: Vector2i) -> bool:
	if _occupied.has(cell):
		return false
	var sym := _sym_at(cell)
	if sym != "G" and sym != "g":
		return false  # only plain ground (skips paths, gates, landmarks, water…)
	# Keep the spawn 3×3 clear so the player never wakes up boxed-in.
	if spawn_cell != Vector2i(-1, -1) \
			and absi(cell.x - spawn_cell.x) <= 1 and absi(cell.y - spawn_cell.y) <= 1:
		return false
	# ≥1 cell away from any D path tile, gate cell, or key landmark object so gate
	# topology / choke points are never blocked.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _blocks_topology(_sym_at(cell + Vector2i(dx, dy))):
				return false
	return true


## Symbols that scatter must stay ≥1 cell away from (path + gate + choke cells).
func _blocks_topology(sym: String) -> bool:
	match sym:
		"D", "K", "N", "B", "O", "C", "U", "S", "m":
			return true
	return false


func _sym_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _layout.size():
		return ""
	var row: String = _layout[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


## Pick a scatter object symbol for a cell, weighted by zone band + the density
## table proportions (tufts most common, then flowers, trees, stones, rocks).
##   band 0 (rows 0..16, north approach / hills): more trees
##   band 1 (rows 17..27, central meadow approach): more flowers
##   band 2 (rows 28..39, southern home ground): balanced, more tufts/bushes
func _scatter_symbol(cell: Vector2i) -> String:
	var band := 0
	if cell.y >= 28:
		band = 2
	elif cell.y >= 17:
		band = 1
	# weight table per band: [tuft t, flower F, tree T, bush h, stone s, rock R]
	var weights: Array
	match band:
		0: weights = [26, 14, 14, 6, 6, 3]     # hills: trees prominent
		1: weights = [24, 24, 6, 8, 5, 3]      # approach: flowers prominent
		_: weights = [30, 14, 8, 10, 6, 3]     # home: tufts + bushes
	var syms := ["t", "F", "T", "h", "s", "R"]
	var total := 0
	for w in weights:
		total += w
	var roll := _cell_hash(cell.x, cell.y, 211) % total
	var acc := 0
	for i in range(syms.size()):
		acc += weights[i]
		if roll < acc:
			return syms[i]
	return "t"


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


## True if the cell's current tile is walkable (custom-data). Used by the
## pathfinding grid (M6a). Out-of-bounds / empty cells are treated non-walkable.
func is_cell_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	var data := get_cell_tile_data(cell)
	if data == null:
		return false
	return bool(data.get_custom_data("walkable"))
