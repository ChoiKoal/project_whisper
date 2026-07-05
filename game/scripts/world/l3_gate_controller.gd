extends Node
class_name L3GateController
## (L3-3) The single node that wires Layer-3's four power gates onto the already-spawned
## clockwork_city objects + map. It reuses the Layer-1/2 signal patterns wholesale (§C-3),
## with only node_id strings + key-item ids swapped — NO new gate systems:
##   G1 톱니 맞물림   — 맞물림 톱니 D104 → 기어 조립대 X(place_slot) 장착 →
##                      power_node_energized("gate_gear") → 협곡 잔교 g 셀 순차 walkable (기어열 회전 연출).
##   G2 증기 보일러   — 압력 밸브 D105 → 대형 보일러 E 사용(item_used_on_object) + 젖은 석탄 D106 소지 →
##                      밸브문 v 개방 + **에너지 Whisper ×1 획득** (§보완, 필수). (L2 gen_sub 패턴 계승.)
##   G3 멈춘 승강기   — 평형추 D108 → 승강기 제어반 C(place_slot) 장착 →
##                      power_node_energized("elevator") → 승강기 L 셀 walkable + **상부 플랫폼(+1) 해금**
##                      (고도 게이팅은 map_height 그대로 — L 병목이 하부→+1 유일 접점, §C-3 승강기 특례).
##   G4 대시계 재가동 — 태엽심장 D111(whisper_cost:1) → 대시계 배전반 K(place_slot) 장착 →
##                      power_node_energized("clock_core") → Layer 3 정화 컷신 → layer3_purified.
##
## Mounting model: the assembly/boiler/ctrl/mount objects are spawned as plain Sprite2Ds by the
## loader. This controller wraps each in a use-target (a Gatherable with object_id, no item) so the
## EXISTING _try_use_on_object framework routes the key item onto it, then listens to
## GameState.item_used_on_object to fire the right power-node effect. Idempotent on reload.
## Defensive against missing autoloads/nodes.

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l3_map_legend.json `gates`). Empty on non-L3 maps → controller idle.
var _gates: Dictionary = {}

const DARK_SOURCE := 25   # L3 sealed (dark, non-walkable) — matches legend g/v/L/H tiles.

## G1 gear-bridge cells (south→north light order) + assembly use-target.
var _gear_cells: Array = []
var _g1_lit_source := 20
## G2 valve-door cells + boiler node.
var _door_cells: Array = []
var _door_node: Node = null
var _g2_lit_source := 22
## G3 elevator lift cells + ctrl.
var _lift_cells: Array = []
var _elevator_node: Node = null
var _g3_lit_source := 23
## G4 clock-neck cells + mount + clock.
var _neck_cells: Array = []
var _clock_node: Node = null
var _g4_lit_source := 24

## Guard so the G2 Whisper acquisition 연출 fires exactly once.
var _g2_reward_given: bool = false
## Held-item required alongside the valve for G2 ignition (젖은 석탄).
const G2_COAL := "D106"


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
	if _gates.is_empty() or not _gates.has("G4") or not _is_l3():
		return  # not a Layer-3 map
	_wire_use_targets()
	_wire_gear()
	_wire_door()
	_wire_elevator()
	_wire_clock()
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.power_node_energized.is_connected(_on_power_node):
			GameState.power_node_energized.connect(_on_power_node)
	_reapply_persisted_state()


## Distinguish an L3 map from an L2 map (both have `gates`): L3's G1 carries a bridge over a
## `gate_gear` node_id + `assembly` list.
func _is_l3() -> bool:
	var g1: Dictionary = _gates.get("G1", {})
	return String(g1.get("node_id", "")) == "gate_gear"


# ==== object wiring ========================================================

## Turn the assembly / boiler / ctrl / mount spawned Sprite2Ds into use-targets so the held key
## item routes onto them (via the existing adjacency/use pick).
func _wire_use_targets() -> void:
	for key in _loader.l2_object_nodes.keys():
		var l3id := String(key).split("@")[0]
		var rec: Dictionary = _loader.l2_object_nodes[key]
		var node: Node = rec.get("node")
		if node == null or not is_instance_of(node, Sprite2D):
			continue
		if l3id == "gear_assembly" or l3id == "boiler" or l3id == "elevator_ctrl" or l3id == "clock_mount":
			_make_use_target(node as Sprite2D, l3id)


func _make_use_target(sprite: Sprite2D, object_id: String) -> void:
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


func _wire_gear() -> void:
	var g1: Dictionary = _gates.get("G1", {})
	_gear_cells = _cells_of(g1.get("bridge_cells", []))
	_gear_cells.sort_custom(func(a, b): return a.y > b.y)   # south→north
	_g1_lit_source = int(g1.get("lit_source", 20))


func _wire_door() -> void:
	var g2: Dictionary = _gates.get("G2", {})
	_door_cells = _cells_of(g2.get("door_cells", []))
	_g2_lit_source = int(g2.get("lit_source", 22))
	_door_node = _find_node("valve_door")


func _wire_elevator() -> void:
	var g3: Dictionary = _gates.get("G3", {})
	_lift_cells = _cells_of(g3.get("lift_cells", []))
	_g3_lit_source = int(g3.get("lit_source", 23))
	_elevator_node = _find_node("elevator")


func _wire_clock() -> void:
	var g4: Dictionary = _gates.get("G4", {})
	_neck_cells = _cells_of(g4.get("neck_cells", []))
	_g4_lit_source = int(g4.get("lit_source", 24))
	_clock_node = _find_node("grand_clock")


# ==== key-item use → power node energize ===================================

func _on_item_used(item: String, obj: Node) -> void:
	if obj == null:
		return
	var oid := String(obj.get("object_id")) if obj.has_method("get") else ""
	match oid:
		"gear_assembly":
			if item == "D104":
				_spark_at(obj)
				GameState.energize_power_node("gate_gear")
		"boiler":
			# G2 needs the valve D105 used on the boiler AND 젖은 석탄 D106 in hand.
			if item == "D105" and _has_coal():
				_spark_at(obj)
				_energize_boiler(obj)
		"elevator_ctrl":
			if item == "D108":
				_spark_at(obj)
				GameState.energize_power_node("elevator")
		"clock_mount":
			if item == "D111":
				_spark_at(obj)
				GameState.energize_power_node("clock_core")


func _on_power_node(node_id: String) -> void:
	match node_id:
		"gate_gear":
			_mesh_gears()
		"elevator":
			_raise_elevator()
		"clock_core":
			_start_purification()


# ==== G1: gear mesh (bridge deck) ==========================================

## Sequentially open the gear-bridge deck cells (0.12s stagger) — reads as the gear train meshing
## and rotating a notch at a time. Reuses the walkable-swap + AStar rebuild (set_gate_cell_source).
func _mesh_gears(instant: bool = false) -> void:
	if _gear_cells.is_empty():
		return
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	# swap the assembly art to the completed/meshed variant.
	_swap_art("gear_assembly", "res://assets/objects/l3_gear_assembly_on.png")
	var i := 0
	for cell in _gear_cells:
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


# ==== G2: boiler + steam valve door + energy Whisper (필수) =================

func _energize_boiler(boiler_obj: Node) -> void:
	GameState.energize_power_node("boiler")
	if boiler_obj is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l3_boiler_on.png")
		if on_tex != null:
			(boiler_obj as Sprite2D).texture = on_tex
		_add_running_glow(boiler_obj as Node2D)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_open_door()
	_grant_energy_whisper(boiler_obj)


func _open_door(instant: bool = false) -> void:
	for cell in _door_cells:
		_loader.set_gate_cell_source(cell, true, _g2_lit_source, DARK_SOURCE)
	if _door_node != null and is_instance_valid(_door_node):
		for ch in _door_node.get_children():
			if ch is StaticBody2D:
				(ch as StaticBody2D).process_mode = Node.PROCESS_MODE_DISABLED
				var col := (ch as StaticBody2D).get_child(0)
				if col is CollisionShape2D:
					(col as CollisionShape2D).set_deferred("disabled", true)
		if _door_node is Sprite2D:
			var open_tex := _tex_if_exists("res://assets/objects/l3_valve_door_open.png")
			if open_tex != null:
				(_door_node as Sprite2D).texture = open_tex


## Grant the first 에너지 Whisper (§보완 필수). +1 energy → WhisperCurrency, 주황 빛줄기 연출
## toward the player + 플로팅 텍스트, exactly once.
func _grant_energy_whisper(source: Node) -> void:
	if _g2_reward_given:
		return
	_g2_reward_given = true
	if typeof(WhisperCurrency) != TYPE_NIL:
		WhisperCurrency.add_energy(1)
	var anchor: Vector2 = _player.global_position if _player != null else \
		(source.get("global_position") if source != null and source.has_method("get") else Vector2.ZERO)
	_spawn_energy_beam(source, anchor)
	var fb := _feedback_parent()
	if fb != null and typeof(FloatingLabel) != TYPE_NIL:
		FloatingLabel.spawn(fb, anchor - Vector2(0, 96), "…처음으로, 힘이 내 것이 되었다")


## An orange light streak from the boiler flowing into the player (온기가 흘러듦).
func _spawn_energy_beam(source: Node, to_world: Vector2) -> void:
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
	line.default_color = Color(1.0, 0.60, 0.24, 0.9)  # 주황 #ff9a3c
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


# ==== G3: elevator (walkable + upper platform unlock) ======================

## Raise the elevator: open the lift L cells (walkable swap → hop onto the +1 platform via the
## same L병목, no extra elevation code needed §C-3 승강기 특례). Swap art + orange arrival lamp.
func _raise_elevator(instant: bool = false) -> void:
	if _lift_cells.is_empty():
		return
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_swap_art("elevator", "res://assets/objects/l3_elevator_on.png")
	for cell in _lift_cells:
		_loader.set_gate_cell_source(cell, true, _g3_lit_source, DARK_SOURCE)
		if not instant:
			_add_glow(cell)


# ==== G4: grand clock reactivation → Layer 3 purification ===================

var _purifying: bool = false

func _start_purification(instant: bool = false) -> void:
	if _purifying or (GameState != null and GameState.get("layer3_purified_flag") == true):
		_apply_purified_endstate()
		return
	_purifying = true
	if GameState != null:
		GameState.time_running = false
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	# open the clock neck H cells so the coreは reachable end-state.
	for cell in _neck_cells:
		_loader.set_gate_cell_source(cell, true, _g4_lit_source, DARK_SOURCE)
	if instant:
		_finish_purification()
		return
	_run_purification()


func _run_purification() -> void:
	_light_clock_face()
	await get_tree().create_timer(0.5).timeout
	_wave_energize_city()
	await get_tree().create_timer(2.2).timeout
	_brighten_base_tone()
	await _purify_card("…도시가, 마지막으로 한 번 째깍였다.")
	_finish_purification()


func _finish_purification() -> void:
	_purifying = false
	if GameState != null:
		GameState.set("layer3_purified_flag", true)
		GameState.time_running = true
		if GameState.has_signal("layer3_purified"):
			GameState.layer3_purified.emit("machine")


func _apply_purified_endstate() -> void:
	for cell in _neck_cells:
		_loader.set_gate_cell_source(cell, true, _g4_lit_source, DARK_SOURCE)
	_light_clock_face()
	_wave_energize_city(true)
	_brighten_base_tone()


func _light_clock_face() -> void:
	if _clock_node != null and is_instance_valid(_clock_node) and _clock_node is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l3_grand_clock_on.png")
		if on_tex != null:
			(_clock_node as Sprite2D).texture = on_tex
		_add_running_glow(_clock_node as Node2D, 1.2)


## Re-mesh/raise everything + light every landmark with a small row stagger (도시 순차 재기동).
func _wave_energize_city(instant: bool = false) -> void:
	_mesh_gears(true)
	_open_door(true)
	_raise_elevator(true)
	# swap the boiler landmark to lit too.
	_swap_art("boiler", "res://assets/objects/l3_boiler_on.png")
	_swap_art("boiler_landmark", "res://assets/objects/l3_boiler_on.png")
	_swap_art("elevator_cage", "res://assets/objects/l3_elevator_on.png")


func _brighten_base_tone() -> void:
	var cm := _find_canvas_modulate()
	if cm != null and is_instance_valid(cm):
		var tw := cm.create_tween()
		tw.tween_property(cm, "color", Color("#8a6a44"), 1.5)   # warm brass daylight


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
	lbl.add_theme_color_override("font_color", Color("#ffe6c8"))
	lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.03, 0.9))
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


func _find_node(l3id: String) -> Node:
	for key in _loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == l3id:
			return _loader.l2_object_nodes[key].get("node")
	return null


func _swap_art(l3id: String, path: String) -> void:
	var n := _find_node(l3id)
	if n != null and is_instance_valid(n) and n is Sprite2D:
		var tex := _tex_if_exists(path)
		if tex != null:
			(n as Sprite2D).texture = tex


func _has_coal() -> bool:
	return typeof(Inventory) != TYPE_NIL and Inventory.has(G2_COAL)


func _add_glow(cell: Vector2i) -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load("res://assets/objects/light_pool_orange.png")
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
	var tex := load("res://assets/objects/light_pool_orange.png")
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.scale = Vector2(strength, strength)
	node.add_child(pool)


func _feedback_parent() -> Node:
	return _loader.get_node_or_null(_loader.ysort_layer_path)


## Re-apply persisted energized/purified state on a restored / re-entered city.
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.is_power_node_energized("gate_gear"):
		_mesh_gears(true)
	if GameState.is_power_node_energized("boiler"):
		_g2_reward_given = true
		_open_door(true)
	if GameState.is_power_node_energized("elevator"):
		_raise_elevator(true)
	if GameState.get("layer3_purified_flag") == true:
		_apply_purified_endstate()
