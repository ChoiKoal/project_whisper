extends Node
class_name MineSession
## (EXL3-5) Session glue for the L3 확장 SUB-zone 「태엽 광산」 (clockwork_mine.tscn / l3m). Mirrors
## SanctumSession + ClockworkCity: registers the world, spawns the 정비대(실 Cauldron, L3 스킨),
## the 갱도에 갇힌 줄 모르는 굴착 로봇 잔재 NPC (N-digger) + the 광부 로그 석판 진상 조각 (L3 심부 =
## 엔딩 5조각의 에너지/기계 조각 `stopped_robot` 심화), and a RETURN portal back to the CLOCKWORK CITY
## (the mine is reached via the 낡은 광차 승강로 하강 under the 대시계 광장). Gate LOGIC + cutscene C-4 +
## the 잔류 태엽 발전기 idempotent add_energy live in the L3mGateController node.
##
## Defensive against missing autoloads. Zero regression to the base L3 clockwork_city.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _return_portal: ReturnPortalController = null

## (EXL3-5) 광부 로그 석판 진상 조각 — L3 심부(에너지/기계) 조각. Reuses the canonical 5-set id
## "stopped_robot" (deepening the L3/기계 진상, NOT a new sixth id) exactly as SanctumSession reuses
## "l2_last_log". Placed at the 광부 로그 석판 landmark `3` (27,22).
const SHARD_ID := "stopped_robot"
const SHARD_CELLS := [Vector2i(27, 22), Vector2i(26, 22), Vector2i(28, 22)]
const SHARD_LOG := "…광부 로그 석판. 마지막 교대 광부가 남긴 기록 — 우리는 더 깊이, 더 빨리 캤다. 영원히 감길 태엽을 찾아서. 그런 건 없었다. 마지막 갱에서, 첫 태엽이 다 풀리는 걸 보고서야 알았다. 우리가 어디서 틀렸는지, 여기 적혀 있다."


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = WorldContext.SCENE_MINE
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	var respawn := get_node_or_null(respawn_path) as ObjectRespawn
	if _loader == null:
		return
	if _player != null and respawn != null and typeof(SaveManager) != TYPE_NIL:
		SaveManager.register_world(_loader, _player, respawn)
	_spawn_workbench()
	_spawn_npc()
	_spawn_truth_shard()
	_spawn_return_portal()
	if typeof(SaveManager) != TYPE_NIL:
		if SaveManager.pending_load:
			SaveManager.pending_load = false
			SaveManager.load_game()
		elif SaveManager.has_world_snapshot(WorldContext.current_scene):
			SaveManager.restore_registered_world()
		if typeof(GameState) != TYPE_NIL:
			GameState.reconcile_portal_line()
	if typeof(AudioManager) != TYPE_NIL:
		if AudioManager.has_method("start_world_audio"):
			AudioManager.start_world_audio()
		if AudioManager.has_method("set_home_ambience"):
			AudioManager.set_home_ambience(true)   # 지하 심부 = 조용한 저음 (홈 앰비언스 재사용)
	# (EXL3-5) 첫 진입 시 L3 속삭임 라인은 clockwork_city가 이미 활성 — 광산은 N-digger 라인만
	# (QuestNPC 최초 상호작용 시 activate_npc_line). 별도 라인 활성 불필요.


## (EXL3-5) Spawn the 정비대 (mine workbench = the L3 crafting station, 실 Cauldron with the shared
## brew skin) at the legend `special.workbench_cell` (20,38). Clones clockwork_city._spawn_workbench
## so the "첫 조합 ≤4분" pacing (§A-7) holds — the player lands and the bench is 2 cells away.
func _spawn_workbench() -> void:
	var cell := _loader.l2_workbench_special_cell()
	if cell == Vector2i(-1, -1):
		return
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
	# L3 flame = 주황 (태엽 동력). Pool offset matches the shared cauldron footprint.
	_add_pool(s, "res://assets/objects/light_pool_orange.png", Vector2(0, -8), 0.85)


func _bind_fusion_ui(caul: Cauldron) -> void:
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


## Spawn the 잔재 NPC 「갱도에 갇힌 줄 모르는 굴착 로봇」 (N-digger) beside the legend N cell (19,10).
func _spawn_npc() -> void:
	if _loader == null:
		return
	QuestNPC.spawn(self, _loader, Vector2i(19, 11), "digger", "갱도에 갇힌 굴착 로봇",
		"…다음 광차, 도착 예정… 대기 중. 벌써 오래됐는데. 실어 낼 광석은, 여기 쌓여만 가.",
		"res://assets/objects/l3m_digger_bot.png")


## (EXL3-5) Place the 광부 로그 석판 진상 조각 at landmark `3` (27,22). Reuses the miner-log slab art;
## falls back to the nearest walkable cell.
func _spawn_truth_shard() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/l3m_miner_log_slab.png") as Texture2D
	for cell in SHARD_CELLS:
		if not _loader.is_cell_walkable(cell):
			continue
		var s := TruthShard.new()
		s.setup(SHARD_ID, "광부 로그 석판", SHARD_LOG, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		if _loader.has_method("apply_height_lift"):
			_loader.apply_height_lift(s)
		return


## Return portal near the mine spawn (19,39) — travels back to the CLOCKWORK CITY (승강로 상행).
func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	var candidates := [
		_loader.spawn_cell + Vector2i(0, -2),
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, -3),
	]
	_return_portal.setup(_loader, _player, candidates, "E 시계탑 도시로")
	_return_portal.entered.connect(_on_return_portal)


func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_CLOCKWORK
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_CLOCKWORK))
