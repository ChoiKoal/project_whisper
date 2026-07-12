extends Node
class_name BelfrySession
## (EXL5-5) Session glue for the L5 확장 SUB-zone 「침묵의 종탑」 (belfry.tscn / l5b). Mirrors
## ArchiveSession: registers the world, spawns the 정비대(주종대, 실 Cauldron with the shared brew
## skin), the 아직도 종을 지키는 종지기의 그림자 잔재 NPC (N-bellkeeper), the 신의 마지막 기록 진상 조각
## (L5 심부 = 엔딩 5조각의 신성 조각 심화), and a RETURN portal back to the CATHEDRAL (침묵의 종탑은
## 대성당 대제단 곁 종탑 계단으로 진입). Gate LOGIC + cutscene C-4 + the 잔향 성수반 idempotent add_vita
## live in the L5bGateController node.
##
## Defensive against missing autoloads. Zero regression to the base L5 cathedral.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _return_portal: ReturnPortalController = null

## (EXL5-5) 신의 마지막 기록 진상 조각 — L5 심부(신성) 조각. Reuses the canonical 5-set id
## "petrified_pilgrim" (= 신성/L5 조각; deepening the same shard the base 대성당 cathedral emits, NOT a
## new sixth id) exactly as ArchiveSession reuses "mage_ghost". 비게이팅: 엔딩 5조각은 대성당에서 이미
## 획득 가능하고, 종탑 기록판은 같은 신성 조각을 재조사(re-look)로 완성/심화할 뿐 6번째 게이트를 추가하지
## 않는다(§EX-L5 5). Placed at the 신의 마지막 기록 landmark `3` (27,22).
const SHARD_ID := "petrified_pilgrim"
const SHARD_CELLS := [Vector2i(27, 22), Vector2i(26, 22), Vector2i(28, 22)]
const SHARD_LOG := "…신의 마지막 기록. 신은 마지막으로 물었다 — '아직 거기 있니.' 아무도 대답하지 않았다. 나는 대답을 들으려 했을 뿐인데, 침묵이 나를 시들게 했다. 믿음은, 서로가 서로에게 대답할 때에만 살아 있다. 종을 울려라. 그것이, 세계에게 보내는 가장 큰 대답이다."


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = WorldContext.SCENE_BELFRY
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
			AudioManager.set_home_ambience(true)   # 종탑 심부 = 조용한 저음/침묵 (홈 앰비언스 재사용)
	# (EXL5-5) 첫 진입 시 L5 속삭임 라인은 cathedral이 이미 활성 — 종탑은 N-bellkeeper 라인만
	# (QuestNPC 최초 상호작용 시 activate_npc_line). 별도 라인 활성 불필요.


## (EXL5-5) Spawn the 정비대 (주종대 = the L5 crafting station, 실 Cauldron with the shared brew skin)
## at the legend `special.workbench_cell` (20,38). Clones ArchiveSession._spawn_workbench so the
## "첫 조합 ≤4분" pacing (§A-7) holds — the player lands and the bench is 2 cells away.
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
	# L5 flame = 호박/앰버 (신성). Pool offset matches the shared cauldron footprint.
	_add_pool(s, "res://assets/objects/light_pool_amber.png", Vector2(0, -8), 0.85)


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


## Spawn the 잔재 NPC 「아직도 종을 지키는 종지기의 그림자」 (N-bellkeeper) beside the legend N cell (19,10).
func _spawn_npc() -> void:
	if _loader == null:
		return
	QuestNPC.spawn(self, _loader, Vector2i(19, 10), "bellkeeper", "종지기의 그림자",
		"…종 칠 시간이, 지났나. 나는 아직… 밧줄을 쥐고 있는데. 아무도 안 와. 다음 타종은, 언제였더라.",
		"res://assets/objects/l5b_bellkeeper_shade.png")


## (EXL5-5) Place the 신의 마지막 기록 진상 조각 at landmark `3` (27,22). Reuses the record-slab art;
## falls back to the nearest walkable cell.
func _spawn_truth_shard() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/l5b_gods_last_record_slab.png") as Texture2D
	for cell in SHARD_CELLS:
		if not _loader.is_cell_walkable(cell):
			continue
		var s := TruthShard.new()
		s.setup(SHARD_ID, "신의 마지막 기록", SHARD_LOG, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		if _loader.has_method("apply_height_lift"):
			_loader.apply_height_lift(s)
		return


## Return portal near the belfry spawn (19,39) — travels back to the CATHEDRAL (종탑 계단 하행).
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
	_return_portal.setup(_loader, _player, candidates, "E 대성당으로")
	_return_portal.entered.connect(_on_return_portal)


func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_CATHEDRAL
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_CATHEDRAL))
