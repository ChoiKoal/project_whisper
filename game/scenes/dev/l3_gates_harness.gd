extends Node
## (L3-3) Layer-3 게이트 + 전력계 acceptance harness. Boots the REAL clockwork_city.tscn (the scene
## the machine portal travels to) and drives each of the four 동력 게이트 through its real controller
## + signals — the L3 mirror of l2_gates_harness (§C-3 동일 시그널 패턴, node_id/키아이템만 교체):
##   G1 톱니 맞물림  — 맞물림 톱니 D104 → 기어 조립대 X 사용 → power_node_energized("gate_gear") →
##                     협곡 잔교 g 셀 순차 walkable (기어열 회전 연출).
##   G2 증기 보일러  — 압력 밸브 D105 → 대형 보일러 E 사용 + 젖은 석탄 D106 소지 → 밸브문 v 개방
##                     + **에너지 Whisper ×1 획득** (§보완 필수, 정확히 1회).
##   G3 멈춘 승강기  — 평형추 D108 → 승강기 제어반 C 사용 → power_node_energized("elevator") →
##                     승강기 L 셀 walkable (상부 플랫폼 해금).
##   G4 대시계 재가동 — 태엽심장 D111(whisper_cost energy:1) → 대시계 배전반 K 사용 →
##                     power_node_energized("clock_core") → Layer 3 정화 컷신 → layer3_purified +
##                     time_running 복구 (v0.6.1 페어링 규칙).
##
## Uses the item_used_on_object framework path (real interaction) via the invisible use-targets the
## controller wraps around the assembly/boiler/ctrl/mount sprites. L3 key items injected here.
##
## Prints PASS/FAIL per check; quits with the failure count as exit code.

const CITY := "res://scenes/world/clockwork_city.tscn"

var _fail := 0
var _purified := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L3 GATES HARNESS (전력 노드 / 게이트 / 에너지 Whisper) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	WhisperCurrency.reset()
	SaveManager.pending_load = false

	var scene: PackedScene = load(CITY)
	var map := scene.instantiate()
	add_child(map)
	# Let the loader spawn objects + the gate controller wire itself (deferred + 2 frames).
	for i in range(6):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L3GateController")
	_check("loader present", loader != null)
	_check("L3GateController present", gates != null)
	if loader == null or gates == null:
		print("=== RESULT: FAIL (missing core nodes) ===")
		get_tree().quit(1)
		return

	GameState.layer3_purified.connect(func(_l): _purified = true)

	_test_legend(loader)
	_test_gather_craft_chain(loader)
	_test_return_portal()
	await _test_g1_gear_bridge(loader)
	await _test_g2_boiler_and_whisper(loader, map)
	_test_whisper_cost()
	await _test_g3_elevator(loader)
	await _test_g4_purification(loader)
	_test_persistence()
	await _test_persistence_reapply(loader)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- (a) legend gate records ---------------------------------------------

func _test_legend(loader: MapLoader) -> void:
	var g: Dictionary = loader.legend_gates()
	_check("legend_gates() has G1..G4",
		g.has("G1") and g.has("G2") and g.has("G3") and g.has("G4"))
	_check("G1 node_id = gate_gear", String(g.get("G1", {}).get("node_id", "")) == "gate_gear",
		"node_id=%s" % String(g.get("G1", {}).get("node_id", "")))
	# G2 uses a `target` (boiler) rather than a power node_id in the legend.
	_check("G2 target = boiler", String(g.get("G2", {}).get("target", "")) == "boiler",
		"target=%s" % String(g.get("G2", {}).get("target", "")))
	_check("G3 node_id = elevator", String(g.get("G3", {}).get("node_id", "")) == "elevator",
		"node_id=%s" % String(g.get("G3", {}).get("node_id", "")))
	_check("G4 node_id = clock_core", String(g.get("G4", {}).get("node_id", "")) == "clock_core",
		"node_id=%s" % String(g.get("G4", {}).get("node_id", "")))


# ---- (b) G1 gear bridge ---------------------------------------------------

func _test_g1_gear_bridge(loader: MapLoader) -> void:
	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var bridge_cells := _cells(g1.get("bridge_cells", []))
	_check("G1 bridge cells present in legend", bridge_cells.size() >= 4, "n=%d" % bridge_cells.size())
	var any: Vector2i = bridge_cells[0] if not bridge_cells.is_empty() else Vector2i(-1, -1)
	_check("기어 잔교 tile starts NON-walkable (dark, 통행 불가)",
		any != Vector2i(-1, -1) and not loader.is_cell_walkable(any))

	# Drive the real interaction path: hold 맞물림 톱니 D104, use on the gear_assembly use-target.
	Inventory.add("D104", 1)
	var target := _find_use_target(loader, "gear_assembly")
	_check("gear_assembly use-target wired (기어 조립대 X)", target != null)
	if target != null:
		Inventory.remove("D104", 1)
		GameState.item_used_on_object.emit("D104", target)
	_check("power_node 'gate_gear' recorded in powered_nodes",
		GameState.is_power_node_energized("gate_gear"))
	# Staggered light timers fire (0.12s * up to 4 cells). SceneTreeTimer uses REAL time.
	await get_tree().create_timer(1.2).timeout
	var all_walk := true
	for c in bridge_cells:
		if not loader.is_cell_walkable(c):
			all_walk = false
	_check("G1 톱니 맞물림 후 전 잔교 타일 walkable (물리+AStar 갱신)", all_walk)


# ---- (c) G2 boiler + steam valve door + energy Whisper --------------------

func _test_g2_boiler_and_whisper(loader: MapLoader, map: Node) -> void:
	var g2: Dictionary = loader.legend_gates().get("G2", {})
	var door_cells := _cells(g2.get("door_cells", []))
	_check("G2 door cells present", door_cells.size() >= 2, "n=%d" % door_cells.size())
	var d0: Vector2i = door_cells[0] if not door_cells.is_empty() else Vector2i(-1, -1)
	_check("밸브문 starts NON-walkable (잠김)",
		d0 != Vector2i(-1, -1) and not loader.is_cell_walkable(d0))

	# G2 needs the valve D105 used on the boiler AND 젖은 석탄 D106 in hand.
	Inventory.add("D106", 1)   # 젖은 석탄 (held-item requirement)
	Inventory.add("D105", 1)   # 압력 밸브
	var boiler := _find_use_target(loader, "boiler")
	_check("boiler use-target wired (대형 보일러 E)", boiler != null)
	var energy_before := WhisperCurrency.energy
	if boiler != null:
		Inventory.remove("D105", 1)
		GameState.item_used_on_object.emit("D105", boiler)
	# Allow the door swap + whisper grant.
	for i in range(6):
		await get_tree().process_frame
	var door_open := true
	for c in door_cells:
		if not loader.is_cell_walkable(c):
			door_open = false
	_check("G2 밸브→보일러 사용 → 밸브문 v 개방 (walkable)", door_open)
	_check("boiler power node recorded", GameState.is_power_node_energized("boiler"))
	_check("에너지 Whisper ×1 획득 (G2 보상, 필수)", WhisperCurrency.energy == energy_before + 1,
		"energy=%d" % WhisperCurrency.energy)

	# Idempotent reward: re-emitting the use does NOT grant a 2nd energy.
	var energy_after := WhisperCurrency.energy
	Inventory.add("D105", 1)
	if boiler != null:
		Inventory.remove("D105", 1)
		GameState.item_used_on_object.emit("D105", boiler)
	for i in range(4):
		await get_tree().process_frame
	_check("G2 보상 idempotent (재사용 시 2번째 에너지 미지급)",
		WhisperCurrency.energy == energy_after, "energy=%d" % WhisperCurrency.energy)

	var hud := map.get_node_or_null("WhisperHUD")
	_check("WhisperHUD present", hud != null)


# ---- (d) whisper_cost recipe ----------------------------------------------

func _test_whisper_cost() -> void:
	# L3-R09 태엽심장 = D109 + D109 (심장 뼈대 둘), whisper_cost energy:1 (§보완 재화 소모 계약).
	var recipe := RecipeDB.find_recipe(["D109", "D109"])
	_check("L3-R09 recipe (태엽심장) exists", not recipe.is_empty())
	_check("L3-R09 output = D111 (태엽심장)", String(recipe.get("output", "")) == "D111",
		"output=%s" % String(recipe.get("output", "")))
	_check("L3-R09 carries whisper_cost energy:1",
		int(RecipeDB.whisper_cost(recipe).get("energy", 0)) == 1)

	# Drive the Fusion path (mirrors l2 _test_whisper_cost). Drain energy → shortfall no-op.
	Inventory.clear()
	while WhisperCurrency.energy > 0:
		WhisperCurrency.spend_energy(WhisperCurrency.energy)
	Inventory.add("D109", 2)   # two 심장 뼈대 (same-ingredient recipe)
	var res_fail := Fusion.fuse("D109", "D109")
	_check("에너지 부족 시 fuse 실패 (재화 없음)", not res_fail["matched"])
	_check("실패 사유 = '에너지가 부족하다'", String(res_fail.get("failure_reason", "")) == "에너지가 부족하다")
	_check("실패 시 재료 미소모 (D109 2 잔존)", Inventory.count("D109") == 2)

	# Grant energy → the fuse succeeds and consumes 1 energy + the two pieces.
	WhisperCurrency.add_energy(1)
	var res_ok := Fusion.fuse("D109", "D109")
	_check("에너지 충분 시 fuse 성공 → 태엽심장(D111) 산출",
		res_ok["matched"] and res_ok["output"] == "D111")
	_check("성공 시 에너지 1 소모 (0으로)", WhisperCurrency.energy == 0, "energy=%d" % WhisperCurrency.energy)
	_check("성공 시 재료 소모 (D109 0)", Inventory.count("D109") == 0)
	Inventory.clear()


# ---- (e) G3 elevator ------------------------------------------------------

func _test_g3_elevator(loader: MapLoader) -> void:
	var g3: Dictionary = loader.legend_gates().get("G3", {})
	var lift_cells := _cells(g3.get("lift_cells", []))
	_check("G3 lift cells present", lift_cells.size() >= 2, "n=%d" % lift_cells.size())
	var l0: Vector2i = lift_cells[0] if not lift_cells.is_empty() else Vector2i(-1, -1)
	_check("승강기 lift tile starts NON-walkable (멈춤)",
		l0 != Vector2i(-1, -1) and not loader.is_cell_walkable(l0))

	Inventory.add("D108", 1)   # 평형추
	var ctrl := _find_use_target(loader, "elevator_ctrl")
	_check("elevator_ctrl use-target wired (승강기 제어반 C)", ctrl != null)
	if ctrl != null:
		Inventory.remove("D108", 1)
		GameState.item_used_on_object.emit("D108", ctrl)
	_check("power_node 'elevator' recorded", GameState.is_power_node_energized("elevator"))
	for i in range(4):
		await get_tree().process_frame
	var lift_walk := true
	for c in lift_cells:
		if not loader.is_cell_walkable(c):
			lift_walk = false
	_check("G3 승강기 재가동 → lift 셀 walkable (상부 플랫폼 해금)", lift_walk)


# ---- (f) G4 grand clock reactivation → purification -----------------------

func _test_g4_purification(loader: MapLoader) -> void:
	_check("정화 전 layer3_purified_flag = false", not GameState.layer3_purified_flag)
	Inventory.add("D111", 1)   # 태엽심장
	var mount := _find_use_target(loader, "clock_mount")
	_check("clock_mount use-target wired (대시계 배전반 K)", mount != null)
	if mount != null:
		Inventory.remove("D111", 1)
		GameState.item_used_on_object.emit("D111", mount)
	_check("power_node 'clock_core' recorded", GameState.is_power_node_energized("clock_core"))
	# The purification cutscene runs (~3s of real-time timers). Poll with a real-time wait.
	for i in range(60):
		await get_tree().create_timer(0.1).timeout
		if GameState.layer3_purified_flag:
			break
	_check("G4 대시계 재가동 → Layer 3 정화 플래그 set", GameState.layer3_purified_flag)
	_check("정화 컷신 → layer3_purified 시그널 발화", _purified)
	# time_running restored after the cutscene (v0.6.1 pairing rule).
	_check("정화 컷신 후 time_running 복구 (v0.6.1 페어링)", GameState.time_running)


# ---- (g) persistence in the save dict -------------------------------------

func _test_persistence() -> void:
	var d := SaveManager.build_save_dict()
	var pn: Dictionary = d.get("powered_nodes", {})
	_check("save dict carries powered_nodes (L3 node ids)",
		d.has("powered_nodes") and pn.has("gate_gear") and pn.has("boiler")
		and pn.has("elevator") and pn.has("clock_core"))
	_check("save dict carries layer3_purified", bool(d.get("layer3_purified", false)))
	_check("save dict carries whisper 재화", d.has("whisper"))


## A FRESH controller booted with the GameState flags pre-set must re-apply the energized
## end-state (bridge/door/lift already walkable) via _reapply_persisted_state — mirror l2.
func _test_persistence_reapply(loader: MapLoader) -> void:
	# The flags from the drive above are still set (gate_gear/boiler/elevator energized + purified).
	_check("(사전조건) 급전 플래그 유지", GameState.is_power_node_energized("gate_gear")
		and GameState.is_power_node_energized("boiler")
		and GameState.is_power_node_energized("elevator"))
	# Spawn a fresh L3GateController pointed at the SAME live loader → _reapply_persisted_state.
	var fresh: Node = load("res://scripts/world/l3_gate_controller.gd").new()
	add_child(fresh)
	fresh.set("map_loader_path", fresh.get_path_to(loader))
	# _setup runs deferred (+2 frames); give it a real beat for any instant reapply.
	for i in range(6):
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var g2: Dictionary = loader.legend_gates().get("G2", {})
	var g3: Dictionary = loader.legend_gates().get("G3", {})
	var bridge := _cells(g1.get("bridge_cells", []))
	var door := _cells(g2.get("door_cells", []))
	var lift := _cells(g3.get("lift_cells", []))
	var ok := true
	for c in bridge + door + lift:
		if not loader.is_cell_walkable(c):
			ok = false
	_check("_reapply_persisted_state → 브리지/문/리프트 즉시 walkable (재진입 복원)", ok)
	if is_instance_valid(fresh):
		fresh.queue_free()


# ---- (h) gather sources (K1-K7) + craft chain -----------------------------

func _test_gather_craft_chain(loader: MapLoader) -> void:
	# All 7 K-element gatherables must be represented by at least one spawned Gatherable.
	var seen := {}
	for key in loader.l2_object_nodes:
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node is Gatherable:
			seen[String((node as Gatherable).item_id)] = true
	var missing := []
	for k in ["K1", "K2", "K3", "K4", "K5", "K6", "K7"]:
		if not seen.has(k):
			missing.append(k)
	_check("K1-K7 채집원 전부 맵에 존재", missing.is_empty(), "missing=%s" % [missing])

	# Craft 맞물림 톱니 D104 via the L3-R01 → L3-R02 chain (proves the G1 key is craftable e2e).
	Inventory.clear()
	Inventory.add("K2", 1); Inventory.add("K3", 1)
	var d103 := Fusion.fuse("K2", "K3")            # L3-R01: 황동 톱니판 D103
	Inventory.add("K1", 1)
	var d104 := Fusion.fuse("D103", "K1")          # L3-R02: 맞물림 톱니 D104
	_check("맞물림 톱니(D104) = 톱니판(K2+K3)→(+K1) 다단 크래프트 성공",
		d103["output"] == "D103" and d104["output"] == "D104" and Inventory.count("D104") == 1)
	Inventory.clear()


# ---- (i) return portal ----------------------------------------------------

func _test_return_portal() -> void:
	# The clockwork_city session spawns a ReturnPortalController with the "홈으로 돌아가기" prompt.
	var found := false
	var prompt_ok := false
	for n in _all_nodes(get_tree().root):
		if n.get_class() == "Node" and n.has_method("entry_prompt_text"):
			pass
	# ReturnPortalController spawns a Portal in the "gatherable" group (same as grove/L2).
	for n in get_tree().get_nodes_in_group("gatherable"):
		if n is Portal:
			found = true
			if String((n as Portal).entry_prompt_text()).findn("홈으로") >= 0:
				prompt_ok = true
	# Fallback: the ReturnPortalController itself carries the prompt string.
	if not prompt_ok:
		for n in _all_nodes(get_tree().root):
			if n.has_method("get") and n.has_method("setup") and "_prompt" in n:
				if String(n.get("_prompt")).findn("홈으로") >= 0:
					found = true
					prompt_ok = true
	_check("L3 귀환 포탈 present (clockwork_city 스폰)", found)
	_check("L3 귀환 포탈 프롬프트 = '홈으로 돌아가기'", prompt_ok)


# ---- helpers --------------------------------------------------------------

func _cells(arr: Array) -> Array:
	var out: Array = []
	for e in arr:
		if e is Array and e.size() >= 2:
			out.append(Vector2i(int(e[0]), int(e[1])))
	return out


## Find the invisible Gatherable use-target the controller attached to a structure sprite.
func _find_use_target(loader: MapLoader, object_id: String) -> Node:
	for key in loader.l2_object_nodes.keys():
		if String(key).split("@")[0] == object_id:
			var node: Node = loader.l2_object_nodes[key].get("node")
			if node == null:
				continue
			for ch in node.get_children():
				if ch is Gatherable and String((ch as Gatherable).object_id) == object_id:
					return ch
			return node
	return null


func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out += _all_nodes(c)
	return out
