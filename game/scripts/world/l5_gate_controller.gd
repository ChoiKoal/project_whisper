extends Node
class_name L5GateController
## (L5-3) The single node that wires Layer-5 「응답 없는 대성당」's four 봉헌/응답 게이트 onto the
## already-spawned cathedral objects + map. Reuses the L2/L3/L4 signal patterns wholesale (§C-3),
## with only node_id strings + key-item ids swapped — NO new gate systems. Theme: L1~L4 정화 =
## "멈춘 것을 되살림 / 풀려난 것을 다시 봉인함", L5 정화 = "응답 없는 세계에, 우리가 대답함" (§A-1).
##   G1 등불 봉헌   — 성소의 등불 D178 → 성소 등불 제단(lantern_altar X, 배치형=use) 봉헌 →
##                    power_node_energized("lantern_path") → 꺼진 참배길 g 셀 순차 walkable (호박빛 점등).
##   G2 생명의 샘   — 생명의 씨 D180 → 생명의 샘 E 사용(item_used_on_object) → 밸브문 e 개방
##                    + **생명 Whisper ×1 획득** (§보완 필수, L5에서 첫 vita, idempotent, add_vita).
##   G3 침묵의 회랑 — 침묵의 성가 D182 소지 상태 폴링(L4 부적 held-item 패턴) → 침묵 병목 Y walkable +
##                    **BGM 덕킹**(입술 없는 노래만 남도록). 장착·소모 아닌 소지 판정 (신규 조작 0).
##   G4 대제단 봉헌 — 응답 D186(whisper_cost {energy:1, mana:1, vita:1}) → 봉헌 제단(offering_altar) 사용 →
##                    power_node_energized("great_altar") → Layer 5 정화(응답) 컷신 → layer5_purified +
##                    time_running 복구 (v0.6.1 페어링 규칙).
##
## §A-2 (byte-identical) carries NO K symbol, so this controller SPAWNS the offering_altar (G4) mount
## at gates.G4.mount (19,2), wraps it + the E life_spring + the X lantern_altar in invisible use-targets
## (Gatherable with object_id, no item) so the EXISTING _try_use_on_object framework routes the key
## item onto them. It also spawns the two 재획득처 — 발전 제단 A(에너지+마력)/마력 성물함 B(마력) — as
## idempotent reward objects (§A-4, softlock 회복). Idempotent on reload. Defensive vs missing autoloads.

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l5_map_legend.json `gates`). Empty on non-L5 maps → controller idle.
var _gates: Dictionary = {}

const DARK_SOURCE := 38   # L5 sealed (dark, non-walkable) — matches legend g/e/Y/H tiles.

## G1 등불 봉헌: dead-lantern path cells (south→north light order) + altar cell/node.
var _lantern_cells: Array = []
var _g1_lit_source := 33
var _altar_cell: Vector2i = Vector2i(-1, -1)
var _altar_node: Node2D = null
## G2 생명의 샘: valve-door cells + spring node.
var _door_cells: Array = []
var _spring_node: Node = null
var _g2_lit_source := 34
## G3 침묵의 회랑: silence bottleneck cells + choir stand.
var _corridor_cells: Array = []
var _g3_lit_source := 36
## G4 대제단 봉헌: offering-neck cells + mount.
var _neck_cells: Array = []
var _g4_lit_source := 37
var _mount_cell: Vector2i = Vector2i(-1, -1)
var _mount_node: Node2D = null

## Key items (per §B-1 recipe chain / legend).
const G1_LANTERN := "D178"   # 성소의 등불 (배치/봉헌형, lantern_altar에 사용)
const G2_SEED := "D180"      # 생명의 씨 (life_spring에 사용)
const G3_HYMN := "D182"      # 침묵의 성가 (소지형)
const G4_OFFERING := "D186"  # 응답 (offering_altar에 사용, whisper_cost 3키)

## Guard so the G2 생명 Whisper acquisition 연출 fires exactly once (idempotent 보상).
var _g2_reward_given: bool = false
## G3 held-hymn poll state (open = corridor cells currently walkable + BGM ducked).
var _g3_open: bool = false

## 재획득처 A/B: idempotent 1회 grant guards + cells.
var _reacquire_a_cell: Vector2i = Vector2i(12, 13)
var _reacquire_b_cell: Vector2i = Vector2i(27, 13)
var _reacquire_a_node: Node2D = null
var _reacquire_b_node: Node2D = null
var _reacquire_a_given: bool = false
var _reacquire_b_given: bool = false


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader == null:
		return
	_gates = _loader.legend_gates()
	if _gates.is_empty() or not _gates.has("G4") or not _is_l5():
		return  # not a Layer-5 map
	_wire_gate_data()
	_spawn_mount()
	_spawn_reacquire()
	_wire_use_targets()
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.power_node_energized.is_connected(_on_power_node):
			GameState.power_node_energized.connect(_on_power_node)
	_reapply_persisted_state()
	# G3 held-hymn poll runs every frame (§C-3 허용, 값싼 소지 검사). Also polls A/B proximity grants.
	set_process(true)


## Distinguish an L5 map: L5's G1 node_id is dead_lantern (unique to the cathedral legend).
func _is_l5() -> bool:
	var g1: Dictionary = _gates.get("G1", {})
	return String(g1.get("node_id", "")) == "dead_lantern"


# ==== gate data wiring =====================================================

func _wire_gate_data() -> void:
	var g1: Dictionary = _gates.get("G1", {})
	_lantern_cells = _cells_of(g1.get("bridge_cells", []))
	_lantern_cells.sort_custom(func(a, b): return a.y > b.y)   # south→north
	_g1_lit_source = int(g1.get("lit_source", 33))
	var altar: Array = _cells_of(g1.get("altar", []))
	if altar.size() > 0:
		_altar_cell = altar[0]

	var g2: Dictionary = _gates.get("G2", {})
	_door_cells = _cells_of(g2.get("door_cells", []))
	_g2_lit_source = int(g2.get("lit_source", 34))
	_spring_node = _find_node("life_spring")

	var g3: Dictionary = _gates.get("G3", {})
	_corridor_cells = _cells_of(g3.get("gate_cells", []))
	_g3_lit_source = int(g3.get("lit_source", 36))

	var g4: Dictionary = _gates.get("G4", {})
	_neck_cells = _cells_of(g4.get("neck_cells", []))
	_g4_lit_source = int(g4.get("lit_source", 37))
	var mount: Array = _cells_of(g4.get("mount", []))
	if mount.size() > 0:
		_mount_cell = mount[0]


## §A-2 has no K symbol, so spawn the offering_altar (G4) mount at the gate mount coord with an
## object_id, so the use-target wiring routes the 응답 key item onto it.
func _spawn_mount() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	if _mount_cell != Vector2i(-1, -1):
		_mount_node = _spawn_slot(ys, _mount_cell, "res://assets/objects/l5_offering_altar.png",
			Vector2(0, -40), "offering_altar")


## Spawn the two 재획득처 (발전 제단 A: 에너지+마력, 마력 성물함 B: 마력) at their legend cells. These
## are NOT in §A-2's spawned object set (A/B tiles are 침묵의 회랑 pavement); the controller owns them.
func _spawn_reacquire() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	# Read A/B cells from the layout (A/B chars) — fall back to the doc coords.
	var a := _find_layout_char("A")
	var b := _find_layout_char("B")
	if a != Vector2i(-1, -1):
		_reacquire_a_cell = a
	if b != Vector2i(-1, -1):
		_reacquire_b_cell = b
	_reacquire_a_node = _spawn_slot(ys, _reacquire_a_cell,
		"res://assets/objects/l5_pilgrim_dynamo.png", Vector2(0, -40), "pilgrim_dynamo")
	_reacquire_b_node = _spawn_slot(ys, _reacquire_b_cell,
		"res://assets/objects/l5_mana_reliquary.png", Vector2(0, -40), "mana_reliquary")


func _spawn_slot(ys: Node2D, cell: Vector2i, tex_path: String, off: Vector2, object_id: String) -> Node2D:
	# Reuse an object already spawned by the loader at this object_id if present (avoid doubles).
	var existing := _find_node(object_id)
	if existing != null and is_instance_valid(existing) and existing is Node2D:
		return existing as Node2D
	var s := Sprite2D.new()
	var tex := _tex_if_exists(tex_path)
	if tex != null:
		s.texture = tex
	s.offset = off
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.y_sort_enabled = true
	s.set_meta("object_id", object_id)
	ys.add_child(s)
	s.global_position = _loader.cell_center_world(cell)
	if _loader.has_method("apply_height_lift"):
		_loader.apply_height_lift(s)
	return s


## Wrap the spawned mount / A / B + the loader-spawned life_spring + lantern_altar in use-targets
## (a Gatherable child with object_id, no item) so the held key item routes onto them.
func _wire_use_targets() -> void:
	if _mount_node != null:
		_make_use_target(_mount_node, "offering_altar")
	if _reacquire_a_node != null:
		_make_use_target(_reacquire_a_node, "pilgrim_dynamo")
	if _reacquire_b_node != null:
		_make_use_target(_reacquire_b_node, "mana_reliquary")
	for key in _loader.l2_object_nodes.keys():
		var l5id := String(key).split("@")[0]
		var rec: Dictionary = _loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		if node == null or not is_instance_of(node, Sprite2D):
			continue
		if l5id == "life_spring":
			_make_use_target(node as Sprite2D, "life_spring")
		elif l5id == "lantern_altar":
			_make_use_target(node as Sprite2D, "lantern_altar")
			if _altar_node == null:
				_altar_node = node as Node2D


func _make_use_target(sprite: Node2D, object_id: String) -> void:
	for ch in sprite.get_children():
		if ch is Gatherable and String((ch as Gatherable).object_id) == object_id:
			return
	var g := Gatherable.new()
	g.item_id = ""
	g.object_id = object_id
	g.texture = null
	g.modulate = Color(1, 1, 1, 0)
	sprite.add_child(g)
	g.position = Vector2.ZERO


# ==== key-item use → power node energize ===================================

func _on_item_used(item: String, obj: Node) -> void:
	if obj == null:
		return
	var oid := String(obj.get("object_id")) if obj.has_method("get") else ""
	match oid:
		"lantern_altar":
			if item == G1_LANTERN:
				_spark_at(obj)
				GameState.energize_power_node("lantern_path")
		"life_spring":
			if item == G2_SEED:
				_spark_at(obj)
				_refill_spring(obj)
		"offering_altar":
			if item == G4_OFFERING:
				_spark_at(obj)
				GameState.energize_power_node("great_altar")
		"pilgrim_dynamo":
			_grant_reacquire_a(obj)
		"mana_reliquary":
			_grant_reacquire_b(obj)


func _on_power_node(node_id: String) -> void:
	match node_id:
		"lantern_path":
			_light_lantern_path()
		"great_altar":
			_start_purification()


# ==== G1: 등불 봉헌 (참배길 순차 점등) ======================================

## Sequentially open the dead-lantern path cells (0.12s stagger) — reads as 꺼진 등불이 호박빛으로
## 하나씩 되살아나는 연출. Reuses the walkable-swap + AStar rebuild (set_gate_cell_source).
func _light_lantern_path(instant: bool = false) -> void:
	if _lantern_cells.is_empty():
		return
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_swap_slot_art(_altar_node, "res://assets/objects/l5_lantern_altar_on.png")
	_swap_art("dead_lantern", "res://assets/objects/l5_lantern_path_lit.png")
	var i := 0
	for cell in _lantern_cells:
		if instant:
			_loader.set_gate_cell_source(cell, true, _g1_lit_source, DARK_SOURCE)
			_add_glow(cell)
		else:
			var c: Vector2i = cell
			get_tree().create_timer(0.12 * i).timeout.connect(func():
				if is_instance_valid(_loader):
					_loader.set_gate_cell_source(c, true, _g1_lit_source, DARK_SOURCE)
					_add_glow(c))
		i += 1


# ==== G2: 생명의 샘 + 밸브문 + 생명 Whisper (필수) =========================

func _refill_spring(spring_obj: Node) -> void:
	GameState.energize_power_node("life_spring")
	if spring_obj is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l5_life_spring_on.png")
		if on_tex != null:
			(spring_obj as Sprite2D).texture = on_tex
		_add_running_glow(spring_obj as Node2D)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_open_door()
	_grant_vita_whisper(spring_obj)


func _open_door(instant: bool = false) -> void:
	for cell in _door_cells:
		_loader.set_gate_cell_source(cell, true, _g2_lit_source, DARK_SOURCE)
	# swap the life-door node art to open.
	var door := _find_node("life_door")
	if door != null and is_instance_valid(door):
		for ch in door.get_children():
			if ch is StaticBody2D:
				(ch as StaticBody2D).process_mode = Node.PROCESS_MODE_DISABLED
				var col := (ch as StaticBody2D).get_child(0)
				if col is CollisionShape2D:
					(col as CollisionShape2D).set_deferred("disabled", true)
		if door is Sprite2D:
			var open_tex := _tex_if_exists("res://assets/objects/l5_life_door_open.png")
			if open_tex != null:
				(door as Sprite2D).texture = open_tex


## Grant the first 생명 Whisper (§보완 필수, L5에서 생명 Whisper 첫 등장·정사 — 3속성 완성). +1 vita →
## WhisperCurrency, 연둣빛 빛줄기 연출 toward the player + 플로팅 텍스트, exactly once (idempotent).
func _grant_vita_whisper(source: Node) -> void:
	if _g2_reward_given:
		return
	_g2_reward_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_vita"):
		WhisperCurrency.add_vita(1)
	var anchor: Vector2 = _player.global_position if _player != null else \
		(source.get("global_position") if source != null and source.has_method("get") else Vector2.ZERO)
	_spawn_life_beam(source, anchor)
	var fb := _feedback_parent()
	if fb != null and typeof(FloatingLabel) != TYPE_NIL:
		FloatingLabel.spawn(fb, anchor - Vector2(0, 96), "…처음으로, 생명이 내 것이 되었다")


## A verdant life streak from the spring flowing into the player (생명이 흘러듦).
func _spawn_life_beam(source: Node, to_world: Vector2) -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var from_world: Vector2 = to_world
	if source != null and source.has_method("get"):
		var gp: Variant = source.get("global_position")
		if typeof(gp) == TYPE_VECTOR2:
			from_world = gp
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = Color(0.56, 0.85, 0.41, 0.9)  # 연둣빛 #8fd968
	line.points = PackedVector2Array([from_world, from_world])
	line.z_index = 60
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = mat
	ys.add_child(line)
	var grow := func(t: float) -> void:
		if is_instance_valid(line):
			line.points = PackedVector2Array([from_world, from_world.lerp(to_world, t)])
	var tw := ys.create_tween()
	tw.tween_method(grow, 0.0, 1.0, 0.6)
	tw.tween_property(line, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		if is_instance_valid(line):
			line.queue_free())


# ==== G3: 침묵의 회랑 (성가 소지 → walkable swap + BGM 덕킹) ================

## Poll the 침묵의 성가 possession while the map is active: hymn held → 침묵 병목 Y walkable + BGM
## 덕킹(입술 없는 노래만 남도록); else re-seal + BGM 복구. Same held-item判定 as L4's 부적 (no equip,
## no consume). Also runs the idempotent A/B proximity grants.
func _process(_delta: float) -> void:
	if not is_instance_valid(_loader):
		return
	var carrying := _has_hymn()
	if carrying and not _g3_open:
		_g3_open = true
		_set_corridor_walkable(true)
		_duck_bgm(true)
	elif not carrying and _g3_open:
		_g3_open = false
		_set_corridor_walkable(false)
		_duck_bgm(false)
	_poll_reacquire()


func _set_corridor_walkable(carrying: bool) -> void:
	for cell in _corridor_cells:
		_loader.set_gate_cell_source(cell, carrying, _g3_lit_source, DARK_SOURCE)
		if carrying:
			_add_glow(cell)
	if _g3_open:
		_swap_art("silence_gate", "res://assets/objects/l5_silence_gate_on.png")
		_swap_art("silence_landmark", "res://assets/objects/l5_silence_gate_on.png")
		_swap_art("choir_stand", "res://assets/objects/l5_choir_stand_on.png")


func _duck_bgm(on: bool) -> void:
	if AudioManager != null and AudioManager.has_method("duck_bgm"):
		AudioManager.duck_bgm(on)


func _has_hymn() -> bool:
	return typeof(Inventory) != TYPE_NIL and Inventory.has(G3_HYMN)


# ==== 재획득처 A/B (idempotent 1회 보상) ===================================

## Grant energy+mana ONCE at 발전 제단 A (에너지 재획득; A grants energy, and — per the doc — also
## mana? No: A=에너지, B=마력. A grants energy only, idempotent). Kept as its own guard.
func _grant_reacquire_a(_obj: Node = null) -> void:
	if _reacquire_a_given:
		return
	_reacquire_a_given = true
	if typeof(WhisperCurrency) != TYPE_NIL:
		if WhisperCurrency.has_method("add_energy"):
			WhisperCurrency.add_energy(1)
	_spark_at(_reacquire_a_node)
	_swap_slot_art(_reacquire_a_node, "res://assets/objects/l5_pilgrim_dynamo_on.png")
	_floating("…발전 제단이, 에너지를 다시 건넸다", _reacquire_a_node)


func _grant_reacquire_b(_obj: Node = null) -> void:
	if _reacquire_b_given:
		return
	_reacquire_b_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_mana"):
		WhisperCurrency.add_mana(1)
	_spark_at(_reacquire_b_node)
	_swap_slot_art(_reacquire_b_node, "res://assets/objects/l5_mana_reliquary_on.png")
	_floating("…성물함이, 마력을 다시 건넸다", _reacquire_b_node)


## Proximity auto-grant for A/B (placed on the 침묵의 회랑, reached before G4). When the player steps
## onto/adjacent to the altar, grant once. Cheap manhattan check; idempotent guards make revisits no-ops.
func _poll_reacquire() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _reacquire_a_given and _near(_reacquire_a_cell):
		_grant_reacquire_a()
	if not _reacquire_b_given and _near(_reacquire_b_cell):
		_grant_reacquire_b()


func _near(cell: Vector2i) -> bool:
	if _player == null or not is_instance_valid(_player) or _loader == null:
		return false
	var pc := _loader.world_to_cell(_player.global_position) if _loader.has_method("world_to_cell") \
		else Vector2i(-999, -999)
	return absi(pc.x - cell.x) <= 1 and absi(pc.y - cell.y) <= 1


# ==== G4: 대제단 봉헌 = Layer 5 정화(응답) ===================================

var _purifying: bool = false

func _start_purification(instant: bool = false) -> void:
	if _purifying or (GameState != null and GameState.get("layer5_purified_flag") == true):
		_apply_purified_endstate()
		return
	_purifying = true
	_swap_slot_art(_mount_node, "res://assets/objects/l5_offering_altar_on.png")
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	# open the offering neck H cells so the altar core is reachable end-state.
	for cell in _neck_cells:
		_loader.set_gate_cell_source(cell, true, _g4_lit_source, DARK_SOURCE)
	if instant:
		_finish_purification()
		return
	_run_purification()


func _run_purification() -> void:
	_light_altar()
	await get_tree().create_timer(0.5).timeout
	_wave_cathedral()
	await get_tree().create_timer(2.2).timeout
	_brighten_base_tone()
	await _purify_card("…응답 없던 세계가, 처음으로 대답을 들었다.")
	# (L5-5 §C-4) 정화가 layer5_purified 를 emit 하면 Cathedral 훅이 다섯 포탈 전점등 + 빛의 문 예고를
	# 발동한다(5-AND 멱등). 마지막 레이어이면(다섯 정화 완료) 그 완결을 예고하는 카드를 이어 보여준다.
	# 다섯 정화가 아직 안 끝났으면(하네스 단독 L5 클리어 등) 기본 카드만 — 조건 판단은 GameState가 소유.
	_finish_purification()
	if GameState != null and GameState.get("light_gate_previewed_flag") == true:
		await _portal_completion_cutscene()


## (L5-5 §C-4) 다섯 포탈 완결 컷신 — 다섯 포탈 전점등 (비주얼: 대성당 위 다섯 빛기둥 순차 점화) +
## 홈 섬 중앙 빛의 문 예고 (텍스트 카드). 문 생성 자체는 다음 마일스톤(엔딩 M) — 여기서는 예고까지.
## 컷신 동안 input lock/time_running 을 다시 잠갔다가 끝에서 확실히 복구한다(v0.6.1 페어링).
func _portal_completion_cutscene() -> void:
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	_spawn_five_portal_beams()
	await get_tree().create_timer(1.6).timeout
	await _purify_card("다섯 세계가, 전부 대답을 들었다. 다섯 문이 함께 빛난다.")
	await _purify_card("…홈 섬 한가운데, 빛의 문이 열릴 자리가 밝아온다.")
	if GameState != null:
		GameState.time_running = true
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)


## (L5-5) 다섯 포탈 전점등의 비주얼 — 대성당 위로 다섯 빛기둥이 순차 점화(자연/과학/기계/마법/신성).
## CanvasLayer 오버레이 위 다섯 세로 광선을 페이드-인/아웃. 헤드리스에서도 크래시 없이 (그냥 안 보임).
func _spawn_five_portal_beams() -> void:
	if _loader == null:
		return
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	var tints := [
		Color("#8fd08a"),  # nature
		Color("#7fd7e0"),  # science
		Color("#e0a86a"),  # machine
		Color("#c8a0f0"),  # magic
		Color("#f5ecd0"),  # divinity (상아/호박)
	]
	var i := 0
	for tint in tints:
		var beam := ColorRect.new()
		beam.color = tint
		beam.custom_minimum_size = Vector2(26, 220)
		beam.size = Vector2(26, 220)
		beam.position = Vector2(240 + i * 90, 60)
		beam.modulate.a = 0.0
		cl.add_child(beam)
		var tw := cl.create_tween()
		tw.tween_interval(0.18 * i)
		tw.tween_property(beam, "modulate:a", 0.85, 0.35)
		tw.tween_interval(1.4)
		tw.tween_property(beam, "modulate:a", 0.0, 0.6)
		i += 1
	get_tree().create_timer(3.2).timeout.connect(func():
		if is_instance_valid(cl):
			cl.queue_free())


func _finish_purification() -> void:
	_purifying = false
	if GameState != null:
		GameState.set("layer5_purified_flag", true)
		# v0.6.1 페어링 규칙: time_running false로 잠근 곳에서 반드시 복구.
		GameState.time_running = true
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)
		if GameState.has_signal("layer5_purified"):
			GameState.layer5_purified.emit("divinity")


func _apply_purified_endstate() -> void:
	_swap_slot_art(_mount_node, "res://assets/objects/l5_offering_altar_on.png")
	for cell in _neck_cells:
		_loader.set_gate_cell_source(cell, true, _g4_lit_source, DARK_SOURCE)
	_light_altar()
	_wave_cathedral(true)
	_brighten_base_tone()


func _light_altar() -> void:
	var altar := _find_node("great_altar_landmark")
	if altar != null and is_instance_valid(altar) and altar is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l5_great_altar_on.png")
		if on_tex != null:
			(altar as Sprite2D).texture = on_tex
		_add_running_glow(altar as Node2D, 1.2)


## Re-light/open everything (대성당 순차 응답). L5 정화 = 응답 → 따뜻한 호박빛으로 안정.
func _wave_cathedral(instant: bool = false) -> void:
	_light_lantern_path(true)
	_open_door(true)
	_swap_art("life_spring", "res://assets/objects/l5_life_spring_on.png")
	_swap_art("spring_landmark", "res://assets/objects/l5_life_spring_on.png")


## Brighten toward a settled warm amber (응답 후 온기) — L5 정화 = 대답, so the tone warms.
func _brighten_base_tone() -> void:
	var cm := _find_canvas_modulate()
	if cm != null and is_instance_valid(cm):
		var tw := cm.create_tween()
		tw.tween_property(cm, "color", Color("#c8a86a"), 1.5)   # settled warm amber calm


func _find_canvas_modulate() -> CanvasModulate:
	var root := _loader.get_parent()
	if root == null:
		return null
	for ch in root.get_children():
		if ch is CanvasModulate:
			return ch as CanvasModulate
	return null


func _purify_card(text: String) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 11
	add_child(cl)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color("#f5ecd0"))
	lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.05, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.modulate.a = 0.0
	cl.add_child(lbl)
	var tw := cl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.7)
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		if is_instance_valid(cl):
			cl.queue_free())
	await tw.finished


# ==== helpers ==============================================================

func _cells_of(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


func _find_layout_char(ch: String) -> Vector2i:
	if not is_instance_valid(_loader):
		return Vector2i(-1, -1)
	for r in range(_loader.height):
		var row: String = _loader._layout[r]
		for c in range(row.length()):
			if row[c] == ch:
				return Vector2i(c, r)
	return Vector2i(-1, -1)


func _tex_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _find_node(l5id: String) -> Node:
	if not is_instance_valid(_loader):
		return null
	for key in _loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == l5id:
			return _loader.l2_object_nodes[key].get("node")
	return null


func _swap_art(l5id: String, path: String) -> void:
	var n := _find_node(l5id)
	if n != null and is_instance_valid(n) and n is Sprite2D:
		var tex := _tex_if_exists(path)
		if tex != null:
			(n as Sprite2D).texture = tex


func _swap_slot_art(node: Node2D, path: String) -> void:
	if node != null and is_instance_valid(node) and node is Sprite2D:
		var tex := _tex_if_exists(path)
		if tex != null:
			(node as Sprite2D).texture = tex


func _add_glow(cell: Vector2i) -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load("res://assets/objects/light_pool_gold.png")
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.scale = Vector2(0.55, 0.55)
	ys.add_child(pool)
	pool.global_position = _loader.cell_center_world(cell)


func _spark_at(obj: Node) -> void:
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_spark")
	if obj is Node2D:
		_add_running_glow(obj as Node2D, 0.9)


func _add_running_glow(node: Node2D, strength: float = 0.8) -> void:
	if not is_instance_valid(node):
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load("res://assets/objects/light_pool_gold.png")
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.scale = Vector2(strength, strength)
	node.add_child(pool)


func _floating(text: String, near: Node) -> void:
	var fb := _feedback_parent()
	if fb == null or typeof(FloatingLabel) == TYPE_NIL:
		return
	var anchor := Vector2.ZERO
	if near != null and near.has_method("get"):
		var gp: Variant = near.get("global_position")
		if typeof(gp) == TYPE_VECTOR2:
			anchor = gp
	FloatingLabel.spawn(fb, anchor - Vector2(0, 72), text)


func _feedback_parent() -> Node:
	return _loader.get_node_or_null(_loader.ysort_layer_path)


## Re-apply persisted energized/purified state on a restored / re-entered cathedral.
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.is_power_node_energized("lantern_path"):
		_light_lantern_path(true)
	if GameState.is_power_node_energized("life_spring"):
		_g2_reward_given = true
		_open_door(true)
	if GameState.get("layer5_purified_flag") == true:
		_apply_purified_endstate()
