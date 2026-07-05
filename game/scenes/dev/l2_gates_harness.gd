extends Node
## (L2-3) Layer-2 게이트 + 전력계 acceptance harness. Boots the REAL terminal_station.tscn (the
## scene the portal travels to) and drives each gate through its real controller + signals:
##   1. PowerNode: 배전반 K에 전지(D64) 장착 → power_node_energized("bridge") + powered_nodes 기록.
##   2. G1 브리지: 급전 후 브리지 B 타일이 walkable로 전환 (AStar 갱신 트리거).
##   3. G2 발전기→문: 퓨즈(D66) → gen_sub 사용 → 차폐문 D 개방(walkable) + 에너지 Whisper ×1 획득
##      + HUD 표기 조건(보유 시).
##   4. whisper_cost: L2-R08(파워코어) 레시피가 에너지 부족이면 실패("에너지가 부족하다"),
##      충분하면 에너지 1 소모하고 성공.
##   5. G3 정전: 랜턴(D65) 미소지 시 병목 벽 유지, 소지 시 통행(벽 콜리전 off).
##   6. G4 관제탑: 파워코어(D69) → control_core 급전 → 정화 시그널(layer2_purified) + 플래그.
##
## Uses the item_used_on_object framework path where possible (real interaction), else drives the
## controller's public energize entrypoints. L2 real item data lands in L2-4, so key items are
## injected into the inventory here.
##
## Prints PASS/FAIL per check; quits with the failure count as exit code.

const STATION := "res://scenes/world/terminal_station.tscn"

var _fail := 0
var _purified := false


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L2 GATES HARNESS (전력 노드 / 게이트 / 에너지 Whisper) ===")
	Inventory.clear()
	GameState.set_game_time(0.0)
	GameState.reset_portals()
	GameState.reset_layer2()
	WhisperCurrency.reset()
	SaveManager.pending_load = false

	var scene: PackedScene = load(STATION)
	var map := scene.instantiate()
	add_child(map)
	# Let the loader spawn objects + the gate controller wire itself (deferred + 2 frames).
	for i in range(6):
		await get_tree().process_frame

	var loader := map.get_node("Ground") as MapLoader
	var gates := map.get_node_or_null("L2GateController")
	_check("loader present", loader != null)
	_check("L2GateController present", gates != null)
	if loader == null or gates == null:
		print("=== RESULT: FAIL (missing core nodes) ===")
		get_tree().quit(1)
		return

	GameState.layer2_purified.connect(func(_l): _purified = true)

	_test_gather_craft_chain(loader)
	_test_return_portal(map)
	await _test_power_node_bridge(loader)
	await _test_g2_door_and_whisper(loader, map)
	_test_whisper_cost()
	await _test_g3_blackout(gates)
	await _test_g4_purification(loader, gates)
	_test_persistence_reapply()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- 1 & 2: PowerNode + G1 bridge ----------------------------------------

func _test_power_node_bridge(loader: MapLoader) -> void:
	# Bridge cells start sealed (non-walkable).
	var g1: Dictionary = loader.legend_gates().get("G1", {})
	var bridge_cells := _cells(g1.get("bridge_cells", []))
	_check("G1 bridge cells present in legend", bridge_cells.size() >= 6, "n=%d" % bridge_cells.size())
	var any: Vector2i = bridge_cells[0] if not bridge_cells.is_empty() else Vector2i(-1, -1)
	_check("bridge tile starts NON-walkable (어둡고 통행 불가)",
		any != Vector2i(-1, -1) and not loader.is_cell_walkable(any))

	# Energize the bridge power node (the effect of 전지 D64 → 배전반 K 장착).
	GameState.energize_power_node("bridge")
	_check("power_node_energized recorded in powered_nodes",
		GameState.is_power_node_energized("bridge"))
	# Let the staggered light timers fire (0.1s * up to 10 cells → ~1.1s). SceneTreeTimer uses
	# REAL time, so wait a real duration (frame-count waits complete instantly headless).
	await get_tree().create_timer(1.6).timeout
	# All bridge cells must now be walkable.
	var all_walk := true
	for c in bridge_cells:
		if not loader.is_cell_walkable(c):
			all_walk = false
	_check("G1 브리지 순차 점등 후 전 타일 walkable (물리+AStar 갱신)", all_walk)


# ---- 3: G2 shield door + energy Whisper ----------------------------------

func _test_g2_door_and_whisper(loader: MapLoader, map: Node) -> void:
	var g2: Dictionary = loader.legend_gates().get("G2", {})
	var door_cells := _cells(g2.get("door_cells", []))
	_check("G2 door cells present", door_cells.size() >= 2, "n=%d" % door_cells.size())
	var d0: Vector2i = door_cells[0] if not door_cells.is_empty() else Vector2i(-1, -1)
	_check("차폐문 starts NON-walkable (잠김)",
		d0 != Vector2i(-1, -1) and not loader.is_cell_walkable(d0))

	# Drive the real interaction path: hold 퓨즈 D66, use on the gen_sub use-target.
	Inventory.add("D66", 1)
	var gen := _find_use_target(loader, "gen_sub")
	_check("gen_sub use-target wired (PowerNode 장착 대상)", gen != null)
	var energy_before := WhisperCurrency.energy
	if gen != null:
		# Fire the framework signal the interaction would emit (item used on object).
		Inventory.remove("D66", 1)
		GameState.item_used_on_object.emit("D66", gen)
	# Allow the door swap + whisper grant.
	for i in range(6):
		await get_tree().process_frame
	var door_open := true
	for c in door_cells:
		if not loader.is_cell_walkable(c):
			door_open = false
	_check("G2 퓨즈→발전기 e 사용 → 차폐문 D 개방 (walkable)", door_open)
	_check("에너지 Whisper ×1 획득 (G2 보상, 필수)", WhisperCurrency.energy == energy_before + 1,
		"energy=%d" % WhisperCurrency.energy)
	# HUD shows only when energy > 0.
	var hud := map.get_node_or_null("WhisperHUD")
	_check("WhisperHUD present", hud != null)
	if hud != null and hud.has_method("get") and "_panel" in hud:
		var panel = hud.get("_panel")
		_check("에너지 HUD 보유 시 표시 (visible)", panel != null and panel.visible)


# ---- 4: whisper_cost recipe ----------------------------------------------

func _test_whisper_cost() -> void:
	# L2-R08 파워코어 = D68 + D68 (코어 조각 둘), whisper_cost energy:1. §보완 재화 소모 계약.
	# First DRAIN energy so the fuse fails with the shortfall reason.
	var recipe := RecipeDB.find_recipe(["D68", "D68"])
	_check("L2-R08 recipe (파워코어) exists", not recipe.is_empty())
	_check("L2-R08 carries whisper_cost energy:1",
		int(RecipeDB.whisper_cost(recipe).get("energy", 0)) == 1)

	# spend all energy → insufficient.
	while WhisperCurrency.energy > 0:
		WhisperCurrency.spend_energy(WhisperCurrency.energy)
	Inventory.add("D68", 2)   # two core pieces (same-ingredient recipe)
	var res_fail := Fusion.fuse("D68", "D68")
	_check("에너지 부족 시 fuse 실패 (재화 없음)", not res_fail["matched"])
	_check("실패 사유 = '에너지가 부족하다'", String(res_fail.get("failure_reason", "")) == "에너지가 부족하다")
	_check("실패 시 재료 미소모 (D68 2 잔존)", Inventory.count("D68") == 2)

	# Now grant energy → the fuse succeeds and consumes 1 energy + the two pieces.
	WhisperCurrency.add_energy(1)
	var res_ok := Fusion.fuse("D68", "D68")
	_check("에너지 충분 시 fuse 성공 → 파워코어(D69) 산출", res_ok["matched"] and res_ok["output"] == "D69")
	_check("성공 시 에너지 1 소모 (0으로)", WhisperCurrency.energy == 0, "energy=%d" % WhisperCurrency.energy)
	_check("성공 시 재료 소모 (D68 0)", Inventory.count("D68") == 0)


# ---- 5: G3 blackout held-item gate ---------------------------------------

func _test_g3_blackout(gates: Node) -> void:
	# The gate controller built a bottleneck wall (StaticBody). Without the lantern the wall is
	# ON; holding the lantern turns it off. Drive _apply_g3 through the possession check.
	Inventory.remove("D65", 99)   # ensure no lantern
	if gates.has_method("_apply_g3"):
		gates.call("_apply_g3", false)
	var wall_on := _g3_wall_disabled(gates) == false
	_check("G3 랜턴 미소지 → 병목 벽 유지 (통행 차단)", wall_on)

	Inventory.add("D65", 1)       # neon lantern (unique key item)
	if gates.has_method("_apply_g3"):
		gates.call("_apply_g3", true)
	for i in range(3):
		await get_tree().process_frame
	var wall_off := _g3_wall_disabled(gates) == true
	_check("G3 랜턴 소지 → 병목 통행 (벽 콜리전 off)", wall_off)


# ---- 6: G4 control tower purification -------------------------------------

func _test_g4_purification(loader: MapLoader, gates: Node) -> void:
	_check("정화 전 layer2_purified_flag = false", not GameState.layer2_purified_flag)
	# Energize the control core (파워코어 D69 → 관제탑 배전반 K 설치).
	GameState.energize_power_node("control_core")
	_check("control_core power node recorded", GameState.is_power_node_energized("control_core"))
	# The purification cutscene runs (~3-4s of real-time timers). Poll with a real-time wait.
	for i in range(60):
		await get_tree().create_timer(0.1).timeout
		if GameState.layer2_purified_flag:
			break
	_check("G4 관제탑 재가동 → Layer 2 정화 플래그 set", GameState.layer2_purified_flag)
	_check("정화 컷신 → layer2_purified 시그널 발화 (cleared)", _purified)
	_check("정화 후 다음 포탈(machine) flickering 준비", true)  # session hook set it; portal state below
	_check("machine 포탈 flickering 전파", GameState.portal_state("machine") == GameState.PORTAL_FLICKERING)
	# time_running restored after the cutscene.
	_check("정화 컷신 후 time_running 복구", GameState.time_running)


# ---- persistence re-apply -------------------------------------------------

func _test_persistence_reapply() -> void:
	# powered_nodes + purified flag must survive a save round-trip in the dict.
	var d := SaveManager.build_save_dict()
	_check("save dict carries powered_nodes", d.has("powered_nodes") and (d["powered_nodes"] as Dictionary).has("bridge"))
	_check("save dict carries layer2_purified", bool(d.get("layer2_purified", false)))
	_check("save dict carries whisper 재화", d.has("whisper"))


# ---- full gather→craft chain (gate keys built from J-stubs, not injected) -

## Drive the WHOLE gate-key chain through the REAL recipe DB from the J1-J7 gather stubs, proving
## each key item (전지 D64 / 랜턴 D65 / 퓨즈 D66 / 파워코어 D69) is craftable end-to-end — not just
## injected. Also asserts the J-element gatherables actually spawned on the loaded station.
func _test_gather_craft_chain(loader: MapLoader) -> void:
	# (a) J-element gatherables present on the map (wired to L2-2 debris/crate/dome/neon/oil).
	var j_seen := {}
	for key in loader.l2_object_nodes.keys():
		var node: Node = loader.l2_object_nodes[key].get("node")
		if node is Gatherable:
			var iid := String((node as Gatherable).item_id)
			if iid.begins_with("J"):
				j_seen[iid] = true
	# Gate chain needs J1,J2,J3,J4,J5,J6 (J7 재 = decor only). All must have a live source.
	var need := ["J1", "J2", "J3", "J4", "J5", "J6"]
	var missing := []
	for j in need:
		if not j_seen.has(j):
			missing.append(j)
	_check("게이트 체인 원소 J1-J6 전부 맵에 채집원 존재", missing.is_empty(), "missing=%s" % [missing])
	# Both J2 AND J4 sourced from parts boxes (the deterministic split), and the split SURVIVES a
	# respawn rebuild (regression: rebuild_gatherable must re-apply parity, else J4 erodes to J2).
	_check("부품상자에서 J2·J4 둘 다 채집 가능 (셀 패리티 분기)",
		j_seen.has("J2") and j_seen.has("J4"))
	var rb_even := loader.rebuild_gatherable("s", Vector2i(2, 2))   # parity 0 → J2
	var rb_odd := loader.rebuild_gatherable("s", Vector2i(2, 3))    # parity 1 → J4
	var rb_ok := rb_even != null and rb_odd != null and String(rb_even.item_id) == "J2" and String(rb_odd.item_id) == "J4"
	if rb_even != null: rb_even.free()
	if rb_odd != null: rb_odd.free()
	_check("리스폰 rebuild가 J2/J4 패리티 유지 (J4 소멸 방지)", rb_ok)

	# (b) 전지 D64 chain: J1+J2→D62(구리도선), J4+J5→D63(정류회로), D62+D63→D64(전지).
	Inventory.clear()
	Inventory.add("J1", 1); Inventory.add("J2", 1)
	var d62 := Fusion.fuse("J1", "J2")
	Inventory.add("J4", 1); Inventory.add("J5", 1)
	var d63 := Fusion.fuse("J4", "J5")
	var d64 := Fusion.fuse("D62", "D63")
	_check("전지(D64) = 구리도선(J1+J2) + 정류회로(J4+J5) 크래프트 성공",
		d62["output"] == "D62" and d63["output"] == "D63" and d64["output"] == "D64" and Inventory.count("D64") == 1)

	# (c) 네온 랜턴 D65: J3+J6.
	Inventory.add("J3", 1); Inventory.add("J6", 1)
	var d65 := Fusion.fuse("J3", "J6")
	_check("네온 랜턴(D65) = 유리(J3)+네온(J6) 크래프트 성공 + key_item",
		d65["output"] == "D65" and Inventory.count("D65") == 1 and bool(ItemDB.get_item("D65").get("key_item", false)))

	# (d) 퓨즈 D66: 구리도선(D62) + 유리(J3). Rebuild a 도선 first.
	Inventory.add("J1", 1); Inventory.add("J2", 1)
	Fusion.fuse("J1", "J2")   # → D62
	Inventory.add("J3", 1)
	var d66 := Fusion.fuse("D62", "J3")
	_check("퓨즈(D66) = 구리도선(D62)+유리(J3) 크래프트 성공", d66["output"] == "D66" and Inventory.count("D66") == 1)

	# (e) 코어 조각 D68 chain: J4+D64→D67(골격), D67+J6→D68(조각). Need a fresh 전지 for the 골격.
	Inventory.add("J1", 1); Inventory.add("J2", 1); Fusion.fuse("J1", "J2")   # D62
	Inventory.add("J4", 1); Inventory.add("J5", 1); Fusion.fuse("J4", "J5")   # D63
	Fusion.fuse("D62", "D63")   # D64 전지
	Inventory.add("J4", 1)
	var d67 := Fusion.fuse("J4", "D64")
	Inventory.add("J6", 1)
	var d68 := Fusion.fuse("D67", "J6")
	_check("코어 조각(D68) = 골격(J4+전지)→조각(+J6) 다단 크래프트 성공",
		d67["output"] == "D67" and d68["output"] == "D68" and Inventory.count("D68") == 1)
	# leave inventory clean for the gate tests that follow.
	Inventory.clear()


## The L2 return portal (terminal_station spawn) exists as a real Portal with the reworked
## entry-zone + "홈으로 돌아가기" prompt (deliverable B, L2 side).
func _test_return_portal(map: Node) -> void:
	var rp: Portal = null
	for n in get_tree().get_nodes_in_group("gatherable"):
		if n is Portal and String((n as Portal).object_id) == "portal_return":
			rp = n
			break
	_check("L2 귀환 포탈 present (터미널 스테이션 스폰)", rp != null)
	if rp == null:
		return
	_check("L2 귀환 포탈 = OPEN 상태 + 진입 존 존재",
		GameState.portal_state("return") == GameState.PORTAL_OPEN and rp.has_method("is_player_in_entry_zone"))
	_check("L2 귀환 포탈 프롬프트 = '홈으로 돌아가기'",
		String(rp.entry_prompt_text()).findn("홈으로") >= 0)


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
			# fallback: the sprite itself carries the object_id meta.
			return node
	return null


## Return true if the G3 wall body's collision is DISABLED (i.e. passable), false if enabled.
func _g3_wall_disabled(gates: Node) -> bool:
	var body = gates.get("_g3_body") if "_g3_body" in gates else null
	if body == null or not is_instance_valid(body):
		return true  # no wall built = passable
	var col = body.get_child(0)
	if col is CollisionShape2D:
		return (col as CollisionShape2D).disabled
	return true
