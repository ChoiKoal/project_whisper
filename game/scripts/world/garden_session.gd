extends Node
class_name GardenSession
## (EXL1-2/5) Session glue for the L1 확장 SUB-zone 「고요의 화원」 (quiet_garden.tscn / l1g). Mirrors
## GroveSession/TerminalStation but for a grove SUB-zone: it registers the world with SaveManager,
## spawns the 정원사 석상 잔재 NPC (N-gardener) + the 첫 실험/석화 진상 조각, and a RETURN portal back
## to the GROVE (the garden is reached from the grove-north 오솔길, so its exit returns to the grove).
## The gate LOGIC lives in the L1xGateController node in the scene; this session is slim.
##
## Defensive against missing autoloads (release templates strip assert()). Zero regression to the base
## 시작의 숲 — this is an additive sub-zone.

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
var _return_portal: ReturnPortalController = null

## (EXL1-5) 화원 진상 조각 — 정원사 석화(tone). A pure 회고 log shard placed at the 정원사 석상
## 실루엣 landmark. Not one of the 5 canonical endgame shards — a tone piece.
const GARDEN_SHARD_ID := "gardener_petrified"
const GARDEN_SHARD_CELLS := [Vector2i(19, 21), Vector2i(18, 22), Vector2i(20, 22)]
const GARDEN_SHARD_LOG := "…정원사 석상. 손 모양이, 물감을 개던 그대로 굳어 있다. 색을 되찾아줘도, 그는 움직이지 않는다. 이미, 오래전에 멈춘 손이다."


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = WorldContext.SCENE_GARDEN
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
	# Restore this zone's snapshot on 이어하기 / re-entry (gates the L1xGateController re-applies from
	# the purified flag; placed/gathered state restores here).
	if typeof(SaveManager) != TYPE_NIL:
		if SaveManager.pending_load:
			SaveManager.pending_load = false
			SaveManager.load_game()
		elif SaveManager.has_world_snapshot(WorldContext.current_scene):
			SaveManager.restore_registered_world()
		if typeof(GameState) != TYPE_NIL:
			GameState.reconcile_portal_line()
	# Ambient audio — reuse the grove soundscape (this is still Layer 1).
	if typeof(AudioManager) != TYPE_NIL:
		if AudioManager.has_method("start_world_audio"):
			AudioManager.start_world_audio()
		if AudioManager.has_method("set_home_ambience"):
			AudioManager.set_home_ambience(false)
	# (EXL1-5) 색을 잃은 정원사 석상 잔재 NPC 라인 (N-gardener) 활성 — 첫 진입 시.
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("activate_npc_line"):
		# Activated by the NPC on interact; nothing to force here.
		pass


## Spawn the 잔재 NPC 「색을 잃은 정원사 석상」 (N-gardener). Its art (석상) is authored on the N cell by
## the loader as a blocking l1x object; here we add a QuestNPC use-target beside it so E-대화 activates
## the N-gardener whisper chain. Anchor near the legend N cell (19,12).
func _spawn_npc() -> void:
	if _loader == null:
		return
	QuestNPC.spawn(self, _loader, Vector2i(19, 13), "gardener", "색을 잃은 정원사 석상",
		"…물감이, 어디 갔더라. 색을 맞춰야 하는데. 손이, 굳어서.",
		"res://assets/objects/gardener_statue.png")


## (EXL1-5) Place the 정원사 석화 진상 조각 at the 정원사 석상 실루엣 landmark (회고 트리거).
func _spawn_truth_shard() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var tex := load("res://assets/objects/gardener_statue_silhouette.png") as Texture2D
	for cell in GARDEN_SHARD_CELLS:
		if not _loader.is_cell_walkable(cell):
			continue
		var s := TruthShard.new()
		s.setup(GARDEN_SHARD_ID, "색을 잃은 정원사 석상", GARDEN_SHARD_LOG, tex)
		s.offset = Vector2(0, -40)
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		if _loader.has_method("apply_height_lift"):
			_loader.apply_height_lift(s)
		return  # one shard, first walkable cell


## Return portal near the garden spawn (19,39) — travels back to the GROVE (the garden's origin).
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
		SaveManager.save_game()   # snapshot the garden so re-entry restores it
	WorldContext.current_scene = WorldContext.SCENE_GROVE
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_GROVE))
