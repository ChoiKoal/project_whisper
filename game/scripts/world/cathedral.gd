extends Node
class_name Cathedral
## (L5-2) Session glue for the Layer-5 「응답 없는 대성당」 (cathedral.tscn). Mirrors MageTower
## exactly (the L4 session) with L5 신성 art + the divinity-world purification hook:
##   1. spawns the 봉헌 작업대 (L5 crafting station) at legend special.workbench_cell, with a GOLD
##      fusion glow (drawn art + gold glow pool);
##   2. sparse debris scatter (부서진 대리석 파편 + 잿빛 재 무리) on eligible ground, EXCLUDING
##      cliff-rim / ramp / occupied cells (same exclusion as the L2/L3/L4 stations);
##   3. scatters a few 석화된 순례자 (petrified pilgrims) as deco — investigate → "진상의 조각"
##      (L4 마법사 잔영에 대응하는 L5 서사 오브젝트: 신에게 응답하려다 굳어버린 이들);
##   4. registers the world with SaveManager so the cathedral snapshots/restores like other scenes.
## Reads the same parameterized MapLoader (l5_* data overrides on the Ground node). Defensive
## against missing autoloads (release templates strip assert()).

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
## (L5-2) The L5 return portal at the spawn — same reworked entry-zone pattern as grove/home/L2~L4.
var _return_portal: ReturnPortalController = null

## Debris scatter tuning: sparse — a crumbling cathedral, not a meadow. Deterministic by cell hash.
const DEBRIS_TARGET := 40
const DEBRIS_SEED := 0x3B2C4E

## Petrified-pilgrim deco: a handful of poses at authored-ish cells (석화된 순례자 5~7체 산재).
const STATUE_ARTS := ["l5_petrified_standing", "l5_petrified_reaching", "l5_petrified_kneeling"]
## The 진상의 조각 (신이 사라진 자리에서 응답을 바라다 굳어버린 이들의 마지막 기록).
const STATUE_LOGS := [
	"…진상의 조각: 우리는 응답을 기다렸다. 기다리다, 무릎 꿇은 채로 굳었다.",
	"…진상의 조각: 신의 잔불이 꺼져가도, 아무도 손을 뻗지 않았다. 뻗은 손은, 이렇게 돌이 됐다.",
	"…진상의 조각: 대답이 없는 게 아니었다. 물을 사람이, 남지 않았을 뿐.",
	"…진상의 조각: 마지막 순례자는 여기서 노래했다. 침묵의 회랑을, 성가 하나로.",
	"…진상의 조각: 이번엔 우리가 대답할 차례라던 그 말을, 아무도 끝내지 못했다.",
]


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = "cathedral"
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
	_scatter_statues()
	_spawn_npc()
	_spawn_return_portal()
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
	# (L5-5) Layer 5 정화 완료 → 다섯 포탈 전점등 + 빛의 문 예고 (§C-4 포탈 완결).
	if typeof(GameState) != TYPE_NIL and GameState.has_signal("layer5_purified"):
		if not GameState.layer5_purified.is_connected(_on_layer5_purified):
			GameState.layer5_purified.connect(_on_layer5_purified)
	# (L5-5) 첫 L5 진입 시 Layer-5 속삭임 라인(L5-Q1~) 활성 — L1~L4 라인과 퀘스트 로그에 공존.
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("activate_l5_line"):
		QuestManager.activate_l5_line()


## (L5-5) Called when the 대제단 봉헌(응답) 정화 컷신 completes. Advances the portal line so the
## divinity 포탈이 열리고 — 다섯 포탈이 전부 점등된다(빛의 문 예고). Save so the purified flag +
## vita + powered nodes persist.
func _on_layer5_purified(_layer: String) -> void:
	if typeof(GameState) != TYPE_NIL and GameState.has_method("set_portal_state"):
		# divinity 포탈 = OPEN (정화한 세계는 열린 채 — 5레이어 완결, 다섯 포탈 전부 open).
		GameState.set_portal_state("divinity", GameState.PORTAL_OPEN)
		# (L5-5) §C-4: 다섯 정화(L1~L5) 전부 완료면 다섯 포탈 전점등 + 빛의 문 예고를 발동한다.
		# maybe_light_five_portals 는 5-AND + 멱등 가드를 스스로 검사하므로 여기서 조건 판단 불필요.
		if GameState.has_method("maybe_light_five_portals"):
			GameState.maybe_light_five_portals()
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()


func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	# Spawn S is (19,37) on ivory pavement; drop the gate a couple cells beside it.
	var candidates := [
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, -2),
		_loader.spawn_cell + Vector2i(-3, 0),
	]
	_return_portal.setup(_loader, _player, candidates, "E 홈으로 돌아가기")
	_return_portal.entered.connect(_on_return_portal)


## Travel back to the home island from Layer 5 (mirrors MageTower._on_return_portal — no
## ignition; the L5 purification cutscene already advanced the portal line + saved).
func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_HOME))


## Spawn the 봉헌 작업대 (L5 crafting station). Reuses the L5 workbench art + a gold glow pool. Sits
## on its legend cell (near spawn) so the "first craft ≤N분" pacing holds.
func _spawn_workbench() -> void:
	var cell := _loader.l2_workbench_special_cell()
	if cell == Vector2i(-1, -1):
		return
	# (v1.0.4 P0 hotfix) Real Cauldron wearing the L5 봉헌 작업대 skin — see terminal_station.gd for
	# why: a plain Sprite2D never emitted `interacted`, so Fusion was unreachable in real play.
	# (v1.1.0 GP-1) UNIFIED 솥단지 — shared cauldron art + live brew. Layer identity = 호박/앰버 flame.
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
	# L5 flame = 호박/앰버 (신성). Pool offset matches the shared cauldron footprint.
	_add_pool(s, "res://assets/objects/light_pool_amber.png", Vector2(0, -8), 0.85)


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


## Sparse debris scatter — 부서진 대리석 파편 (l5_debris_marble) + 잿빛 재 무리 (l5_debris_ash) —
## on eligible walkable ground, deterministic per cell. EXCLUDES void, cliff-rim, ramp, occupied.
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
			var ash := (_loader._cell_hash(c, r, DEBRIS_SEED + 1) % 2) == 0
			var s := Sprite2D.new()
			s.texture = load("res://assets/objects/l5_debris_ash.png" if ash else "res://assets/objects/l5_debris_marble.png")
			s.offset = Vector2(0, -8)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.y_sort_enabled = true
			ys.add_child(s)
			s.global_position = _loader.cell_center_world(cell)
			_loader.apply_height_lift(s)
			placed += 1


## Scatter a few 석화된 순례자 across the districts. Plain deco sprites carrying an object_id +
## a "truth-fragment" line as meta (mirror of L4's mage afterimages).
func _scatter_statues() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	# Authored-ish deco cells in the walkable plazas (deterministic, off the gate spine).
	var cells := [
		Vector2i(11, 35), Vector2i(28, 33), Vector2i(13, 24),
		Vector2i(27, 25), Vector2i(14, 16), Vector2i(25, 16),
	]
	var i := 0
	for cell in cells:
		if not _loader.is_cell_walkable(cell):
			i += 1
			continue
		var art: String = STATUE_ARTS[i % STATUE_ARTS.size()]
		var log_line: String = STATUE_LOGS[i % STATUE_LOGS.size()]
		# (EG-2) 진상 조각 조사 오브젝트: investigating any 석화된 순례자 collects the L5 shard.
		var s := TruthShard.new()
		s.setup("petrified_pilgrim", "석화된 순례자", log_line, load("res://assets/objects/%s.png" % art))
		s.offset = Vector2(0, -60)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		_loader.apply_height_lift(s)
		i += 1


## (v1.1.0 GP-4 §1) Spawn the 기도하다 굳은 석상 QuestNPC near spawn (reachable). E-상호작용이 `saint`
## 서브체인을 활성.
func _spawn_npc() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	QuestNPC.spawn(self, _loader, _loader.spawn_cell + Vector2i(3, 0), "saint", "석상",
		"…응답은, 오지 않았습니다. 그래도, 당신이 왔으니.", "res://assets/objects/l5_pilgrim_dynamo.png")


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
