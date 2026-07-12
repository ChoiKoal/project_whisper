extends Node
class_name L2sGateController
## (EXL2-3) 지하 데이터 성소(l2s) 4-게이트를 이미-스폰된 맵/오브젝트 위에 얹는 단일 노드.
## l1x_gate_controller.gd 패턴 계승(stepping/use/puzzle/chain-offering + 정화 컷신 + persisted-state
## reapply). §Part C: 신규 엔진 로직은 GB3 데이터 정합 술어뿐(EX-L1 GA3 색맞춤과 동형, 아이템 id만 교체).
##
##   GB1 (배치/stepping): 방수 디딤돌 D256 → 냉각 침수로 K 배치 → placed_object_placed → K 셀 walkable.
##   GB2 (사용): 디코더 젤 D258 → 봉인 격벽(sealed_bulkhead) 사용 → item_used_on_object → D 셀 개방 + 아트 스왑.
##   GB3 (배치 미니 퍼즐 data_shard_3): 정합 조각 D259/D260/D261 → 3 x 슬롯 배치(순서 무관·재배치) → 3조각
##       모두 채워지면 데이터 문 M 개방 + data_shard_matched 시그널.
##   GB4 (체인/봉헌): 복원 코어 D263 → 백업 봉헌 목(backup_altar) 봉헌 → 성소 정화 + 컷신 C-4「깨어나는 백업」
##       (control_lock/time_running 페어링 + ESC 스킵) → sanctum_purified 플래그.
##   잔류 전력 노드 E: idempotent add_energy(1) — GB1→GB2 회랑에 강제 배치, 게이트 아님(§A-6.3).
##
## Defensive against missing autoloads/nodes (release templates strip assert()); every hook guards.
## Idempotent: re-applies opened/purified state on load/re-entry (no cutscene replay).

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l2s legend `gates`). Empty on non-l2s maps → controller idle.
var _gates: Dictionary = {}
var _active: bool = false

## GB1 침수로 디딤돌 셀 / GB2 격벽 셀 / GB3 데이터 문 셀 + 정합 슬롯 / GB4 봉헌 목 셀.
var _gb1_cells: Array = []
var _gb2_cells: Array = []
var _gb3_door_cells: Array = []
var _gb3_slot_cells: Array = []
var _gb3_slots: Dictionary = {}   # Vector2i(slot) -> item_id placed ("D259"/"D260"/"D261")
var _gb3_solved: bool = false
var _gb4_cells: Array = []

## Cached art nodes.
var _sealed_bulkhead: Node = null
var _backup_altar: Node = null
var _backup_core: Node = null

## One-shot latches.
var _sanctum_purifying: bool = false
var _energy_given: bool = false

## GB1 디딤돌 lit source (walkable) / sealed(냉각수) sources. K 셀은 T5A(8) 냉각수 → 디딤돌 배치 후
## T1(1) 판데크로 walkable. GROUND(2)=T2A 서버실 바닥(개방된 게이트 walkable). 닫힌 D/M(source-2,
## 원래 walkable)은 냉각수(T5A=8, 이 맵에서 non-walkable 증명됨)로 seal — garden A/M seal 방식 동형.
const BRIDGE_LIT_SOURCE := 1    # T1 — walkable 방수 디딤돌 데크
const WATER_SOURCE := 8         # T5A — sealed 냉각 침수로
const GROUND_SOURCE := 2        # T2A — walkable 서버실 바닥(GB2/GB3/GB4 open state)
const SANCTUM_CLOSED_SOURCE := 8   # T5A 냉각수 — 닫힌 D/M 병목 seal(non-walkable)

## 데이터 정합 퍼즐 성공 시그널(EX-L1 color_bed_solved 병렬).
signal data_shard_matched()


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# Wait a couple frames so the loader has finished spawning all l2s objects.
	await get_tree().process_frame
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader == null:
		return
	_gates = _loader.legend_gates()
	if _gates.is_empty():
		return
	# Only drive the sanctum (l2s has GB* gates; other maps use GA*/GH*/G*).
	if not (_gates.has("GB1") or _gates.has("GB4")):
		return
	_active = true
	_wire_cells()
	_seal_closed_gates()
	_wire_art()
	_spawn_power_residue()
	# Listen for the gate-driving signals.
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.placed_object_placed.is_connected(_on_placed):
			GameState.placed_object_placed.connect(_on_placed)
	# Re-apply any already-opened / purified state (save / re-entry) without replaying cutscenes.
	_reapply_persisted_state()


# ==== wiring ================================================================

func _wire_cells() -> void:
	_gb1_cells = _cells_of(_gates.get("GB1", {}).get("cells", []))
	_gb2_cells = _cells_of(_gates.get("GB2", {}).get("cells", []))
	var gb3: Dictionary = _gates.get("GB3", {})
	_gb3_door_cells = _cells_of(gb3.get("cells", []))
	_gb3_slot_cells = _cells_of(gb3.get("slot_cells", []))
	_gb4_cells = _cells_of(_gates.get("GB4", {}).get("cells", []))


## Seal the D(GB2) / M(GB3) bottlenecks non-walkable on load. Their authored tile is source-2
## (T2A, walkable), so without this the closed gates are passable — contradicting the design
## (§A-6 truth tables) and l2x_bfs.py, which treat every closed gate cell as a wall. GB1's K
## cells are already 냉각수-sealed (source 8) by the layout, so they are skipped. GB4's H 봉헌 목
## is an offering point (not a void bottleneck) inside the sanctum, reachable once GB3 opens —
## it is NOT tile-sealed (like heart GH2 mount / garden GA4 font). _reapply (called just after)
## re-opens whatever the save/flag state says should be open.
func _seal_closed_gates() -> void:
	for cell in (_gb2_cells + _gb3_door_cells):
		_loader.set_gate_cell_source(cell, false, GROUND_SOURCE, SANCTUM_CLOSED_SOURCE)


func _wire_art() -> void:
	_sealed_bulkhead = _find_node("sealed_bulkhead")
	_backup_altar = _find_node("backup_altar")
	_backup_core = _find_node("backup_core")


# ==== placement (GB1 stepping + GB3 데이터 정합 미니 퍼즐) ===================

func _on_placed(item_id: String, cell: Vector2i) -> void:
	if not _active:
		return
	if item_id == "D256":
		_try_gb1_place(cell)
	elif item_id == "D259" or item_id == "D260" or item_id == "D261":
		_try_gb3_place(item_id, cell)


## GB1: 방수 디딤돌 placed on a 냉각 침수로 K cell → that cell becomes walkable (stepping-stone swap).
func _try_gb1_place(cell: Vector2i) -> void:
	if not (cell in _gb1_cells):
		return
	_loader.set_gate_cell_source(cell, true, BRIDGE_LIT_SOURCE, WATER_SOURCE)
	_add_glow(cell, "res://assets/objects/light_pool_cyan.png", 0.5)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")


## GB3: a 정합 조각 placed on one of the 3 정합 슬롯 → record it (re-placeable). When all three
## DISTINCT shards are present across the 3 slots, open the 데이터 문 M (순서 무관).
func _try_gb3_place(item_id: String, cell: Vector2i) -> void:
	var slot := _nearest_slot(cell)
	if slot == Vector2i(-9999, -9999):
		return
	_gb3_slots[slot] = item_id
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")
	_check_gb3_solved()


func _nearest_slot(cell: Vector2i) -> Vector2i:
	if cell in _gb3_slot_cells:
		return cell
	var best := Vector2i(-9999, -9999)
	var best_d := 2.5
	for s in _gb3_slot_cells:
		var d: float = Vector2(s).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = s
	return best


## Solved iff the 3 slots collectively hold all three distinct shards (order-free).
func _check_gb3_solved() -> void:
	if _gb3_solved:
		return
	var shards := {}
	for s in _gb3_slots.keys():
		shards[_gb3_slots[s]] = true
	if shards.has("D259") and shards.has("D260") and shards.has("D261"):
		_gb3_solved = true
		_open_gb3_door()
		data_shard_matched.emit()


func _open_gb3_door(instant: bool = false) -> void:
	for cell in _gb3_door_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)
		if not instant:
			_add_glow(cell, "res://assets/objects/light_pool_cyan.png", 0.6)
	if not instant and AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_open")


# ==== use / offering (GB2, GB4) ============================================

func _on_item_used(item: String, obj: Node) -> void:
	if not _active or obj == null:
		return
	var oid := ""
	if obj.has_method("get"):
		var v: Variant = obj.get("object_id")
		if typeof(v) == TYPE_STRING:
			oid = v
	if oid == "":
		oid = String(obj.get_meta("object_id", ""))
	match oid:
		"sealed_bulkhead":
			if item == "D258":
				_open_gb2()
		"backup_altar":
			if item == "D263":
				_offer_sanctum()


## GB2: 봉인 격벽 개방 → D 셀 개방 + 아트 스왑(sealed_bulkhead_open).
func _open_gb2(instant: bool = false) -> void:
	for cell in _gb2_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)
	_swap_art(_sealed_bulkhead, "res://assets/objects/l2s_sealed_bulkhead_open.png")
	if not instant:
		_add_glow(_gb2_cells[0] if not _gb2_cells.is_empty() else _loader.spawn_cell,
			"res://assets/objects/light_pool_cyan.png", 0.7)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_open")


# ==== GB4: 성소 정화 + 컷신 C-4 「깨어나는 백업」 ============================

func _offer_sanctum(instant: bool = false) -> void:
	if _sanctum_purifying or (GameState != null and GameState.sanctum_purified_flag):
		_apply_sanctum_endstate()
		return
	_sanctum_purifying = true
	_swap_art(_backup_altar, "res://assets/objects/l2s_backup_altar_lit.png")
	_swap_art(_backup_core, "res://assets/objects/l2s_backup_core_lit.png")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_sanctum()
		return
	_run_sanctum_cutscene()


## Cutscene C-4 — control_lock/time_running pairing + ESC skip (v1.3.0 QA). 모달 CanvasLayer.
var _cs_layer: CanvasLayer = null
var _cs_line: Label = null
var _cs_dim: ColorRect = null
var _cs_skip := false
var _cs_running := false

const C4_CARDS := [
	"부식된 채 명멸하던 코어가… 한 번, 깊게 점등한다.",
	"광섬유를 따라, 죽어 있던 데이터가 다시 흐르기 시작한다.",
	"…접근 권한, 확인… 됐어. 백업이, 깨어났어. 나는 이걸 지키라고만 남겨졌는데… 이제야, 지킨 게 뭔지 알겠어. 너는… 잊지 말고, 가.",
	"문명의 마지막 기억이, 다시 켜진다.",
]


func _run_sanctum_cutscene() -> void:
	_cs_running = true
	_cs_skip = false
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	_build_cs_layer()
	# 1. 저음 부팅 톤 1회 + 시안 발광 파문 (오프닝 CS-01 수미상관).
	_purify_flash_ring(Color(0.25, 0.88, 1.0), _core_pos())
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	await _cs_wait(0.6)
	if is_instance_valid(_cs_dim):
		var dtw := _cs_layer.create_tween()
		dtw.tween_property(_cs_dim, "color:a", 0.55, 0.8)
	for card in C4_CARDS:
		if _cs_skip:
			break
		await _cs_card(card)
		# 데이터 트레이 발광이 최심부→어귀로 남하 (best-effort ripple).
		if not _cs_skip:
			_purify_flash_ring(Color(0.25, 0.78, 0.95, 1.0), _core_pos())
			await _cs_wait(0.3)
	_finish_sanctum()


func _build_cs_layer() -> void:
	_cs_layer = CanvasLayer.new()
	_cs_layer.layer = 11
	add_child(_cs_layer)
	_cs_dim = ColorRect.new()
	_cs_dim.color = Color(0.05, 0.08, 0.12, 0.0)
	_cs_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cs_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cs_layer.add_child(_cs_dim)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cs_layer.add_child(center)
	_cs_line = Label.new()
	_cs_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cs_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cs_line.custom_minimum_size = Vector2(560, 0)
	_cs_line.add_theme_color_override("font_color", Color("#e6f8ff"))
	_cs_line.add_theme_font_size_override("font_size", 28)
	_cs_line.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.08, 0.9))
	_cs_line.add_theme_constant_override("outline_size", 5)
	_cs_line.modulate.a = 0.0
	center.add_child(_cs_line)
	var hint := Label.new()
	hint.text = "ESC 건너뛰기"
	hint.add_theme_color_override("font_color", Color(0.78, 0.82, 0.85, 0.5))
	hint.add_theme_font_size_override("font_size", 13)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position = Vector2(-120, -34)
	_cs_layer.add_child(hint)


func _cs_card(text: String) -> void:
	if not is_instance_valid(_cs_line):
		return
	_cs_line.text = text
	var tw := _cs_layer.create_tween()
	tw.tween_property(_cs_line, "modulate:a", 1.0, 0.7)
	tw.tween_interval(1.4)
	tw.tween_property(_cs_line, "modulate:a", 0.0, 0.5)
	await tw.finished


## Unpausable tree timer so beats play while time_running=false.
func _cs_wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


## ESC (ui_cancel) or interact skips the C-4 cutscene (v1.3.0 QA).
func _unhandled_input(event: InputEvent) -> void:
	if not _cs_running or _cs_skip:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_cs_skip = true
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()


func _finish_sanctum() -> void:
	if not _sanctum_purifying and GameState != null and GameState.sanctum_purified_flag:
		return  # already finished (double-guard)
	_sanctum_purifying = false
	_cs_running = false
	if is_instance_valid(_cs_layer):
		_cs_layer.queue_free()
	_cs_layer = null
	if GameState != null:
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)
		GameState.time_running = true
		GameState.sanctum_purified_flag = true
		GameState.sanctum_purified.emit("sanctum")
	_apply_sanctum_endstate()


func _apply_sanctum_endstate() -> void:
	_swap_art(_backup_altar, "res://assets/objects/l2s_backup_altar_lit.png")
	_swap_art(_backup_core, "res://assets/objects/l2s_backup_core_lit.png")


# ==== 잔류 전력 노드 E (idempotent add_energy) =============================

## 잔류 전력 노드(sanctum_power_residue) 근접 시 에너지 Whisper 1회 재획득(보유 보장만, 중복 파밍
## 불가). 게이트 아님 — GB1→GB2 회랑에 놓여 최심부로 오르는 도중 반드시 지난다(§A-6.3). EX-L1
## 생명의 샘물 idempotent 패턴 계승.
func _spawn_power_residue() -> void:
	var node := _find_node("sanctum_power_residue")
	if node == null or not is_instance_valid(node):
		return
	var area := Area2D.new()
	area.monitoring = true
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 64.0
	col.shape = shape
	area.add_child(col)
	if node is Node2D:
		(node as Node2D).add_child(area)
	else:
		return
	area.body_entered.connect(func(body):
		if _player != null and body == _player:
			_grant_energy(node))


func _grant_energy(source: Node) -> void:
	if _energy_given:
		return
	_energy_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_energy"):
		WhisperCurrency.add_energy(1)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gather")
	var fb := _loader.get_node_or_null(_loader.ysort_layer_path)
	if fb != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
		FloatingLabel.spawn(fb, _player.global_position - Vector2(0, 96),
			"…잔류 전력을, 다시 거둔다")


# ==== persisted-state reapply ==============================================

## Re-apply any opened / purified state on a restored / re-entered zone so reopened gates stay open
## and the purified end-state is shown without replaying the cutscene. 성소 정화 ⇒ 모든 게이트 개방
## (공간 순서 강제 = GB1→GB2→GB3→GB4).
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.sanctum_purified_flag:
		for cell in _gb1_cells:
			_loader.set_gate_cell_source(cell, true, BRIDGE_LIT_SOURCE, WATER_SOURCE)
		_open_gb2(true)
		_gb3_solved = true
		_open_gb3_door(true)
		_apply_sanctum_endstate()


# ==== helpers ==============================================================

func _cells_of(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


func _tex_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Find a spawned l2s object node by its l2_id (loader stores them as "l2_id@cell").
func _find_node(l2_id: String) -> Node:
	if _loader == null:
		return null
	for key in _loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == l2_id:
			return _loader.l2_object_nodes[key].get("node")
	return null


func _swap_art(node: Node, path: String) -> void:
	if node == null or not is_instance_valid(node) or not (node is Sprite2D):
		return
	var tex := _tex_if_exists(path)
	if tex != null:
		(node as Sprite2D).texture = tex


func _add_glow(cell: Vector2i, tex_path: String, strength: float) -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := _tex_if_exists(tex_path)
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.scale = Vector2(strength, strength)
	ys.add_child(pool)
	pool.global_position = _loader.cell_center_world(cell)


## A tinted flash + expanding ripple ring from `origin` — the shared purification set-piece.
func _purify_flash_ring(tint: Color, origin: Vector2) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 12
	add_child(cl)
	if typeof(CutsceneDirector) != TYPE_NIL:
		var flash := CutsceneDirector.make_flash(Color(tint.r, tint.g, tint.b))
		cl.add_child(flash)
		CutsceneDirector.flash(self, flash, 0.85, 0.1, 1.0)
		var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
		if ys != null:
			CutsceneDirector.spawn_ripple_ring(self, ys, origin, tint, 18.0, 1.8, 60)
	get_tree().create_timer(1.6, true, false, true).timeout.connect(func():
		if is_instance_valid(cl):
			cl.queue_free())


func _core_pos() -> Vector2:
	if _backup_core != null and is_instance_valid(_backup_core) and _backup_core is Node2D:
		return (_backup_core as Node2D).global_position
	if _backup_altar != null and is_instance_valid(_backup_altar) and _backup_altar is Node2D:
		return (_backup_altar as Node2D).global_position
	return _map_center()


func _map_center() -> Vector2:
	if _loader != null:
		return _loader.cell_center_world(Vector2i(int(_loader.width / 2), int(_loader.height / 2)))
	return Vector2.ZERO
