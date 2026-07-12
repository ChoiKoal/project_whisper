extends Node
class_name L5bGateController
## (EXL5-3) 침묵의 종탑(l5b) 4-게이트를 이미-스폰된 맵/오브젝트 위에 얹는 단일 노드.
## l4a_gate_controller.gd 패턴 계승(placement/use/ordered-puzzle/chain-offering + 정화 컷신 +
## persisted-state reapply). §Part C: 신규 엔진 로직은 GB3 타종 울림 순서 술어 chime_ordered뿐(순서
## 강제 = 데이터 정합, 아이템 id만 교체). 유니크 촉매 프레임 v1.1: S12 미소모(fusion.gd이 처리) —
## 게이트 컨트롤러는 D332 봉헌만 본다.
##
##   GB1 (배치/bridge): 종석 잔교 D325 → 종석 제단 X 배치 → placed_object_placed → g 잔교 셀 walkable.
##   GB2 (사용): 정음의 물 D327 → 흐려진 종음 결계 본체(chime_ward) 사용 → item_used_on_object →
##       e 셀 개방 + 아트 스왑(chime_ward_clear).
##   GB3 (배치 순서 퍼즐 chime_ordered_3): 울림 종 D328/D329/D330 → 3 y 슬롯에 순서대로(1→2→3) 배치.
##       순서가 맞을 때만 진행, 3종 순서 완성 시 종탑 상층문 L 개방 + chime_ordered 시그널.
##   GB4 (체인/봉헌): 응답의 타종구 D332 → 큰 종 봉헌 목(great_bell_altar) 봉헌 → 종탑 정화(재타종) +
##       컷신 C-4 「마지막으로 한 번, 세계 전체가 듣도록」 + 3속성 Whisper(에너지·마력·생명) 각1 소모
##       (GB4 유일 sink) → belfry_purified 플래그.
##   잔향 성수반 F: idempotent add_vita(1) — GB1→GB2 회랑에 강제 배치, 게이트 아님(§A-6.3).
##
## 각 게이트 병목의 walkable/sealed source id는 legend gate 레코드의 lit_source/dark_source에서 읽는다
## (없으면 기본 5=상아 바닥 / 31=봉인석). Defensive against missing autoloads/nodes. Idempotent:
## re-applies opened/purified state on load/re-entry (no cutscene replay).

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l5b legend `gates`). Empty on non-l5b maps → controller idle.
var _gates: Dictionary = {}
var _active: bool = false

## GB1 잔교 셀 / GB2 결계문 셀 / GB3 상층문 셀 + 종 슬롯 / GB4 봉헌 목 셀.
var _gb1_cells: Array = []
var _gb2_cells: Array = []
var _gb3_door_cells: Array = []
var _gb3_slot_cells: Array = []
var _gb3_slots: Dictionary = {}   # Vector2i(slot) -> item_id placed ("D328"/"D329"/"D330")
var _gb3_order: Array = []        # 타종(배치) 순서 of DISTINCT bells (for 1→2→3 = 저→중→고)
var _gb3_solved: bool = false
var _gb4_cells: Array = []

## Cached art nodes.
var _chime_ward: Node = null
var _bell_altar: Node = null
var _great_bell: Node = null

## One-shot latches.
var _belfry_purifying: bool = false
var _vita_given: bool = false

## Default open/sealed sources. 5 = 상아/백은 바닥(walkable, l5b floor). 31 = 봉인석(non-walkable seal).
## NB: source 0(허공 T0)은 tileset custom-data상 walkable=true라 seal에 부적합 — 반드시 진짜
## non-walkable source(31)로 닫아야 is_cell_walkable=false가 성립한다.
const DEFAULT_LIT_SOURCE := 5
const DEFAULT_DARK_SOURCE := 31
const GLOW_TEX := "res://assets/objects/light_pool_gold.png"

## 타종 울림 순서 퍼즐 성공 시그널.
signal chime_ordered()


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
	if _gates.is_empty():
		return
	# Only drive the belfry (l5b has GB* gates; other maps use GA*/GW*/GH*/GM*/G*).
	if not (_gates.has("GB1") or _gates.has("GB4")):
		return
	_active = true
	_wire_cells()
	_seal_closed_gates()
	_wire_art()
	_spawn_vita_residue()
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.placed_object_placed.is_connected(_on_placed):
			GameState.placed_object_placed.connect(_on_placed)
	_reapply_persisted_state()


# ==== wiring ================================================================

func _wire_cells() -> void:
	_gb1_cells = _cells_of(_gates.get("GB1", {}).get("cells", []))
	_gb2_cells = _cells_of(_gates.get("GB2", {}).get("cells", []))
	var gb3: Dictionary = _gates.get("GB3", {})
	_gb3_door_cells = _cells_of(gb3.get("cells", []))
	_gb3_slot_cells = _cells_of(gb3.get("slot_cells", []))
	_gb4_cells = _cells_of(_gates.get("GB4", {}).get("cells", []))


func _lit_of(gate: String) -> int:
	return int(_gates.get(gate, {}).get("lit_source", DEFAULT_LIT_SOURCE))


func _dark_of(gate: String) -> int:
	return int(_gates.get(gate, {}).get("dark_source", DEFAULT_DARK_SOURCE))


## Seal the g(GB1 잔교) / e(GB2 결계문) / L(GB3 상층문) bottlenecks non-walkable on load. Their
## authored tile may already be void-sealed by the layout, but re-seal defensively so l5x_bfs.py's
## "every closed gate cell is a wall" invariant holds. GB4's H 봉헌 목 is an offering point (not a
## void bottleneck) at the summit, reachable once GB3 opens — it is NOT tile-sealed here.
func _seal_closed_gates() -> void:
	for cell in _gb1_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GB1"), _dark_of("GB1"))
	for cell in _gb2_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GB2"), _dark_of("GB2"))
	for cell in _gb3_door_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GB3"), _dark_of("GB3"))


func _wire_art() -> void:
	_chime_ward = _find_node("chime_ward")
	_bell_altar = _find_node("great_bell_altar")
	_great_bell = _find_node("great_bell")


# ==== placement (GB1 bridge + GB3 타종 울림 순서 미니 퍼즐) ==================

func _on_placed(item_id: String, cell: Vector2i) -> void:
	if not _active:
		return
	if item_id == "D325":
		_try_gb1_place(cell)
	elif item_id == "D328" or item_id == "D329" or item_id == "D330":
		_try_gb3_place(item_id, cell)


## GB1: 종석 잔교 D325가 종석 제단 X(altar) 또는 잔교 g 인접에 배치되면 → 잔교 g 셀 전부 walkable(허공에
## 청동 종석 잔교가 걸린다). 제단 좌표는 legend gate GB1.altar.
func _try_gb1_place(cell: Vector2i) -> void:
	var altar: Variant = _gates.get("GB1", {}).get("altar", [])
	var altar_cell := Vector2i(-9999, -9999)
	if altar is Array and altar.size() >= 2:
		altar_cell = Vector2i(int(altar[0]), int(altar[1]))
	# Accept placement on the altar cell, adjacent to it, or directly on a bridge slot.
	var ok := (cell in _gb1_cells)
	if not ok and altar_cell.x != -9999:
		ok = Vector2(cell).distance_to(Vector2(altar_cell)) <= 2.5
	if not ok:
		return
	for c in _gb1_cells:
		_loader.set_gate_cell_source(c, true, _lit_of("GB1"), _dark_of("GB1"))
		_add_glow(c, GLOW_TEX, 0.5)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")


## GB3: 울림 종이 y 슬롯에 배치(타종) → 기록. 순서 강제(1→2→3 = D328→D329→D330 = 저→중→고): 잘못된
## 순서면 무효화(재배치 요구). 셋이 순서대로 완성되면 종탑 상층문 L 개방 + chime_ordered.
func _try_gb3_place(item_id: String, cell: Vector2i) -> void:
	var slot := _nearest_slot(cell)
	if slot == Vector2i(-9999, -9999):
		return
	_gb3_slots[slot] = item_id
	# Track chime(placement) order for the ordered-chime check. 재배치 허용(실수 복구, 설계 §GB3):
	# 이미 울린 종을 다시 울리면 그 종을 순서열 맨 뒤로 옮겨 최신 타종 의도를 반영한다 —
	# 잘못된 첫 시도도 정순으로 다시 울리면 복구된다(잘못된 순서면 공명 미완).
	_gb3_order.erase(item_id)
	_gb3_order.append(item_id)
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


## Solved iff the 3 slots hold all three bells rung in the correct order D328→D329→D330 (저→중→고).
## 순서가 어긋나면(예: D329 먼저) 아직 미해결로 두어 재타종을 요구한다.
func _check_gb3_solved() -> void:
	if _gb3_solved:
		return
	var placed := {}
	for s in _gb3_slots.keys():
		placed[_gb3_slots[s]] = true
	if not (placed.has("D328") and placed.has("D329") and placed.has("D330")):
		return
	# All three present — enforce the 1→2→3 ordering via the distinct-chime order.
	if _gb3_order.size() >= 3 and _gb3_order[0] == "D328" and _gb3_order[1] == "D329" and _gb3_order[2] == "D330":
		_gb3_solved = true
		_open_gb3_door()
		chime_ordered.emit()


func _open_gb3_door(instant: bool = false) -> void:
	for cell in _gb3_door_cells:
		_loader.set_gate_cell_source(cell, true, _lit_of("GB3"), _dark_of("GB3"))
		if not instant:
			_add_glow(cell, GLOW_TEX, 0.6)
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
		"chime_ward":
			if item == "D327":
				_open_gb2()
		"great_bell_altar":
			if item == "D332":
				_offer_belfry()


## GB2: 흐려진 종음 결계 정화 → e 셀 개방 + 아트 스왑(chime_ward_clear).
func _open_gb2(instant: bool = false) -> void:
	for cell in _gb2_cells:
		_loader.set_gate_cell_source(cell, true, _lit_of("GB2"), _dark_of("GB2"))
	_swap_art(_chime_ward, "res://assets/objects/l5b_chime_ward_clear.png")
	if not instant:
		_add_glow(_gb2_cells[0] if not _gb2_cells.is_empty() else _loader.spawn_cell, GLOW_TEX, 0.7)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_open")


# ==== GB4: 종탑 정화(재타종) + 컷신 C-4 「마지막으로 한 번, 세계 전체가 듣도록」 ============

func _offer_belfry(instant: bool = false) -> void:
	if _belfry_purifying or (GameState != null and GameState.get("belfry_purified_flag") == true):
		_apply_belfry_endstate()
		return
	# 3속성 Whisper(에너지·마력·생명) 각1 소모(GB4 유일 sink). 부족하면 봉헌 불가(F에서 add_vita 후 재시도).
	# 세 속삭임 전부를 종에 실어 세계에 보내는 응답 — atomic: 셋 다 있어야만 소비한다.
	if typeof(WhisperCurrency) != TYPE_NIL:
		var have_e: bool = not WhisperCurrency.has_method("has_energy") or WhisperCurrency.has_energy(1)
		var have_m: bool = not WhisperCurrency.has_method("has_mana") or WhisperCurrency.has_mana(1)
		var have_v: bool = not WhisperCurrency.has_method("has_vita") or WhisperCurrency.has_vita(1)
		if not (have_e and have_m and have_v):
			_whisper_short_feedback()
			return
		if WhisperCurrency.has_method("spend_energy"):
			WhisperCurrency.spend_energy(1)
		if WhisperCurrency.has_method("spend_mana"):
			WhisperCurrency.spend_mana(1)
		if WhisperCurrency.has_method("spend_vita"):
			WhisperCurrency.spend_vita(1)
	_belfry_purifying = true
	_swap_art(_bell_altar, "res://assets/objects/l5b_bell_altar_lit.png")
	_swap_art(_great_bell, "res://assets/objects/l5b_great_bell_lit.png")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_belfry()
		return
	_run_belfry_cutscene()


func _whisper_short_feedback() -> void:
	if _loader != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
		var fb0 := _loader.get_node_or_null(_loader.ysort_layer_path)
		if fb0 != null:
			FloatingLabel.spawn(fb0, _player.global_position - Vector2(0, 96),
				"…세 속삭임이 모자라. 잔향 성수반으로 돌아가.")


## Cutscene C-4 — control_lock/time_running pairing + ESC skip (v1.3.0 QA). 모달 CanvasLayer.
var _cs_layer: CanvasLayer = null
var _cs_line: Label = null
var _cs_dim: ColorRect = null
var _cs_skip := false
var _cs_running := false

const C4_CARDS := [
	"…완전한 침묵. 종탑 정점의 큰 종만이, 호박빛 잔불로 희미하게 떤다.",
	"방랑자가 응답의 타종구를 바치고, 세 속삭임을 종에 불어넣는다. 오래 침묵하던 큰 종이 마지막으로, 깊고 크게 울린다.",
	"…들려. 종이 다시 울려. 신은 마지막으로 물었어 — '아직 거기 있니'라고. 방금, 네가 대답했어. 종으로. 가장 큰 소리로.",
	"첫 소리가 침묵의 세계로 돌아온다. 잔향이 종탑 너머로 퍼져, 다섯 세계가 그 응답을 듣는다.",
]


func _run_belfry_cutscene() -> void:
	_cs_running = true
	_cs_skip = false
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	_build_cs_layer()
	# 호박빛 타종 파문 1회 (침묵→공명 = 각성, 대성당 "응답"의 컬미네이션).
	_purify_flash_ring(Color(1.0, 0.84, 0.4), _core_pos())
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
		if not _cs_skip:
			_purify_flash_ring(Color(1.0, 0.8, 0.35, 1.0), _core_pos())
			await _cs_wait(0.3)
	_finish_belfry()


func _build_cs_layer() -> void:
	_cs_layer = CanvasLayer.new()
	_cs_layer.layer = 11
	add_child(_cs_layer)
	_cs_dim = ColorRect.new()
	_cs_dim.color = Color(0.06, 0.05, 0.03, 0.0)
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
	_cs_line.add_theme_color_override("font_color", Color("#fff2d9"))
	_cs_line.add_theme_font_size_override("font_size", 28)
	_cs_line.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 0.9))
	_cs_line.add_theme_constant_override("outline_size", 5)
	_cs_line.modulate.a = 0.0
	center.add_child(_cs_line)
	var hint := Label.new()
	hint.text = "ESC 건너뛰기"
	hint.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 0.5))
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


func _finish_belfry() -> void:
	if not _belfry_purifying and GameState != null and GameState.get("belfry_purified_flag") == true:
		return  # already finished (double-guard)
	_belfry_purifying = false
	_cs_running = false
	if is_instance_valid(_cs_layer):
		_cs_layer.queue_free()
	_cs_layer = null
	if GameState != null:
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)
		GameState.time_running = true
		GameState.set("belfry_purified_flag", true)
		if GameState.has_signal("belfry_purified"):
			GameState.belfry_purified.emit("belfry")
	_apply_belfry_endstate()


func _apply_belfry_endstate() -> void:
	_swap_art(_bell_altar, "res://assets/objects/l5b_bell_altar_lit.png")
	_swap_art(_great_bell, "res://assets/objects/l5b_great_bell_lit.png")


# ==== 잔향 성수반 F (idempotent add_vita) =================================

## 잔향 성수반(belfry_residual_font) 근접 시 생명 Whisper 1회 재획득(보유 보장만, 중복 파밍 불가).
## 게이트 아님 — GB1→GB2 회랑 유일 경로에 놓여 정점으로 오르는 도중 반드시 지난다(§A-6.3). GB4
## 재타종(3속성 소비)의 소진 세이브 안전망.
func _spawn_vita_residue() -> void:
	var node := _find_node("belfry_residual_font")
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
			_grant_vita(node))


func _grant_vita(_source: Node) -> void:
	if _vita_given:
		return
	_vita_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_vita"):
		WhisperCurrency.add_vita(1)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gather")
	var fb := _loader.get_node_or_null(_loader.ysort_layer_path)
	if fb != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
		FloatingLabel.spawn(fb, _player.global_position - Vector2(0, 96),
			"…잔향에 잠긴 생명을, 다시 거둔다")


# ==== persisted-state reapply ==============================================

## Re-apply any opened / purified state on a restored / re-entered zone so reopened gates stay open
## and the purified end-state is shown without replaying the cutscene. 종탑 정화 ⇒ 모든 게이트 개방
## (공간 순서 강제 = GB1→GB2→GB3→GB4).
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.get("belfry_purified_flag") == true:
		for cell in _gb1_cells:
			_loader.set_gate_cell_source(cell, true, _lit_of("GB1"), _dark_of("GB1"))
		_open_gb2(true)
		_gb3_solved = true
		_open_gb3_door(true)
		_apply_belfry_endstate()


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


## Find a spawned l5b object node by its l2_id (loader stores them as "l2_id@cell").
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
	if _great_bell != null and is_instance_valid(_great_bell) and _great_bell is Node2D:
		return (_great_bell as Node2D).global_position
	if _bell_altar != null and is_instance_valid(_bell_altar) and _bell_altar is Node2D:
		return (_bell_altar as Node2D).global_position
	return _map_center()


func _map_center() -> Vector2:
	if _loader != null:
		return _loader.cell_center_world(Vector2i(int(_loader.width / 2), int(_loader.height / 2)))
	return Vector2.ZERO
