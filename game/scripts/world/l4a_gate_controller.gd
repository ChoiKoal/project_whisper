extends Node
class_name L4aGateController
## (EXL4-3) 부유 서고(l4a) 4-게이트를 이미-스폰된 맵/오브젝트 위에 얹는 단일 노드.
## l3m_gate_controller.gd 패턴 계승(placement/use/ordered-puzzle/chain-offering + 정화 컷신 +
## persisted-state reapply). §Part C: 신규 엔진 로직은 GW3 봉인 순서 술어 seal_ordered뿐(순서 강제
## = 데이터 정합, 아이템 id만 교체). 유니크 촉매 프레임 v1.1: P12 미소모(fusion.gd이 처리) — 게이트
## 컨트롤러는 D309 봉헌만 본다.
##
##   GW1 (배치/bridge): 부유 서가 다리석 D302 → 룬 제단 X 배치 → placed_object_placed → g 잔교 셀 walkable.
##   GW2 (사용): 열람 정화의 물 D304 → 흐려진 열람 결계 본체(reading_ward) 사용 → item_used_on_object →
##       v 셀 개방 + 아트 스왑(reading_ward_clear).
##   GW3 (배치 순서 퍼즐 seal_ordered_3): 봉인 서판 D305/D306/D307 → 3 z 슬롯에 순서대로(1→2→3) 배치.
##       순서가 맞을 때만 진행, 3장 순서 완성 시 금서고 통로문 L 개방 + seal_ordered 시그널.
##   GW4 (체인/봉헌): 금기 봉인구 D309 → 금서고 코어 봉헌 목(archive_core_altar) 봉헌 → 서고 정화 +
##       컷신 C-4 「마지막으로 한 번 더, 조용히」 + 마력 Whisper 1 소모(GW4 유일 sink) → archive_purified 플래그.
##   잔류 열람 결계정 W: idempotent add_mana(1) — GW1→GW2 회랑에 강제 배치, 게이트 아님(§A-6.3).
##
## 각 게이트 병목의 walkable/sealed source id는 legend gate 레코드의 lit_source/dark_source에서 읽는다
## (없으면 기본 4=자수정 바닥 / 0=허공). Defensive against missing autoloads/nodes. Idempotent:
## re-applies opened/purified state on load/re-entry (no cutscene replay).

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l4a legend `gates`). Empty on non-l4a maps → controller idle.
var _gates: Dictionary = {}
var _active: bool = false

## GW1 잔교 셀 / GW2 결계문 셀 / GW3 통로문 셀 + 서판 슬롯 / GW4 봉헌 목 셀.
var _gw1_cells: Array = []
var _gw2_cells: Array = []
var _gw3_door_cells: Array = []
var _gw3_slot_cells: Array = []
var _gw3_slots: Dictionary = {}   # Vector2i(slot) -> item_id placed ("D305"/"D306"/"D307")
var _gw3_order: Array = []        # placement order of DISTINCT tablets (for 1→2→3 enforcement)
var _gw3_solved: bool = false
var _gw4_cells: Array = []

## Cached art nodes.
var _reading_ward: Node = null
var _archive_altar: Node = null
var _archive_core: Node = null

## One-shot latches.
var _archive_purifying: bool = false
var _mana_given: bool = false

## Default open/sealed sources. 4 = 자수정/파편 바닥(walkable). 0 = 허공 T0(void, non-walkable).
const DEFAULT_LIT_SOURCE := 4
const DEFAULT_DARK_SOURCE := 0
const GLOW_TEX := "res://assets/objects/light_pool_violet.png"
const GOLD_TEX := "res://assets/objects/light_pool_gold.png"

## 봉인 순서 퍼즐 성공 시그널.
signal seal_ordered()


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
	# Only drive the archive (l4a has GW* gates; other maps use GA*/GB*/GH*/GM*/G*).
	if not (_gates.has("GW1") or _gates.has("GW4")):
		return
	_active = true
	_wire_cells()
	_seal_closed_gates()
	_wire_art()
	_spawn_mana_residue()
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.placed_object_placed.is_connected(_on_placed):
			GameState.placed_object_placed.connect(_on_placed)
	_reapply_persisted_state()


# ==== wiring ================================================================

func _wire_cells() -> void:
	_gw1_cells = _cells_of(_gates.get("GW1", {}).get("cells", []))
	_gw2_cells = _cells_of(_gates.get("GW2", {}).get("cells", []))
	var gw3: Dictionary = _gates.get("GW3", {})
	_gw3_door_cells = _cells_of(gw3.get("cells", []))
	_gw3_slot_cells = _cells_of(gw3.get("slot_cells", []))
	_gw4_cells = _cells_of(_gates.get("GW4", {}).get("cells", []))


func _lit_of(gate: String) -> int:
	return int(_gates.get(gate, {}).get("lit_source", DEFAULT_LIT_SOURCE))


func _dark_of(gate: String) -> int:
	return int(_gates.get(gate, {}).get("dark_source", DEFAULT_DARK_SOURCE))


## Seal the g(GW1 잔교) / v(GW2 결계문) / L(GW3 통로문) bottlenecks non-walkable on load. Their
## authored tile may already be void-sealed by the layout, but re-seal defensively so l4x_bfs.py's
## "every closed gate cell is a wall" invariant holds. GW4's H 봉헌 목 is an offering point (not a
## void bottleneck) at the top, reachable once GW3 opens — it is NOT tile-sealed here.
func _seal_closed_gates() -> void:
	for cell in _gw1_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GW1"), _dark_of("GW1"))
	for cell in _gw2_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GW2"), _dark_of("GW2"))
	for cell in _gw3_door_cells:
		_loader.set_gate_cell_source(cell, false, _lit_of("GW3"), _dark_of("GW3"))


func _wire_art() -> void:
	_reading_ward = _find_node("reading_ward")
	_archive_altar = _find_node("archive_core_altar")
	_archive_core = _find_node("archive_core")


# ==== placement (GW1 bridge + GW3 봉인 순서 미니 퍼즐) ======================

func _on_placed(item_id: String, cell: Vector2i) -> void:
	if not _active:
		return
	if item_id == "D302":
		_try_gw1_place(cell)
	elif item_id == "D305" or item_id == "D306" or item_id == "D307":
		_try_gw3_place(item_id, cell)


## GW1: 다리석 D302가 룬 제단 X(altar) 또는 잔교 g 인접에 배치되면 → 잔교 g 셀 전부 walkable(허공에
## 룬 다리가 걸친다). 제단 좌표는 legend gate GW1.altar.
func _try_gw1_place(cell: Vector2i) -> void:
	var altar := _gates.get("GW1", {}).get("altar", [])
	var altar_cell := Vector2i(-9999, -9999)
	if altar is Array and altar.size() >= 2:
		altar_cell = Vector2i(int(altar[0]), int(altar[1]))
	# Accept placement on the altar cell, adjacent to it, or directly on a bridge slot.
	var ok := (cell in _gw1_cells)
	if not ok and altar_cell.x != -9999:
		ok = Vector2(cell).distance_to(Vector2(altar_cell)) <= 2.5
	if not ok:
		return
	for c in _gw1_cells:
		_loader.set_gate_cell_source(c, true, _lit_of("GW1"), _dark_of("GW1"))
		_add_glow(c, GLOW_TEX, 0.5)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")


## GW3: 봉인 서판이 z 슬롯에 배치 → 기록. 순서 강제(1→2→3 = D305→D306→D307): 잘못된 순서면 무효화
## (재배치 요구). 셋이 순서대로 완성되면 통로문 L 개방 + seal_ordered.
func _try_gw3_place(item_id: String, cell: Vector2i) -> void:
	var slot := _nearest_slot(cell)
	if slot == Vector2i(-9999, -9999):
		return
	_gw3_slots[slot] = item_id
	# Track distinct-tablet placement order for the ordered-seal check.
	if not (_gw3_order.has(item_id)):
		_gw3_order.append(item_id)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")
	_check_gw3_solved()


func _nearest_slot(cell: Vector2i) -> Vector2i:
	if cell in _gw3_slot_cells:
		return cell
	var best := Vector2i(-9999, -9999)
	var best_d := 2.5
	for s in _gw3_slot_cells:
		var d: float = Vector2(s).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = s
	return best


## Solved iff the 3 slots hold all three tablets placed in the correct order D305→D306→D307.
## 순서가 어긋나면(예: D306 먼저) 아직 미해결로 두어 재배치를 요구한다.
func _check_gw3_solved() -> void:
	if _gw3_solved:
		return
	var placed := {}
	for s in _gw3_slots.keys():
		placed[_gw3_slots[s]] = true
	if not (placed.has("D305") and placed.has("D306") and placed.has("D307")):
		return
	# All three present — enforce the 1→2→3 ordering via the distinct-placement order.
	if _gw3_order.size() >= 3 and _gw3_order[0] == "D305" and _gw3_order[1] == "D306" and _gw3_order[2] == "D307":
		_gw3_solved = true
		_open_gw3_door()
		seal_ordered.emit()


func _open_gw3_door(instant: bool = false) -> void:
	for cell in _gw3_door_cells:
		_loader.set_gate_cell_source(cell, true, _lit_of("GW3"), _dark_of("GW3"))
		if not instant:
			_add_glow(cell, GLOW_TEX, 0.6)
	if not instant and AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_open")


# ==== use / offering (GW2, GW4) ============================================

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
		"reading_ward":
			if item == "D304":
				_open_gw2()
		"archive_core_altar":
			if item == "D309":
				_offer_archive()


## GW2: 흐려진 열람 결계 정화 → v 셀 개방 + 아트 스왑(reading_ward_clear).
func _open_gw2(instant: bool = false) -> void:
	for cell in _gw2_cells:
		_loader.set_gate_cell_source(cell, true, _lit_of("GW2"), _dark_of("GW2"))
	_swap_art(_reading_ward, "res://assets/objects/l4a_reading_ward_clear.png")
	if not instant:
		_add_glow(_gw2_cells[0] if not _gw2_cells.is_empty() else _loader.spawn_cell, GLOW_TEX, 0.7)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_open")


# ==== GW4: 서고 정화 + 컷신 C-4 「마지막으로 한 번 더, 조용히」 ==============

func _offer_archive(instant: bool = false) -> void:
	if _archive_purifying or (GameState != null and GameState.archive_purified_flag):
		_apply_archive_endstate()
		return
	# 마력 Whisper 1 소모(GW4 유일 sink). 부족하면 봉헌 불가(재획득처 W에서 add_mana 후 재시도).
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("spend_mana"):
		if not WhisperCurrency.spend_mana(1):
			if _loader != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
				var fb0 := _loader.get_node_or_null(_loader.ysort_layer_path)
				if fb0 != null:
					FloatingLabel.spawn(fb0, _player.global_position - Vector2(0, 96),
						"…마력이 모자라. 결계정으로 돌아가.")
			return
	_archive_purifying = true
	_swap_art(_archive_altar, "res://assets/objects/l4a_seal_altar_lit.png")
	_swap_art(_archive_core, "res://assets/objects/l4a_archive_core_lit.png")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_archive()
		return
	_run_archive_cutscene()


## Cutscene C-4 — control_lock/time_running pairing + ESC skip (v1.3.0 QA). 모달 CanvasLayer.
var _cs_layer: CanvasLayer = null
var _cs_line: Label = null
var _cs_dim: ColorRect = null
var _cs_skip := false
var _cs_running := false

const C4_CARDS := [
	"명멸하던 금서고 코어가… 금빛으로, 한 번 조용히 감긴다.",
	"찢겨 떠돌던 서가들이 제자리를 찾고, 금기의 한 줄이 마지막으로 봉인된다.",
	"…다 읽었어. 더 알 것도, 더 펼칠 것도 없어. 힘의 극한은 결국, 조용히 덮는 법을 배우는 일이었어. 너는… 이걸 알고도, 여기 남지 마.",
	"영원히 펼쳐 둘 금서는 없었다. 마지막 장에서, 봉인을 다시 여미고서야 알았다.",
]


func _run_archive_cutscene() -> void:
	_cs_running = true
	_cs_skip = false
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	_build_cs_layer()
	# 금빛 봉인 파문 1회 (마탑 최심부 재봉인 수미상관).
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
	_finish_archive()


func _build_cs_layer() -> void:
	_cs_layer = CanvasLayer.new()
	_cs_layer.layer = 11
	add_child(_cs_layer)
	_cs_dim = ColorRect.new()
	_cs_dim.color = Color(0.06, 0.04, 0.09, 0.0)
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
	_cs_line.add_theme_color_override("font_color", Color("#f2e6ff"))
	_cs_line.add_theme_font_size_override("font_size", 28)
	_cs_line.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.09, 0.9))
	_cs_line.add_theme_constant_override("outline_size", 5)
	_cs_line.modulate.a = 0.0
	center.add_child(_cs_line)
	var hint := Label.new()
	hint.text = "ESC 건너뛰기"
	hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.9, 0.5))
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


func _finish_archive() -> void:
	if not _archive_purifying and GameState != null and GameState.archive_purified_flag:
		return  # already finished (double-guard)
	_archive_purifying = false
	_cs_running = false
	if is_instance_valid(_cs_layer):
		_cs_layer.queue_free()
	_cs_layer = null
	if GameState != null:
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)
		GameState.time_running = true
		GameState.archive_purified_flag = true
		GameState.archive_purified.emit("archive")
	_apply_archive_endstate()


func _apply_archive_endstate() -> void:
	_swap_art(_archive_altar, "res://assets/objects/l4a_seal_altar_lit.png")
	_swap_art(_archive_core, "res://assets/objects/l4a_archive_core_lit.png")


# ==== 잔류 열람 결계정 W (idempotent add_mana) ============================

## 잔류 열람 결계정(archive_residual_ward) 근접 시 마력 Whisper 1회 재획득(보유 보장만, 중복 파밍
## 불가). 게이트 아님 — GW1→GW2 회랑 유일 경로에 놓여 최심부로 오르는 도중 반드시 지난다(§A-6.3).
## GW4 봉인구 봉헌(마력 1 소모)의 소진 세이브 안전망.
func _spawn_mana_residue() -> void:
	var node := _find_node("archive_residual_ward")
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
			_grant_mana(node))


func _grant_mana(_source: Node) -> void:
	if _mana_given:
		return
	_mana_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_mana"):
		WhisperCurrency.add_mana(1)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gather")
	var fb := _loader.get_node_or_null(_loader.ysort_layer_path)
	if fb != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
		FloatingLabel.spawn(fb, _player.global_position - Vector2(0, 96),
			"…잔류 열람 마력을, 다시 거둔다")


# ==== persisted-state reapply ==============================================

## Re-apply any opened / purified state on a restored / re-entered zone so reopened gates stay open
## and the purified end-state is shown without replaying the cutscene. 서고 정화 ⇒ 모든 게이트 개방
## (공간 순서 강제 = GW1→GW2→GW3→GW4).
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.archive_purified_flag:
		for cell in _gw1_cells:
			_loader.set_gate_cell_source(cell, true, _lit_of("GW1"), _dark_of("GW1"))
		_open_gw2(true)
		_gw3_solved = true
		_open_gw3_door(true)
		_apply_archive_endstate()


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


## Find a spawned l4a object node by its l2_id (loader stores them as "l2_id@cell").
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
	if _archive_core != null and is_instance_valid(_archive_core) and _archive_core is Node2D:
		return (_archive_core as Node2D).global_position
	if _archive_altar != null and is_instance_valid(_archive_altar) and _archive_altar is Node2D:
		return (_archive_altar as Node2D).global_position
	return _map_center()


func _map_center() -> Vector2:
	if _loader != null:
		return _loader.cell_center_world(Vector2i(int(_loader.width / 2), int(_loader.height / 2)))
	return Vector2.ZERO
