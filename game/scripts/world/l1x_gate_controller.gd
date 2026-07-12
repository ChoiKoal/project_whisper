extends Node
class_name L1xGateController
## (EXL1-3) The single node that wires the L1 확장 두 SUB-zone 게이트를 이미-스폰된 맵/오브젝트 위에
## 얹는다. Layer-agnostic: it reads legend_gates() and branches by gate id, so ONE controller drives
## BOTH 「고요의 화원」(l1g: GA1→GA2→GA3→GA4) and 「생명의 심장」(l1h: GH1→GH2). Clones the
## l2_gate_controller.gd pattern (stepping/use/held/chain + purification cutscene + persisted-state
## reapply). §Part C: 신규 엔진 로직은 GA3 색맞춤 술어뿐 — 나머지는 기존 시그널 재사용.
##
##   GA1 (배치/stepping): 꽃돌다리 D223 → 색의 여울 K 배치 → placed_object_placed → K 셀 walkable.
##   GA2 (사용): 개화의 물감 D225 → 시든 아치(wilted_arch) 사용 → item_used_on_object → A 셀 개방 + 아트 스왑.
##   GA3 (배치 미니 퍼즐 color_bed_3): 3색 물감 D226/D227/D228 → 3 x 슬롯 배치(순서 무관·재배치) → 3색
##       모두 채워지면 색의 문 M 개방 + color_bed_solved-style 시그널.
##   GA4 (체인/봉헌): 색의 정수 D230 → 무지개 분수(rainbow_font) 봉헌 → 화원 정화(빛-플래시/리플, 대사 無)
##       → garden_purified 플래그 + 시그널.
##   GH1 (사용): 소생의 수액 D232 → 뒤엉킨 뿌리문(root_gate) 사용 → item_used_on_object → L 셀 개방 + 아트 스왑.
##   GH2 (체인/정화): 되살아난 심장 D235 → 심장 봉인(heart_seal) 봉헌 → 심장 정화 + 컷신 C-4「다시 뛰는 심장」
##       (control_lock/time_running 페어링 + ESC 스킵) → heart_purified 플래그.
##   생명의 샘물 E: idempotent add_vita(1) — GH1→GH2 회랑에 강제 배치, 게이트 아님(§A-6.3).
##
## Defensive against missing autoloads/nodes (release templates strip assert()); every hook guards.
## Idempotent: re-applies opened/purified state on load/re-entry (no cutscene replay).

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l1g/l1h legend `gates`). Empty on non-l1x maps → controller idle.
var _gates: Dictionary = {}

## Which zone this instance drives: "garden" (l1g) | "heart" (l1h) | "" (idle). Inferred from gate ids.
var _zone: String = ""

## GA1 / GH1 gate cell lists (the bottleneck cells that flip walkable when opened).
var _ga1_cells: Array = []
var _gh1_cells: Array = []
## GA2 arch cells / GA3 door cells / GH2 seal-neck cells.
var _ga2_cells: Array = []
var _ga3_door_cells: Array = []
var _gh2_cells: Array = []
## GA3 color-bed slot cells (3) and the color currently placed on each (item id or "").
var _ga3_slot_cells: Array = []
var _ga3_slots: Dictionary = {}   # Vector2i(slot) -> item_id placed ("D226"/"D227"/"D228")
var _ga3_solved: bool = false

## Cached art nodes.
var _wilted_arch: Node = null
var _root_gate: Node = null
var _rainbow_font: Node = null
var _heart_seal: Node = null
var _tree_heart: Node = null

## One-shot latches.
var _garden_purifying: bool = false
var _heart_purifying: bool = false
var _life_spring_given: bool = false

## GA1 bridge lit source (walkable) / sealed (water) sources. K cells are T5A(8) water when sealed;
## opened they show T1 dirt (walkable) like the grove stepping stone. GH1 L cells are T2A(2) ground
## authored non-walkable; opened they become plain walkable T2A.
const BRIDGE_LIT_SOURCE := 1    # T1 dirt — walkable 꽃돌다리 deck
const WATER_SOURCE := 8         # T5A — sealed 색의 여울
const GROUND_SOURCE := 2        # T2A — walkable ground (GA2/GA3/GH1/GH2 open state)

## Signal parity with the L2 line: emitted the moment a color bed puzzle is solved.
signal color_bed_solved()


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# Wait a couple frames so the loader has finished spawning all l1x objects.
	await get_tree().process_frame
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader == null:
		return
	_gates = _loader.legend_gates()
	if _gates.is_empty():
		return
	# Infer the zone from which gate ids are present.
	if _gates.has("GA1") or _gates.has("GA4"):
		_zone = "garden"
	elif _gates.has("GH1") or _gates.has("GH2"):
		_zone = "heart"
	else:
		return
	_wire_cells()
	_wire_art()
	_wrap_use_targets()
	_spawn_life_spring()
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
	if _zone == "garden":
		_ga1_cells = _cells_of(_gates.get("GA1", {}).get("cells", []))
		_ga2_cells = _cells_of(_gates.get("GA2", {}).get("cells", []))
		var ga3: Dictionary = _gates.get("GA3", {})
		_ga3_door_cells = _cells_of(ga3.get("cells", []))
		_ga3_slot_cells = _cells_of(ga3.get("slot_cells", []))
	else:
		_gh1_cells = _cells_of(_gates.get("GH1", {}).get("cells", []))
		_gh2_cells = _cells_of(_gates.get("GH2", {}).get("cells", []))


func _wire_art() -> void:
	_wilted_arch = _find_node("wilted_arch")
	_rainbow_font = _find_node("rainbow_font")
	_heart_seal = _find_node("heart_seal")
	_tree_heart = _find_node("tree_heart")


## GA1/GH1 use-targets: the wilted_arch / rainbow_font / heart_seal objects are spawned by the loader
## as Gatherable/Sprite nodes carrying their l2_id as object_id (see _spawn_l2_object). The interaction
## framework routes a held item onto them via item_used_on_object — no wrapping needed for those. The
## ONE missing target is GH1's 뿌리문(root_gate): the L cells are plain tiles with no object. Spawn a
## use-target Gatherable on the L bottleneck so D232 can be used on it (mirrors the L2 breaker wrap).
func _wrap_use_targets() -> void:
	if _zone != "heart" or _gh1_cells.is_empty():
		return
	# Already have one?
	if _root_gate != null and is_instance_valid(_root_gate):
		return
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	# Anchor the root_gate on the SOUTH L cell (nearest to the approaching player).
	var anchor: Vector2i = _gh1_cells[0]
	for c in _gh1_cells:
		if c.y > anchor.y:
			anchor = c
	var g := Gatherable.new()
	g.item_id = ""            # use-only (can_gather()==false)
	g.object_id = "root_gate"
	g.offset = Vector2(0, -36)
	var tex := _tex_if_exists("res://assets/objects/root_gate.png")
	if tex != null:
		g.texture = tex
	g.blocks_movement = false  # the tile collision already seals it; art must not double-block
	ys.add_child(g)
	g.global_position = _loader.cell_center_world(anchor)
	if _loader.has_method("apply_height_lift"):
		_loader.apply_height_lift(g)
	_root_gate = g


# ==== placement (GA1 stepping + GA3 color bed) =============================

func _on_placed(item_id: String, cell: Vector2i) -> void:
	if _zone == "garden":
		if item_id == "D223":
			_try_ga1_place(cell)
		elif item_id == "D226" or item_id == "D227" or item_id == "D228":
			_try_ga3_place(item_id, cell)


## GA1: 꽃돌다리 placed on a 색의 여울 K cell → that cell becomes walkable (stepping-stone swap). If
## every K cell of the bottleneck is now bridged, GA1 is open.
func _try_ga1_place(cell: Vector2i) -> void:
	if not (cell in _ga1_cells):
		return
	_loader.set_gate_cell_source(cell, true, BRIDGE_LIT_SOURCE, WATER_SOURCE)
	_add_glow(cell, "res://assets/objects/light_pool_violet.png", 0.5)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")


## GA3: a color paint placed on one of the 3 화단 슬롯 → record it (re-placeable). When all three
## DISTINCT colors are present across the 3 slots, open the 색의 문 M.
func _try_ga3_place(item_id: String, cell: Vector2i) -> void:
	# Snap to the nearest slot cell (placement lands on the slot tile; be tolerant of adjacency).
	var slot := _nearest_slot(cell)
	if slot == Vector2i(-9999, -9999):
		return
	_ga3_slots[slot] = item_id
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("place")
	_check_ga3_solved()


func _nearest_slot(cell: Vector2i) -> Vector2i:
	# Exact slot?
	if cell in _ga3_slot_cells:
		return cell
	# Otherwise the closest slot within 1 cell (tolerate a place on the adjacent stand cell).
	var best := Vector2i(-9999, -9999)
	var best_d := 2.5
	for s in _ga3_slot_cells:
		var d: float = Vector2(s).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = s
	return best


## Solved iff the 3 slots collectively hold all three distinct colors (order-free).
func _check_ga3_solved() -> void:
	if _ga3_solved:
		return
	var colors := {}
	for s in _ga3_slots.keys():
		colors[_ga3_slots[s]] = true
	if colors.has("D226") and colors.has("D227") and colors.has("D228"):
		_ga3_solved = true
		_open_ga3_door()
		color_bed_solved.emit()


func _open_ga3_door(instant: bool = false) -> void:
	for cell in _ga3_door_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)
		if not instant:
			_add_glow(cell, "res://assets/objects/light_pool_violet.png", 0.6)
	if not instant and AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_open")


# ==== use / offering (GA2, GH1, GA4, GH2) ==================================

func _on_item_used(item: String, obj: Node) -> void:
	if obj == null:
		return
	var oid := ""
	if obj.has_method("get"):
		var v: Variant = obj.get("object_id")
		if typeof(v) == TYPE_STRING:
			oid = v
	if oid == "":
		oid = String(obj.get_meta("object_id", ""))
	match oid:
		"wilted_arch":
			if item == "D225":
				_open_ga2()
		"root_gate":
			if item == "D232":
				_open_gh1()
		"rainbow_font":
			if item == "D230":
				_offer_garden()
		"heart_seal":
			if item == "D235":
				_offer_heart()


## GA2: 시든 아치 개화 → A 셀 개방 + 아트 스왑(wilted_arch_open).
func _open_ga2(instant: bool = false) -> void:
	for cell in _ga2_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)
	_swap_art(_wilted_arch, "res://assets/objects/wilted_arch_open.png")
	if not instant:
		_add_glow(_ga2_cells[0] if not _ga2_cells.is_empty() else _loader.spawn_cell,
			"res://assets/objects/light_pool_violet.png", 0.7)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_open")


## GH1: 뒤엉킨 뿌리문 소생 → L 셀 개방 + 아트 스왑(root_gate_open).
func _open_gh1(instant: bool = false) -> void:
	for cell in _gh1_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)
	_swap_art(_root_gate, "res://assets/objects/root_gate_open.png")
	if not instant:
		_add_glow(_gh1_cells[0] if not _gh1_cells.is_empty() else _loader.spawn_cell,
			"res://assets/objects/light_pool_violet.png", 0.7)
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_open")


# ==== GA4: garden purification (색의 봉헌 — NO dialogue cutscene) ===========

func _offer_garden(instant: bool = false) -> void:
	if _garden_purifying or (GameState != null and GameState.garden_purified_flag):
		_apply_garden_endstate()
		return
	_garden_purifying = true
	_swap_art(_rainbow_font, "res://assets/objects/rainbow_font_lit.png")
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_garden()
		return
	_run_garden_purify()


## 색이 물결처럼 번지는 정화 — a light flash + expanding ripple set-piece (설계: 대사 컷신 불필요, 색 번짐만).
func _run_garden_purify() -> void:
	var origin := _font_pos()
	_purify_flash_ring(Color(1.0, 0.85, 0.55), origin)   # warm rainbow bloom
	# a short beat, then finish (no cards).
	await get_tree().create_timer(1.4, true, false, true).timeout
	_finish_garden()


func _finish_garden() -> void:
	_garden_purifying = false
	if GameState != null:
		GameState.garden_purified_flag = true
		GameState.garden_purified.emit("garden")


func _apply_garden_endstate() -> void:
	_swap_art(_rainbow_font, "res://assets/objects/rainbow_font_lit.png")


# ==== GH2: heart purification + cutscene C-4 「다시 뛰는 심장」 =============

func _offer_heart(instant: bool = false) -> void:
	if _heart_purifying or (GameState != null and GameState.heart_purified_flag):
		_apply_heart_endstate()
		return
	_heart_purifying = true
	_swap_art(_heart_seal, "res://assets/objects/heart_seal_open.png")
	# open the seal-neck cells so the deepest room is reachable after the beat.
	for cell in _gh2_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_heart()
		return
	_run_heart_cutscene()


## Cutscene C-4 — control_lock/time_running pairing + ESC skip (v1.3.0 QA). Clones ClearSequence's
## beat structure but as a modal CanvasLayer built here (so the l1x controller is self-contained).
var _cs_layer: CanvasLayer = null
var _cs_line: Label = null
var _cs_dim: ColorRect = null
var _cs_skip := false
var _cs_running := false

const C4_CARDS := [
	"멈춰 있던 심장이… 한 번, 크게 뛴다.",
	"뿌리를 따라, 생명수가 다시 흐르기 시작한다.",
	"…아, 이렇게 하는 거였구나. 나는, 꺼내기만 하고 돌려주는 걸 잊었어. 너는, 잊지 마.",
	"세계의 심장이, 다시 뛴다.",
]


func _run_heart_cutscene() -> void:
	_cs_running = true
	_cs_skip = false
	# Pair the locks (both restored in _finish_heart / skip).
	if GameState != null:
		GameState.time_running = false
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(true)
	_build_cs_layer()
	# 1. 저음 심장박동 1회 + 보라·초록 발광 파문 (오프닝 CS-01 수미상관).
	_purify_flash_ring(Color(0.62, 0.45, 0.85), _heart_pos())
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	await _cs_wait(0.6)
	# dim in.
	if is_instance_valid(_cs_dim):
		var dtw := _cs_layer.create_tween()
		dtw.tween_property(_cs_dim, "color:a", 0.55, 0.8)
	for card in C4_CARDS:
		if _cs_skip:
			break
		await _cs_card(card)
		# root glow flows S→N between cards (best-effort ripple).
		if not _cs_skip:
			_purify_flash_ring(Color(0.42, 0.72, 0.36, 1.0), _heart_pos())
			await _cs_wait(0.3)
	_finish_heart()


func _build_cs_layer() -> void:
	_cs_layer = CanvasLayer.new()
	_cs_layer.layer = 11
	add_child(_cs_layer)
	_cs_dim = ColorRect.new()
	_cs_dim.color = Color(0.10, 0.08, 0.13, 0.0)
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
	_cs_line.add_theme_color_override("font_color", Color("#faf5e6"))
	_cs_line.add_theme_font_size_override("font_size", 28)
	_cs_line.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
	_cs_line.add_theme_constant_override("outline_size", 5)
	_cs_line.modulate.a = 0.0
	center.add_child(_cs_line)
	# a faint "ESC 건너뛰기" hint.
	var hint := Label.new()
	hint.text = "ESC 건너뛰기"
	hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72, 0.5))
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


func _finish_heart() -> void:
	if not _heart_purifying and GameState != null and GameState.heart_purified_flag:
		return  # already finished (double-guard)
	_heart_purifying = false
	_cs_running = false
	# tear down the cutscene layer.
	if is_instance_valid(_cs_layer):
		_cs_layer.queue_free()
	_cs_layer = null
	# restore locks (paired).
	if GameState != null:
		if GameState.has_method("set_control_lock"):
			GameState.set_control_lock(false)
		GameState.time_running = true
		GameState.heart_purified_flag = true
		GameState.heart_purified.emit("heart")
	_apply_heart_endstate()


func _apply_heart_endstate() -> void:
	_swap_art(_heart_seal, "res://assets/objects/heart_seal_open.png")
	for cell in _gh2_cells:
		_loader.set_gate_cell_source(cell, true, GROUND_SOURCE, GROUND_SOURCE)


# ==== 생명의 샘물 E (idempotent add_vita) ==================================

## Wrap the 생명의 샘물 (heart_life_spring) object in an interaction that grants vita ONCE per save.
## Clones L5 발전 제단/마력 성물함 재획득처: idempotent (보유 보장만, 중복 파밍 불가). Not a gate — it
## sits on the GH1→GH2 corridor so the player necessarily passes it.
func _spawn_life_spring() -> void:
	if _zone != "heart":
		return
	var node := _find_node("heart_life_spring")
	if node == null or not is_instance_valid(node):
		return
	# The spring is a plain (non-gatherable) l1x object → give it a use/interact proxy. Reuse the
	# item_used_on_object path is overkill (needs a held item); instead poll adjacency in _process via
	# a tiny Area2D that fires the idempotent grant when the player is near. Simpler + robust: connect
	# to GameState.item_gathered? No — grant on proximity. Build a small Area2D.
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
		_loader.add_child(area)
		area.global_position = (node as Node2D).global_position if node is Node2D else Vector2.ZERO
	area.body_entered.connect(func(body):
		if _player != null and body == _player:
			_grant_life_spring(node))


func _grant_life_spring(source: Node) -> void:
	if _life_spring_given:
		return
	_life_spring_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_vita"):
		WhisperCurrency.add_vita(1)
	# swap to the lit spring art if present.
	if source is Sprite2D:
		var lit := _tex_if_exists("res://assets/objects/l5_life_spring_on.png")
		if lit != null:
			(source as Sprite2D).texture = lit
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gather")
	var fb := _loader.get_node_or_null(_loader.ysort_layer_path)
	if fb != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
		FloatingLabel.spawn(fb, _player.global_position - Vector2(0, 96),
			"…처음으로, 생명이 내 것이 되었다")


# ==== persisted-state reapply ==============================================

## Re-apply any opened / purified state on a restored / re-entered zone so reopened gates stay open
## and purified end-states are shown without replaying cutscenes.
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if _zone == "garden" and GameState.garden_purified_flag:
		# Garden purified ⇒ every garden gate is necessarily open (spatial order forced it).
		_open_all_garden_gates_instant()
		_apply_garden_endstate()
	elif _zone == "heart" and GameState.heart_purified_flag:
		_open_gh1(true)
		_apply_heart_endstate()


func _open_all_garden_gates_instant() -> void:
	for cell in _ga1_cells:
		_loader.set_gate_cell_source(cell, true, BRIDGE_LIT_SOURCE, WATER_SOURCE)
	_open_ga2(true)
	_ga3_solved = true
	_open_ga3_door(true)


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


## Find a spawned l1x object node by its l2_id (loader stores them as "l2_id@cell").
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


func _font_pos() -> Vector2:
	if _rainbow_font != null and is_instance_valid(_rainbow_font) and _rainbow_font is Node2D:
		return (_rainbow_font as Node2D).global_position
	return _map_center()


func _heart_pos() -> Vector2:
	if _tree_heart != null and is_instance_valid(_tree_heart) and _tree_heart is Node2D:
		return (_tree_heart as Node2D).global_position
	if _heart_seal != null and is_instance_valid(_heart_seal) and _heart_seal is Node2D:
		return (_heart_seal as Node2D).global_position
	return _map_center()


func _map_center() -> Vector2:
	if _loader != null:
		return _loader.cell_center_world(Vector2i(int(_loader.width / 2), int(_loader.height / 2)))
	return Vector2.ZERO
