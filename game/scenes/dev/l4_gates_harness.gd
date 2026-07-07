extends Node
## (L4-3) Layer-4 게이트 + 마력 Whisper acceptance harness. Boots the REAL mage_tower.tscn (the scene
## the magic portal travels to) and drives each of the four 봉인/결계 게이트 through its real
## controller + signals — the L4 mirror of l3_gates_harness (§C-3 동일 시그널 패턴, node_id/키아이템만
## 교체; L4 정화 = "풀려난 것을 다시 봉인함"):
##   G1 룬 다리   — 룬 다리석 D141 → 룬 제단(rune_altar) 사용 → power_node_energized("rune_bridge") →
##                  허공 잔교 g 셀 순차 walkable (금색 룬 다리 전개 연출).
##   G2 결계 분수 — 정화의 물 D143 → 마력샘 E 사용 → 밸브문 v 개방
##                  + **마력 Whisper ×1 획득** (§보완 필수, 정확히 1회, idempotent) + WhisperHUD 존재.
##   G3 균열 통과 — 보호 부적 D145 소지 상태 폴링(L2 랜턴 held-item 패턴) → 균열 병목 L walkable.
##                  무부적 → 재차단. 장착·소모 아닌 소지 판정 (신규 조작 0).
##   G4 최심부 봉인 — 최심부 봉인구 D148(whisper_cost.mana:1) → 봉인 코어(seal_mount) 사용 →
##                  power_node_energized("seal_core") → Layer 4 정화 컷신 → layer4_purified +
##                  time_running 복구 (v0.6.1 페어링 규칙) + magic OPEN/divinity FLICKERING 전파.
##                  **마력 0 → D148 조합 거부 / 마력 1 → 성공 + 소모 후 0 어서션 (QA §B-2 필수).**
##
## Uses the item_used_on_object framework path (real interaction) via the invisible use-targets the
## controller wraps around the altar/spring/mount sprites. L4 key items injected here.
##
## Prints PASS/FAIL per check; quits with the failure count as exit code.

const TOWER := "res://scenes/world/mage_tower.tscn"

var _fail := 0
var _purified := false
var _purified_layer := ""


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L4 GATES HARNESS (봉인/결계 게이트 / 마력 Whisper) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	GameState.reset_layer3()
	GameState.reset_layer4()
	WhisperCurrency.reset()
	SaveManager.pending_load = false

	var scene: PackedScene = load(TOWER)
	var map := scene.instantiate()
	add_child(map)
	# Let the loader spawn objects + the gate controller wire itself (deferred + 2 frames).
	for i in range(6):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L4GateController")
	_check("loader present", loader != null)
	_check("L4GateController present", gates != null)
	if loader == null or gates == null:
		print("=== RESULT: FAIL (missing core nodes) ===")
		get_tree().quit(1)
		return

	GameState.layer4_purified.connect(func(l):
		_purified = true
		_purified_layer = l)

	_test_legend(loader)
	_test_gather_craft_chain(loader)
	_test_return_portal()
	await _test_g1_rune_bridge(loader)
	await _test_g2_spring_and_mana_whisper(loader, map)
	_test_g4_whisper_cost()
	await _test_g3_crack_charm(loader)
	await _test_g4_seal_purification(loader)
	_test_persistence()
	await _test_persistence_reapply(loader)

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- (a) legend gate records ---------------------------------------------

func _test_legend(loader: MapLoader) -> void:
	var g: Dictionary = loader.legend_gates()
	_check("legend_gates() has G1..G4",
		g.has("G1") and g.has("G2") and g.has("G3") and g.has("G4"))
	_check("G1 node_id = rune_bridge", String(g.get("G1", {}).get("node_id", "")) == "rune_bridge",
		"node_id=%s" % String(g.get("G1", {}).get("node_id", "")))
	# G2 uses a `target` (mana_spring) rather than a power node_id in the legend.
	_check("G2 target = mana_spring", String(g.get("G2", {}).get("target", "")) == "mana_spring",
		"target=%s" % String(g.get("G2", {}).get("target", "")))
	_check("G3 charm_item = D145 (소지형)", String(g.get("G3", {}).get("charm_item", "")) == "D145",
		"charm=%s" % String(g.get("G3", {}).get("charm_item", "")))
	_check("G4 node_id = seal_core", String(g.get("G4", {}).get("node_id", "")) == "seal_core",
		"node_id=%s" % String(g.get("G4", {}).get("node_id", "")))


# ---- (b) G1 rune bridge ---------------------------------------------------

func _test_g1_rune_bridge(loader: MapLoader) -> void:
	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var bridge_cells := _cells(g1.get("bridge_cells", []))
	_check("G1 bridge cells present in legend", bridge_cells.size() >= 4, "n=%d" % bridge_cells.size())
	var any: Vector2i = bridge_cells[0] if not bridge_cells.is_empty() else Vector2i(-1, -1)
	_check("허공 잔교 tile starts NON-walkable (봉인, 통행 불가)",
		any != Vector2i(-1, -1) and not loader.is_cell_walkable(any))

	# Drive the real interaction path: hold 룬 다리석 D141, use on the rune_altar use-target.
	Inventory.add("D141", 1)
	var target := _find_use_target(loader, "rune_altar")
	_check("rune_altar use-target wired (룬 제단)", target != null)
	if target != null:
		Inventory.remove("D141", 1)
		GameState.item_used_on_object.emit("D141", target)
	# (GP-6 §2) 장착 → 룬 점등 퍼즐 모달 → 스킵(=그냥 장착=동일 energize)으로 급전 실경로 완주.
	await get_tree().process_frame
	_check("G1 승격 퍼즐(rune) 모달 개방 + 스킵 경로 해소", _resolve_gate_puzzle_if_open())
	_check("power_node 'rune_bridge' recorded in powered_nodes",
		GameState.is_power_node_energized("rune_bridge"))
	# Staggered light timers fire (0.12s * up to N cells). SceneTreeTimer uses REAL time.
	await get_tree().create_timer(1.4).timeout
	var all_walk := true
	for c in bridge_cells:
		if not loader.is_cell_walkable(c):
			all_walk = false
	_check("G1 룬 다리 전개 후 전 잔교 타일 walkable (물리+AStar 갱신)", all_walk)


# ---- (c) G2 mana spring + ward door + mana Whisper (필수) -----------------

func _test_g2_spring_and_mana_whisper(loader: MapLoader, map: Node) -> void:
	var g2: Dictionary = loader.legend_gates().get("G2", {})
	var door_cells := _cells(g2.get("door_cells", []))
	_check("G2 door cells present", door_cells.size() >= 2, "n=%d" % door_cells.size())
	var d0: Vector2i = door_cells[0] if not door_cells.is_empty() else Vector2i(-1, -1)
	_check("결계 밸브문 starts NON-walkable (봉인)",
		d0 != Vector2i(-1, -1) and not loader.is_cell_walkable(d0))

	# G2 needs the 정화의 물 D143 used on the mana_spring.
	Inventory.add("D143", 1)
	var spring := _find_use_target(loader, "mana_spring")
	_check("mana_spring use-target wired (마력샘 E)", spring != null)
	var mana_before := WhisperCurrency.mana
	if spring != null:
		Inventory.remove("D143", 1)
		GameState.item_used_on_object.emit("D143", spring)
	# Allow the door swap + whisper grant.
	for i in range(6):
		await get_tree().process_frame
	var door_open := true
	for c in door_cells:
		if not loader.is_cell_walkable(c):
			door_open = false
	_check("G2 정화의물→마력샘 사용 → 밸브문 v 개방 (walkable)", door_open)
	_check("mana_spring power node recorded", GameState.is_power_node_energized("mana_spring"))
	_check("마력 Whisper ×1 획득 (G2 보상, 필수, 첫 마력)",
		WhisperCurrency.mana == mana_before + 1, "mana=%d" % WhisperCurrency.mana)

	# Idempotent reward: re-emitting the use does NOT grant a 2nd mana.
	var mana_after := WhisperCurrency.mana
	Inventory.add("D143", 1)
	if spring != null:
		Inventory.remove("D143", 1)
		GameState.item_used_on_object.emit("D143", spring)
	for i in range(4):
		await get_tree().process_frame
	_check("G2 보상 idempotent (재사용 시 2번째 마력 미지급)",
		WhisperCurrency.mana == mana_after, "mana=%d" % WhisperCurrency.mana)

	var hud := map.get_node_or_null("WhisperHUD")
	_check("WhisperHUD present", hud != null)


# ---- (d) G4 whisper_cost recipe — mana 0 거부 / mana 1 성공 (QA §B-2 필수) --

func _test_g4_whisper_cost() -> void:
	# L4-R09 최심부 봉인구 = D146 + D146 (봉인구 뼈대 둘), whisper_cost mana:1 (유일한 마력 sink).
	var recipe := RecipeDB.find_recipe(["D146", "D146"])
	_check("L4-R09 recipe (최심부 봉인구) exists", not recipe.is_empty())
	_check("L4-R09 output = D148 (최심부 봉인구)", String(recipe.get("output", "")) == "D148",
		"output=%s" % String(recipe.get("output", "")))
	_check("L4-R09 carries whisper_cost mana:1",
		int(RecipeDB.whisper_cost(recipe).get("mana", 0)) == 1)

	# Drive the Fusion path. Drain mana → shortfall must REJECT the combine (D148 조합 거부).
	Inventory.clear()
	while WhisperCurrency.mana > 0:
		WhisperCurrency.spend_mana(WhisperCurrency.mana)
	Inventory.add("D146", 2)   # two 봉인구 뼈대 (same-ingredient recipe)
	var res_fail := Fusion.fuse("D146", "D146")
	_check("마력 0 → D148 조합 거부 (재화 없음)", not res_fail["matched"])
	_check("실패 사유 = '마력이 부족하다'", String(res_fail.get("failure_reason", "")) == "마력이 부족하다",
		"reason=%s" % String(res_fail.get("failure_reason", "")))
	_check("거부 시 재료 미소모 (D146 2 잔존)", Inventory.count("D146") == 2)

	# Grant mana 1 → the fuse succeeds, outputs D148, consumes exactly 1 mana (→ 0) + the two pieces.
	WhisperCurrency.add_mana(1)
	var res_ok := Fusion.fuse("D146", "D146")
	_check("마력 1 → fuse 성공 → 최심부 봉인구(D148) 산출",
		res_ok["matched"] and res_ok["output"] == "D148")
	_check("성공 시 마력 1 소모 (0으로)", WhisperCurrency.mana == 0, "mana=%d" % WhisperCurrency.mana)
	_check("성공 시 재료 소모 (D146 0)", Inventory.count("D146") == 0)
	Inventory.clear()


# ---- (e) G3 crack passage (held-charm walkable swap) ----------------------

func _test_g3_crack_charm(loader: MapLoader) -> void:
	var g3: Dictionary = loader.legend_gates().get("G3", {})
	var crack_cells := _cells(g3.get("crack_cells", []))
	_check("G3 crack cells present", crack_cells.size() >= 2, "n=%d" % crack_cells.size())
	var c0: Vector2i = crack_cells[0] if not crack_cells.is_empty() else Vector2i(-1, -1)
	_check("균열 병목 tile starts NON-walkable (봉인)",
		c0 != Vector2i(-1, -1) and not loader.is_cell_walkable(c0))

	# Hold 보호 부적 D145 → the controller's per-frame poll opens the crack passage.
	Inventory.add("D145", 1)
	for i in range(4):
		await get_tree().process_frame
	var crack_walk := true
	for c in crack_cells:
		if not loader.is_cell_walkable(c):
			crack_walk = false
	_check("G3 보호 부적 소지 → 균열 병목 walkable (통과)", crack_walk)

	# Drop the charm → the crack re-seals (소지형: 무부적 차단).
	Inventory.remove("D145", 1)
	for i in range(4):
		await get_tree().process_frame
	var resealed := true
	for c in crack_cells:
		if loader.is_cell_walkable(c):
			resealed = false
	_check("G3 부적 미소지 → 균열 재차단 (무부적 통행 불가)", resealed)

	# Restore the charm so the seal-neck path is passable for the final gate (real journey order).
	Inventory.add("D145", 1)
	for i in range(4):
		await get_tree().process_frame
	Inventory.clear()


# ---- (f) G4 seal-core reconstruction → purification -----------------------

func _test_g4_seal_purification(loader: MapLoader) -> void:
	_check("정화 전 layer4_purified_flag = false", not GameState.layer4_purified_flag)
	Inventory.add("D148", 1)   # 최심부 봉인구
	var mount := _find_use_target(loader, "seal_mount")
	_check("seal_mount use-target wired (봉인 코어 배전반)", mount != null)
	if mount != null:
		Inventory.remove("D148", 1)
		GameState.item_used_on_object.emit("D148", mount)
	_check("power_node 'seal_core' recorded", GameState.is_power_node_energized("seal_core"))
	# The purification cutscene runs (~3s of real-time timers). Poll with a real-time wait.
	for i in range(60):
		await get_tree().create_timer(0.1).timeout
		if GameState.layer4_purified_flag:
			break
	_check("G4 최심부 봉인 재구축 → Layer 4 정화 플래그 set", GameState.layer4_purified_flag)
	_check("정화 컷신 → layer4_purified 시그널 발화", _purified)
	_check("정화 시그널 payload = 'magic'", _purified_layer == "magic", "layer=%s" % _purified_layer)
	# time_running restored after the cutscene (v0.6.1 pairing rule).
	_check("정화 컷신 후 time_running 복구 (v0.6.1 페어링)", GameState.time_running)
	# The mage_tower session hook advances the portal line (magic OPEN, divinity FLICKERING).
	_check("정화 → magic 포탈 OPEN (정화한 세계는 열린 채)",
		GameState.portal_state("magic") == GameState.PORTAL_OPEN,
		"magic=%s" % GameState.portal_state("magic"))
	_check("정화 → divinity 포탈 flickering (다음 세계 깨어남)",
		GameState.portal_state("divinity") == GameState.PORTAL_FLICKERING,
		"divinity=%s" % GameState.portal_state("divinity"))


# ---- (g) persistence in the save dict -------------------------------------

func _test_persistence() -> void:
	var d := SaveManager.build_save_dict()
	var pn: Dictionary = d.get("powered_nodes", {})
	_check("save dict carries powered_nodes (L4 node ids)",
		d.has("powered_nodes") and pn.has("rune_bridge") and pn.has("mana_spring")
		and pn.has("seal_core"))
	_check("save dict carries layer4_purified", bool(d.get("layer4_purified", false)))
	var w: Dictionary = d.get("whisper", {})
	_check("save dict carries whisper 재화 (mana 포함)", d.has("whisper") and w.has("mana"))


## A FRESH controller booted with the GameState flags pre-set must re-apply the energized
## end-state (bridge/door already walkable) via _reapply_persisted_state — mirror l3.
func _test_persistence_reapply(loader: MapLoader) -> void:
	# The flags from the drive above are still set (rune_bridge/mana_spring energized + purified).
	_check("(사전조건) 급전 플래그 유지", GameState.is_power_node_energized("rune_bridge")
		and GameState.is_power_node_energized("mana_spring"))
	# Spawn a fresh L4GateController pointed at the SAME live loader → _reapply_persisted_state.
	var fresh: Node = load("res://scripts/world/l4_gate_controller.gd").new()
	add_child(fresh)
	fresh.set("map_loader_path", fresh.get_path_to(loader))
	# _setup runs deferred (+2 frames); give it a real beat for any instant reapply.
	for i in range(6):
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
	_check("_reapply_persisted_state → 룬 다리/밸브문 즉시 walkable (재진입 복원)", ok)
	if is_instance_valid(fresh):
		fresh.queue_free()


# ---- (h) gather sources (P1-P7) + craft chain -----------------------------

func _test_gather_craft_chain(loader: MapLoader) -> void:
	# All 7 P-element gatherables must be represented by at least one spawned Gatherable.
	var seen := {}
	for key in loader.l2_object_nodes:
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node is Gatherable:
			seen[String((node as Gatherable).item_id)] = true
	var missing := []
	for p in ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]:
		if not seen.has(p):
			missing.append(p)
	_check("P1-P7 채집원 전부 맵에 존재", missing.is_empty(), "missing=%s" % [missing])

	# Craft 봉인구 뼈대 D146 via L4-R07 (P1 + P5) — proves the G4 key is craftable e2e.
	Inventory.clear()
	Inventory.add("P1", 1); Inventory.add("P5", 1)
	var d146 := Fusion.fuse("P1", "P5")            # L4-R07: 봉인구 뼈대 D146
	_check("봉인구 뼈대(D146) = (P1+P5) 크래프트 성공",
		d146["output"] == "D146" and Inventory.count("D146") == 1)
	Inventory.clear()


# ---- (i) return portal ----------------------------------------------------

func _test_return_portal() -> void:
	# The mage_tower session spawns a ReturnPortalController with the "홈으로 돌아가기" prompt.
	var found := false
	var prompt_ok := false
	# ReturnPortalController spawns a Portal in the "gatherable" group (same as grove/L2/L3).
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
	_check("L4 귀환 포탈 present (mage_tower 스폰)", found)
	_check("L4 귀환 포탈 프롬프트 = '홈으로 돌아가기'", prompt_ok)


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
	# The altar/mount are controller-spawned (not in l2_object_nodes); search the ysort layer.
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


## (GP-6 §2 정합) G1 승격이 GatePuzzle 모달(GP-5 §3)을 거쳐 energize — skip == 그냥 장착 == 동일 개방.
## current_scene 아래로 붙은 열린 퍼즐을 찾아 스킵 경로로 해소. 열린 퍼즐 없음(직행 energize)도 valid.
func _resolve_gate_puzzle_if_open() -> bool:
	for n in _all_nodes(get_tree().root):
		if n is GatePuzzle:
			(n as GatePuzzle).skip_for_test()
			return true
	return false
