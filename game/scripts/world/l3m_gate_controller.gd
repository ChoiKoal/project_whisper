extends Node
class_name L3mGateController
## (EXL3-3) 태엽 광산(l3m) 4-게이트를 이미-스폰된 맵/오브젝트 위에 얹는 단일 노드.
## l2s_gate_controller.gd 패턴 계승(stepping/use/puzzle/chain-offering + 정화 컷신 + persisted-state
## reapply). §Part C: 신규 엔진 로직은 GM3 레일 전환 술어 rail_routed뿐(EX-L2 GB3 데이터 정합과
## 동형, 아이템 id만 교체).
##
##   GM1 (배치/stepping): 붕락 궤도판 D279 → 붕락 낙석 협곡 K 배치 → placed_object_placed → K 셀 walkable.
##   GM2 (사용): 감압 밸브 젤 D281 → 막힌 통풍문(vent_door) 사용 → item_used_on_object → D 셀 개방 + 아트 스왑.
##   GM3 (배치 미니 퍼즐 rail_route_3): 전환 레버 D282/D283/D284 → 3 x 슬롯 배치(순서 무관·재배치) → 3레버
##       모두 채워지면 광차문 M 개방 + rail_routed 시그널.
##   GM4 (체인/봉헌): 태엽 노심 D286 → 태엽 노심 봉헌 목(excavator_altar) 봉헌 → 광산 정화 + 컷신 C-4
##       「되감기는 첫 태엽」(control_lock/time_running 페어링 + ESC 스킵) → mine_purified 플래그.
##   잔류 태엽 발전기 E: idempotent add_energy(1) — GM1→GM2 회랑에 강제 배치, 게이트 아님(§A-6.3).
##
## 각 게이트 병목의 walkable/sealed source id는 legend gate 레코드의 lit_source/dark_source에서 읽는다
## (l2s는 상수였지만 광산은 지대별로 다른 갱도 리컬러 source를 쓰므로 데이터 주도). 기본 20(갱구 바닥)/25(암반).
##
## Defensive against missing autoloads/nodes. Idempotent: re-applies opened/purified state on
## load/re-entry (no cutscene replay).

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l3m legend `gates`). Empty on non-l3m maps → controller idle.
var _gates: Dictionary = {}
var _active: bool = false

## GM1 협곡 궤도판 셀 / GM2 통풍문 셀 / GM3 광차문 셀 + 전환 슬롯 / GM4 봉헌 목 셀.
var _gm1_cells: Array = []
var _gm2_cells: Array = []
var _gm3_door_cells: Array = []
var _gm3_slot_cells: Array = []
var _gm3_slots: Dictionary = {}   # Vector2i(slot) -> item_id placed ("D282"/"D283"/"D284")
var _gm3_solved: bool = false
var _gm4_cells: Array = []

## Cached art nodes.
var _vent_door: Node = null
var _excavator_altar: Node = null
var _excavator_core: Node = null

## One-shot latches.
var _mine_purifying: bool = false
var _energy_given: bool = false

## Default open/sealed sources (overridden per-gate from legend lit_source/dark_source).
## GROUND (20)=갱구 바닥 walkable. RUBBLE (25)=붕락 낙석 암반 sealed(non-walkable).
const DEFAULT_LIT_SOURCE := 20
const DEFAULT_DARK_SOURCE := 25
const GLOW_TEX := "res://assets/objects/light_pool_orange.png"

## 레일 전환 퍼즐 성공 시그널(EX-L2 data_shard_matched 병렬).
signal rail_routed()


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# Wait a couple frames so the loader has finished spawning all l3m objects.
	await get_tree().process_frame
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader == null:
		return
	_gates = _loader.legend_gates()
	if _gates.is_empty():
		return
	# Only drive the mine (l3m has GM* gates; other maps use GA*/GB*/GH*/G*).
	if not (_gates.has("GM1") or _gates.has("GM4")):
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
	_gm1_cells = _cells_of(_gates.get("GM1", {}).get("cells", []))
	_gm2_cells = _cells_of(_gates.get("GM2", {}).get("cells", []))
	var gm3: Dictionary = _gates.get("GM3", {})
	_gm3_door_cells = _cells_of(gm3.get("cells", []))
	_gm3_slot_cells = _cells_of(gm3.get("slot_cells", []))
	_gm4_cells = _cells_of(_gates.get("GM4", {}).get("cells", []))


## Per-gate walkable/sealed source ids from the legend (lit_source/dark_source), default 20/25.
func _lit_of(gate: String) -> int:
	return int(_gates.get(gate, {}).get("lit_source", DEFAULT_LIT_SOURCE))


func _dark_of(gate: String) -> int:
	return int(_gates.get(gate, {}).get("dark_source", DEFAULT_DARK_SOURCE))


## Seal the D(GM2) / M(GM3) bottlenecks non-walkable on load. Their authored tile may be a
## walkable source, so without this the closed gates are passable — contradicting the design
## (§A-6 truth tables) and l3x_bfs.py, which treat every closed gate cell as a wall. GM1's K
## cells are already 암반-sealed (source 25) by the layout, so they are skipped. GM4's H 봉헌 목
## is an offering point (not a void bottleneck) inside the mine, reachable once GM3 opens —
## it is NOT tile-sealed. _reapply (called just after) re-opens whatever the save/flag state says.
func _seal_closed_gates() -> void:
	for cell in _gm2_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GM2"), _dark_of("GM2"))
	for cell in _gm3_door_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GM3"), _dark_of("GM3"))


func _wire_art() -> void:
	_vent_door = _find_node("vent_door")
	_excavator_altar = _find_node("excavator_altar")
	_excavator_core = _find_node("excavator_core")


# ==== placement (GM1 stepping + GM3 레일 전환 미니 퍼즐) =====================

func _on_placed(item_id: String, cell: Vector2i) -> void:
	if not _active:
		return
	if item_id == "D279":
		_try_gm1_place(cell)
	elif item_id == "D282" or item_id == "D283" or item_id == "D284":
		_try_gm3_place(item_id, cell)


## GM1: 붕락 궤도판 placed on a 붕락 낙석 협곡 K cell → that cell becomes walkable (stepping-stone swap).
func _try_gm1_place(cell: Vector2i) -> void:
	if not (cell in _gm1_cells):
		return
	_loader.set_gate_cell_source(cell, true, _lit_of("GM1"), _dark_of("GM1"))
	_add_glow(cell, GLOW_TEX, 0.5)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")


## GM3: a 전환 레버 placed on one of the 3 전환 슬롯 → record it (re-placeable). When all three
## DISTINCT levers are present across the 3 slots, open the 광차문 M (순서 무관).
func _try_gm3_place(item_id: String, cell: Vector2i) -> void:
	var slot := _nearest_slot(cell)
	if slot == Vector2i(-9999, -9999):
		return
	_gm3_slots[slot] = item_id
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")
	_check_gm3_solved()


func _nearest_slot(cell: Vector2i) -> Vector2i:
	if cell in _gm3_slot_cells:
		return cell
	var best := Vector2i(-9999, -9999)
	var best_d := 2.5
	for s in _gm3_slot_cells:
		var d: float = Vector2(s).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = s
	return best


## Solved iff the 3 slots collectively hold all three distinct levers (order-free).
func _check_gm3_solved() -> void:
	if _gm3_solved:
		return
	var levers := {}
	for s in _gm3_slots.keys():
		levers[_gm3_slots[s]] = true
	if levers.has("D282") and levers.has("D283") and levers.has("D284"):
		_gm3_solved = true
		_open_gm3_door()
		rail_routed.emit()


func _open_gm3_door(instant: bool = false) -> void:
	for cell in _gm3_door_cells:
		_loader.set_gate_cell_source(cell, true, _lit_of("GM3"), _dark_of("GM3"))
		if not instant:
			_add_glow(cell, GLOW_TEX, 0.6)
	if not instant and AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_open")


# ==== use / offering (GM2, GM4) ============================================

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
		"vent_door":
			if item == "D281":
				_open_gm2()
		"excavator_altar":
			if item == "D286":
				_offer_mine()


## GM2: 막힌 통풍문 개방 → D 셀 개방 + 아트 스왑(vent_door_open).
func _open_gm2(instant: bool = false) -> void:
	for cell in _gm2_cells:
		_loader.set_gate_cell_source(cell, true, _lit_of("GM2"), _dark_of("GM2"))
	_swap_art(_vent_door, "res://assets/objects/l3m_vent_door_open.png")
	if not instant:
		_add_glow(_gm2_cells[0] if not _gm2_cells.is_empty() else _loader.spawn_cell, GLOW_TEX, 0.7)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_open")


# ==== GM4: 광산 정화 + 컷신 C-4 「되감기는 첫 태엽」 =========================

func _offer_mine(instant: bool = false) -> void:
	if _mine_purifying or (GameState != null and GameState.mine_purified_flag):
		_apply_mine_endstate()
		return
	_mine_purifying = true
	_swap_art(_excavator_altar, "res://assets/objects/l3m_excavator_altar_lit.png")
	_swap_art(_excavator_core, "res://assets/objects/l3m_excavator_core_lit.png")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_mine()
		return
	_run_mine_cutscene()


## Cutscene C-4 — control_lock/time_running pairing + ESC skip (v1.3.0 QA). 모달 CanvasLayer.
var _cs_layer: CanvasLayer = null
var _cs_line: Label = null
var _cs_dim: ColorRect = null
var _cs_skip := false
var _cs_running := false

const C4_CARDS := [
	"태엽이 다 풀린 채 명멸하던 대굴착기 코어가… 한 번, 깊게 감긴다.",
	"광차 레일을 따라, 태엽의 온기가 최심부에서 갱구로 되흐르기 시작한다.",
	"…다음 광차, 도착… 아니야. 알겠어. 광차는 안 와. 도시가 멈췄으니까. 파낸 걸 실어 갈 곳이, 처음부터 없었어. 너는… 여기 남지 말고, 가.",
	"영원히 감길 태엽은 없었다. 마지막 갱에서, 첫 태엽이 다 풀리는 걸 보고서야 알았다.",
]


func _run_mine_cutscene() -> void:
	_cs_running = true
	_cs_skip = false
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	_build_cs_layer()
	# 1. 저음 태엽 감기 톤 1회 + 주황 발광 파문 (구역 1 대시계 재가동 수미상관).
	_purify_flash_ring(Color(1.0, 0.62, 0.24), _core_pos())
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
		# 레일 발광이 최심부→갱구로 남하 (best-effort ripple).
		if not _cs_skip:
			_purify_flash_ring(Color(1.0, 0.55, 0.2, 1.0), _core_pos())
			await _cs_wait(0.3)
	_finish_mine()


func _build_cs_layer() -> void:
	_cs_layer = CanvasLayer.new()
	_cs_layer.layer = 11
	add_child(_cs_layer)
	_cs_dim = ColorRect.new()
	_cs_dim.color = Color(0.09, 0.05, 0.03, 0.0)
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
	_cs_line.add_theme_color_override("font_color", Color("#ffe8cc"))
	_cs_line.add_theme_font_size_override("font_size", 28)
	_cs_line.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))
	_cs_line.add_theme_constant_override("outline_size", 5)
	_cs_line.modulate.a = 0.0
	center.add_child(_cs_line)
	var hint := Label.new()
	hint.text = "ESC 건너뛰기"
	hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.5))
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


func _finish_mine() -> void:
	if not _mine_purifying and GameState != null and GameState.mine_purified_flag:
		return  # already finished (double-guard)
	_mine_purifying = false
	_cs_running = false
	if is_instance_valid(_cs_layer):
		_cs_layer.queue_free()
	_cs_layer = null
	if GameState != null:
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)
		GameState.time_running = true
		GameState.mine_purified_flag = true
		GameState.mine_purified.emit("mine")
	_apply_mine_endstate()


func _apply_mine_endstate() -> void:
	_swap_art(_excavator_altar, "res://assets/objects/l3m_excavator_altar_lit.png")
	_swap_art(_excavator_core, "res://assets/objects/l3m_excavator_core_lit.png")


# ==== 잔류 태엽 발전기 E (idempotent add_energy) ===========================

## 잔류 태엽 발전기(mine_residual_dynamo) 근접 시 에너지 Whisper 1회 재획득(보유 보장만, 중복 파밍
## 불가). 게이트 아님 — GM1→GM2 회랑에 놓여 최심부로 오르는 도중 반드시 지난다(§A-6.3). EX-L2
## 잔류 전력 노드 idempotent 패턴 계승.
func _spawn_power_residue() -> void:
	var node := _find_node("mine_residual_dynamo")
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


func _grant_energy(_source: Node) -> void:
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
			"…잔류 태엽 동력을, 다시 거둔다")


# ==== persisted-state reapply ==============================================

## Re-apply any opened / purified state on a restored / re-entered zone so reopened gates stay open
## and the purified end-state is shown without replaying the cutscene. 광산 정화 ⇒ 모든 게이트 개방
## (공간 순서 강제 = GM1→GM2→GM3→GM4).
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.mine_purified_flag:
		for cell in _gm1_cells:
			_loader.set_gate_cell_source(cell, true, _lit_of("GM1"), _dark_of("GM1"))
		_open_gm2(true)
		_gm3_solved = true
		_open_gm3_door(true)
		_apply_mine_endstate()


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


## Find a spawned l3m object node by its l2_id (loader stores them as "l2_id@cell").
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
	if _excavator_core != null and is_instance_valid(_excavator_core) and _excavator_core is Node2D:
		return (_excavator_core as Node2D).global_position
	if _excavator_altar != null and is_instance_valid(_excavator_altar) and _excavator_altar is Node2D:
		return (_excavator_altar as Node2D).global_position
	return _map_center()


func _map_center() -> Vector2:
	if _loader != null:
		return _loader.cell_center_world(Vector2i(int(_loader.width / 2), int(_loader.height / 2)))
	return Vector2.ZERO
