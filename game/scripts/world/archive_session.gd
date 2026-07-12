extends Node
class_name ArchiveSession
## (EXL4-5) Session glue for the L4 확장 SUB-zone 「부유 서고」 (floating_archive.tscn / l4a). Mirrors
## MineSession: registers the world, spawns the 정비대(제본대, 실 Cauldron with the shared brew skin),
## the 아직도 책을 정리하는 사서 잔영 잔재 NPC (N-librarian), the 금기 열람 기록 석판 진상 조각 (L4 심부 =
## 엔딩 5조각의 마법 조각 심화), and a RETURN portal back to the MAGE TOWER (부유 서고는 마탑 최심부
## 곁 찢긴 서고 통로로 진입). Gate LOGIC + cutscene C-4 + the 잔류 열람 결계정 idempotent add_mana live
## in the L4aGateController node.
##
## Defensive against missing autoloads. Zero regression to the base L4 mage_tower.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _return_portal: ReturnPortalController = null

## (EXL4-5) 금기 열람 기록 석판 진상 조각 — L4 심부(마법) 조각. Reuses the canonical 5-set id
## "mage_ghost" (= 마력/L4 조각; deepening the same shard the base 마탑 mage_tower emits, NOT a new
## sixth id) exactly as MineSession reuses "stopped_robot". 비게이팅: 엔딩 5조각은 마탑에서 이미
## 획득 가능하고, 서고 기록판은 같은 마력 조각을 재조사(re-look)로 완성/심화할 뿐 6번째 게이트를
## 추가하지 않는다(§EX-L4 5·487). Placed at the 금기 열람 기록 석판 landmark `3` (27,22).
const SHARD_ID := "mage_ghost"
const SHARD_CELLS := [Vector2i(27, 22), Vector2i(26, 22), Vector2i(28, 22)]
const SHARD_LOG := "…금기 열람 기록 석판. 마지막 사서가 남긴 기록 — 우리는 더 깊이, 더 많이 읽었다. 힘의 극한, 세계를 다시 쓰는 한 줄을 찾아서. 그런 줄은 봉인해야 했다. 마지막 장에서, 봉인을 다시 여미고서야 알았다. 우리가 어디서 펼치지 말았어야 했는지, 여기 적혀 있다."


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = WorldContext.SCENE_ARCHIVE
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
			AudioManager.set_home_ambience(true)   # 부유 심부 = 조용한 저음 (홈 앰비언스 재사용)
	# (EXL4-5) 첫 진입 시 L4 속삭임 라인은 mage_tower가 이미 활성 — 서고는 N-librarian 라인만
	# (QuestNPC 최초 상호작용 시 activate_npc_line). 별도 라인 활성 불필요.


## (EXL4-5) Spawn the 정비대 (archive bindery = the L4 crafting station, 실 Cauldron with the shared
## brew skin) at the legend `special.bindery_cell` (20,38). Clones MineSession._spawn_workbench so the
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
	# L4 flame = 자수정 보라 (금기 마력). Pool offset matches the shared cauldron footprint.
	_add_pool(s, "res://assets/objects/light_pool_violet.png", Vector2(0, -8), 0.85)


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


## Spawn the 잔재 NPC 「아직도 책을 정리하는 사서 잔영」 (N-librarian) beside the legend N cell (19,11).
func _spawn_npc() -> void:
	if _loader == null:
		return
	QuestNPC.spawn(self, _loader, Vector2i(19, 12), "librarian", "책을 정리하는 사서 잔영",
		"…이 책은, 제자리가… 어디였더라. 열람 순번이, 흐트러졌어. 나는 아직… 정리 중인데. 다음 열람자는, 언제 오나.",
		"res://assets/objects/l4a_archivist_shade.png")


## (EXL4-5) Place the 금기 열람 기록 석판 진상 조각 at landmark `3` (27,22). Reuses the log-slab art;
## falls back to the nearest walkable cell.
func _spawn_truth_shard() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/l4a_forbidden_log_slab.png") as Texture2D
	for cell in SHARD_CELLS:
		if not _loader.is_cell_walkable(cell):
			continue
		var s := TruthShard.new()
		s.setup(SHARD_ID, "금기 열람 기록 석판", SHARD_LOG, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		if _loader.has_method("apply_height_lift"):
			_loader.apply_height_lift(s)
		return


## Return portal near the archive spawn (19,39) — travels back to the MAGE TOWER (서고 통로 상행).
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
	_return_portal.setup(_loader, _player, candidates, "E 마탑으로")
	_return_portal.entered.connect(_on_return_portal)


func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_MAGE_TOWER
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_MAGE_TOWER))
