extends Node
class_name ClockworkCity
## (L3-2) Session glue for the Layer-3 「태엽이 멈춘 도시」 (clockwork_city.tscn). Mirrors
## TerminalStation exactly (the L2 session) with L3 art + the machine-world purification hook:
##   1. spawns the 정비대 (L3 tech workbench = crafting station) at legend special.workbench_cell,
##      with an ORANGE fusion glow (drawn art + orange glow pool);
##   2. sparse debris scatter (loose cogs + warm soot wisps) on eligible ground, EXCLUDING
##      cliff-rim / ramp / occupied cells (same v0.5c exclusion as the L2 station);
##   3. scatters a few 멈춘 로봇 (stopped robots) as street deco — investigate → "마지막 로그";
##   4. registers the world with SaveManager so the city snapshots/restores like the other scenes.
## Reads the same parameterized MapLoader (l3_* data overrides on the Ground node). Defensive
## against missing autoloads (release templates strip assert()).

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
## (L3-2) The L3 return portal at the spawn — same reworked entry-zone pattern as grove/home/L2.
var _return_portal: ReturnPortalController = null

## Debris scatter tuning: sparse — a dead clockwork city, not a meadow. Deterministic by cell hash.
const DEBRIS_TARGET := 40
const DEBRIS_SEED := 0x3A2C1E

## Stopped-robot street deco: a handful of poses at authored-ish cells (§C-2 5~7체 산재).
const ROBOT_ARTS := ["l3_robot_sweeper", "l3_robot_courier", "l3_robot_standing"]
## The 마지막 로그 lines (진상 조각 — 선배 컨스트럭터가 세계를 완성하고 떠나 속삭임이 끊긴 것).
const ROBOT_LOGS := [
	"…마지막 로그: 청소를 끝내면, 다음 명령을 기다리라 하셨다. 명령은, 오지 않았다.",
	"…마지막 로그: 그분은 도시를 '완성'이라 부르고 떠나셨다. 완성된 것은, 멈추는 것이었나.",
	"…마지막 로그: 속삭임이 끊긴 날을 기록한다. 태엽이 다 풀리기, 꼭 한 시간 전.",
	"…마지막 로그: 전령 임무 12,004번째. 받는 이가 더는 없다. 그래도, 한 발을 내디뎠다.",
	"…마지막 로그: 우리는 효율적이었다. 영원할 만큼은, 아니었다.",
]


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = "clockwork_city"
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
	_scatter_robots()
	_spawn_npc()
	_spawn_return_portal()
	# (EXL3-2) 대시계 재가동(L3 정화) 후 낡은 광차 승강로 하강 = 태엽 광산 개방.
	_spawn_mine_descent()
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("register_world"):
		SaveManager.register_world(_loader, _player, respawn)
		# (v1.3.1 BUG B) 이어하기 load or in-run RE-ENTRY (portal travel): restore this world's
		# snapshot instead of rebuilding fresh.
		if SaveManager.pending_load:
			SaveManager.pending_load = false
			SaveManager.load_game()
		elif SaveManager.has_world_snapshot(WorldContext.current_scene):
			SaveManager.restore_registered_world()
		# (v1.3.1 BUG A) Self-heal the portal line from the progression flags on every boot.
		GameState.reconcile_portal_line()
	if typeof(AudioManager) != TYPE_NIL:
		if AudioManager.has_method("start_world_audio"):
			AudioManager.start_world_audio()
		if AudioManager.has_method("set_home_ambience"):
			AudioManager.set_home_ambience(true)
	# (L3-5) Layer 3 정화 완료 → 다음 포탈(magic) flickering + 홈 귀환 유도 (§C-4 포탈 전파).
	if typeof(GameState) != TYPE_NIL and GameState.has_signal("layer3_purified"):
		if not GameState.layer3_purified.is_connected(_on_layer3_purified):
			GameState.layer3_purified.connect(_on_layer3_purified)
	# (L3-5) 첫 L3 진입 시 Layer-3 속삭임 라인(L3-Q1~Q7) 활성 — L1/L2 라인과 퀘스트 로그에 공존.
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("activate_l3_line"):
		QuestManager.activate_l3_line()


## (L3-5) Called when the 대시계 재가동 정화 컷신 completes. Advances the portal line (machine
## → magic flickering) so the next dead world opens on return home. Save so the purified flag +
## powered nodes persist.
func _on_layer3_purified(_layer: String) -> void:
	if typeof(GameState) != TYPE_NIL and GameState.has_method("set_portal_state"):
		# machine 포탈 = OPEN (정화한 세계는 열린 채로 — nature→open, science→open 패턴 계승).
		GameState.set_portal_state("machine", GameState.PORTAL_OPEN)
		# 다음 죽은 세계(magic = Layer 4) flickering 전파 — 홈 귀환 시 뛰기 시작.
		GameState.set_portal_state("magic", GameState.PORTAL_FLICKERING)
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	# (EXL3-2) 정화 직후 승강로 하강 개방(재진입 없이 즉시 나타남 — terminal→sanctum 패턴 계승).
	_spawn_mine_descent()


## (EXL3-2) Spawn the 낡은 광차 승강로 하강 연결점 to the 태엽 광산 (l3m) — ONLY after L3 정화
## (대시계 재가동 = 승강로에 잔류 태엽 동력이 도는 신호). A real Portal near spawn with a custom
## travel handler into SCENE_MINE. Idempotent (guarded). Clones terminal_station._spawn_sanctum_descent.
var _mine_descent_spawned := false

func _spawn_mine_descent() -> void:
	if _mine_descent_spawned:
		return
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	if not (typeof(GameState) != TYPE_NIL and GameState.layer3_purified_flag):
		return  # locked until 시계탑 도시 is 정화된 (대시계 재가동)
	_mine_descent_spawned = true
	# 광차 승강로: a walkable cell NORTH of spawn (대시계 광장단 아래로 하강 = 최심부 방향).
	var candidates := [
		_loader.spawn_cell + Vector2i(0, -4),
		_loader.spawn_cell + Vector2i(-3, -2),
		_loader.spawn_cell + Vector2i(3, -2),
		_loader.spawn_cell + Vector2i(-4, 0),
	]
	var cell := Vector2i(-1, -1)
	for c in candidates:
		if _loader.is_cell_walkable(c):
			cell = c
			break
	if cell == Vector2i(-1, -1):
		return
	var ctrl := ReturnPortalController.new()
	add_child(ctrl)
	ctrl.setup(_loader, _player, [cell], "E 태엽 광산으로")
	ctrl.entered.connect(_on_mine_descent)


func _on_mine_descent() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_MINE
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_MINE))


func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	# Spawn S is (19,37) on brass pavement; drop the gate a couple cells beside it.
	var candidates := [
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, -2),
		_loader.spawn_cell + Vector2i(-3, 0),
	]
	_return_portal.setup(_loader, _player, candidates, "E 홈으로 돌아가기")
	_return_portal.entered.connect(_on_return_portal)


## Travel back to the home island from Layer 3 (mirrors TerminalStation._on_return_portal —
## no ignition; the L3 purification cutscene already advanced the portal line + saved).
func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_HOME))


## Spawn the 정비대 (L3 tech workbench). Reuses the L3 workbench art + an orange glow pool. Sits
## on its legend cell (west of spawn) so the "first craft ≤4분" pacing (§A-7) holds.
func _spawn_workbench() -> void:
	var cell := _loader.l2_workbench_special_cell()
	if cell == Vector2i(-1, -1):
		return
	# (v1.0.4 P0 hotfix) Real Cauldron wearing the L3 workbench skin — see terminal_station.gd for
	# why: a plain Sprite2D never emitted `interacted`, so Fusion was unreachable in real play.
	# (v1.1.0 GP-1) UNIFIED 솥단지 — shared cauldron art + live brew. Layer identity = 주황 flame.
	var s := Cauldron.new()
	s.configure_shared(Vector2(0, -64))
	s.y_sort_enabled = true
	var world := _loader.cell_center_world(cell)
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys != null:
		ys.add_child(s)
	else:
		_loader.add_child(s)
	s.global_position = world
	_loader.l2_workbench_cell = cell
	_bind_fusion_ui(s)
	# L3 flame = 주황 (마지막 온기). Pool offset matches the shared cauldron footprint.
	_add_pool(s, "res://assets/objects/light_pool_orange.png", Vector2(0, -8), 0.85)


## (v1.0.4) Bind the crafting station to the scene FusionUI (order-independent; see terminal_station).
func _bind_fusion_ui(caul: Cauldron) -> void:
	# Resolve the scene root via `owner` (works whether this scene is current_scene in real play
	# OR parented under a test harness like e2e), falling back to current_scene.
	var root: Node = owner if owner != null else get_tree().current_scene
	if root == null:
		return
	var fusion := root.get_node_or_null("FusionUI")
	if fusion != null and fusion.has_method("bind_cauldron"):
		fusion.bind_cauldron(caul)


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


## Sparse debris scatter — loose cogs (l3_debris_cog) + warm soot wisps (l3_debris_soot) — on
## eligible walkable ground, deterministic per cell. EXCLUDES void, cliff-rim, ramp, occupied.
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
			if (_loader._cell_hash(c, r, DEBRIS_SEED) % 12) != 0:
				continue
			var soot := (_loader._cell_hash(c, r, DEBRIS_SEED + 1) % 2) == 0
			var s := Sprite2D.new()
			s.texture = load("res://assets/objects/l3_debris_soot.png" if soot else "res://assets/objects/l3_debris_cog.png")
			s.offset = Vector2(0, -8)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.y_sort_enabled = true
			ys.add_child(s)
			s.global_position = _loader.cell_center_world(cell)
			_loader.apply_height_lift(s)
			placed += 1


## Scatter a few 멈춘 로봇 across the districts. They are plain deco sprites carrying an
## object_id + a "last log" line as meta; the interaction framework shows the log on투 investigate.
func _scatter_robots() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	# Authored-ish deco cells in the walkable plazas (deterministic, off the gate spine).
	var cells := [
		Vector2i(11, 34), Vector2i(28, 33), Vector2i(13, 24),
		Vector2i(27, 25), Vector2i(14, 16), Vector2i(25, 14),
	]
	var i := 0
	for cell in cells:
		if not _loader.is_cell_walkable(cell):
			i += 1
			continue
		var art: String = ROBOT_ARTS[i % ROBOT_ARTS.size()]
		var log_line: String = ROBOT_LOGS[i % ROBOT_LOGS.size()]
		# (EG-2) 진상 조각 조사 오브젝트: investigating ANY 멈춘 로봇 collects the L3 shard
		# ("stopped_robot"); each pose shows its own 마지막 로그 line. Idempotent per shard.
		var s := TruthShard.new()
		s.setup("stopped_robot", "멈춘 로봇", log_line, load("res://assets/objects/%s.png" % art))
		s.offset = Vector2(0, -60)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		_loader.apply_height_lift(s)
		i += 1


## (v1.1.0 GP-4 §1) Spawn the 파수 로봇 QuestNPC near spawn (reachable). E-상호작용이 `guard`
## 서브체인을 활성.
func _spawn_npc() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	QuestNPC.spawn(self, _loader, _loader.spawn_cell + Vector2i(3, 0), "guard", "파수 로봇",
		"경비… 교대. 없음. …계속, 선다.", "res://assets/objects/l3_robot_standing.png")


func _debris_eligible(cell: Vector2i) -> bool:
	if not _loader.is_cell_walkable(cell):
		return false
	if _loader.is_ramp(cell) or _loader._is_rim_cell(cell):
		return false
	if _loader._occupied.has(cell) or _loader.l2_blackout_cells.has(cell):
		return false
	if _loader.spawn_cell != Vector2i(-1, -1):
		if absi(cell.x - _loader.spawn_cell.x) <= 1 and absi(cell.y - _loader.spawn_cell.y) <= 1:
			return false
	return true
