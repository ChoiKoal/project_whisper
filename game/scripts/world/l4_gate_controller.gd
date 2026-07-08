extends Node
class_name L4GateController
## (L4-3) The single node that wires Layer-4's four gates onto the already-spawned mage_tower
## objects + map. It reuses the Layer-1/2/3 signal patterns wholesale (§C-3), with only node_id
## strings + key-item ids swapped — NO new gate systems. The one theme twist: L1~L3 정화 =
## "멈춘 것을 되살림", L4 정화 = "풀려난 것을 다시 봉인함" (§A-1).
##   G1 룬 다리   — 룬 다리석 D141 → 룬 제단(rune_altar, place_slot) 설치 →
##                  power_node_energized("rune_bridge") → 허공 잔교 g 셀 순차 walkable (빛의 다리 전개).
##   G2 결계 분수 — 정화의 물 D143 → 마력샘 E 사용(item_used_on_object) →
##                  밸브문 v 개방 + **마력 Whisper ×1 획득** (§보완, 필수, WhisperCurrency.add_mana).
##   G3 균열 통과 — 보호 부적 D145 소지 상태 폴링(L2 랜턴 held-item 패턴) → 균열 병목 L·균열 x walkable.
##                  장착·소모 아닌 소지 판정. (신규 조작 0.)
##   G4 최심부 봉인 — 최심부 봉인구 D148(whisper_cost.mana:1) → 봉인 코어 배전반(seal_mount) 설치 →
##                  power_node_energized("seal_core") → Layer 4 정화 컷신 → layer4_purified.
##
## §A-2 (byte-identical) carries NO X/K symbols, so this controller SPAWNS the rune_altar (G1) and
## seal_mount (G4) sprites at the gates-block altar/mount coords, wraps them + the E mana_spring in
## use-targets (Gatherable with object_id, no item) so the EXISTING _try_use_on_object framework
## routes the key item onto them. Idempotent on reload. Defensive against missing autoloads/nodes.

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l4_map_legend.json `gates`). Empty on non-L4 maps → controller idle.
var _gates: Dictionary = {}

const DARK_SOURCE := 31   # L4 sealed (dark, non-walkable) — matches legend g/v/L/H tiles.
const CRACK_SOURCE := 32  # L4 crack tile (x, non-walkable until warded).

## G1 rune-bridge cells (south→north light order) + altar use-target + altar node.
var _bridge_cells: Array = []
var _g1_lit_source := 28
var _altar_cell: Vector2i = Vector2i(-1, -1)
var _altar_node: Node2D = null
## G2 valve-door cells + spring node.
var _door_cells: Array = []
var _spring_node: Node = null
var _g2_lit_source := 28
## G3 crack bottleneck cells + scattered crack tiles + ward pillar.
var _crack_cells: Array = []
var _crack_tiles: Array = []   # scattered `x` cells discovered from the layout
var _g3_lit_source := 29
## G4 seal-neck cells + mount + core.
var _neck_cells: Array = []
var _g4_lit_source := 30
var _mount_cell: Vector2i = Vector2i(-1, -1)
var _mount_node: Node2D = null
var _core_node: Node = null

## Guard so the G2 마력 Whisper acquisition 연출 fires exactly once.
var _g2_reward_given: bool = false
## Held item that opens G3 (보호 부적).
const G3_CHARM := "D145"
## G3 held-item poll state (open = crack cells currently walkable).
var _g3_open: bool = false


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
	if _gates.is_empty() or not _gates.has("G4") or not _is_l4():
		return  # not a Layer-4 map
	_wire_gate_data()
	_spawn_mounts()
	_wire_use_targets()
	_discover_crack_tiles()
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.power_node_energized.is_connected(_on_power_node):
			GameState.power_node_energized.connect(_on_power_node)
	_reapply_persisted_state()
	# G3 held-charm poll runs every frame only while relevant (§C-3 허용, 값싼 소지 검사).
	set_process(true)


## Distinguish an L4 map from an L3 map (both have `gates`): L4's G1 node_id is rune_bridge.
func _is_l4() -> bool:
	var g1: Dictionary = _gates.get("G1", {})
	return String(g1.get("node_id", "")) == "rune_bridge"


# ==== gate data wiring =====================================================

func _wire_gate_data() -> void:
	var g1: Dictionary = _gates.get("G1", {})
	_bridge_cells = _cells_of(g1.get("bridge_cells", []))
	_bridge_cells.sort_custom(func(a, b): return a.y > b.y)   # south→north
	_g1_lit_source = int(g1.get("lit_source", 28))
	var altar: Array = _cells_of(g1.get("altar", []))
	if altar.size() > 0:
		_altar_cell = altar[0]

	var g2: Dictionary = _gates.get("G2", {})
	_door_cells = _cells_of(g2.get("door_cells", []))
	_g2_lit_source = int(g2.get("lit_source", 28))
	_spring_node = _find_node("mana_spring")

	var g3: Dictionary = _gates.get("G3", {})
	_crack_cells = _cells_of(g3.get("crack_cells", []))
	_g3_lit_source = int(g3.get("lit_source", 29))

	var g4: Dictionary = _gates.get("G4", {})
	_neck_cells = _cells_of(g4.get("neck_cells", []))
	_g4_lit_source = int(g4.get("lit_source", 30))
	_core_node = _find_node("seal_core")
	var mount: Array = _cells_of(g4.get("mount", []))
	if mount.size() > 0:
		_mount_cell = mount[0]


## §A-2 has no X/K symbol, so spawn the rune_altar (G1) + seal_mount (G4) sprites at the gate
## coords with an object_id, so the use-target wiring routes the key item onto them.
func _spawn_mounts() -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	if _altar_cell != Vector2i(-1, -1):
		_altar_node = _spawn_slot(ys, _altar_cell, "res://assets/objects/l4_rune_altar.png", Vector2(0, -34), "rune_altar")
	if _mount_cell != Vector2i(-1, -1):
		_mount_node = _spawn_slot(ys, _mount_cell, "res://assets/objects/l4_seal_mount.png", Vector2(0, -34), "seal_mount")


func _spawn_slot(ys: Node2D, cell: Vector2i, tex_path: String, off: Vector2, object_id: String) -> Node2D:
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


## Wrap the spawned altar / mount + the loader-spawned mana_spring in use-targets (a Gatherable
## child with object_id, no item) so the held key item routes onto them.
func _wire_use_targets() -> void:
	if _altar_node != null:
		_make_use_target(_altar_node, "rune_altar")
	if _mount_node != null:
		_make_use_target(_mount_node, "seal_mount")
	for key in _loader.l2_object_nodes.keys():
		var l4id := String(key).split("@")[0]
		var rec: Dictionary = _loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		if node == null or not is_instance_of(node, Sprite2D):
			continue
		if l4id == "mana_spring":
			_make_use_target(node as Sprite2D, "mana_spring")


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


## Find all scattered `x` crack tiles in the layout (source 32) so G3 warding lights them for flavor.
func _discover_crack_tiles() -> void:
	_crack_tiles.clear()
	for r in range(_loader.height):
		for c in range(_loader.width):
			if _loader.get_cell_source_id(Vector2i(c, r)) == CRACK_SOURCE:
				_crack_tiles.append(Vector2i(c, r))


# ==== key-item use → power node energize ===================================

func _on_item_used(item: String, obj: Node) -> void:
	if obj == null:
		return
	var oid := String(obj.get("object_id")) if obj.has_method("get") else ""
	match oid:
		"rune_altar":
			if item == "D141":
				_spark_at(obj)
				# (v1.1.0 GP-5 §3) G1 승격 = 룬 점등 순서 퍼즐 → 성공/스킵 모두 기존 개방.
				_puzzle_then_energize("rune", "rune_bridge")
		"mana_spring":
			if item == "D143":
				_spark_at(obj)
				_repurify_spring(obj)
		"seal_mount":
			if item == "D148":
				_spark_at(obj)
				GameState.energize_power_node("seal_core")


## (v1.1.0 GP-5 §3) 승격 게이트: 퍼즐 모달 → 성공/스킵 모두 기존 개방(진행 차단 아님). 씬 루트 없으면 直行.
func _puzzle_then_energize(puzzle_type: String, node_id: String) -> void:
	var root: Node = get_tree().current_scene if get_tree() != null else null
	var energize := func(): GameState.energize_power_node(node_id)
	if root == null or GatePuzzle.open(root, puzzle_type, energize, energize) == null:
		GameState.energize_power_node(node_id)


func _on_power_node(node_id: String) -> void:
	match node_id:
		"rune_bridge":
			_light_bridge()
		"seal_core":
			_start_purification()


# ==== G1: rune bridge (deck light) =========================================

## Sequentially open the rune-bridge deck cells (0.12s stagger) — reads as 금색 룬 다리가 허공에
## 펼쳐지는 연출. Reuses the walkable-swap + AStar rebuild (set_gate_cell_source).
func _light_bridge(instant: bool = false) -> void:
	if _bridge_cells.is_empty():
		return
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_swap_slot_art(_altar_node, "res://assets/objects/l4_rune_altar_on.png")
	var i := 0
	for cell in _bridge_cells:
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


# ==== G2: mana spring + ward door + mana Whisper (필수) =====================

func _repurify_spring(spring_obj: Node) -> void:
	GameState.energize_power_node("mana_spring")
	if spring_obj is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l4_mana_spring_on.png")
		if on_tex != null:
			(spring_obj as Sprite2D).texture = on_tex
		_add_running_glow(spring_obj as Node2D)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_open_door()
	_grant_mana_whisper(spring_obj)


func _open_door(instant: bool = false) -> void:
	for cell in _door_cells:
		_loader.set_gate_cell_source(cell, true, _g2_lit_source, DARK_SOURCE)
	# swap the ward-door node art to open.
	var door := _find_node("ward_door")
	if door != null and is_instance_valid(door):
		for ch in door.get_children():
			if ch is StaticBody2D:
				(ch as StaticBody2D).process_mode = Node.PROCESS_MODE_DISABLED
				var col := (ch as StaticBody2D).get_child(0)
				if col is CollisionShape2D:
					(col as CollisionShape2D).set_deferred("disabled", true)
		if door is Sprite2D:
			var open_tex := _tex_if_exists("res://assets/objects/l4_ward_door_open.png")
			if open_tex != null:
				(door as Sprite2D).texture = open_tex


## Grant the first 마력 Whisper (§보완 필수, L4에서 마력 Whisper 첫 등장). +1 mana → WhisperCurrency,
## 금색 빛줄기 연출 toward the player + 플로팅 텍스트, exactly once.
func _grant_mana_whisper(source: Node) -> void:
	if _g2_reward_given:
		return
	_g2_reward_given = true
	if typeof(WhisperCurrency) != TYPE_NIL and WhisperCurrency.has_method("add_mana"):
		WhisperCurrency.add_mana(1)
	var anchor: Vector2 = _player.global_position if _player != null else \
		(source.get("global_position") if source != null and source.has_method("get") else Vector2.ZERO)
	_spawn_mana_beam(source, anchor)
	var fb := _feedback_parent()
	if fb != null and typeof(FloatingLabel) != TYPE_NIL:
		FloatingLabel.spawn(fb, anchor - Vector2(0, 96), "…처음으로, 마력이 내 것이 되었다")


## A golden mana streak from the spring flowing into the player (마력줄기가 흘러듦).
func _spawn_mana_beam(source: Node, to_world: Vector2) -> void:
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
	line.default_color = Color(0.95, 0.76, 0.31, 0.9)  # 금색 #f2c14e
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


# ==== G3: crack passage (held-charm walkable swap) =========================

## Poll the 보호 부적 possession while the map is active: charm held → crack bottleneck L + scattered
## x tiles walkable; else re-seal. Same held-item判定 as L2's랜턴 (no lantern → wall), only via
## tile-source swap here (the L/x cells carry the dark/crack sources).
func _process(_delta: float) -> void:
	if not is_instance_valid(_loader):
		return
	var warded := _has_charm()
	if warded and not _g3_open:
		_g3_open = true
		_set_crack_walkable(true)
	elif not warded and _g3_open:
		_g3_open = false
		_set_crack_walkable(false)


func _set_crack_walkable(warded: bool) -> void:
	# The bottleneck L cells → lit walkable (M platform source) when warded, dark(31) when not.
	for cell in _crack_cells:
		_loader.set_gate_cell_source(cell, warded, _g3_lit_source, DARK_SOURCE)
		if warded:
			_add_glow(cell)
	# Scattered `x` crack tiles → walkable platform when warded, crack(32) when not (연출/지름길).
	for cell in _crack_tiles:
		_loader.set_gate_cell_source(cell, warded, _g3_lit_source, CRACK_SOURCE)
	# swap the crack-gate landmark art to the warded (membrane) variant.
	if _g3_open:
		_swap_art("crack_gate", "res://assets/objects/l4_crack_gate_on.png")
		_swap_art("crack_landmark", "res://assets/objects/l4_crack_gate_on.png")


func _has_charm() -> bool:
	return typeof(Inventory) != TYPE_NIL and Inventory.has(G3_CHARM)


# ==== G4: seal-core reconstruction → Layer 4 purification ===================

var _purifying: bool = false

func _start_purification(instant: bool = false) -> void:
	if _purifying or (GameState != null and GameState.get("layer4_purified_flag") == true):
		_apply_purified_endstate()
		return
	_purifying = true
	_swap_slot_art(_mount_node, "res://assets/objects/l4_seal_mount_on.png")
	if GameState != null:
		GameState.time_running = false
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	# open the seal neck H cells so the core is reachable end-state.
	for cell in _neck_cells:
		_loader.set_gate_cell_source(cell, true, _g4_lit_source, DARK_SOURCE)
	if instant:
		_finish_purification()
		return
	_run_purification()


func _run_purification() -> void:
	# 0. (CQ-4 G11) 빛 파문 — a golden rune flash + ripple ring from the seal core (봉인이 다시 짜인다).
	_purify_flash_ring(Color(0.95, 0.8, 0.45), _l4_core_pos())
	_light_core()
	await get_tree().create_timer(0.5).timeout
	_wave_seal_tower()
	await get_tree().create_timer(2.2).timeout
	_darken_base_tone()
	await _purify_card("…풀려난 것이, 마지막으로 한 번 더 잠들었다.")
	_finish_purification()


## (CQ-4 G11) Shared purify flash + ripple ring, gold rune-tinted for the sealing sanctum.
func _purify_flash_ring(tint: Color, origin: Vector2) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 12
	add_child(cl)
	var flash := CutsceneDirector.make_flash(Color(tint.r, tint.g, tint.b))
	cl.add_child(flash)
	CutsceneDirector.flash(self, flash, 0.85, 0.1, 1.0)
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D if _loader != null else null
	if ys != null:
		CutsceneDirector.spawn_ripple_ring(self, ys, origin, tint, 18.0, 1.8, 60)
	get_tree().create_timer(1.3, true, false, true).timeout.connect(func():
		if is_instance_valid(cl):
			cl.queue_free())


func _l4_core_pos() -> Vector2:
	if _core_node != null and is_instance_valid(_core_node) and _core_node is Node2D:
		return (_core_node as Node2D).global_position
	if _loader != null and _mount_cell != Vector2i(-1, -1):
		return _loader.cell_center_world(_mount_cell)
	if _loader != null:
		return _loader.cell_center_world(Vector2i(int(_loader.width / 2), int(_loader.height / 2)))
	return Vector2.ZERO


func _finish_purification() -> void:
	_purifying = false
	if GameState != null:
		GameState.set("layer4_purified_flag", true)
		GameState.time_running = true
		if GameState.has_signal("layer4_purified"):
			GameState.layer4_purified.emit("magic")


func _apply_purified_endstate() -> void:
	_swap_slot_art(_mount_node, "res://assets/objects/l4_seal_mount_on.png")
	for cell in _neck_cells:
		_loader.set_gate_cell_source(cell, true, _g4_lit_source, DARK_SOURCE)
	_light_core()
	_wave_seal_tower(true)
	_darken_base_tone()


func _light_core() -> void:
	if _core_node != null and is_instance_valid(_core_node) and _core_node is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l4_seal_core_on.png")
		if on_tex != null:
			(_core_node as Sprite2D).texture = on_tex
		_add_running_glow(_core_node as Node2D, 1.2)


## Re-light/open everything + light every landmark (탑 순차 재봉인).
func _wave_seal_tower(instant: bool = false) -> void:
	_light_bridge(true)
	_open_door(true)
	# swap the mana spring landmark to purified too.
	_swap_art("mana_spring", "res://assets/objects/l4_mana_spring_on.png")
	_swap_art("spring_landmark", "res://assets/objects/l4_mana_spring_on.png")


## Darken toward a settled deep-amethyst (봉인 후 고요) — L4 is re-sealing, so the tone deepens
## (vs L3 brightening). Cosmetic only.
func _darken_base_tone() -> void:
	var cm := _find_canvas_modulate()
	if cm != null and is_instance_valid(cm):
		var tw := cm.create_tween()
		tw.tween_property(cm, "color", Color("#4a3a70"), 1.5)   # settled amethyst calm


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
	lbl.add_theme_color_override("font_color", Color("#f0e4c8"))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12, 0.9))
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


func _tex_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _find_node(l4id: String) -> Node:
	# Guard against a torn-down loader (deferred signal firing during scene teardown).
	if not is_instance_valid(_loader):
		return null
	for key in _loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == l4id:
			return _loader.l2_object_nodes[key].get("node")
	return null


func _swap_art(l4id: String, path: String) -> void:
	var n := _find_node(l4id)
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


func _feedback_parent() -> Node:
	return _loader.get_node_or_null(_loader.ysort_layer_path)


## Re-apply persisted energized/purified state on a restored / re-entered tower.
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.is_power_node_energized("rune_bridge"):
		_light_bridge(true)
	if GameState.is_power_node_energized("mana_spring"):
		_g2_reward_given = true
		_open_door(true)
	if GameState.get("layer4_purified_flag") == true:
		_apply_purified_endstate()
