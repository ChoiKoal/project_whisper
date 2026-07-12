extends Node
class_name HeartSession
## (EXL1-2/5) Session glue for the L1 확장 SUB-zone 「생명의 심장」 (life_heart.tscn / l1h). Mirrors
## GardenSession: registers the world, spawns the 첫 컨스트럭터의 잔향 잔재 NPC (N-constructor) + the
## 첫 실험 흔적 진상 조각 (L1 심부 = 엔딩 5조각 구조의 L1 조각), and a RETURN portal back to the GROVE
## (the heart is reached via the world-tree descent from the grove). Gate LOGIC + cutscene C-4 + the
## 생명의 샘물 idempotent add_vita live in the L1xGateController node.
##
## Defensive against missing autoloads. Zero regression to the base 시작의 숲.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _return_portal: ReturnPortalController = null

## (EXL1-5) 심장 진상 조각 — 첫 실험 흔적. This IS an endgame-shard-tier piece: the L1 심부 조각 that
## deepens the 세계수(EG) 진상. Placed at the 첫 실험 흔적 landmark `3` (27,22). Uses the canonical
## "world_tree" shard id so it counts toward the 5-set 진상 (deepening, not a new sixth id).
const HEART_SHARD_ID := "world_tree"
const HEART_SHARD_CELLS := [Vector2i(27, 22), Vector2i(26, 23), Vector2i(28, 22)]
const HEART_SHARD_LOG := "…첫 실험 흔적. 누군가 여기서 생명을 만들려 했다. 심장에서 꺼내기만 하고, 돌려주는 걸 잊은 채로. 선배들도, 되살리려 했으나 — 꺼내는 법만 알았다."


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = WorldContext.SCENE_HEART
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
			AudioManager.set_home_ambience(true)   # 심부 = 조용한 저음 (홈 앰비언스 재사용)


## Spawn the 잔재 NPC 「첫 컨스트럭터의 잔향」 (N-constructor) beside the legend N cell (15,8).
func _spawn_npc() -> void:
	if _loader == null:
		return
	QuestNPC.spawn(self, _loader, Vector2i(15, 9), "constructor", "첫 컨스트럭터의 잔향",
		"…너도, 왔구나. 나도 이걸 되살리려 했어. 오래전에. …왜 실패했는지, 이제 알겠어?",
		"res://assets/objects/first_constructor_echo.png")


## (EXL1-5) Place the 첫 실험 흔적 진상 조각 at landmark `3` (27,22).
func _spawn_truth_shard() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/first_experiment_shard.png") as Texture2D
	for cell in HEART_SHARD_CELLS:
		if not _loader.is_cell_walkable(cell):
			continue
		var s := TruthShard.new()
		s.setup(HEART_SHARD_ID, "첫 실험 흔적", HEART_SHARD_LOG, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		if _loader.has_method("apply_height_lift"):
			_loader.apply_height_lift(s)
		return


## Return portal near the heart spawn (19,39) — travels back to the GROVE.
func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	var candidates := [
		_loader.spawn_cell + Vector2i(0, -2),
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, 2),
	]
	_return_portal.setup(_loader, _player, candidates, "E 시작의 숲으로")
	_return_portal.entered.connect(_on_return_portal)


func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_GROVE))
