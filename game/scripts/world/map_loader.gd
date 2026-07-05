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

## Default (grove) data files. A scene may override these two exports to build a
## different world (v0.5.0 home island) from the same loader.
const LAYOUT_PATH := "res://data/map_layout.txt"
const LEGEND_PATH := "res://data/map_legend.json"
## (v0.5 phase B) Parallel height map: one char per cell — '0'/'1'/'2' heights, '/' ramp.
## Optional (a world without hills simply omits it → everything stays height 0).
const HEIGHT_PATH := "res://data/map_height.txt"
## (v0.5.0) Per-scene overrides. Empty → use the LAYOUT_PATH / LEGEND_PATH defaults.
@export var layout_path_override: String = ""
@export var legend_path_override: String = ""
@export var height_path_override: String = ""
const ATLAS := Vector2i(0, 0)

## Deterministic global seed mixed into every procedural hash (map coords → value).
const MAP_SEED := 0x9E3779B9

## ---- Draw-order z tiers (v0.2.1 bug-A fix) --------------------------------
## Ground tiles sit at the tilemap's own z (0). The edge overlays and brightness
## jitter are children of the tilemap (z_as_relative) at these z values, and the
## sibling YSortLayer carries YSORT_Z (set in the scene) which MUST be greater than
## both so the player/objects always draw above the ground treatment. The glow
## sprites live on a separate CanvasLayer (always above the root canvas); UI panels
## are on higher CanvasLayers. Exposed as constants so the harness can assert the
## ordering programmatically.
const EDGE_OVERLAY_Z := 1
const JITTER_Z := 2
## Expected z_index of the YSortLayer node in the grove scene (player + objects).
const YSORT_Z := 5
## (v0.3.0 A1) Cliff-skirt sprites hang BELOW the island slab. They are children of
## the Ground tilemap (z_as_relative) at a negative z so they draw under the ground
## tiles (effective z 0 + (-1) = -1) — the island reads as a floating diorama slab.
const CLIFF_SKIRT_Z := -1

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
	_load_height_data()
	_classify_void_cells()
	_build_tiles()
	_build_objects()
	_scatter_objects()
	_build_ridges()
	_build_cliff_skirts()
	_classify_elevation()
	_build_elevation()
	_build_edge_overlays()
	# v0.5: brightness jitter retired — the real CC0 grass tiles carry their own
	# per-diamond texture variation, so the synthetic ±3% jitter is redundant.
	# (_build_brightness_jitter kept in the file for reference / harness compat.)
	_build_border_collision()
	_lift_hill_objects()
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
	var layout_path := layout_path_override if layout_path_override != "" else LAYOUT_PATH
	var legend_path := legend_path_override if legend_path_override != "" else LEGEND_PATH
	var f := FileAccess.open(layout_path, FileAccess.READ)
	# assert() is compiled OUT of release templates, so a missing layout would
	# fall through to f.eof_reached() on a NULL handle → SIGSEGV in export.
	# Guard explicitly and bail with a warning instead.
	if f == null:
		push_warning("MapLoader: %s missing; map not built" % layout_path)
		return
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

	# assert() is stripped in release templates, so a missing legend would fall
	# through to lf.get_as_text() on a NULL handle → SIGSEGV during the grove
	# change_scene flush (this runs inside MapLoader._ready). Guard explicitly.
	var lf := FileAccess.open(legend_path, FileAccess.READ)
	if lf == null:
		push_warning("MapLoader: %s missing; using grass fallback" % legend_path)
		_legend = {}
		return
	var parsed: Variant = JSON.parse_string(lf.get_as_text())
	lf.close()
	# A non-Dictionary parse (also asserted-only before) would make every later
	# _legend.get(...) call fail; fall back to an empty legend instead.
	if parsed is Dictionary:
		_legend = parsed
	else:
		push_warning("MapLoader: %s parse failed; using grass fallback" % legend_path)
		_legend = {}


## (v0.5 phase B) Load the parallel height map into `_height_rows`. A missing file
## leaves the map flat (every cell height 0) — the elevation build then no-ops.
func _load_height_data() -> void:
	_height_rows.clear()
	var hp := height_path_override if height_path_override != "" else HEIGHT_PATH
	var hf := FileAccess.open(hp, FileAccess.READ)
	if hf == null:
		return  # flat world; not an error
	while not hf.eof_reached():
		var line := hf.get_line()
		if line.length() == 0:
			continue
		_height_rows.append(line)
	hf.close()


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


# ---- VOID classification (v0.4.0 A3) -------------------------------------

## Authored VOID cells that are INTERIOR ridge walls (unreachable from the map
## outside via 4-connected VOID) — as opposed to the outer border VOID that fringes
## the island. Interior ridge V gets a raised rock-ridge sprite so it reads as
## impassable TERRAIN ("바위 맵"); border V keeps the cliff-skirt treatment. Populated
## by _classify_void_cells(); read by _build_ridges() and _build_cliff_skirts().
var ridge_cells: Dictionary = {}   # Vector2i -> true (interior ridge V)

## Classify every authored VOID cell as INTERIOR RIDGE or OUTER BORDER.
##
## The spec's first suggestion (flood-fill from outside → unreachable V = ridge) does NOT
## discriminate on THIS map, because the interior wall bands touch the left/right border
## void (row 7 spans full width; rows 14-16 likewise), so every V is reachable from
## outside. We therefore use the spec's OTHER stated rule — robustly generalised to thick
## bands: a V cell is an INTERIOR RIDGE if it sits between playable land on BOTH opposing
## sides along either axis. "Opposing sides" is tested by walking outward across the
## contiguous VOID band: if walking north AND south each first reaches playable LAND
## (before leaving the map or hitting water), the cell is sandwiched inside the island →
## it is an interior wall band, not the fringe. Same for east/west.
##
## This lights up exactly the two authored interior bands (G2 corridor walls rows 14-16,
## G3 night-path wall row 7) and leaves the outer border fringe (which opens to off-map or
## to water on one side) as cliff. Deterministic; authored-`_layout` only (a runtime
## gathered HOLLOW is a different tile source and is never in `_layout`).
func _classify_void_cells() -> void:
	ridge_cells.clear()
	if height == 0 or width == 0:
		return
	for r in range(height):
		var row: String = _layout[r] if r < _layout.size() else ""
		for c in range(min(width, row.length())):
			if row[c] != "V":
				continue
			var cell := Vector2i(c, r)
			var ns := _scan_reaches_land(cell, Vector2i(0, -1)) and _scan_reaches_land(cell, Vector2i(0, 1))
			var ew := _scan_reaches_land(cell, Vector2i(-1, 0)) and _scan_reaches_land(cell, Vector2i(1, 0))
			if ns or ew:
				ridge_cells[cell] = true


## Walk from `cell` in direction `dir` across contiguous authored VOID. Return true if the
## first NON-void cell reached is playable LAND (not water, not off-map). Leaving the map
## bounds → false (that side opens to the outside = a fringe, not an interior sandwich).
func _scan_reaches_land(cell: Vector2i, dir: Vector2i) -> bool:
	var p := cell + dir
	# Bound the walk by the map span so a malformed layout can never loop forever.
	var steps := width + height
	while steps > 0:
		steps -= 1
		var sym := _sym_at(p)
		if sym == "":
			return false                       # left the map / no data → open to outside
		if sym != "V":
			# First non-void cell: land iff it is not water/mystic (island ground/obj).
			return sym != "W" and sym != "w" and sym != "m"
		p += dir
	return false


# ---- interior ridge walls (v0.4.0 A3) ------------------------------------

## Node2D holding the ridge sprites (raised rock mounds on interior VOID bands).
var _ridge_overlay: Node2D
## Count of ridge sprites placed, for the harness.
var ridge_sprite_count: int = 0
## Node2D holding the worn-dirt trail-hint decals leading to the G2 corridor.
var _trail_overlay: Node2D
var trail_decal_count: int = 0

## z of ridge sprites: they are TERRAIN, so they sit below the YSorted objects/player
## (z5) but above the ground treatment. Children of the tilemap (z_as_relative), so
## effective z = 0 + RIDGE_Z. A small positive value keeps them over the ground tiles
## and edge overlays while staying under the y-sorted objects.
const RIDGE_Z := 3

## Lay a raised rock-ridge sprite on every interior ridge VOID cell so the authored wall
## bands (G2 corridor walls rows ~14-16, G3 night-path wall row ~7) read as impassable
## rock rather than flat black hollow-like tiles. Also drops a few worn-dirt trail decals
## on the playable cells just south of the G2 corridor gap (subtle "the path is here" hint).
## VISUAL ONLY — collision is unchanged (the authored-V border body already seals these
## cells in _build_border_collision).
func _build_ridges() -> void:
	_ridge_overlay = Node2D.new()
	_ridge_overlay.name = "Ridges"
	_ridge_overlay.z_index = RIDGE_Z
	add_child(_ridge_overlay)

	# v0.5: continuous rock WALL — real CC0 iso rock-cliff pillars (128×~230). Two
	# variants alternate deterministically for break-up; laid on every interior ridge
	# cell they tile side-by-side into a continuous wall band (no more tent/cone rows).
	var tex_a := load("res://assets/tiles/ridge_rock.png") as Texture2D
	var tex_b := load("res://assets/tiles/ridge_rock_b.png") as Texture2D
	if tex_a == null:
		push_warning("MapLoader: ridge_rock texture missing; skipping ridges")
	else:
		for cell in ridge_cells:
			var s := Sprite2D.new()
			# Alternate the two wall variants by cell parity+hash so the wall face
			# breaks up but stays a continuous band.
			var use_b := tex_b != null and (_cell_hash(cell.x, cell.y, 907) & 1) == 1
			var t: Texture2D = tex_b if use_b else tex_a
			s.texture = t
			s.centered = false
			# Anchor the sprite's BOTTOM (the wall base) at the cell's lower rim so the
			# rock rises up out of the diamond. The piece is 128 wide; left edge at
			# center.x-64, bottom at center.y + TILE_HALF_H.
			var center: Vector2 = map_to_local(cell)
			var th: float = float(t.get_height())
			s.position = center + Vector2(-64.0, TILE_HALF_H - th)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_ridge_overlay.add_child(s)
			ridge_sprite_count += 1

	_build_corridor_trail()


## (legacy) How far the old cone-mound rose; retained for reference. v0.5 anchors the
## wall by its base instead (see _build_ridges).
const RIDGE_RISE := 96.0

## Drop 2-3 worn-dirt patch decals on playable cells leading from the south toward the
## G2 bush corridor gap, hinting the corridor is the way through. The gap is the single
## non-ridge column in the G2 wall band (the authored bush cell `B`), so we trail up to it
## from the meadow rows just below.
func _build_corridor_trail() -> void:
	_trail_overlay = Node2D.new()
	_trail_overlay.name = "CorridorTrail"
	_trail_overlay.z_index = EDGE_OVERLAY_Z  # sit with the ground treatment, below objects
	add_child(_trail_overlay)
	var tex := load("res://assets/tiles/worn_dirt_patch.png") as Texture2D
	if tex == null:
		return
	# The corridor gap is at the bush cell (bush_cell); trail the 3 cells directly south.
	if bush_cell == Vector2i(-1, -1):
		return
	for i in range(1, 4):  # 1,2,3 cells south of the bush
		var cell := bush_cell + Vector2i(0, i)
		if not is_cell_walkable(cell):
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.position = map_to_local(cell)
		# slight deterministic horizontal jitter so the trail doesn't look ruler-straight
		var j := (int(_cell_hash(cell.x, cell.y, 313)) % 11) - 5
		s.position += Vector2(float(j), 0.0)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_trail_overlay.add_child(s)
		trail_decal_count += 1


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
	# Draw order (v0.2.1 bug-A fix): ground tiles (z0) < edge overlays (z1) <
	# brightness jitter (z2) < YSortLayer objects+player (z5, set in the scene) <
	# glow (separate CanvasLayer) < UI. These overlays are children of the Ground
	# tilemap with z_as_relative, so their effective z is 0+1 / 0+2 — strictly below
	# the YSortLayer's z5, so the player/objects always render ABOVE the ground
	# treatment (previously z1/z2 beat the YSortLayer's z0 and drew over the player,
	# most visibly at night when the CanvasModulate darkened the overlays).
	_edge_overlay.z_index = EDGE_OVERLAY_Z
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
	var jitter_script := load("res://scripts/world/ground_jitter.gd")
	if jitter_script == null:
		push_warning("MapLoader: ground_jitter.gd failed to load; skipping jitter")
		return
	_bright_overlay = Node2D.new()
	_bright_overlay.name = "BrightnessJitter"
	_bright_overlay.z_index = JITTER_Z
	_bright_overlay.set_script(jitter_script)
	add_child(_bright_overlay)
	# Duck-typed call: only invoke if the script actually exposes setup().
	if _bright_overlay.has_method("setup"):
		_bright_overlay.call("setup", self)


## Public: brightness jitter factor for a grass cell (used by the jitter node).
## Returns a signed value in roughly [-0.03, 0.03].
func brightness_jitter(cell: Vector2i) -> float:
	if not _is_grass_cell(cell):
		return 0.0
	var n := float(_cell_hash(cell.x, cell.y, 53) & 0xffff) / 65535.0
	return (n - 0.5) * 0.06


# ---- diorama cliff skirts (v0.3.0 A1) ------------------------------------

## Node2D holding the cliff-skirt sprites (drawn below the ground tiles).
var _cliff_overlay: Node2D
## Count of skirt sprites placed, for the harness.
var cliff_skirt_count: int = 0
## Cells that received a south-facing skirt (for the harness south-edge assertion).
var cliff_skirt_south_cells: Array[Vector2i] = []
## v0.5: loaded cliff-face textures (rock wall variants) used for the island edge.
var _cliff_faces: Array[Texture2D] = []


## Deterministic cliff-face variant for an edge cell (varied rock wall look).
func _cliff_face_for(cell: Vector2i) -> Texture2D:
	if _cliff_faces.is_empty():
		return null
	var idx := int(_cell_hash(cell.x, cell.y, 611)) % _cliff_faces.size()
	return _cliff_faces[idx]

## The half-height of a skirt sprite's rim relative to the diamond center: the skirt
## PNG is 128×112 with its top (the diamond's lower rim) anchored at the cell's local
## origin +HALF (so the wall hangs from the tile's bottom edges downward).
const SKIRT_TOP_OFFSET := 0.0

## Render a downward earth/rock cross-section under every authored playable cell whose
## outer (south / east / south-east) neighbour is off-island (VOID or out of bounds),
## so the map reads as a floating-island slab instead of ending in flat void tiles.
##
## Iso-diamond screen geometry (Diamond Down): a cell's two lower silhouette edges
## face +row (screen SW → the 's' skirt) and +col (screen SE → the 'e' skirt). Where
## BOTH the +row and +col neighbours are off-island the outer corner shows, so an
## 'se' corner skirt is placed as well. Sprites are children of the tilemap at a
## negative z (below the ground) and offset downward so the wall tucks under the
## tile's bottom vertex. VISUAL ONLY — no collision, base tiles untouched.
func _build_cliff_skirts() -> void:
	_cliff_overlay = Node2D.new()
	_cliff_overlay.name = "CliffSkirts"
	_cliff_overlay.z_index = CLIFF_SKIRT_Z
	add_child(_cliff_overlay)

	# v0.5: real CC0 iso rock cliff FACES (128×~230) replace the procedural skirts.
	# Four variants give the island edge a natural, varied rock wall → true floating
	# diorama slab. Falls back gracefully if a texture is missing.
	_cliff_faces.clear()
	for n in ["cliff_face_a", "cliff_face_b", "cliff_face_c", "cliff_face_d"]:
		var t := load("res://assets/tiles/%s.png" % n) as Texture2D
		if t != null:
			_cliff_faces.append(t)
	if _cliff_faces.is_empty():
		push_warning("MapLoader: cliff-face textures missing; skipping skirts")
		return

	for r in range(height):
		var row := _layout[r] if r < _layout.size() else ""
		for c in range(min(width, row.length())):
			if not _is_island_cell(Vector2i(c, r)):
				continue
			# "Open" = the neighbour drops to the EXTERIOR void (or off-map), where a cliff
			# edge belongs. An interior RIDGE neighbour is raised rock terrain, NOT a cliff
			# drop, so it must not sprout a skirt (v0.4.0 A3: ridge ≠ cliff).
			var south_open := _is_cliff_open(Vector2i(c, r + 1))   # +row → screen SW
			var east_open := _is_cliff_open(Vector2i(c + 1, r))    # +col → screen SE
			if not south_open and not east_open:
				continue
			# South-facing (or corner) edges get the full cliff face and are recorded for
			# the harness; a purely east-facing edge also gets a face (island reads solid).
			var tex := _cliff_face_for(Vector2i(c, r))
			_place_skirt(tex, Vector2i(c, r))
			if south_open:
				cliff_skirt_south_cells.append(Vector2i(c, r))


## A cell is "island" (part of the authored playable slab) if it is in-bounds and its
## authored symbol is not VOID. Uses `_layout` (authored data), NOT live tile data, so
## a runtime gathered-VOID hole in the interior does not sprout a cliff wall.
func _is_island_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.y >= _layout.size():
		return false
	var row: String = _layout[cell.y]
	if cell.x >= row.length():
		return false
	return row[cell.x] != "V"


## True if `cell` is an EXTERIOR-void / off-map drop that a cliff skirt should hang under.
## Out-of-bounds counts (the map fringe). An interior RIDGE cell does NOT — it is raised
## rock terrain, not a cliff edge, so the island cell beside it stays skirt-free.
func _is_cliff_open(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.y >= _layout.size():
		return true
	var row: String = _layout[cell.y]
	if cell.x >= row.length():
		return true
	if row[cell.x] != "V":
		return false            # a playable island cell
	return not ridge_cells.has(cell)   # exterior void = open; interior ridge = not


## Add one skirt sprite centered on the cell, hanging below its bottom rim. The PNG's
## top row is the diamond's lower rim; anchoring the sprite top at the cell origin +
## TILE_HALF_H drops the wall straight down from the tile's bottom vertex.
func _place_skirt(tex: Texture2D, cell: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	# map_to_local gives the cell center; the 128-wide cliff face's left edge sits at
	# center.x - 64. Its top rim tucks just above the diamond's centre so the rock
	# reads as the tile's own edge dropping away into the void below.
	var center := map_to_local(cell)
	s.position = center + Vector2(-64.0, -TILE_HALF_H * 0.5 + SKIRT_TOP_OFFSET)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cliff_overlay.add_child(s)
	cliff_skirt_count += 1


# ---- border collision (v0.2.1 bug-B fix) ---------------------------------

## Physics node holding the map-border walls. Built in code.
var _border_body: StaticBody2D

## Half-extents of a 128×64 iso diamond, for per-cell collision polygons.
const TILE_HALF_W := 64.0
const TILE_HALF_H := 32.0

## Seal the playable area so WASD movement (which only samples tile speed, not
## walkability — non-walkable tiles rely on physics) can never leave the map.
##
## Two layers, belt-and-suspenders:
##   1. A diamond collision polygon on every ORIGINAL-layout VOID cell (symbol 'V').
##      Read from `_layout`, NOT from live tile data, so a VOID hole created at
##      runtime by GATHERING a tile inside the map stays walkable exactly as before
##      — only the authored border band becomes solid.
##   2. A rectangular perimeter frame just outside the 40×40 iso bounds, catching
##      the outermost edge (e.g. the southern grass row that borders open space with
##      no VOID beyond it).
##
## Water/mystic cells already carry their own TileSet physics polygons, so they are
## left to the tilemap; the stepping-stone mechanism (swap water→dirt via set_cell)
## keeps working untouched. This node never covers water cells.
func _build_border_collision() -> void:
	_border_body = StaticBody2D.new()
	_border_body.name = "BorderCollision"
	# collision_layer 1 matches the tileset physics layer the player collides with.
	_border_body.collision_layer = 1
	_border_body.collision_mask = 0
	add_child(_border_body)

	# 1. Per-cell diamond walls on authored VOID cells.
	for r in range(height):
		var row := _layout[r] if r < _layout.size() else ""
		for c in range(min(width, row.length())):
			if row[c] != "V":
				continue
			var col := CollisionPolygon2D.new()
			var center := map_to_local(Vector2i(c, r))
			col.polygon = PackedVector2Array([
				center + Vector2(0, -TILE_HALF_H),
				center + Vector2(TILE_HALF_W, 0),
				center + Vector2(0, TILE_HALF_H),
				center + Vector2(-TILE_HALF_W, 0),
			])
			_border_body.add_child(col)

	# 2. Perimeter frame just outside the iso bounds (thick walls so fast motion
	#    can't tunnel). Computed from the four extreme cell centers.
	_build_perimeter_frame()


## A rectangular ring of four thick wall segments enclosing the whole iso map, so
## the outermost walkable cells (with no VOID beyond them) are still sealed.
func _build_perimeter_frame() -> void:
	if width <= 0 or height <= 0:
		return
	# Iso extremes: top = cell(0,0) top vertex, bottom = cell(w-1,h-1) bottom vertex,
	# left = cell(0,h-1) left vertex, right = cell(w-1,0) right vertex.
	var top := map_to_local(Vector2i(0, 0)).y - TILE_HALF_H
	var bottom := map_to_local(Vector2i(width - 1, height - 1)).y + TILE_HALF_H
	var left := map_to_local(Vector2i(0, height - 1)).x - TILE_HALF_W
	var right := map_to_local(Vector2i(width - 1, 0)).x + TILE_HALF_W
	var thick := 128.0
	var pad := 8.0
	# Each wall is a CollisionShape2D rectangle hugging one outer edge.
	var walls := [
		# top:    spans full width, sits above `top`
		[Vector2((left + right) * 0.5, top - pad - thick * 0.5), Vector2(right - left + thick * 2, thick)],
		# bottom: below `bottom`
		[Vector2((left + right) * 0.5, bottom + pad + thick * 0.5), Vector2(right - left + thick * 2, thick)],
		# left:   left of `left`
		[Vector2(left - pad - thick * 0.5, (top + bottom) * 0.5), Vector2(thick, bottom - top + thick * 2)],
		# right:  right of `right`
		[Vector2(right + pad + thick * 0.5, (top + bottom) * 0.5), Vector2(thick, bottom - top + thick * 2)],
	]
	for w in walls:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = w[1]
		cs.shape = rect
		cs.position = w[0]
		_border_body.add_child(cs)


## Test helper: true if a world point lies inside a border wall (VOID cell diamond
## or the perimeter frame). Used by the containment harness to prove a motion test
## at a border midpoint is blocked. Uses the same authored-VOID data as the builder.
func point_in_border(world: Vector2) -> bool:
	var cell := world_to_cell(world)
	# Authored VOID cell?
	if cell.y >= 0 and cell.y < _layout.size():
		var row: String = _layout[cell.y]
		if cell.x >= 0 and cell.x < row.length() and row[cell.x] == "V":
			return true
	# Outside the iso bounds → caught by the perimeter frame.
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return true
	return false


# ---- real elevation (v0.5 phase B) ---------------------------------------
##
## Owner: "언덕이면 언덕처럼 / 최악중의 최악" → real height, not a flat decal. A parallel
## height map (data/map_height.txt, digits 0-2, '/' = ramp) lifts the central grass
## meadow ("풀 언덕", authored rows 17-23) to +1, a small core to +2. Elevation is now
## GAMEPLAY, not just visual:
##   - each raised cell is drawn on a dedicated elevation TileMapLayer offset -HILL_LIFT
##     per level (real per-height layer, same tileset), so the plateau reads as lifted
##     ground with the correct iso stacking;
##   - grass-topped rock CLIFF FACES are drawn on every downhill (screen S / E) height
##     transition, auto-selecting straight vs. corner by neighbourhood; ramp cells show
##     a worn slope instead of a wall;
##   - a height TRANSITION BLOCKS movement (both physics collision on the ledge AND the
##     AStar graph edge) unless one side is a ramp — the player climbs only at ramps;
##   - objects/player standing on a raised cell get a matching -HILL_LIFT*level position
##     offset so they sit ON the plateau and Y-sort stays correct across levels.
## `height_at()` / `is_ramp()` / `can_traverse()` / `hill_cells` / `ramp_cells` are the
## public surface the TouchController (height-aware AStar) and the harness read.

## Vertical lift (px) per elevation level. Iso half-tile — one plateau step.
const HILL_LIFT := 32.0
## z of the raised-surface elevation layers: above ground + edge overlays, below the
## y-sorted objects so the player still draws over the plateau ground.
const HILL_Z := 3
## z of the cliff-face sprites on height transitions (sit with the elevation surface).
const CLIFF_FACE_Z := 3

## Parsed height rows (one string per map row; chars '0'/'1'/'2'/'/'). Empty → flat.
var _height_rows: Array[String] = []
## cell -> elevation level (1 or 2). Height-0 cells are NOT stored (default 0).
var elevation: Dictionary = {}
## Raised (level ≥ 1) cells and the authored ramp cells.
var hill_cells: Dictionary = {}   # Vector2i -> level (1 or 2)
var ramp_cells: Dictionary = {}   # Vector2i -> true
## Per-level elevation TileMapLayer children (index = level).
var _elev_layers: Array[TileMapLayer] = []
## Node holding the cliff-face + ramp transition sprites.
var _cliff_face_overlay: Node2D
var hill_sprite_count: int = 0     # raised surface tiles laid (harness)
var cliff_face_count: int = 0      # transition cliff-face apron sprites (harness)
var ramp_slope_count: int = 0      # ramp slope sprites (harness)
## StaticBody sealing the non-ramp height ledges (can't walk off/into a cliff).
var _ledge_body: StaticBody2D
var ledge_collider_count: int = 0

## Public: authored/plateau elevation level of a cell (0 if flat/unknown/off-map).
func height_at(cell: Vector2i) -> int:
	return int(elevation.get(cell, 0))

## Public: elevation level (legacy alias kept for older callers).
func elevation_of(cell: Vector2i) -> int:
	return height_at(cell)

## Public: is this an authored ramp cell (a legal up/down crossing)?
func is_ramp(cell: Vector2i) -> bool:
	return ramp_cells.has(cell)

## Public: may the player cross directly between two 4-adjacent cells? Same height →
## yes. Different height → only if EITHER endpoint is a ramp (the stair). Used by the
## height-aware AStar in TouchController and by movement/physics.
func can_traverse(a: Vector2i, b: Vector2i) -> bool:
	if height_at(a) == height_at(b):
		return true
	return is_ramp(a) or is_ramp(b)

## Extra Y offset (px, negative = up) for something standing on `cell`, so raised
## objects/tiles sit on their plateau. A ramp is drawn at the mid-height between its
## low and high neighbour.
func height_offset(cell: Vector2i) -> float:
	if is_ramp(cell):
		return -HILL_LIFT * _ramp_mid_level(cell)
	return -HILL_LIFT * float(height_at(cell))

## Mid level (float) a ramp bridges: average of its highest and lowest 4-neighbour
## levels (so a 0↔1 ramp draws at 0.5, a 1↔2 ramp at 1.5).
func _ramp_mid_level(cell: Vector2i) -> float:
	var lo := 99
	var hi := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var lv := height_at(cell + d)
		lo = mini(lo, lv)
		hi = maxi(hi, lv)
	if lo == 99:
		return float(_raw_height_level(cell))
	return (float(lo) + float(hi)) * 0.5

## Raw digit level at a cell from the height file ('/' resolves to its neighbour mid).
func _raw_height_level(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= _height_rows.size():
		return 0
	var row: String = _height_rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return 0
	var ch := row[cell.x]
	if ch == "1":
		return 1
	if ch == "2":
		return 2
	return 0

## Classify elevation from the parallel height map. Fills `elevation` (level ≥ 1),
## `hill_cells` (level), and `ramp_cells`. A raised cell must also be authored island
## ground (never a border-V / water) so heights can't float over the void.
func _classify_elevation() -> void:
	elevation.clear()
	hill_cells.clear()
	ramp_cells.clear()
	if _height_rows.is_empty() or height == 0:
		return
	for r in range(min(height, _height_rows.size())):
		var hrow: String = _height_rows[r]
		var lrow: String = _layout[r] if r < _layout.size() else ""
		for c in range(min(width, hrow.length())):
			var cell := Vector2i(c, r)
			var lsym := lrow[c] if c < lrow.length() else "V"
			# Only real island ground carries height (not void/water/gate).
			if lsym == "V" or lsym == "W" or lsym == "w" or lsym == "m":
				continue
			var ch := hrow[c]
			if ch == "/":
				ramp_cells[cell] = true
				continue
			var lv := 0
			if ch == "1":
				lv = 1
			elif ch == "2":
				lv = 2
			if lv > 0:
				elevation[cell] = lv
				hill_cells[cell] = lv

## True if `cell` is raised and its screen-SOUTH (+row) or screen-EAST (+col) neighbour
## is at a LOWER level and is not itself reached by a ramp — i.e. a downhill face the
## player sees. Returns the drop direction(s) for face placement.
func _downhill_faces(cell: Vector2i) -> Array:  # of ["s"|"e", drop_levels]
	var out: Array = []
	if is_ramp(cell):
		return out
	var lv := height_at(cell)
	if lv <= 0:
		return out
	var south := height_at(cell + Vector2i(0, 1))
	var east := height_at(cell + Vector2i(1, 0))
	if south < lv and not is_ramp(cell + Vector2i(0, 1)):
		out.append(["s", lv - south])
	if east < lv and not is_ramp(cell + Vector2i(1, 0)):
		out.append(["e", lv - east])
	return out

## Build the raised surface layers, cliff faces on transitions, ramp slopes, and the
## ledge collision. No-op on a flat map.
func _build_elevation() -> void:
	_cliff_face_overlay = Node2D.new()
	_cliff_face_overlay.name = "Elevation"
	_cliff_face_overlay.z_index = HILL_Z
	add_child(_cliff_face_overlay)
	if hill_cells.is_empty() and ramp_cells.is_empty():
		return

	# One real TileMapLayer per level (1,2), each offset up by HILL_LIFT*level. Same
	# tileset so the raised ground is the identical grass art, just lifted.
	var max_level := 0
	for cell in hill_cells:
		max_level = maxi(max_level, int(hill_cells[cell]))
	_elev_layers.resize(max_level + 1)
	for lvl in range(1, max_level + 1):
		var layer := TileMapLayer.new()
		layer.name = "Elev%d" % lvl
		layer.tile_set = tile_set
		layer.position = Vector2(0, -HILL_LIFT * lvl)
		layer.z_index = HILL_Z
		layer.y_sort_enabled = false
		# Purely a visual surface — the base Ground layer + the ledge body own ALL
		# collision. Disable this layer's physics so its offset (-HILL_LIFT) grass tiles
		# can never nudge the player (grass has no physics polygon anyway, but be explicit
		# so a future tileset physics layer can't leak an offset collider onto the plateau).
		layer.collision_enabled = false
		layer.navigation_enabled = false
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Tonally lift each raised tier a touch (sun on the higher ground) so the plateau
		# reads as ABOVE the lower meadow even where the grass art is the same — the cliff
		# wall carries the geometry, this carries the value separation.
		layer.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.14, 1.13, 1.06), float(lvl) / 2.0)
		add_child(layer)
		_elev_layers[lvl] = layer

	# Lay the raised grass surface on each hill cell's level layer, mirroring the base
	# variant so the plateau top matches the ground it rose from.
	for cell in hill_cells:
		var lvl: int = int(hill_cells[cell])
		var layer := _elev_layers[lvl]
		if layer != null:
			var src := get_cell_source_id(cell)
			if src < 2 or src > 5:
				src = _variant_source(cell.x, cell.y)
			layer.set_cell(cell, src, ATLAS)
			hill_sprite_count += 1

	# AO seating shadows on the LOWER ground at the foot of every exposed cliff (drawn
	# first, under the aprons, so the hill reads as resting ON the ground).
	_build_ao_seats()
	# Programmatic full-perimeter rock cliff aprons on every downhill transition
	# (auto straight/outer-corner; +2 stacks seamlessly; grass-lip fringe on top).
	_build_cliff_faces()
	# Ramp slopes drawn at mid height on the authored ramp cells (visible climb).
	_build_ramp_slopes()
	# Physics: seal the non-ramp ledges so the player can't walk off/into a height wall.
	_build_ledge_collision()

## Draw a programmatic full-perimeter rock cliff apron on every downhill (screen S / E)
## height transition. Rewritten (v0.5 phase A2) from the old region-clip of the 128×230
## CC0 monolith — that produced thin, gappy slivers that did not connect the plateau to
## the ground. `CliffGen.make_apron` draws the exposed front diamond edge(s) extruded down
## exactly `drop*HILL_LIFT` px, so the wall starts at the raised diamond bottom edge and
## reaches the lower ground with ZERO gap; a cell exposed on both S and E gets an outer
## corner; +2 drops make a taller wall; the top carries a grass-lip fringe.
##
## The apron Image is anchored at the raised cell's diamond centre (blit top-left =
## center + (-64, -32)); a per-level offset ×HILL_LIFT lifts it with its surface.
func _build_cliff_faces() -> void:
	for cell in hill_cells:
		if is_ramp(cell):
			continue
		var lvl := height_at(cell)
		if lvl <= 0:
			continue
		var east := height_at(cell + Vector2i(1, 0))     # +col => screen SE
		var south := height_at(cell + Vector2i(0, 1))     # +row => screen SW
		var se_drop := (lvl - east) if (east < lvl and not is_ramp(cell + Vector2i(1, 0))) else 0
		var sw_drop := (lvl - south) if (south < lvl and not is_ramp(cell + Vector2i(0, 1))) else 0
		var drop := maxi(se_drop, sw_drop)
		if drop <= 0:
			continue
		var salt := CliffGen.hash2(cell.x, cell.y, 611)
		var img := CliffGen.make_apron(drop, se_drop > 0, sw_drop > 0, salt)
		var tex := ImageTexture.create_from_image(img)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		# Top-left of the apron box = the raised diamond's top-left, lifted by the level.
		var center: Vector2 = map_to_local(cell) + Vector2(0, -HILL_LIFT * float(lvl))
		s.position = center + Vector2(-TILE_HALF_W, -TILE_HALF_H)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_index = CLIFF_FACE_Z
		_cliff_face_overlay.add_child(s)
		cliff_face_count += 1


## AO seating shadow: a soft dark diamond on the LOWER ground at the foot of every exposed
## cliff face, so the hill visibly sits ON the ground rather than floating. Drawn under the
## aprons (lower z). One per exposed lower neighbour.
var ao_seat_count: int = 0
func _build_ao_seats() -> void:
	var ao_tex := ImageTexture.create_from_image(CliffGen.make_ao_diamond(0.6))
	for cell in hill_cells:
		if is_ramp(cell):
			continue
		var lvl := height_at(cell)
		if lvl <= 0:
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = cell + d
			if height_at(nb) < lvl and not is_ramp(nb):
				var s := Sprite2D.new()
				s.texture = ao_tex
				s.centered = false
				var c: Vector2 = map_to_local(nb) + Vector2(0, height_offset(nb))
				s.position = c + Vector2(-TILE_HALF_W, -TILE_HALF_H)
				s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				# Just above the ground tiles, below the aprons/surfaces.
				s.z_index = CLIFF_FACE_Z - 1
				_cliff_face_overlay.add_child(s)
				ao_seat_count += 1

## Draw a worn-dirt slope on ramp cells at the mid height between their neighbours, so
## the up/down crossing reads as a walkable stair rather than a wall.
func _build_ramp_slopes() -> void:
	for cell in ramp_cells:
		var dir := _ramp_climb_dir(cell)
		var img := CliffGen.make_ramp(dir, CliffGen.hash2(cell.x, cell.y, 41))
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(img)
		s.centered = false
		# Anchor like the apron: ramp top diamond at the ramp's MID height.
		var c: Vector2 = map_to_local(cell) + Vector2(0, height_offset(cell))
		s.position = c + Vector2(-TILE_HALF_W, -TILE_HALF_H)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_index = CLIFF_FACE_Z
		_cliff_face_overlay.add_child(s)
		ramp_slope_count += 1


## Screen climb-direction of a ramp — toward its highest 4-neighbour ("se"/"nw"/"sw"/"ne").
func _ramp_climb_dir(cell: Vector2i) -> String:
	var best := "ne"
	var best_lv := -1
	for pair in [[Vector2i(1, 0), "se"], [Vector2i(-1, 0), "nw"], [Vector2i(0, 1), "sw"], [Vector2i(0, -1), "ne"]]:
		var lv := height_at(cell + (pair[0] as Vector2i))
		if lv > best_lv:
			best_lv = lv
			best = String(pair[1])
	return best

## Seal every non-ramp height ledge with a thin collision wall along the shared diamond
## edge, so keyboard / tap movement can't cross a cliff (only ramps let the player pass).
## The AStar graph is separately height-aware (TouchController.can_traverse), so tap
## paths never even try a wall; this body is the physics belt for keyboard walking.
func _build_ledge_collision() -> void:
	_ledge_body = StaticBody2D.new()
	_ledge_body.name = "LedgeCollision"
	_ledge_body.collision_layer = 1
	_ledge_body.collision_mask = 0
	add_child(_ledge_body)
	# For every adjacent pair that cannot be traversed, drop a short capsule wall on the
	# shared iso edge. Iterate island cells once; check the +col (SE) and +row (SW) edge.
	for cell in hill_cells.keys() + ramp_cells.keys():
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var nb: Vector2i = cell + d
			if can_traverse(cell, nb):
				continue
			# Only add each edge once (from the higher cell, or the ramp-free side).
			if height_at(cell) < height_at(nb):
				continue
			_add_ledge_wall(cell, d)

## Add a small rectangle collider straddling the shared diamond edge between `cell` and
## its neighbour in direction `d`, positioned at the higher cell's lifted rim.
func _add_ledge_wall(cell: Vector2i, d: Vector2i) -> void:
	# Collision lives in FLAT logical space: the CharacterBody's global_position is the
	# un-lifted cell centre (world_to_cell reads it), and the visual HILL_LIFT is a pure
	# sprite offset. So the wall sits at the un-lifted shared-edge midpoint — right where
	# the player's body reaches when it tries to step across the (logical) grid edge.
	var center := map_to_local(cell)
	var edge_mid: Vector2
	if d == Vector2i(1, 0):        # SE edge (screen down-right)
		edge_mid = center + Vector2(TILE_HALF_W * 0.5, TILE_HALF_H * 0.5)
	elif d == Vector2i(0, 1):      # SW edge (screen down-left)
		edge_mid = center + Vector2(-TILE_HALF_W * 0.5, TILE_HALF_H * 0.5)
	elif d == Vector2i(-1, 0):     # NW edge (screen up-left)
		edge_mid = center + Vector2(-TILE_HALF_W * 0.5, -TILE_HALF_H * 0.5)
	else:                          # d == (0,-1) NE edge (screen up-right)
		edge_mid = center + Vector2(TILE_HALF_W * 0.5, -TILE_HALF_H * 0.5)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Thin wall lying ALONG the diamond edge: long enough to seal it (no gap a radius-20
	# body slips through) but shallow (10px) so it hugs the edge line and never intrudes
	# into either cell centre — a body legitimately standing on a cell (~36px from the
	# edge midpoint) is not pushed off. The iso edge runs at ±atan2(HALF_H, HALF_W).
	rect.size = Vector2(78, 10)
	cs.shape = rect
	cs.position = edge_mid
	var iso_angle := atan2(TILE_HALF_H, TILE_HALF_W)  # ≈ 0.4636 rad
	# SE / NW edges rise to the right (+angle); SW / NE edges rise to the left (−angle).
	cs.rotation = iso_angle if (d == Vector2i(1, 0) or d == Vector2i(-1, 0)) else -iso_angle
	_ledge_body.add_child(cs)
	ledge_collider_count += 1

## Lift objects/player that stand on a raised cell by the cell's height offset so they
## sit ON the plateau (Y-sort still uses their world Y, which now includes the lift, so
## an object on a hill correctly sorts against the raised ground and its neighbours).
func _lift_hill_objects() -> void:
	if _ysort == null or hill_cells.is_empty():
		return
	for child in _ysort.get_children():
		if not (child is Node2D):
			continue
		var cell := world_to_cell((child as Node2D).global_position)
		var off := height_offset(cell)
		if off != 0.0:
			(child as Node2D).position.y += off


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
			var caul_script := load("res://scripts/world/cauldron.gd")
			if caul_script != null:
				caul.set_script(caul_script)
				caul.set("object_id", "cauldron")
			else:
				push_warning("MapLoader: cauldron.gd failed to load")
			caul.texture = load("res://assets/objects/cauldron.png")
			caul.offset = Vector2(0, -64)
			_place(caul, world)
			# A3: warm violet light pool under the cauldron.
			_add_light_pool(caul, "res://assets/objects/light_pool_violet.png", Vector2(0, -8), 0.85)
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
				# A3: large violet light pool washing the world-tree base.
				_add_light_pool(tree, "res://assets/objects/light_pool_violet_lg.png", Vector2(0, 0), 1.0)
				# v0.5b: Q6 QuestMarker — a violet whisper-wisp bobbing at the world-tree /
				# night-path entrance while Q6 ("위로… 빛나는 곳으로 와") is the active whisper.
				_add_quest_marker(tree, "Q6", "wisp", Vector2(0, -200))
		"m":
			var mw := MysticWater.new()
			_place(mw, world)
			# A3: cyan-violet pool over the mystic water.
			_add_light_pool(mw, "res://assets/objects/light_pool_cyan.png", Vector2(0, 0), 0.7)
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
			# trees: a/b/c deterministic split. v0.5 CC0 iso trees (~230px tall,
			# trunk base at sprite bottom → offset ≈ -height/2 to plant the trunk on
			# the cell centre).
			var pick := h % 3
			if pick == 0:
				return ["res://assets/objects/tree_a.png", Vector2(0, -110)]
			elif pick == 1:
				return ["res://assets/objects/tree_b.png", Vector2(0, -116)]
			return ["res://assets/objects/tree_c.png", Vector2(0, -105)]
		"F":
			var pick := h % 3
			if pick == 0:
				return ["res://assets/objects/flower.png", Vector2(0, -24)]
			elif pick == 1:
				return ["res://assets/objects/flower_violet.png", Vector2(0, -24)]
			return ["res://assets/objects/flower_pink.png", Vector2(0, -24)]
		"R":
			return ["res://assets/objects/rock.png", Vector2(0, -22)]
		"s":
			return ["res://assets/objects/stone.png", Vector2(0, -14)]
		"t":
			return ["res://assets/objects/grass_tuft.png", Vector2(0, -12)]
		"h":
			return ["res://assets/objects/bush_green.png", Vector2(0, -18)]
	return ["res://assets/objects/rock.png", Vector2(0, -22)]


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
	# v0.3.1 R3: only trees physically block the player; small scatter (rock/stone/flower/
	# grass tuft/green bush) stays walkable-over. Detected from the art path — trees use
	# tree_a/b/c.png, everything else is small.
	g.blocks_movement = tex_path.contains("tree")
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
		_: weights = [28, 13, 8, 9, 7, 6]      # home: tufts + bushes (rocks up: G1 needs 6 boulders)
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


## A3: attach a soft additive light-pool decal to a spawned object. The pool
## script reparents itself onto the glow CanvasLayer (unaffected by CanvasModulate)
## in _ready, so at night it blooms. `scale_strength` scales the pool footprint and
## its peak alpha. Fails soft if the texture or script is missing.
func _add_light_pool(parent: Node2D, tex_path: String, off: Vector2, scale_strength: float) -> void:
	var pool_script := load("res://scripts/world/light_pool.gd")
	var tex := load(tex_path)
	if pool_script == null or tex == null:
		return
	var pool: Sprite2D = pool_script.new()
	pool.texture = tex
	pool.offset = off
	pool.scale = Vector2(scale_strength, scale_strength)
	parent.add_child(pool)


## v0.5b: attach a QuestMarker (bobbing wisp/drop + pulse ring, gated on a quest id) to a
## world object so the active quest's target is legible. quest_id e.g. "Q6"; variant
## "wisp"/"drop"; icon_off is the marker's Y offset above the object anchor.
func _add_quest_marker(parent: Node2D, quest_id: String, variant: String, icon_off: Vector2) -> void:
	var scr := load("res://scripts/world/quest_marker.gd")
	if scr == null:
		return
	var m := Node2D.new()
	m.set_script(scr)
	m.set("quest_id", quest_id)
	m.set("variant", variant)
	m.set("icon_offset", icon_off)
	m.set("ring_offset", Vector2(0, -40))
	parent.add_child(m)


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
