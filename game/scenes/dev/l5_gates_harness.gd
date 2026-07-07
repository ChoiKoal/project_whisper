extends Node
## (L5-3) Layer-5 봉헌/응답 게이트 + 생명(vita) Whisper acceptance harness. Boots the REAL
## cathedral.tscn (the scene the divinity portal travels to) and drives each of the four
## 봉헌/응답 게이트 through its real controller + signals — the L5 mirror of l4_gates_harness
## (§C-3 동일 시그널 패턴, node_id/키아이템만 교체; L5 정화 = "응답 없는 세계에, 우리가 대답함"):
##   G1 등불 봉헌   — 성소의 등불 D178 → 성소 등불 제단(lantern_altar) 봉헌 →
##                    power_node_energized("lantern_path") → 꺼진 참배길 g 셀 순차 walkable.
##   G2 생명의 샘   — 생명의 씨 D180 → 생명의 샘(life_spring) 사용 → 밸브문 e 개방
##                    + **생명 Whisper ×1 획득** (§보완 필수, L5 첫 vita, 정확히 1회, idempotent).
##   G3 침묵의 회랑 — 침묵의 성가 D182 소지 상태 폴링(L4 부적 held-item 패턴) → 침묵 병목 Y walkable +
##                    **BGM 덕킹**. 무성가 → 재차단 + BGM 복구. 장착·소모 아닌 소지 판정 (신규 조작 0).
##   G4 대제단 봉헌 — 응답 D186(whisper_cost {energy:1, mana:1, vita:1}) → 봉헌 제단(offering_altar)
##                    → power_node_energized("great_altar") → Layer 5 정화(응답) 컷신 →
##                    layer5_purified + time_running/control_lock 복구 (v0.6.1 페어링 규칙).
##
## 어서션 3종 (CLAUDE.md 필수):
##   ① 3속성(energy/mana/vita) 중 하나라도 0 → 「응답」(D186, whisper_cost 3키) 조합 거부 (재료 미소모).
##   ② 3속성 전부 보유 → 조합 성공 + 세 속성 전부 소모(각 0).
##   ③ 재획득처 A(발전 제단, 에너지)·B(마력 성물함, 마력) 재방문 시 중복 지급 없음 (idempotent).
##
## Uses the item_used_on_object framework path (real interaction) via the invisible use-targets the
## controller wraps around the altar/spring/mount sprites. L5 key items injected here.
##
## Prints PASS/FAIL per check; quits with the failure count as exit code.

const CATHEDRAL := "res://scenes/world/cathedral.tscn"

## (L5-4) The 「응답」 gate is the REAL L5-R10 recipe now that items.json/recipes.json carry it:
## 봉헌의 그릇(D183) 둘 → 응답(D186), whisper_cost{energy:1,mana:1,vita:1}. The stub 합성 레시피 is
## retired — the harness now exercises the shipped data path directly (same-pair D183+D183).
const RESP_A := "D183"
const RESP_B := "D183"

var _fail := 0
var _purified := false
var _purified_layer := ""


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L5 GATES HARNESS (봉헌/응답 게이트 / 생명 Whisper) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	GameState.reset_layer4()
	GameState.reset_layer5()
	WhisperCurrency.reset()
	SaveManager.pending_load = false

	var scene: PackedScene = load(CATHEDRAL)
	var map := scene.instantiate()
	add_child(map)
	# Let the loader spawn objects + the gate controller wire itself (deferred + 2 frames).
	for _i in range(8):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L5GateController")
	_check("loader present", loader != null)
	_check("L5GateController present", gates != null)
	if loader == null or gates == null:
		print("=== RESULT: FAIL (missing core nodes) ===")
		get_tree().quit(1)
		return

	# (L5-4) The L5 key items (D178/D180/D182/D183/D186) now ship in items.json — assert they are real
	# ItemDB records (no stubs). If any are missing the data step regressed.
	_assert_real_l5_items()

	if GameState.has_signal("layer5_purified"):
		GameState.layer5_purified.connect(func(l):
			_purified = true
			_purified_layer = l)

	_test_legend(loader)
	await _test_g1_lantern_offering(loader)
	await _test_g2_spring_and_vita_whisper(loader, map)
	await _test_g3_silence_corridor(loader)
	_test_g4_whisper_cost_trio()       # 어서션 ①②
	await _test_reacquire_idempotent(loader)   # 어서션 ③
	await _test_g4_altar_purification(loader)
	_test_persistence()
	await _test_persistence_reapply(loader)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- (a) legend gate records ---------------------------------------------

func _test_legend(loader: MapLoader) -> void:
	var g: Dictionary = loader.legend_gates()
	_check("legend_gates() has G1..G4",
		g.has("G1") and g.has("G2") and g.has("G3") and g.has("G4"))
	# G1 node_id = dead_lantern (unique to the cathedral legend; the controller's _is_l5 sentinel).
	_check("G1 node_id = dead_lantern", String(g.get("G1", {}).get("node_id", "")) == "dead_lantern",
		"node_id=%s" % String(g.get("G1", {}).get("node_id", "")))
	# G2 uses a `target` (life_spring) rather than a power node_id in the legend.
	_check("G2 target = life_spring", String(g.get("G2", {}).get("target", "")) == "life_spring",
		"target=%s" % String(g.get("G2", {}).get("target", "")))
	_check("G3 hymn_item = D182 (소지형)", String(g.get("G3", {}).get("hymn_item", "")) == "D182",
		"hymn=%s" % String(g.get("G3", {}).get("hymn_item", "")))
	_check("G4 node_id = offering_altar", String(g.get("G4", {}).get("node_id", "")) == "offering_altar",
		"node_id=%s" % String(g.get("G4", {}).get("node_id", "")))


# ---- (b) G1 등불 봉헌 (참배길 순차 점등) ----------------------------------

func _test_g1_lantern_offering(loader: MapLoader) -> void:
	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var bridge_cells := _cells(g1.get("bridge_cells", []))
	_check("G1 참배길 cells present in legend", bridge_cells.size() >= 4, "n=%d" % bridge_cells.size())
	var any: Vector2i = bridge_cells[0] if not bridge_cells.is_empty() else Vector2i(-1, -1)
	_check("꺼진 참배길 tile starts NON-walkable (봉인, 통행 불가)",
		any != Vector2i(-1, -1) and not loader.is_cell_walkable(any))

	# Drive the real interaction path: hold 성소의 등불 D178, use on the lantern_altar use-target.
	Inventory.add("D178", 1)
	var target := _find_use_target(loader, "lantern_altar")
	_check("lantern_altar use-target wired (성소 등불 제단)", target != null)
	if target != null:
		Inventory.remove("D178", 1)
		GameState.item_used_on_object.emit("D178", target)
	# (GP-6 §2) 봉헌 → 음 순서 퍼즐 모달 → 스킵(=그냥 봉헌=동일 energize)으로 급전 실경로 완주.
	await get_tree().process_frame
	_check("G1 승격 퍼즐(chime) 모달 개방 + 스킵 경로 해소", _resolve_gate_puzzle_if_open())
	_check("power_node 'lantern_path' recorded in powered_nodes",
		GameState.is_power_node_energized("lantern_path"))
	# Staggered light timers fire (0.12s * up to N cells). SceneTreeTimer uses REAL time.
	await get_tree().create_timer(1.4).timeout
	var all_walk := true
	for c in bridge_cells:
		if not loader.is_cell_walkable(c):
			all_walk = false
	_check("G1 참배길 순차 점등 후 전 셀 walkable (물리+AStar 갱신)", all_walk)


# ---- (c) G2 생명의 샘 + 밸브문 + 생명 Whisper (필수) -----------------------

func _test_g2_spring_and_vita_whisper(loader: MapLoader, map: Node) -> void:
	var g2: Dictionary = loader.legend_gates().get("G2", {})
	var door_cells := _cells(g2.get("door_cells", []))
	_check("G2 밸브문 cells present", door_cells.size() >= 2, "n=%d" % door_cells.size())
	var d0: Vector2i = door_cells[0] if not door_cells.is_empty() else Vector2i(-1, -1)
	_check("생명의 밸브문 starts NON-walkable (봉인)",
		d0 != Vector2i(-1, -1) and not loader.is_cell_walkable(d0))

	# G2 needs 생명의 씨 D180 used on the life_spring.
	Inventory.add("D180", 1)
	var spring := _find_use_target(loader, "life_spring")
	_check("life_spring use-target wired (생명의 샘 E)", spring != null)
	var vita_before := WhisperCurrency.vita
	if spring != null:
		Inventory.remove("D180", 1)
		GameState.item_used_on_object.emit("D180", spring)
	# Allow the door swap + whisper grant.
	for _i in range(6):
		await get_tree().process_frame
	var door_open := true
	for c in door_cells:
		if not loader.is_cell_walkable(c):
			door_open = false
	_check("G2 생명의씨→샘 사용 → 밸브문 e 개방 (walkable)", door_open)
	_check("life_spring power node recorded", GameState.is_power_node_energized("life_spring"))
	_check("생명 Whisper ×1 획득 (G2 보상, 필수, L5 첫 vita)",
		WhisperCurrency.vita == vita_before + 1, "vita=%d" % WhisperCurrency.vita)

	# Idempotent reward: re-emitting the use does NOT grant a 2nd vita.
	var vita_after := WhisperCurrency.vita
	Inventory.add("D180", 1)
	if spring != null:
		Inventory.remove("D180", 1)
		GameState.item_used_on_object.emit("D180", spring)
	for _i in range(4):
		await get_tree().process_frame
	_check("G2 보상 idempotent (재사용 시 2번째 vita 미지급)",
		WhisperCurrency.vita == vita_after, "vita=%d" % WhisperCurrency.vita)

	var hud := map.get_node_or_null("WhisperHUD")
	_check("WhisperHUD present (생명 3번째 자릿수)", hud != null)


# ---- (d) G3 침묵의 회랑 (성가 소지 → walkable swap + BGM 덕킹) --------------

func _test_g3_silence_corridor(loader: MapLoader) -> void:
	var g3: Dictionary = loader.legend_gates().get("G3", {})
	var gate_cells := _cells(g3.get("gate_cells", []))
	_check("G3 침묵 병목 cells present", gate_cells.size() >= 2, "n=%d" % gate_cells.size())
	var c0: Vector2i = gate_cells[0] if not gate_cells.is_empty() else Vector2i(-1, -1)
	_check("침묵의 회랑 tile starts NON-walkable (봉인)",
		c0 != Vector2i(-1, -1) and not loader.is_cell_walkable(c0))
	_check("BGM 덕킹 off at boot", not _bgm_ducked())

	# Hold 침묵의 성가 D182 → the controller's per-frame poll opens the corridor + ducks BGM.
	Inventory.add("D182", 1)
	for _i in range(4):
		await get_tree().process_frame
	var corridor_walk := true
	for c in gate_cells:
		if not loader.is_cell_walkable(c):
			corridor_walk = false
	_check("G3 성가 소지 → 침묵의 회랑 walkable (통과)", corridor_walk)
	_check("G3 성가 소지 → BGM 덕킹 on (입술 없는 노래만)", _bgm_ducked())

	# Drop the hymn → the corridor re-seals + BGM restores (소지형: 무성가 차단).
	Inventory.remove("D182", 1)
	for _i in range(4):
		await get_tree().process_frame
	var resealed := true
	for c in gate_cells:
		if loader.is_cell_walkable(c):
			resealed = false
	_check("G3 성가 미소지 → 침묵의 회랑 재차단 (무성가 통행 불가)", resealed)
	_check("G3 성가 미소지 → BGM 덕킹 off (복구)", not _bgm_ducked())

	# Restore the hymn so the corridor stays passable for the final gate (real journey order).
	Inventory.add("D182", 1)
	for _i in range(4):
		await get_tree().process_frame
	Inventory.remove("D182", 1)   # keep it out of the way for the whisper-cost fuse assertions
	for _i in range(2):
		await get_tree().process_frame


# ---- (e) 어서션 ①② — 「응답」(D186) 3속성 whisper_cost gate --------------------
##   ① energy/mana/vita 중 하나라도 0 → 조합 거부 (재료 미소모).
##   ② 3속성 전부 보유 → 성공 + 세 속성 전부 소모(각 0).

func _test_g4_whisper_cost_trio() -> void:
	var recipe := RecipeDB.find_recipe([RESP_A, RESP_B])
	_check("「응답」 실 레시피(L5-R10) 등록됨", not recipe.is_empty()
		and String(recipe.get("output", "")) == "D186",
		"id=%s out=%s" % [String(recipe.get("id", "")), String(recipe.get("output", ""))])
	var wc := RecipeDB.whisper_cost(recipe)
	_check("「응답」 whisper_cost 3키 {energy:1,mana:1,vita:1}",
		int(wc.get("energy", 0)) == 1 and int(wc.get("mana", 0)) == 1 and int(wc.get("vita", 0)) == 1,
		"cost=%s" % str(wc))

	# ① 각 속성이 0인 세 조합 각각 조합 거부 + 재료 미소모.
	_assert_reject_when_missing("energy", "에너지가 부족하다")
	_assert_reject_when_missing("mana", "마력이 부족하다")
	_assert_reject_when_missing("vita", "생명이 부족하다")

	# ② 3속성 전부 1 보유 → 성공 + 세 속성 전부 0으로 소모.
	_drain_all()
	WhisperCurrency.add_energy(1)
	WhisperCurrency.add_mana(1)
	WhisperCurrency.add_vita(1)
	Inventory.clear()
	Inventory.add(RESP_A, 1)
	Inventory.add(RESP_B, 1)
	var res_ok := Fusion.fuse(RESP_A, RESP_B)
	_check("3속성 보유 → 「응답」 fuse 성공", res_ok["matched"], "reason=%s" % String(res_ok.get("failure_reason", "")))
	_check("성공 산출 = 응답(D186)", String(res_ok.get("output", "")) == "D186",
		"out=%s" % String(res_ok.get("output", "")))
	_check("성공 시 energy 전소모 (0)", WhisperCurrency.energy == 0, "energy=%d" % WhisperCurrency.energy)
	_check("성공 시 mana 전소모 (0)", WhisperCurrency.mana == 0, "mana=%d" % WhisperCurrency.mana)
	_check("성공 시 vita 전소모 (0)", WhisperCurrency.vita == 0, "vita=%d" % WhisperCurrency.vita)
	Inventory.clear()


## Drain all three attributes, grant the OTHER two, leave `missing` at 0, and assert the fuse rejects
## with the expected reason and consumes NO material.
func _assert_reject_when_missing(missing: String, reason: String) -> void:
	_drain_all()
	if missing != "energy":
		WhisperCurrency.add_energy(1)
	if missing != "mana":
		WhisperCurrency.add_mana(1)
	if missing != "vita":
		WhisperCurrency.add_vita(1)
	Inventory.clear()
	Inventory.add(RESP_A, 1)
	Inventory.add(RESP_B, 1)
	var res := Fusion.fuse(RESP_A, RESP_B)
	_check("%s 0 → 「응답」 조합 거부" % missing, not res["matched"])
	_check("%s 부족 사유 = '%s'" % [missing, reason],
		String(res.get("failure_reason", "")) == reason, "reason=%s" % String(res.get("failure_reason", "")))
	# 봉헌의 그릇² same-pair → 재료 = D183 두 개. 거부 시 둘 다 잔존해야 한다.
	_check("%s 거부 시 재료 미소모 (D183² 잔존)" % missing,
		Inventory.count("D183") == 2)
	Inventory.clear()


# ---- (f) 어서션 ③ — 재획득처 A/B idempotent (재방문 중복 없음) ----------------

func _test_reacquire_idempotent(loader: MapLoader) -> void:
	_drain_all()
	var dyn := _find_use_target(loader, "pilgrim_dynamo")
	var rel := _find_use_target(loader, "mana_reliquary")
	_check("발전 제단 A (pilgrim_dynamo) spawned + use-target", dyn != null)
	_check("마력 성물함 B (mana_reliquary) spawned + use-target", rel != null)

	# First use of A grants +1 energy; B grants +1 mana.
	var e0 := WhisperCurrency.energy
	if dyn != null:
		GameState.item_used_on_object.emit("", dyn)
	for _i in range(2):
		await get_tree().process_frame
	_check("발전 제단 A 첫 사용 → 에너지 +1", WhisperCurrency.energy == e0 + 1,
		"energy=%d" % WhisperCurrency.energy)
	var m0 := WhisperCurrency.mana
	if rel != null:
		GameState.item_used_on_object.emit("", rel)
	for _i in range(2):
		await get_tree().process_frame
	_check("마력 성물함 B 첫 사용 → 마력 +1", WhisperCurrency.mana == m0 + 1,
		"mana=%d" % WhisperCurrency.mana)

	# Re-visit (re-use) A and B: idempotent guards must block a 2nd grant.
	var e1 := WhisperCurrency.energy
	var m1 := WhisperCurrency.mana
	if dyn != null:
		GameState.item_used_on_object.emit("", dyn)
	if rel != null:
		GameState.item_used_on_object.emit("", rel)
	for _i in range(3):
		await get_tree().process_frame
	_check("어서션③ A 재방문 → 에너지 중복 지급 없음", WhisperCurrency.energy == e1,
		"energy=%d" % WhisperCurrency.energy)
	_check("어서션③ B 재방문 → 마력 중복 지급 없음", WhisperCurrency.mana == m1,
		"mana=%d" % WhisperCurrency.mana)


# ---- (g) G4 대제단 봉헌 = Layer 5 정화(응답) -------------------------------

func _test_g4_altar_purification(loader: MapLoader) -> void:
	_check("정화 전 layer5_purified_flag = false", not GameState.layer5_purified_flag)
	var pre_time := GameState.time_running
	_check("정화 전 time_running = true (사전조건)", pre_time)
	Inventory.add("D186", 1)   # 응답
	var mount := _find_use_target(loader, "offering_altar")
	_check("offering_altar use-target wired (대제단 봉헌대, 컨트롤러 스폰)", mount != null)
	if mount != null:
		Inventory.remove("D186", 1)
		GameState.item_used_on_object.emit("D186", mount)
	_check("power_node 'great_altar' recorded", GameState.is_power_node_energized("great_altar"))
	# input lock engages during the cutscene (v0.6.1 페어링 규칙).
	_check("정화 컷신 중 control lock 걸림 (input lock)", GameState.control_locked())
	_check("정화 컷신 중 time_running false (페어링)", not GameState.time_running)
	# The purification cutscene runs (~3s of real-time timers). Poll with a real-time wait.
	for _i in range(70):
		await get_tree().create_timer(0.1).timeout
		if GameState.layer5_purified_flag:
			break
	_check("G4 대제단 봉헌 → Layer 5 정화 플래그 set", GameState.layer5_purified_flag)
	_check("정화 컷신 → layer5_purified 시그널 발화", _purified)
	_check("정화 시그널 payload = 'divinity'", _purified_layer == "divinity", "layer=%s" % _purified_layer)
	# time_running + control lock restored after the cutscene (v0.6.1 페어링 규칙).
	_check("정화 컷신 후 time_running 복구 (v0.6.1 페어링)", GameState.time_running)
	_check("정화 컷신 후 control lock 해제 (input lock 복구)", not GameState.control_locked())


# ---- (h) persistence in the save dict -------------------------------------

func _test_persistence() -> void:
	var d := SaveManager.build_save_dict()
	var pn: Dictionary = d.get("powered_nodes", {})
	_check("save dict carries powered_nodes (L5 node ids)",
		d.has("powered_nodes") and pn.has("lantern_path") and pn.has("life_spring")
		and pn.has("great_altar"))
	_check("save dict carries layer5_purified", bool(d.get("layer5_purified", false)))
	var w: Dictionary = d.get("whisper", {})
	_check("save dict carries whisper 재화 (vita 포함)", d.has("whisper") and w.has("vita"))


## A FRESH controller booted with the GameState flags pre-set must re-apply the energized
## end-state (참배길/밸브문 already walkable) via _reapply_persisted_state — mirror l4.
func _test_persistence_reapply(loader: MapLoader) -> void:
	_check("(사전조건) 급전 플래그 유지", GameState.is_power_node_energized("lantern_path")
		and GameState.is_power_node_energized("life_spring"))
	var fresh: Node = load("res://scripts/world/l5_gate_controller.gd").new()
	add_child(fresh)
	fresh.set("map_loader_path", fresh.get_path_to(loader))
	# _setup runs deferred (+2 frames); give it a real beat for any instant reapply.
	for _i in range(8):
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var g2: Dictionary = loader.legend_gates().get("G2", {})
	var bridge := _cells(g1.get("bridge_cells", []))
	var door := _cells(g2.get("door_cells", []))
	var ok := true
	for c in bridge + door:
		if not loader.is_cell_walkable(c):
			ok = false
	_check("_reapply_persisted_state → 참배길/밸브문 즉시 walkable (재진입 복원)", ok)
	if is_instance_valid(fresh):
		fresh.queue_free()


# ---- helpers --------------------------------------------------------------

func _bgm_ducked() -> bool:
	return typeof(AudioManager) != TYPE_NIL and bool(AudioManager.get("_bgm_ducked"))


func _drain_all() -> void:
	while WhisperCurrency.energy > 0:
		WhisperCurrency.spend_energy(WhisperCurrency.energy)
	while WhisperCurrency.mana > 0:
		WhisperCurrency.spend_mana(WhisperCurrency.mana)
	while WhisperCurrency.vita > 0:
		WhisperCurrency.spend_vita(WhisperCurrency.vita)


## (L5-4) Assert the L5 key items now ship as real ItemDB records (stubs retired). The G3 held-hymn
## poll uses a real Inventory.has check, and the G4 gate consumes the real 봉헌의 그릇(D183) pair.
func _assert_real_l5_items() -> void:
	for id in ["D178", "D180", "D182", "D183", "D186"]:
		_check("실 items.json 레코드 존재: %s" % id, ItemDB.has_item(id))


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
	# The mount / A / B are controller-spawned (not in l2_object_nodes); search the ysort layer.
	var ys := loader.get_node_or_null(loader.ysort_layer_path) as Node2D
	if ys != null:
		for child in ys.get_children():
			if child is Sprite2D and child.has_meta("object_id") \
					and String(child.get_meta("object_id")) == object_id:
				for ch in child.get_children():
					if ch is Gatherable and String((ch as Gatherable).object_id) == object_id:
						return ch
				return child
	return null


func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out += _all_nodes(c)
	return out


## (GP-6 §2 정합) G1 승격이 GatePuzzle 모달(GP-5 §3)을 거쳐 energize—skip==그냥 장착==동일 개방.
## current_scene 아래로 붙은 열린 퍼즐을 찾아 스킵 경로로 해소.
func _resolve_gate_puzzle_if_open() -> bool:
	for n in _all_nodes(get_tree().root):
		if n is GatePuzzle:
			(n as GatePuzzle).skip_for_test()
			return true
	return false
