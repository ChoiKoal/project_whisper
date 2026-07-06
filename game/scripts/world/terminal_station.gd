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
## (v0.6.0) The L2 return portal at the terminal-station spawn — same reworked entry-zone pattern
## as the grove/home gates (real Portal, apron prompt, E + click-walk-then-enter).
var _return_portal: ReturnPortalController = null

## Debris scatter tuning: sparse — this is a dead base, not a meadow. Deterministic by cell hash.
const DEBRIS_TARGET := 42
const DEBRIS_SEED := 0x5C1E0CE  # deterministic salt for the debris hash gate

## (EG-2) L2 진상 조각 — 마지막 로그 스크린. New object (설계 §3: L2 needed NEW log text). A few
## dead terminal screens (l2_screen_off) at authored cells; investigating any collects the
## "l2_last_log" shard. New 조각 대사 (선배가 관제탑을 '완성'이라 부르고 떠나 속삭임이 끊긴 것).
const LOG_SCREEN_LOGS := [
	"…마지막 로그 스크린: 관제탑 정상 가동. '완성' 선언 접수. 담당 컨스트럭터 이임. 이후 수신 없음.",
	"…마지막 로그 스크린: 자동 응답만 반복됨. 이 세계에 말을 거는 이가, 더는 없다.",
	"…마지막 로그 스크린: 마지막 근무자 기록 — '불은 켰다. 그런데 아무도 대답을 안 해.'",
]
const LOG_SCREEN_CELLS := [Vector2i(12, 22), Vector2i(27, 20), Vector2i(19, 30)]


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
	_scatter_log_screens()
	_spawn_return_portal()
	# Register the live world so the station snapshots/restores like the other scenes.
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("register_world"):
		SaveManager.register_world(_loader, _player, respawn)
	# Ambient audio (reuse the quieter home soundscape — a dead station is quiet too).
	if typeof(AudioManager) != TYPE_NIL:
		if AudioManager.has_method("start_world_audio"):
			AudioManager.start_world_audio()
		if AudioManager.has_method("set_home_ambience"):
			AudioManager.set_home_ambience(true)
	# (L2-3) Layer 2 정화 완료 → 다음 포탈(machine) flickering + 홈 귀환 유도 (§C-4 포탈 전파).
	if typeof(GameState) != TYPE_NIL and GameState.has_signal("layer2_purified"):
		if not GameState.layer2_purified.is_connected(_on_layer2_purified):
			GameState.layer2_purified.connect(_on_layer2_purified)
	# (L2-5) 첫 L2 진입 시 Layer-2 속삭임 라인(L2-Q1~Q7) 활성 — L1 라인과 퀘스트 로그에 공존.
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("activate_l2_line"):
		QuestManager.activate_l2_line()


## (L2-3) Called when the 관제탑 재가동 정화 컷신 completes. Advances the portal line (science
## → machine flickering, mirroring the Layer-1 nature→science hand-off) so the next dead world
## opens on return home. Save the run so the purified flag + powered nodes persist.
func _on_layer2_purified(_layer: String) -> void:
	if typeof(GameState) != TYPE_NIL and GameState.has_method("set_portal_state"):
		# (L2-5) science 포탈 = OPEN (자유 왕래) — 정화한 세계는 열린 채로 남는다(nature→open 패턴 계승).
		GameState.set_portal_state("science", GameState.PORTAL_OPEN)
		# 다음 죽은 세계(machine = Layer 3) flickering 전파 — 홈 귀환 시 뛰기 시작.
		GameState.set_portal_state("machine", GameState.PORTAL_FLICKERING)
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()


## (v0.6.0) Spawn the L2 return portal at/near the terminal-station spawn, using the shared
## ReturnPortalController (same entry-zone prompt + E + click-walk-then-enter as the home gates).
## Prominent placement near spawn so it's visible on arrival — the way back to the home island.
func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	# Spawn S is (18,32) on cracked concrete; drop the gate a couple cells SOUTH/beside it.
	var candidates := [
		_loader.spawn_cell + Vector2i(0, 2),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(0, -2),
	]
	_return_portal.setup(_loader, _player, candidates, "E 홈으로 돌아가기")
	_return_portal.entered.connect(_on_return_portal)


## Travel back to the home island from Layer 2 (mirrors GroveSession._return_home, no ignition —
## the L2 purification cutscene already handled the portal-line advance + save).
func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()   # snapshot the station so re-entry restores it
	WorldContext.current_scene = WorldContext.SCENE_HOME
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_HOME))


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


## (EG-2) Scatter the 마지막 로그 스크린 (dead terminals) — the L2 진상 조각 investigation objects.
## Investigating any one collects the "l2_last_log" shard + shows its log. Falls back to the nearest
## walkable cell if an authored cell is blocked so the shard is always reachable.
func _scatter_log_screens() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/l2_screen_off.png") as Texture2D
	var i := 0
	for cell in LOG_SCREEN_CELLS:
		var use_cell: Vector2i = cell
		if not _loader.is_cell_walkable(use_cell):
			# Nudge to a nearby walkable cell (keep it reachable).
			var found := false
			for off in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]:
				if _loader.is_cell_walkable(cell + off):
					use_cell = cell + off
					found = true
					break
			if not found:
				i += 1
				continue
		var log_line: String = LOG_SCREEN_LOGS[i % LOG_SCREEN_LOGS.size()]
		var s := TruthShard.new()
		s.setup("l2_last_log", "마지막 로그 스크린", log_line, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(use_cell)
		_loader.apply_height_lift(s)
		i += 1


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
