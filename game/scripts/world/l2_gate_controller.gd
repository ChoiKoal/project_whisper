extends Node
class_name L2GateController
## (L2-3) The single node that wires Layer-2's four gates onto the已-spawned terminal_station
## objects + map. It reuses Layer-1 signal patterns wholesale (§C-3):
##   G1 에너지 브리지  — 전지 D64 → 배전반 K(bridge) 장착 → power_node_energized("bridge")
##                       → 브리지 B 타일 순차 점등 + walkable 전환 (stepping-stone 갱신 재사용).
##   G2 차폐문+Whisper — 퓨즈 D66 → 보조 발전기 e 사용(item_used_on_object) → 발전기 가동 스왑
##                       → 차폐문 D 개방(콜리전 해제) + 에너지 Whisper ×1 획득 (§보완, 필수).
##   G3 정전 구역     — N 병목 Area2D: Inventory.has_item("D65") 폴링 → 소지 시 통행+조명,
##                       미소지 시 보이지 않는 벽 + 화면 가장자리 암전 경고. (held-item gate)
##   G4 관제탑 재가동  — 파워 코어 D69 → 관제탑 배전반 K(control) 장착 →
##                       power_node_energized("control_core") → Layer 2 정화 컷신 → layer2_purified.
##
## Mounting model (배전반/발전기): the breaker/gen/tower-core objects are spawned as plain
## Sprite2Ds by the loader. This controller wraps each in a PowerNode use-target (a Gatherable
## with object_id but no item) so the EXISTING `_try_use_on_object` framework routes the key item
## onto it (D64 usable_on breaker, D66 usable_on gen_sub, D69 usable_on breaker). It then listens
## to GameState.item_used_on_object to fire the right power-node effect.
##
## Defensive against missing autoloads/nodes (release templates strip assert()); every hook
## guards. Idempotent: re-applies already-energized/purified state on load (powered_nodes).

@export var map_loader_path: NodePath
@export var player_path: NodePath

var _loader: MapLoader
var _player: Node2D

## Legend gate records (from l2_map_legend.json `gates`). Empty on non-L2 maps → controller idle.
var _gates: Dictionary = {}

## G1 bridge cells (in staggered-light order, south→north) and its breaker node_id mapping.
var _bridge_cells: Array = []
## G2 door cells + the gen_sub node handle.
var _door_cells: Array = []
var _door_node: Node = null
## G4 control-tower core cell + screen node.
var _tower_node: Node = null

## The two breaker objects, disambiguated by which gate they belong to (G1 vs G4) via cell.
## breaker cell (Vector2i) → node_id it energizes ("bridge" | "control_core").
var _breaker_node_id: Dictionary = {}

## G3 blackout Area2D + its screen-edge vignette warning (built lazily).
var _g3_area: Area2D = null
var _g3_body: StaticBody2D = null
var _g3_open: bool = false
var _g3_warn: ColorRect = null
var _g3_light_pools: Array = []
const G3_LANTERN := "D65"

## Guard so the G2 Whisper acquisition연출 fires exactly once.
var _g2_reward_given: bool = false


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# Wait a couple frames so the loader has finished spawning all l2 objects.
	await get_tree().process_frame
	await get_tree().process_frame
	_loader = get_node_or_null(map_loader_path) as MapLoader
	_player = get_node_or_null(player_path) as Node2D
	if _loader == null:
		return
	_gates = _loader.legend_gates()
	if _gates.is_empty():
		return  # not a Layer-2 map
	_wire_breakers_and_gen()
	_wire_bridge()
	_wire_door()
	_wire_tower()
	_build_g3_area()
	# Listen for key-item use on the power nodes / generator (drives G1/G2/G4 energizing).
	if GameState != null:
		if not GameState.item_used_on_object.is_connected(_on_item_used):
			GameState.item_used_on_object.connect(_on_item_used)
		if not GameState.power_node_energized.is_connected(_on_power_node):
			GameState.power_node_energized.connect(_on_power_node)
	# Re-apply any already-energized/purified state (save/reentry). Bridge lit, door open, etc.
	_reapply_persisted_state()


# ==== object wiring ========================================================

## Wrap the breaker(s) + gen_sub in PowerNode use-targets so the interaction framework routes the
## key item onto them, and map each breaker cell to the power node it energizes (G1 vs G4).
func _wire_breakers_and_gen() -> void:
	var g1: Dictionary = _gates.get("G1", {})
	var g4: Dictionary = _gates.get("G4", {})
	var g1_breakers := _cells_of(g1.get("breaker", []))
	var g4_breakers := _cells_of(g4.get("breaker", []))
	for c in g1_breakers:
		_breaker_node_id[c] = "bridge"
	for c in g4_breakers:
		_breaker_node_id[c] = "control_core"
	# Turn every spawned breaker/gen_sub Sprite2D into a use-target (adds it to the gatherable
	# group with object_id so ItemDB.can_use_on_object routes the held key item to it).
	for key in _loader.l2_object_nodes.keys():
		var rec: Dictionary = _loader.l2_object_nodes[key]
		var l2id := String(key).split("@")[0]
		var node: Node = rec.get("node")
		if node == null or not is_instance_of(node, Sprite2D):
			continue
		if l2id == "breaker" or l2id == "gen_sub":
			_make_use_target(node as Sprite2D, l2id)


## Convert a plain structure Sprite2D into a PowerNode use-target: attach a child Gatherable
## (no item_id → not gatherable) carrying the object_id at the same world position, so the
## existing adjacency/use pick finds it. The parent Sprite2D keeps its art + blocking body.
func _make_use_target(sprite: Sprite2D, object_id: String) -> void:
	# Already wrapped?
	for ch in sprite.get_children():
		if ch is Gatherable and String((ch as Gatherable).object_id) == object_id:
			return
	var g := Gatherable.new()
	g.item_id = ""            # use-only (can_gather()==false)
	g.object_id = object_id
	g.texture = null          # invisible pick proxy; the parent sprite shows the art
	g.modulate = Color(1, 1, 1, 0)
	sprite.add_child(g)
	g.position = Vector2.ZERO


func _wire_bridge() -> void:
	var g1: Dictionary = _gates.get("G1", {})
	# South→north order for the sequential light (higher row first = closer to spawn/south).
	_bridge_cells = _cells_of(g1.get("bridge_cells", []))
	_bridge_cells.sort_custom(func(a, b): return a.y > b.y)


func _wire_door() -> void:
	var g2: Dictionary = _gates.get("G2", {})
	_door_cells = _cells_of(g2.get("door_cells", []))
	_door_node = _find_l2_node("shield_door")


func _wire_tower() -> void:
	_tower_node = _find_l2_node("control_tower")


# ==== key-item use → power node energize ===================================

## The interaction framework fired: `item` was used on `obj`. Route to the right gate effect.
func _on_item_used(item: String, obj: Node) -> void:
	if obj == null:
		return
	var oid := String(obj.get("object_id")) if obj.has_method("get") else ""
	if oid == "breaker":
		# Which breaker? Find the nearest breaker cell to the object's world position.
		var cell := _node_cell(obj)
		var node_id := String(_breaker_node_id.get(cell, ""))
		if node_id == "" :
			node_id = _nearest_breaker_node_id(obj)
		if node_id == "bridge" and item == "D64":
			_spark_at(obj)
			# (v1.1.0 GP-5 §3) G1 = 승격 게이트. 장착 순간 퓨즈 순서 퍼즐 모달 → 성공/스킵 모두 기존 개방.
			_puzzle_then_energize("fuse", "bridge")
		elif node_id == "control_core" and item == "D69":
			_spark_at(obj)
			GameState.energize_power_node("control_core")
	elif oid == "gen_sub" and item == "D66":
		_spark_at(obj)
		_energize_gen_sub(obj)


## (v1.1.0 GP-5 §3) 승격 게이트: open a mini-puzzle modal, then energize on success OR skip (스킵 =
## 그냥 장착 = 동일 개방; 진행 차단 아님). If no scene tree/root (headless-less context) energize直行.
func _puzzle_then_energize(puzzle_type: String, node_id: String) -> void:
	var root: Node = get_tree().current_scene if get_tree() != null else null
	var energize := func(): GameState.energize_power_node(node_id)
	if root == null or GatePuzzle.open(root, puzzle_type, energize, energize) == null:
		GameState.energize_power_node(node_id)


## A power node became energized (also fires on load re-apply). Drive the visible effect.
func _on_power_node(node_id: String) -> void:
	match node_id:
		"bridge":
			_light_bridge()
		"control_core":
			_start_purification()


# ==== G1: energy bridge ====================================================

## Sequentially light the bridge deck tiles (0.1s stagger) and make each walkable. Reuses the
## stepping-stone walkable-swap + AStar rebuild (l2_set_gate_cell_walkable → tile_walkable_changed).
func _light_bridge(instant: bool = false) -> void:
	if _bridge_cells.is_empty():
		return
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	var i := 0
	for cell in _bridge_cells:
		if instant:
			_loader.l2_set_gate_cell_walkable(cell, true)
			_add_bridge_glow(cell)
		else:
			var delay := 0.1 * i
			var c: Vector2i = cell
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(_loader):
					_loader.l2_set_gate_cell_walkable(c, true)
					_add_bridge_glow(c))
		i += 1


## A cyan发광 strip decal on a newly-lit bridge tile (§C-2 발광 스트립 순차 점등).
func _add_bridge_glow(cell: Vector2i) -> void:
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null:
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load("res://assets/objects/light_pool_cyan.png")
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.scale = Vector2(0.55, 0.55)
	ys.add_child(pool)
	pool.global_position = _loader.cell_center_world(cell)


# ==== G2: shield door + energy Whisper (필수) ==============================

## Fuse用으로 e에 퓨즈 장착됨 → 발전기 가동 텍스처 스왑(이미 L2-1 아트 존재 시) → 차폐문 개방
## + 에너지 Whisper ×1 획득 (§보완). node_id = "gen_sub" isn't a power-node in the K sense, so it
## is tracked in powered_nodes under "gen_sub" for save-consistency, but the door + Whisper reward
## is the observable effect.
func _energize_gen_sub(gen_obj: Node) -> void:
	GameState.energize_power_node("gen_sub")
	# generator 가동 텍스처 스왑 (꺼짐→가동). Uses l2_gen_sub_on.png if present, else keeps art.
	if gen_obj is Sprite2D:
		var on_tex := _tex_if_exists("res://assets/objects/l2_gen_sub_on.png")
		if on_tex != null:
			(gen_obj as Sprite2D).texture = on_tex
		# cyan running glow at the panel.
		_add_running_glow(gen_obj as Node2D)
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_hum")
	_open_door()
	_grant_energy_whisper(gen_obj)


## Open the 차폐문 D: unseal its cells (collision release + walkable) + swap the door node art.
func _open_door(instant: bool = false) -> void:
	for cell in _door_cells:
		_loader.l2_set_gate_cell_walkable(cell, true)
	# Door node: drop its blocking StaticBody + swap to open art, if present.
	if _door_node != null and is_instance_valid(_door_node):
		for ch in _door_node.get_children():
			if ch is StaticBody2D:
				(ch as StaticBody2D).process_mode = Node.PROCESS_MODE_DISABLED
				var col := (ch as StaticBody2D).get_child(0)
				if col is CollisionShape2D:
					(col as CollisionShape2D).set_deferred("disabled", true)
		if _door_node is Sprite2D:
			var open_tex := _tex_if_exists("res://assets/objects/l2_door_open.png")
			if open_tex != null:
				(_door_node as Sprite2D).texture = open_tex


## Grant the first 에너지 Whisper (§보완 필수). Adds 1 energy → WhisperCurrency, fires the 시안
## 빛줄기 연출 toward the player + the플로팅 텍스트, exactly once.
func _grant_energy_whisper(source: Node) -> void:
	if _g2_reward_given:
		return
	_g2_reward_given = true
	if typeof(WhisperCurrency) != TYPE_NIL:
		WhisperCurrency.add_energy(1)
	# 시안 빛줄기 + 플로팅 텍스트.
	var anchor: Vector2 = _player.global_position if _player != null else \
		(source.get("global_position") if source != null and source.has_method("get") else Vector2.ZERO)
	_spawn_energy_beam(source, anchor)
	var fb := _feedback_parent()
	if fb != null and typeof(FloatingLabel) != TYPE_NIL:
		FloatingLabel.spawn(fb, anchor - Vector2(0, 96), "…처음으로, 힘이 내 것이 되었다")


## A cyan light streak from the generator flowing into the player (에너지가 흘러듦).
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
	line.default_color = Color(0.29, 0.85, 0.78, 0.9)  # 시안 #4ad9c8
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


# ==== G3: blackout held-item gate ==========================================

## Build the 정전 병목 Area2D over the sealed N gate cells, an invisible wall (StaticBody), and a
## screen-edge darkening warning ColorRect. Poll Inventory.has_item(D65) while the player is inside:
## soji → 통행(콜리전 off) + 주변 조명; miso ji → 벽 유지 + 국소 암전 경고.
func _build_g3_area() -> void:
	var g3: Dictionary = _gates.get("G3", {})
	var cells := _cells_of(g3.get("cells", []))
	# The loader also derives the actual sealed cells; prefer those (authoritative, can't drift).
	if _loader.l2_blackout_cells.size() > 0:
		cells = _loader.l2_blackout_cells.keys()
	if cells.is_empty():
		return
	_g3_area = Area2D.new()
	_g3_area.monitoring = true
	# A rectangle covering the bottleneck band (min..max of the cells).
	var minc := Vector2i(9999, 9999)
	var maxc := Vector2i(-9999, -9999)
	for c in cells:
		minc.x = mini(minc.x, c.x); minc.y = mini(minc.y, c.y)
		maxc.x = maxi(maxc.x, c.x); maxc.y = maxi(maxc.y, c.y)
	var w0 := _loader.cell_center_world(minc)
	var w1 := _loader.cell_center_world(maxc)
	var center := (w0 + w1) * 0.5
	var half := (w1 - w0).abs() * 0.5 + Vector2(48, 48)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0
	col.shape = shape
	_g3_area.add_child(col)
	_loader.add_child(_g3_area)
	_g3_area.global_position = center
	_g3_area.body_entered.connect(_on_g3_body_entered)
	_g3_area.body_exited.connect(_on_g3_body_exited)

	# Invisible wall sealing the bottleneck while unlit (removed when the lantern is held).
	_g3_body = StaticBody2D.new()
	_g3_body.collision_layer = 1
	_g3_body.collision_mask = 0
	var bcol := CollisionShape2D.new()
	var bshape := RectangleShape2D.new()
	bshape.size = Vector2(half.x * 2.0, maxi(24, int((w1.y - w0.y)) + 48))
	bcol.shape = bshape
	_g3_body.add_child(bcol)
	_loader.add_child(_g3_body)
	_g3_body.global_position = center

	# Screen-edge darkening warning (hidden until the player enters without a lantern).
	_build_g3_warning()
	# Seal EXPLICITLY on build (don't rely on the CollisionShape2D disabled=false default): the
	# bottleneck starts blocked, then the initial-inventory apply opens it only if a lantern is held.
	_set_g3_wall(true)
	# Apply the initial passable state from current inventory (a restored lantern opens it).
	_apply_g3(_has_lantern())


func _build_g3_warning() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 6
	add_child(cl)
	_g3_warn = ColorRect.new()
	_g3_warn.color = Color(0, 0, 0, 0)
	_g3_warn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_g3_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A radial-ish vignette feel via a material would be ideal; a plain dark fill with a
	# center hole is approximated by a strong edge darken. Keep it simple + guarded: a solid
	# dark overlay whose alpha we tween. (The base Vignette node already frames the screen.)
	var mat := CanvasItemMaterial.new()
	_g3_warn.material = mat
	cl.add_child(_g3_warn)


var _in_g3: bool = false

func _on_g3_body_entered(body: Node) -> void:
	if body != _player:
		return
	_in_g3 = true
	set_process(true)


func _on_g3_body_exited(body: Node) -> void:
	if body != _player:
		return
	_in_g3 = false
	# Clear the warning when leaving.
	_set_g3_warning(false)
	set_process(_in_g3)


func _process(_delta: float) -> void:
	if not _in_g3:
		set_process(false)
		return
	# Poll the lantern possession while inside the bottleneck (cheap; §C-3 허용).
	var lit := _has_lantern()
	_apply_g3(lit)


## Apply the G3 passable state: lantern held → wall off + light pools + no warning; else wall on
## + screen-edge darken + flavor. Idempotent; only touches collision on an actual open↔close edge.
func _apply_g3(lit: bool) -> void:
	if lit and not _g3_open:
		_g3_open = true
		_set_g3_wall(false)
		_light_g3_bottleneck()
	elif not lit and _g3_open:
		_g3_open = false
		_set_g3_wall(true)
	# Warning follows the current inside/lit状態 every call (cheap, tween is idempotent).
	_set_g3_warning(_in_g3 and not lit)


## Enable/disable the invisible bottleneck wall's collision.
func _set_g3_wall(on: bool) -> void:
	if _g3_body == null or not is_instance_valid(_g3_body):
		return
	var bcol := _g3_body.get_child(0)
	if bcol is CollisionShape2D:
		(bcol as CollisionShape2D).set_deferred("disabled", not on)


func _has_lantern() -> bool:
	return typeof(Inventory) != TYPE_NIL and Inventory.has(G3_LANTERN)


## 랜턴 소지 시 병목 주변 시안 라이트 풀 (플레이어 주변 조명 반경).
func _light_g3_bottleneck() -> void:
	if not _g3_light_pools.is_empty():
		return
	var ys := _loader.get_node_or_null(_loader.ysort_layer_path) as Node2D
	if ys == null or _g3_area == null:
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load("res://assets/objects/light_pool_cyan.png")
	if scr == null or tex == null:
		return
	for cell in _loader.l2_blackout_cells.keys():
		var pool: Sprite2D = scr.new()
		pool.texture = tex
		pool.scale = Vector2(0.8, 0.8)
		ys.add_child(pool)
		pool.global_position = _loader.cell_center_world(cell)
		_g3_light_pools.append(pool)


func _set_g3_warning(on: bool) -> void:
	if _g3_warn == null or not is_instance_valid(_g3_warn):
		return
	var target := 0.62 if on else 0.0
	if absf(_g3_warn.color.a - target) < 0.01:
		return
	var tw := _g3_warn.create_tween()
	tw.tween_property(_g3_warn, "color:a", target, 0.35)
	if on and _in_g3:
		var fb := _feedback_parent()
		if fb != null and typeof(FloatingLabel) != TYPE_NIL and _player != null:
			FloatingLabel.spawn(fb, _player.global_position - Vector2(0, 80), "너무 어둡다… 빛이 필요하다")


# ==== G4: control tower reactivation → Layer 2 purification =================

var _purifying: bool = false

## Kick off the Layer-2 정화 컷신 (관제탑 재가동). Reuses the CS-04 clear-sequence beat structure:
## screen 점등 → 기지 전역 순차 급전 (bridge/door/lamps 존별 파도) → 톤 밝아짐 → 텍스트 → cleared.
func _start_purification(instant: bool = false) -> void:
	if _purifying or GameState.layer2_purified_flag:
		# Already done (load re-apply): just ensure the visible end-state.
		_apply_purified_endstate()
		return
	_purifying = true
	if GameState != null:
		GameState.time_running = false
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("clear_fanfare")
	if instant:
		_finish_purification()
		return
	_run_purification()


func _run_purification() -> void:
	# 1. control tower screen 점등.
	_light_tower_screen()
	await get_tree().create_timer(0.5).timeout
	# 2. 기지 전역 순차 급전: light all lamps + any unlit bridge, zone wave (~3s).
	_wave_energize_base()
	await get_tree().create_timer(2.4).timeout
	# 3. 배경 톤 밝아짐 (정전 해제): lift the fixed night tone toward a brighter cyan-blue.
	_brighten_base_tone()
	# 4. text card.
	await _purify_card("…기계들이, 숨을 쉬기 시작했다.")
	_finish_purification()


func _finish_purification() -> void:
	_purifying = false
	GameState.layer2_purified_flag = true
	if GameState != null:
		GameState.time_running = true
	# cleared 시그널 (Layer 2 purified 플래그) — session hooks 귀환 유도.
	GameState.layer2_purified.emit("science")


## The visible end-state (used when re-entering an already-purified station): screen lit, base
## bright, bridge/door open.
func _apply_purified_endstate() -> void:
	_light_tower_screen()
	_wave_energize_base(true)
	_brighten_base_tone()


func _light_tower_screen() -> void:
	if _tower_node != null and is_instance_valid(_tower_node) and _tower_node is Sprite2D:
		# The tower has no dedicated 'on' art; its screen 점등 reads via the cyan running glow.
		var on_tex := _tex_if_exists("res://assets/objects/l2_tower_on.png")
		if on_tex != null:
			(_tower_node as Sprite2D).texture = on_tex
		_add_running_glow(_tower_node as Node2D, 1.2)
	# Also light the big_screen landmark if present.
	var scr := _find_l2_node("big_screen")
	if scr != null and is_instance_valid(scr) and scr is Sprite2D:
		var stex := _tex_if_exists("res://assets/objects/l2_screen_on.png")
		if stex != null:
			(scr as Sprite2D).texture = stex


## Wave-light every 가로등 (lamp_off) + ensure bridge/door open. Zone wave = row-staggered.
func _wave_energize_base(instant: bool = false) -> void:
	# Ensure the bridge + door are lit/open (they may already be from G1/G2, idempotent).
	_light_bridge(true)
	_open_door(true)
	# Light every lamp with a small row-based stagger for the파도 feel.
	var lamps: Array = []
	for key in _loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == "lamp_off":
			lamps.append(_loader.l2_object_nodes[key].get("node"))
	lamps.sort_custom(func(a, b):
		var ay: float = a.global_position.y if a != null else 0.0
		var by: float = b.global_position.y if b != null else 0.0
		return ay > by)
	var i := 0
	for lamp in lamps:
		if lamp == null or not is_instance_valid(lamp):
			continue
		var l: Node2D = lamp
		if instant:
			_add_running_glow(l, 0.7)
		else:
			get_tree().create_timer(0.12 * i).timeout.connect(func():
				if is_instance_valid(l):
					_add_running_glow(l, 0.7))
		i += 1


## Lift the fixed dark night tone toward a brighter tint (정전 해제 = 배경 밝아짐).
func _brighten_base_tone() -> void:
	var dn := get_tree().get_first_node_in_group("day_night") if get_tree() != null else null
	# The DayNight is a CanvasModulate with fixed_tone; brighten its color directly.
	var cm := _find_canvas_modulate()
	if cm != null and is_instance_valid(cm):
		var tw := cm.create_tween()
		tw.tween_property(cm, "color", Color("#6a86b0"), 1.5)


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
	lbl.add_theme_color_override("font_color", Color("#d8ecff"))
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.09, 0.9))
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

## Reads the legend `gates` block from the loader (exposed via legend_gates()).
func _cells_of(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


## Load a texture only if it exists (guards against a missing optional swap art hard-erroring —
## load() on an absent path throws in Godot 4, which would abort an await coroutine).
func _tex_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _find_l2_node(l2id: String) -> Node:
	for key in _loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == l2id:
			return _loader.l2_object_nodes[key].get("node")
	return null


func _node_cell(obj: Node) -> Vector2i:
	if obj != null and obj.has_method("get"):
		var gp: Variant = obj.get("global_position")
		if typeof(gp) == TYPE_VECTOR2:
			return _loader.world_to_cell(gp)
	# fallback: parent (the use-target Gatherable is a child of the breaker sprite).
	var p := obj.get_parent()
	if p != null and p.has_method("get"):
		var pg: Variant = p.get("global_position")
		if typeof(pg) == TYPE_VECTOR2:
			return _loader.world_to_cell(pg)
	return Vector2i(-1, -1)


func _nearest_breaker_node_id(obj: Node) -> String:
	var cell := _node_cell(obj)
	var best := ""
	var best_d := INF
	for c in _breaker_node_id.keys():
		var d: float = Vector2(c).distance_to(Vector2(cell))
		if d < best_d:
			best_d = d
			best = String(_breaker_node_id[c])
	return best


func _spark_at(obj: Node) -> void:
	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("power_spark")
	if obj is Node2D:
		_add_running_glow(obj as Node2D, 0.9)


## A cyan additive light pool at an object (급전 발광). Reuses light_pool.gd.
func _add_running_glow(node: Node2D, strength: float = 0.8) -> void:
	if not is_instance_valid(node):
		return
	var scr := load("res://scripts/world/light_pool.gd")
	var tex := load("res://assets/objects/light_pool_cyan.png")
	if scr == null or tex == null:
		return
	var pool: Sprite2D = scr.new()
	pool.texture = tex
	pool.scale = Vector2(strength, strength)
	node.add_child(pool)


func _feedback_parent() -> Node:
	return _loader.get_node_or_null(_loader.ysort_layer_path)


## Re-apply persisted energized/purified state on a restored / re-entered station so the bridge
## stays lit, the door open, and the base purified without replaying the cutscene.
func _reapply_persisted_state() -> void:
	if GameState == null:
		return
	if GameState.is_power_node_energized("bridge"):
		_light_bridge(true)
	if GameState.is_power_node_energized("gen_sub"):
		_g2_reward_given = true  # Whisper already granted in the run that energized it
		_open_door(true)
	if GameState.layer2_purified_flag:
		_apply_purified_endstate()
