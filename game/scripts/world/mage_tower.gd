extends Node
class_name MageTower
## (L4-2) Session glue for the Layer-4 「봉인이 풀린 마탑」 (mage_tower.tscn). Mirrors
## ClockworkCity exactly (the L3 session) with L4 art + the magic-world purification hook:
##   1. spawns the 정비대 (L4 crafting station) at legend special.workbench_cell, with a GOLD
##      fusion glow (drawn art + gold glow pool);
##   2. sparse debris scatter (loose rune shards + arcane ash wisps) on eligible ground, EXCLUDING
##      cliff-rim / ramp / occupied cells (same v0.5c exclusion as the L2/L3 stations);
##   3. scatters a few 마법사들의 잔영 (mage afterimages) as street deco — investigate → "진상의
##      조각" (L3 로봇의 마지막 로그에 대응하는 L4 서사 오브젝트);
##   4. registers the world with SaveManager so the tower snapshots/restores like the other scenes.
## Reads the same parameterized MapLoader (l4_* data overrides on the Ground node). Defensive
## against missing autoloads (release templates strip assert()).

@export var map_loader_path: NodePath
@export var player_path: NodePath
@export var respawn_path: NodePath

var _loader: MapLoader
var _player: Node2D
## (L4-2) The L4 return portal at the spawn — same reworked entry-zone pattern as grove/home/L2/L3.
var _return_portal: ReturnPortalController = null

## Debris scatter tuning: sparse — a crumbling tower, not a meadow. Deterministic by cell hash.
const DEBRIS_TARGET := 40
const DEBRIS_SEED := 0x2A1F3D

## Mage-afterimage street deco: a handful of poses at authored-ish cells (§C-2 5~7체 산재).
const GHOST_ARTS := ["l4_mage_ghost_standing", "l4_mage_ghost_reaching", "l4_mage_ghost_kneeling"]
## The 진상의 조각 (선배 컨스트럭터가 세계를 '완성'하고 떠나 속삭임이 끊긴 진상).
const GHOST_LOGS := [
	"…진상의 조각: 그분은 힘을 '완성'이라 부르고 떠나셨다. 완성된 힘은, 봉인해야 하는 것이었다.",
	"…진상의 조각: 금기를 건드린 건 우리다. 봉인을 열어, 무엇이 있는지 보고 싶었을 뿐인데.",
	"…진상의 조각: 속삭임이 끊긴 날을 기록한다. 봉인이 풀리기, 꼭 한 숨 전.",
	"…진상의 조각: 마지막까지 손을 뻗은 건, 닫으려던 것이었을까 열려던 것이었을까.",
	"…진상의 조각: 우리는 강했다. 다시 봉할 수 있을 만큼은, 아니었다.",
]


func _ready() -> void:
	if typeof(WorldContext) != TYPE_NIL:
		WorldContext.current_scene = "mage_tower"
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
	_scatter_ghosts()
	_spawn_return_portal()
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("register_world"):
		SaveManager.register_world(_loader, _player, respawn)
	if typeof(AudioManager) != TYPE_NIL:
		if AudioManager.has_method("start_world_audio"):
			AudioManager.start_world_audio()
		if AudioManager.has_method("set_home_ambience"):
			AudioManager.set_home_ambience(true)
	# (L4-5) Layer 4 정화 완료 → 다음 포탈(divinity) flickering + 홈 귀환 유도 (§C-4 포탈 전파).
	if typeof(GameState) != TYPE_NIL and GameState.has_signal("layer4_purified"):
		if not GameState.layer4_purified.is_connected(_on_layer4_purified):
			GameState.layer4_purified.connect(_on_layer4_purified)
	# (L4-5) 첫 L4 진입 시 Layer-4 속삭임 라인(L4-Q1~Q7) 활성 — L1/L2/L3 라인과 퀘스트 로그에 공존.
	if typeof(QuestManager) != TYPE_NIL and QuestManager.has_method("activate_l4_line"):
		QuestManager.activate_l4_line()


## (L4-5) Called when the 최심부 봉인 재구축 정화 컷신 completes. Advances the portal line (magic
## → divinity flickering) so the next dead world opens on return home. Save so the purified flag +
## powered nodes persist.
func _on_layer4_purified(_layer: String) -> void:
	if typeof(GameState) != TYPE_NIL and GameState.has_method("set_portal_state"):
		# magic 포탈 = OPEN (정화한 세계는 열린 채로 — nature/science/machine→open 패턴 계승).
		GameState.set_portal_state("magic", GameState.PORTAL_OPEN)
		# 다음 죽은 세계(divinity = Layer 5) flickering 전파 — 홈 귀환 시 뛰기 시작.
		GameState.set_portal_state("divinity", GameState.PORTAL_FLICKERING)
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()


func _spawn_return_portal() -> void:
	if _loader == null or _loader.spawn_cell == Vector2i(-1, -1):
		return
	_return_portal = ReturnPortalController.new()
	add_child(_return_portal)
	# Spawn S is (19,37) on amethyst pavement; drop the gate a couple cells beside it.
	var candidates := [
		_loader.spawn_cell + Vector2i(-2, 0),
		_loader.spawn_cell + Vector2i(2, 0),
		_loader.spawn_cell + Vector2i(0, -2),
		_loader.spawn_cell + Vector2i(-3, 0),
	]
	_return_portal.setup(_loader, _player, candidates, "E 홈으로 돌아가기")
	_return_portal.entered.connect(_on_return_portal)


## Travel back to the home island from Layer 4 (mirrors ClockworkCity._on_return_portal —
## no ignition; the L4 purification cutscene already advanced the portal line + saved).
func _on_return_portal() -> void:
	if typeof(WorldContext) == TYPE_NIL:
		return
	WorldContext.arrival_mode = "portal_arrival"
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("save_game"):
		SaveManager.save_game()
	WorldContext.current_scene = WorldContext.SCENE_HOME
	get_tree().change_scene_to_file(WorldContext.scene_path(WorldContext.SCENE_HOME))


## Spawn the 정비대 (L4 crafting station). Reuses the L4 workbench art + a gold glow pool. Sits
## on its legend cell (west of spawn) so the "first craft ≤4분" pacing (§A-7) holds.
func _spawn_workbench() -> void:
	var cell := _loader.l2_workbench_special_cell()
	if cell == Vector2i(-1, -1):
		return
	# (v1.0.4 P0 hotfix) Real Cauldron wearing the L4 workbench skin — see terminal_station.gd for
	# why: a plain Sprite2D never emitted `interacted`, so Fusion was unreachable in real play.
	var s := Cauldron.new()
	s.configure(load("res://assets/objects/l4_workbench.png"), Vector2(0, -44))
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
	# gold fusion glow at the aperture.
	_add_pool(s, "res://assets/objects/light_pool_gold.png", Vector2(0, -46), 0.7)


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


## Sparse debris scatter — loose rune shards (l4_debris_rune) + arcane ash wisps (l4_debris_ash) —
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
			s.texture = load("res://assets/objects/l4_debris_ash.png" if ash else "res://assets/objects/l4_debris_rune.png")
			s.offset = Vector2(0, -8)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.y_sort_enabled = true
			ys.add_child(s)
			s.global_position = _loader.cell_center_world(cell)
			_loader.apply_height_lift(s)
			placed += 1


## Scatter a few 마법사들의 잔영 across the districts. They are plain deco sprites carrying an
## object_id + a "truth-fragment" line as meta (mirror of L3's stopped robots).
func _scatter_ghosts() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	# Authored-ish deco cells in the walkable plazas (deterministic, off the gate spine).
	var cells := [
		Vector2i(11, 35), Vector2i(28, 33), Vector2i(13, 24),
		Vector2i(27, 25), Vector2i(14, 16), Vector2i(25, 14),
	]
	var i := 0
	for cell in cells:
		if not _loader.is_cell_walkable(cell):
			i += 1
			continue
		var art: String = GHOST_ARTS[i % GHOST_ARTS.size()]
		var log_line: String = GHOST_LOGS[i % GHOST_LOGS.size()]
		# (EG-2) 진상 조각 조사 오브젝트: investigating any 마법사 잔영 collects the L4 shard.
		var s := TruthShard.new()
		s.setup("mage_ghost", "마법사의 잔영", log_line, load("res://assets/objects/%s.png" % art))
		s.offset = Vector2(0, -60)
		s.modulate = Color(1, 1, 1, 0.75)  # translucent afterimage
		ys.add_child(s)
		s.global_position = _loader.cell_center_world(cell)
		_loader.apply_height_lift(s)
		i += 1


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
