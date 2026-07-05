extends Node
class_name TerminalStation
## (L2-2) Session glue for the Layer-2 「꺼진 관문 기지」 (terminal_station.tscn). Analogous to
## HomeSession/GroveSession but SLIM: Layer 2 gate LOGIC + portal travel wiring is stage L2-3.
## This session only:
##   1. spawns the 정비대 (tech workbench = the L2 crafting station, cauldron equivalent) at the
##      legend `special.workbench_cell`, with a violet-cyan fusion glow (drawn art + glow pool);
##   2. does the SPARSE DEBRIS SCATTER (small scrap bits + ash wisps) on eligible ground,
##      EXCLUDING cliff-rim / ramp / occupied cells (respects the v0.5c scatter exclusion) —
##      there is deliberately NO organic scatter (the loader's enable_scatter is false);
##   3. registers the world with SaveManager so the station is a self-consistent saveable scene.
## It reads the same parameterized MapLoader the grove/home use (l2_* data overrides on the
## Ground node). Defensive against missing autoloads (release templates strip assert()).

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Debris scatter tuning: sparse — this is a dead base, not a meadow. Deterministic by cell hash.
const DEBRIS_TARGET := 42
const DEBRIS_SEED := 0x5C1E0CE  # deterministic salt for the debris hash gate


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = "terminal_station"
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	var respawn := get_node_or_null(respawn_path) as ObjectRespawn
	if _loader == null:
		return
	_spawn_workbench()
	_scatter_debris()
	# Register the live world so the station snapshots/restores like the other scenes.
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("register_world"):
		SaveManager.register_world(_loader, _player, respawn)
	# Ambient audio (reuse the quieter home soundscape — a dead station is quiet too).
	if typeof(AudioManager) != TYPE_NIL:
		if AudioManager.has_method("start_world_audio"):
			AudioManager.start_world_audio()
		if AudioManager.has_method("set_home_ambience"):
			AudioManager.set_home_ambience(true)


## Spawn the 정비대 (tech workbench). Reuses the L2 workbench art + a violet-cyan glow pool. Sits
## on its legend cell (west of spawn) so the "first craft ≤4분" pacing (§A-7) holds — the player
## lands and the bench is 2-3 cells away.
func _spawn_workbench() -> void:
	var cell := _loader.l2_workbench_special_cell()
	if cell == Vector2i(-1, -1):
		return
	var s := Sprite2D.new()
	s.texture = load("res://assets/objects/l2_workbench.png")
	s.offset = Vector2(0, -44)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.set_meta("object_id", "workbench")
	s.y_sort_enabled = true
	var world := _loader.cell_center_world(cell)
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys != null:
		ys.add_child(s)
	else:
		_loader.add_child(s)
	s.global_position = world
	_loader.l2_workbench_cell = cell
	# violet-cyan fusion glow at the aperture (reparents onto the glow layer at night).
	_add_pool(s, "res://assets/objects/light_pool_cyan.png", Vector2(0, -46), 0.7)


func _add_pool(parent: Node2D, tex_path: String, off: Vector2, strength: float) -> void:
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load(tex_path)
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.offset = off
	pool.scale = Vector2(strength, strength)
	parent.add_child(pool)


## Sparse debris scatter — small scrap bits (l2_debris_scrap) + ash wisps (l2_debris_ash) — on
## eligible walkable ground, deterministic per cell. EXCLUDES: void/water, cliff-rim cells,
## ramp cells, and any occupied cell (authored object / gate / spawn 3×3). This mirrors the
## v0.5c scatter exclusion so nothing lands on the exposed cliff face or blocks the path.
func _scatter_debris() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var placed := 0
	for r in range(_loader.height):
		for c in range(_loader.width):
			if placed >= DEBRIS_TARGET:
				break
			var cell := Vector2i(c, r)
			if not _debris_eligible(cell):
				continue
			# ~1 in 12 eligible cells gets a debris bit (deterministic hash gate → sparse).
			if (_loader._cell_hash(c, r, DEBRIS_SEED) % 12) != 0:
				continue
			var ash := (_loader._cell_hash(c, r, DEBRIS_SEED + 1) % 2) == 0
			var s := Sprite2D.new()
			s.texture = load("res://assets/objects/l2_debris_ash.png" if ash else "res://assets/objects/l2_debris_scrap.png")
			s.offset = Vector2(0, -8)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.y_sort_enabled = true
			ys.add_child(s)
			s.global_position = _loader.cell_center_world(cell)
			_loader.apply_height_lift(s)
			placed += 1


## A cell is debris-eligible if it is walkable ground, not a ramp, not a cliff rim, and not
## already occupied by an authored object / gate / the spawn area.
func _debris_eligible(cell: Vector2i) -> bool:
	if not _loader.is_cell_walkable(cell):
		return false
	if _loader.is_ramp(cell) or _loader._is_rim_cell(cell):
		return false
	if _loader._occupied.has(cell) or _loader.l2_blackout_cells.has(cell):
		return false
	# keep the spawn 3×3 clear
	if _loader.spawn_cell != Vector2i(-1, -1):
		if absi(cell.x - _loader.spawn_cell.x) <= 1 and absi(cell.y - _loader.spawn_cell.y) <= 1:
			return false
	return true
