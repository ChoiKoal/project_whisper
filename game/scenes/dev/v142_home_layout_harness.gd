extends Node
## v1.4.2 acceptance harness — L0 홈 섬 레이아웃 재저작 (staggered 투영 기준).
##
## 배경: home_layout.txt는 옛 diamond 투영 `[(c-r)·64,(c+r)·32]`을 가정해 저작돼, 실제
## staggered(STACKED) 렌더에선 "가로로 눌린 마름모 + 좌측에 뭉친 포탈"이 됐다. v1.4.2에서
## staggered 투영 기준으로 재저작(21×17) → 의도된 "포탈 아치" 구도 복원.
##
## 이 하네스는 REAL home_island.tscn을 인스턴스화해 다음을 검증한다:
##   (a) 포탈 5기 실좌표가 대칭 아치: P3 최상단 중앙, P1/P5 X 대칭(±)·같은 Y, P2/P4 X 대칭·같은 Y,
##       그리고 arch curve (P3가 P2/P4보다, P2/P4가 P1/P5보다 위 = 작은 Y).
##   (b) 솥(cauldron)이 다이스(S) 기준 좌하 (X<S, Y>S).
##   (c) S 스폰 셀이 유효/보행 가능.
##   (d) 각 포탈이 보행 가능한 진입(엔트리) 인접셀을 보유 — 포탈 엔트리존은 gate 남쪽 apron이므로
##       (col, row+2) 셀이 보행 가능해야 실제로 진입 가능.
##   (e) 섬 지면 비율이 대략 2:1 (staggered 스크린 bbox).
##   (f) 세이브 호환: 구(舊)-레이아웃 좌표(새 레이아웃에선 VOID/오프-슬랩)로 홈 세이브를 로드하면
##       플레이어가 유효(보행 가능) 셀에 착지한다 (SaveManager._nearest_walkable_world clamp).
##
## PASS/FAIL 출력 + 프로세스 exit code = 실패 수.

const HOME := "res://scenes/world/home_island.tscn"
const HH := 32.0   # iso half-height (MapLoader.TILE_HALF_H)

var _fail := 0
var _scene: Node = null


func _ready() -> void:
	print("=== v1.4.2 HOME LAYOUT (staggered arch) HARNESS ===")
	SaveManager.new_game()
	SaveManager.delete_save()
	call_deferred("_run")


func _run() -> void:
	await _frames(1)
	await _a_portal_arch()
	await _b_cauldron_lower_left()
	await _c_spawn_valid()
	await _d_portal_aprons()
	await _e_island_ratio()
	await _g_expansion_core_invariant()
	await _f_legacy_save_lands_valid()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ==== infra ================================================================

func _check(label: String, cond: bool, detail: String = "") -> bool:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  — " + detail) if detail != "" else ""])
	if not cond:
		_fail += 1
	return cond


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _boot_home() -> Node:
	GameState.time_running = false
	WorldContext.current_scene = WorldContext.SCENE_HOME
	WorldContext.arrival_mode = ""
	SaveManager.pending_load = false
	var s: Node = load(HOME).instantiate()
	add_child(s)
	await _frames(5)
	return s


func _teardown() -> void:
	SaveManager.unregister_world()
	if _scene != null:
		_scene.queue_free()
		_scene = null
	await _frames(2)


func _loader() -> MapLoader:
	return _scene.get_node("Ground") as MapLoader


## Portal world position (cell centre) for a layer, from the loader's portal_cells map.
func _portal_pos(layer: String) -> Vector2:
	var ld := _loader()
	if not ld.portal_cells.has(layer):
		return Vector2(INF, INF)
	return ld.cell_center_world(ld.portal_cells[layer])


# ==== (a) portal arch geometry =============================================

func _a_portal_arch() -> void:
	print("--- (a) 포탈 5기 대칭 아치 ---")
	_scene = await _boot_home()
	var ld := _loader()
	_check("포탈 5기 모두 스폰됨", ld.portal_cells.size() == 5,
		"portal_cells=%d" % ld.portal_cells.size())

	# nature=P1, science=P2, machine=P3, magic=P4, divinity=P5 (legend 순서 = 좌→우).
	var p1 := _portal_pos("nature")
	var p2 := _portal_pos("science")
	var p3 := _portal_pos("machine")
	var p4 := _portal_pos("magic")
	var p5 := _portal_pos("divinity")
	print("    P1=%s P2=%s P3=%s P4=%s P5=%s" % [p1, p2, p3, p4, p5])

	# P3 최상단 중앙: 가장 작은 Y.
	_check("P3(machine) 최상단 (P2/P4보다 위)", p3.y < p2.y and p3.y < p4.y,
		"P3.y=%.0f P2.y=%.0f P4.y=%.0f" % [p3.y, p2.y, p4.y])
	_check("P2/P4가 P1/P5보다 위 (arch 곡선)", p2.y < p1.y and p4.y < p5.y,
		"P2.y=%.0f P1.y=%.0f" % [p2.y, p1.y])

	# X 대칭: P1/P5, P2/P4가 P3.x 기준 좌우 대칭 (±32px 허용).
	_check("P1/P5 X 대칭 (±32px)", absf((p1.x - p3.x) + (p5.x - p3.x)) <= 32.0,
		"P1.x-P3.x=%.0f  P5.x-P3.x=%.0f" % [p1.x - p3.x, p5.x - p3.x])
	_check("P2/P4 X 대칭 (±32px)", absf((p2.x - p3.x) + (p4.x - p3.x)) <= 32.0,
		"P2.x-P3.x=%.0f  P4.x-P3.x=%.0f" % [p2.x - p3.x, p4.x - p3.x])
	# 좌→우 순서 (1..5 X 증가).
	_check("포탈 X 좌→우 오름차순 (1→5)", p1.x < p2.x and p2.x < p3.x and p3.x < p4.x and p4.x < p5.x)
	# P1/P5, P2/P4 같은 Y (아치 대칭, ±32px).
	_check("P1/P5 같은 Y (±32px)", absf(p1.y - p5.y) <= 32.0, "|P1.y-P5.y|=%.0f" % absf(p1.y - p5.y))
	_check("P2/P4 같은 Y (±32px)", absf(p2.y - p4.y) <= 32.0, "|P2.y-P4.y|=%.0f" % absf(p2.y - p4.y))

	# 하네스 여러 섹션이 같은 씬을 재사용 → 여기서 teardown 하지 않고 이후 섹션이 정리.


# ==== (b) cauldron lower-left of the dice ==================================

func _b_cauldron_lower_left() -> void:
	print("--- (b) 솥 = 다이스 좌하 ---")
	var ld := _loader()
	_check("S(다이스) 셀 유효", ld.spawn_cell != Vector2i(-1, -1))
	_check("C(솥) 셀 유효", ld.cauldron_cell != Vector2i(-1, -1))
	if ld.spawn_cell == Vector2i(-1, -1) or ld.cauldron_cell == Vector2i(-1, -1):
		return
	var s := ld.cell_center_world(ld.spawn_cell)
	var c := ld.cell_center_world(ld.cauldron_cell)
	_check("솥이 다이스 좌하 (X<S 그리고 Y>S)", c.x < s.x and c.y > s.y,
		"C=%s S=%s (rel x=%.0f y=%.0f)" % [c, s, c.x - s.x, c.y - s.y])
	# 다이스가 아치 중앙(P3) 아래 대략 중앙 정렬 (±64px).
	var p3 := _portal_pos("machine")
	_check("다이스가 아치 중앙(P3) X에 정렬 (±64px)", absf(s.x - p3.x) <= 64.0,
		"S.x=%.0f P3.x=%.0f" % [s.x, p3.x])


# ==== (c) spawn cell valid + walkable ======================================

func _c_spawn_valid() -> void:
	print("--- (c) S 스폰 셀 유효/보행 가능 ---")
	var ld := _loader()
	_check("S 스폰 셀 보행 가능", ld.is_cell_walkable(ld.spawn_cell),
		"spawn_cell=%s" % ld.spawn_cell)
	# 스폰 셀은 4-이웃 중 최소 하나 보행 가능 (고립되지 않음).
	var free_nb := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if ld.is_cell_walkable(ld.spawn_cell + d):
			free_nb += 1
	_check("스폰 셀이 보행 가능 인접셀 보유 (고립 아님)", free_nb >= 2, "free_nb=%d" % free_nb)


# ==== (d) each portal has a walkable entry apron ===========================

func _d_portal_aprons() -> void:
	print("--- (d) 포탈 진입 apron 보행 가능 ---")
	var ld := _loader()
	# 포탈 엔트리존(portal.gd)은 gate 남쪽(screen +y, forward +64)에 놓인다. staggered에서
	# 스크린 남쪽 아래(+64px) = (col, row+2) 셀. 그 셀이 보행 가능해야 실제 진입 가능.
	for layer in ld.portal_cells:
		var cell: Vector2i = ld.portal_cells[layer]
		var apron := cell + Vector2i(0, 2)   # +2 rows = +64px screen-y, same col (parity 유지)
		_check("포탈 %s 남쪽 apron 보행 가능" % layer, ld.is_cell_walkable(apron),
			"portal=%s apron=%s" % [cell, apron])


# ==== (e) island ground ratio ~2:1 (screen bbox) ===========================

func _e_island_ratio() -> void:
	print("--- (e) 섬 지면 비율 ~2:1 ---")
	var ld := _loader()
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for r in range(ld.height):
		for c in range(ld.width):
			if not ld._is_island_cell(Vector2i(c, r)):
				continue
			var p := ld.cell_center_world(Vector2i(c, r))
			minx = minf(minx, p.x - 64.0)
			maxx = maxf(maxx, p.x + 64.0)
			miny = minf(miny, p.y - HH)
			maxy = maxf(maxy, p.y + HH)
	var w := maxx - minx
	var h := maxy - miny
	var ratio := w / h if h > 0.0 else 0.0
	# 톱니 엣지·아치로 정확히 2.00은 아님 — 대략 1.7~2.6 사이면 "가로로 긴 직사각" 의도 충족.
	_check("섬 스크린 bbox 비율 ~2:1 (1.7~2.6)", ratio >= 1.7 and ratio <= 2.6,
		"w=%.0f h=%.0f ratio=%.2f:1" % [w, h, ratio])
	await _teardown()


# ==== (g) v1.10.0 L0 확장: 치수 확장 + 코어 셀 좌표 불변 =====================

func _g_expansion_core_invariant() -> void:
	print("--- (g) L0 허브 확장: 31×25 치수 + 코어 좌표 불변 ---")
	_scene = await _boot_home()
	var ld := _loader()
	# 확장 치수: 21×17 → 31×25.
	_check("맵 폭 31 (확장)", ld.width == 31, "width=%d" % ld.width)
	_check("맵 높이 25 (확장)", ld.height == 25, "height=%d" % ld.height)
	# 승인 아치 구도 불변 — 포탈/스폰/솥 셀 좌표가 v1.4.2 원본과 픽셀 단위로 동일.
	# (이 좌표들은 staggered 투영에서 절대 인덱스에만 의존하므로, 인덱스 불변 = 월드 불변.)
	var core := {
		"nature": Vector2i(7, 5), "science": Vector2i(9, 4), "machine": Vector2i(10, 3),
		"magic": Vector2i(12, 4), "divinity": Vector2i(13, 5),
	}
	for layer in core:
		var got: Vector2i = ld.portal_cells.get(layer, Vector2i(-1, -1))
		_check("포탈 %s 셀 좌표 불변 %s" % [layer, core[layer]], got == core[layer],
			"got=%s expected=%s" % [got, core[layer]])
	_check("스폰(다이스) 셀 좌표 불변 (10,9)", ld.spawn_cell == Vector2i(10, 9),
		"spawn_cell=%s" % ld.spawn_cell)
	_check("솥 셀 좌표 불변 (7,12)", ld.cauldron_cell == Vector2i(7, 12),
		"cauldron_cell=%s" % ld.cauldron_cell)
	_check("관측석 셀 좌표 불변 (14,11)", ld.observation_cell == Vector2i(14, 11),
		"observation_cell=%s" % ld.observation_cell)
	# 확장으로 지면(D)이 된 신규 셀은 보행 가능해야 함 (예: 우측 테라스, 하단 앞마당).
	_check("확장 우측 테라스 보행 가능 (17,11)", ld.is_cell_walkable(Vector2i(17, 11)))
	_check("확장 하단 앞마당 보행 가능 (11,18)", ld.is_cell_walkable(Vector2i(11, 18)))
	await _teardown()


# ==== (f) legacy save coords land on a valid cell ==========================

func _f_legacy_save_lands_valid() -> void:
	print("--- (f) 구 좌표 세이브 로드 → 유효 셀 착지 (세이브 호환) ---")
	# 옛 22×22 diamond 레이아웃에서 홈 세이브의 플레이어 좌표는 새 21×17 staggered 슬랩 밖 /
	# VOID 셀에 떨어질 수 있다. 그런 좌표로 홈 세이브를 만든 뒤 로드해 유효 셀 착지를 검증.
	SaveManager.new_game()
	# 홈 씬 부팅 + 등록.
	_scene = await _boot_home()
	var ld := _loader()
	var player := _scene.get_node("YSortLayer/Player") as Node2D
	SaveManager.register_world(ld, player, _scene.get_node("ObjectRespawn"))
	await _frames(1)

	# 구-레이아웃스러운 "먼" 좌표: 확실히 새 슬랩 밖(오프-맵) 이면서 옛 diamond 월드에 있을 법한 위치.
	# 옛 22×22 diamond 섬은 대략 셀공간 중앙 근처 → 그 시절 저장 좌표가 지금은 슬랩 남서쪽 저 멀리.
	var bogus := Vector2(-4000.0, 4000.0)
	# save dict을 손으로 구성해 홈 스냅샷에 bogus player 좌표를 심고 저장.
	SaveManager.save_game()
	var data := SaveManager._read_save()
	# home world 스냅샷의 player 좌표를 bogus로 덮어써 디스크에 다시 기록.
	var worlds: Dictionary = data.get("worlds", {})
	var home_w: Dictionary = worlds.get(WorldContext.SCENE_HOME, {})
	home_w["player"] = {"x": bogus.x, "y": bogus.y}
	worlds[WorldContext.SCENE_HOME] = home_w
	data["worlds"] = worlds
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

	# 확인: bogus 좌표는 실제로 보행 불가(오프-슬랩) 여야 이 테스트가 의미 있음.
	var bogus_cell := ld.world_to_cell(bogus)
	_check("전제: bogus 구-좌표는 보행 불가(오프-슬랩/VOID)", not ld.is_cell_walkable(bogus_cell),
		"bogus_cell=%s" % bogus_cell)

	# teardown 후 홈을 이어하기(pending_load)로 재부팅 → HomeSession이 load_game() 실행.
	await _teardown()
	SaveManager.new_game()          # 메모리 상태 초기화 (복원이 디스크에서 오도록)
	WorldContext.current_scene = WorldContext.SCENE_HOME
	WorldContext.arrival_mode = ""
	SaveManager.pending_load = true
	_scene = load(HOME).instantiate()
	add_child(_scene)
	await _frames(6)
	var ld2 := _loader()
	var player2 := _scene.get_node("YSortLayer/Player") as Node2D
	var landed_cell := ld2.world_to_cell(player2.global_position)
	_check("(f) 구 좌표 세이브 로드 후 플레이어가 유효(보행 가능) 셀 착지",
		ld2.is_cell_walkable(landed_cell),
		"landed_cell=%s pos=%s" % [landed_cell, player2.global_position])
	await _teardown()
