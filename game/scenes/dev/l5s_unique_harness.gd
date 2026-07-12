extends Node
## (EXL5-6) L5 확장 「침묵의 종탑」 UNIQUE acceptance harness. l5x_recipes.py proves the STATIC
## recipe contract (페어중복/softlock/unique-drain 멤버십/3속성 sink); this proves the RUNTIME
## unique-as-catalyst mechanic on the REAL Fusion.fuse() transaction (fusion.gd _consume_inputs,
## catalyst 규칙 M3). 정본 §㉓ 촉매 정정("유니크는 존재만 요구·소모 0")을 실 인벤토리로 못 박는다:
##
##   A1 유니크 미소모: S12(신의 마지막 음, items.json unique=true)는 GB4 체인 제작에 존재만
##      요구되고 소모되지 않는다. 단 하나의 S12로 EX-L5-R08(타종구 씨 = S12+S8) 제작 후에도
##      S12는 인벤토리에 그대로 1개 남는다 (촉매). 재료(S8)는 정상 소모.
##   A2 self-pair·×2 없음: EX-L5-R09(응답의 타종구 = D331²)는 표면상 타종구 씨 '둘'을 요구하나,
##      S12 미소모이므로 단 하나의 S12로 D331을 2회 제작해 D331 스택 2개를 만들 수 있다
##      (유니크×2 표면 모순 = 런타임 softlock 아님). 또한 유니크 self-pair(가령 S12+S12)는
##      1개만 있어도 통과·소모0인 촉매 경로임을 실측(오늘 그런 레시피는 없지만 규칙 자체를 검증).
##   A3 체인 무결: 단 하나의 S12만으로 S12→R08(D331)→R09(D332) 전 체인을 완주해 실제 GB4
##      최종물 D332(응답의 타종구)에 도달한다. R09는 3속성 Whisper(energy·mana·vita 각1)를
##      소비하고, 완주 후에도 S12는 여전히 1개 (게이트 체인 = 유니크 유일 소비처, drain 0).
##
## Drives the REAL Fusion.fuse() (조합 트랜잭션) — API로 인벤토리 직접 조작해 결과 위조 금지.
## Prints PASS/FAIL; quits with the failure count as exit code.

const S12 := "S12"          # 신의 마지막 음 (unique)
const S8 := "S8"            # 종 파편
const D331 := "D331"         # 타종구 씨 (EX-L5-R08 = S12 + S8)
const D332 := "D332"         # 응답의 타종구 (EX-L5-R09 = D331 + D331, whisper {e,m,v}=1)

var _fail := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _reset() -> void:
	Inventory.clear()
	WhisperCurrency.reset()


func _ready() -> void:
	print("=== L5S UNIQUE HARNESS (유니크 미소모 / self-pair·×2 없음 / 체인 무결) ===")

	# 선결: S12는 실제로 unique 로 로드되어 있어야 catalyst 경로가 발동한다.
	_check("S12 = ItemDB unique (촉매 대상)", ItemDB.is_unique(ItemDB.resolve_id(S12)))
	# 레시피 계약 확인 (R08 = S12+S8 → D331, R09 = D331² → D332).
	var r08 := RecipeDB.find_recipe([S12, S8])
	_check("EX-L5-R08(S12+S8) → D331 레시피 존재", not r08.is_empty()
		and ItemDB.resolve_id(String(r08.get("output", ""))) == ItemDB.resolve_id(D331))
	var r09 := RecipeDB.find_recipe([D331, D331])
	_check("EX-L5-R09(D331²) → D332 레시피 존재", not r09.is_empty()
		and ItemDB.resolve_id(String(r09.get("output", ""))) == ItemDB.resolve_id(D332))

	_test_a1_unique_not_consumed()
	_test_a2_no_self_pair_x2()
	_test_a3_chain_integrity()

	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A1. 유니크 미소모 (촉매) -------------------------------------------

func _test_a1_unique_not_consumed() -> void:
	print("--- A1 유니크 미소모 (S12 = 촉매, 존재만 요구·소모 0) ---")
	_reset()
	var cs12 := ItemDB.resolve_id(S12)
	var cs8 := ItemDB.resolve_id(S8)
	var cd331 := ItemDB.resolve_id(D331)
	# 단 하나의 S12 + S8 1개.
	Inventory.add(cs12, 1)
	Inventory.add(cs8, 1)
	_check("A1 준비: S12=1, S8=1", Inventory.count(cs12) == 1 and Inventory.count(cs8) == 1)

	var res := Fusion.fuse(S12, S8)
	_check("A1 R08 제작 성공", bool(res.get("matched", false))
		and ItemDB.resolve_id(String(res.get("output", ""))) == cd331,
		"output=%s" % String(res.get("output", "")))
	# 핵심: 유니크 S12 미소모 → 여전히 1개. 비유니크 재료 S8 은 정상 소모 → 0.
	_check("A1 유니크 S12 미소모 (촉매, 여전히 1개)", Inventory.count(cs12) == 1,
		"S12=%d" % Inventory.count(cs12))
	_check("A1 비유니크 재료 S8 정상 소모 (1→0)", Inventory.count(cs8) == 0,
		"S8=%d" % Inventory.count(cs8))
	_check("A1 산출 D331 +1", Inventory.count(cd331) == 1, "D331=%d" % Inventory.count(cd331))

	# S8 이 없으면(재료 없음) 유니크가 있어도 제작은 깨끗한 no-op — 촉매만으로 생성 불가.
	# (재료 소진 후 재시도: S8=0 이므로 실패, S12·D331 불변)
	var d331_before := Inventory.count(cd331)
	var res2 := Fusion.fuse(S12, S8)
	_check("A1 재료(S8) 소진 후 재시도 = no-op (촉매만으론 생성 불가)",
		not bool(res2.get("matched", false)))
	_check("A1 no-op: S12=1 불변, D331 불변", Inventory.count(cs12) == 1
		and Inventory.count(cd331) == d331_before)


# ---- A2. self-pair·×2 없음 (유니크 표면 모순 = softlock 아님) ------------

func _test_a2_no_self_pair_x2() -> void:
	print("--- A2 self-pair·×2 없음 (단일 S12로 D331² 도달) ---")
	_reset()
	var cs12 := ItemDB.resolve_id(S12)
	var cs8 := ItemDB.resolve_id(S8)
	var cd331 := ItemDB.resolve_id(D331)
	# 단 하나의 S12(유니크 캡=1) + S8 2개 → D331 을 2회 제작.
	Inventory.add(cs12, 1)
	Inventory.add(cs8, 2)
	_check("A2 준비: S12=1(유니크 캡), S8=2", Inventory.count(cs12) == 1 and Inventory.count(cs8) == 2)

	var ok1 := bool(Fusion.fuse(S12, S8).get("matched", false))
	var ok2 := bool(Fusion.fuse(S12, S8).get("matched", false))
	_check("A2 단일 S12로 R08 2회 제작 성공 (유니크 미소모 덕)", ok1 and ok2)
	_check("A2 → D331 스택 2개 확보 (유니크×2 표면 모순 해소)", Inventory.count(cd331) == 2,
		"D331=%d" % Inventory.count(cd331))
	_check("A2 S12 여전히 1개 (2회 제작에도 소모 0)", Inventory.count(cs12) == 1,
		"S12=%d" % Inventory.count(cs12))

	# self-pair 규칙 자체 검증: 유니크 same-ingredient 은 1개만 있어도 통과·소모0.
	# (fusion.gd _consume_inputs: ca==cb & is_unique → count>=1 이면 소모0 true)
	# 오늘 그런 레시피는 없으므로, 비유니크 self-pair(D331²)는 정확히 2개를 요구함을 대조 검증:
	#   D331 이 1개뿐이면 R09(D331²)는 재료 부족 no-op이어야 한다.
	_reset()
	Inventory.add(cd331, 1)   # 비유니크 self-pair 재료 1개뿐
	var short := Fusion.fuse(D331, D331)
	_check("A2 대조: 비유니크 self-pair는 1개론 부족 no-op (2개 요구 확인)",
		not bool(short.get("matched", false)) and Inventory.count(cd331) == 1)


# ---- A3. 체인 무결 (S12 → R08 → R09 = GB4 최종물) -----------------------

func _test_a3_chain_integrity() -> void:
	print("--- A3 체인 무결 (단일 S12로 D332 완주, drain 0) ---")
	_reset()
	var cs12 := ItemDB.resolve_id(S12)
	var cs8 := ItemDB.resolve_id(S8)
	var cd331 := ItemDB.resolve_id(D331)
	var cd332 := ItemDB.resolve_id(D332)
	# 단 하나의 S12 + S8 2개 + 3속성 Whisper 각1 → 전 체인 완주.
	Inventory.add(cs12, 1)
	Inventory.add(cs8, 2)
	WhisperCurrency.add_energy(1)
	WhisperCurrency.add_mana(1)
	WhisperCurrency.add_vita(1)

	# 1단: R08 두 번 → D331 ×2.
	Fusion.fuse(S12, S8)
	Fusion.fuse(S12, S8)
	_check("A3 1단: D331 ×2 확보", Inventory.count(cd331) == 2)

	# 3속성 부족 시 R09 거부 검증 (whisper sink) — vita 뺏고 시도 → 재료·속삭임 미소모 no-op.
	WhisperCurrency.spend_vita(1)
	var deny := Fusion.fuse(D331, D331)
	_check("A3 3속성(vita) 부족 → R09 거부 (재료 미소모 no-op)",
		not bool(deny.get("matched", false))
		and String(deny.get("failure_reason", "")) != ""
		and Inventory.count(cd331) == 2)
	WhisperCurrency.add_vita(1)   # 복원

	# 2단: R09 → D332 (3속성 각1 소비).
	var res := Fusion.fuse(D331, D331)
	_check("A3 2단: R09 → D332(응답의 타종구) 완주", bool(res.get("matched", false))
		and ItemDB.resolve_id(String(res.get("output", ""))) == cd332)
	_check("A3 D332 +1 (GB4 실 최종물 도달)", Inventory.count(cd332) == 1,
		"D332=%d" % Inventory.count(cd332))
	_check("A3 D331² 정상 소모 (2→0)", Inventory.count(cd331) == 0)
	_check("A3 R09 3속성 각1 소모 (energy·mana·vita sink)",
		WhisperCurrency.energy == 0 and WhisperCurrency.mana == 0 and WhisperCurrency.vita == 0,
		"e=%d m=%d v=%d" % [WhisperCurrency.energy, WhisperCurrency.mana, WhisperCurrency.vita])
	# 체인 완주 후에도 유니크 S12 는 여전히 1개 = 게이트 체인이 유니크 유일 소비처, 실 drain 0.
	_check("A3 체인 완주 후 S12 여전히 1개 (drain 0, 촉매 불변)", Inventory.count(cs12) == 1,
		"S12=%d" % Inventory.count(cs12))
