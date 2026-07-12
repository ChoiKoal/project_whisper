extends Node
class_name SanctumSession
## (EXL2-5) Session glue for the L2 확장 SUB-zone 「지하 데이터 성소」 (data_sanctum.tscn / l2s). Mirrors
## HeartSession + TerminalStation: registers the world, spawns the 정비대(실 Cauldron, L2 스킨),
## the 마지막 백업을 지키는 관리 드론 잔재 NPC (N-archivist) + the 전쟁 기록 단말 진상 조각 (L2 심부 =
## 엔딩 5조각의 에너지 조각 `l2_last_log` 심화), and a RETURN portal back to the TERMINAL STATION (the
## sanctum is reached via the 정비 승강로 하강 under the 관제탑). Gate LOGIC + cutscene C-4 + the
## 잔류 전력 노드 idempotent add_energy live in the L2sGateController node.
##
## Defensive against missing autoloads. Zero regression to the base L2 terminal_station.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _return_portal: ReturnPortalController = null

## (EXL2-5) 전쟁 기록 단말 진상 조각 — L2 심부(에너지) 조각. Reuses the canonical 5-set id "l2_last_log"
## (deepening the L2/에너지 진상, NOT a new sixth id) exactly as HeartSession reuses "world_tree".
## Placed at the 전쟁 기록 단말 landmark `3` (27,22).
const SHARD_ID := "l2_last_log"
const SHARD_CELLS := [Vector2i(27, 22), Vector2i(26, 22), Vector2i(28, 22)]
const SHARD_LOG := "…전쟁 기록 단말. 마지막 백업이 담은 로그 — 문명은 자원을 두고 싸우다 전력을 잃었고, 마지막까지 남긴 것은 무기가 아니라 이 기억이었다. 우리가 어디서 틀렸는지, 여기 적혀 있다."


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = WorldContext.SCENE_SANCTUM
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
	# (EXL2-5) 첫 진입 시 L2 속삭임 라인은 terminal_station이 이미 활성 — 성소는 N-archivist 라인만
	# (QuestNPC 최초 상호작용 시 activate_npc_line). 별도 라인 활성 불필요.


## (EXL2-5) Spawn the 정비대 (tech workbench = the L2 crafting station, 실 Cauldron with the shared
## brew skin) at the legend `special.workbench_cell` (20,38). Clones terminal_station._spawn_workbench
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
	# L2 flame = 시안 (정전된 문명). Pool offset matches the shared cauldron footprint.
	_add_pool(s, "res://assets/objects/light_pool_cyan.png", Vector2(0, -8), 0.85)


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


## Spawn the 잔재 NPC 「마지막 백업을 지키는 관리 드론」 (N-archivist) beside the legend N cell (19,10).
func _spawn_npc() -> void:
	if _loader == null:
		return
	QuestNPC.spawn(self, _loader, Vector2i(19, 11), "archivist", "마지막 백업을 지키는 관리 드론",
		"…접근 권한, 확인 중… 오류. 나는… 이걸, 지키라고 남겨졌어. 누가 남겼는지는, 로그가 지워졌어.",
		"res://assets/objects/l2s_archivist_drone.png")


## (EXL2-5) Place the 전쟁 기록 단말 진상 조각 at landmark `3` (27,22). Reuses the l2_screen_off art
## (dead terminal) already shipped for L2 진상 조각; falls back to the nearest walkable cell.
func _spawn_truth_shard() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/l2_screen_off.png") as Texture2D
	for cell in SHARD_CELLS:
		if not _loader.is_cell_walkable(cell):
			continue
		var s := TruthShard.new()
		s.setup(SHARD_ID, "전쟁 기록 단말", SHARD_LOG, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		if _loader.has_method("apply_height_lift"):
			_loader.apply_height_lift(s)
		return


## Return portal near the sanctum spawn (19,39) — travels back to the TERMINAL STATION (승강로 상행).
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
	_return_portal.setup(_loader, _player, candidates, "E 관문 기지로")
	_return_portal.entered.connect(_on_return_portal)


func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_TERMINAL
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_TERMINAL))
