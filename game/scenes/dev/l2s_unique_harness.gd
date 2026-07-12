extends Node
## (EXL2-I) EX-L2 유니크 촉매 어서션 A1~A3. 코어 정수 J12(unique)는 마지막 백업 코어 O에서 1회만
## 채집되며 GB4 봉헌 체인(R08→R09)의 최초 재료다. I9/I14 촉매 규칙 계승 — unique 입력은 present
## 요구·NOT consumed(미소모). 실 Fusion.fuse()로 구동하여 유니크가 GB4 체인을 데드락시키지 않음을 증명:
##   A1  유니크 미소모: J12+J8 → D262(기억의 씨앗) 조합 후에도 J12 여전히 보유(count 불변). 출력 생성.
##   A2  ×2 요구 없음: 어떤 EX-L2 레시피도 unique 아이템을 self-pair([X,X])로 요구하지 않음
##       (unique 상한 1 → self-pair 영구 미충족 = softlock). 전 레시피 정적 스캔.
##   A3  촉매 체인 무결: J12 1개만 쥔 채 R08→R09 전체 체인을 실 Fusion으로 완주하여 D263(복원 코어)
##       획득 — J12는 R08 이후에도 남아 이후 체인/재조합을 막지 않음. 막다른 데코(R21~R23) J12 미사용.
##
## Prints PASS/FAIL per check and quits with the failure count as exit code.

var _fail := 0

# GB4 백업 봉헌 체인 (design §B): 코어 정수(unique)+데이터 결정 → 기억의 씨앗 → 복원 코어.
const CHAIN := [
	{"a": "J12", "b": "J8", "out": "D262"},    # R08: 코어 정수(unique)+데이터 결정 → 기억의 씨앗
	{"a": "D262", "b": "J10", "out": "D263"},  # R09: 기억의 씨앗+광섬유 → 복원 코어
]


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L2s UNIQUE CATALYST HARNESS (J12 코어 정수 · A1~A3) ===")
	_test_a1_not_consumed()
	_test_a2_no_double_unique()
	_test_a3_chain_intact()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A1: 유니크 미소모 ------------------------------------------------------

func _test_a1_not_consumed() -> void:
	print("--- A1: 유니크 미소모 (J12+J8 → D262, J12 잔존) ---")
	_check("J12 = unique 아이템", ItemDB.is_unique("J12"))
	Inventory.clear()
	Inventory.add("J12", 1)   # 유니크는 백업 코어에서 딱 1회 채집 → 1개
	Inventory.add("J8", 1)
	var res := Fusion.fuse("J12", "J8")
	_check("A1 R08 조합 성립 (matched)", bool(res.get("matched", false)), "recipe=%s" % res.get("recipe_id", ""))
	_check("A1 출력 = D262 생성", Inventory.count("D262") == 1)
	_check("A1 유니크 J12 미소모 (조합 후에도 잔존)", Inventory.count("J12") == 1,
		"J12 count=%d" % Inventory.count("J12"))
	_check("A1 비유니크 J8 정상 소모", Inventory.count("J8") == 0)


# ---- A2: unique self-pair(×2) 요구 없음 ------------------------------------

func _test_a2_no_double_unique() -> void:
	print("--- A2: 어떤 EX-L2 레시피도 unique ×2(self-pair) 요구 안 함 ---")
	var offenders: Array = []
	for rec in RecipeDB.all_recipes():
		var inputs: Array = rec.get("inputs", [])
		if inputs.size() != 2:
			continue
		var ca := ItemDB.resolve_id(String(inputs[0]))
		var cb := ItemDB.resolve_id(String(inputs[1]))
		if ca == cb and ItemDB.is_unique(ca):
			offenders.append(String(rec.get("id", "?")))
	_check("A2 unique self-pair 레시피 0건 (softlock 없음)", offenders.is_empty(),
		"offenders=%s" % str(offenders))
	# 추가: J12는 GB4 봉헌 체인(R08 조상)에만 소비 — 막다른 데코/상호 조합에 미사용(설계 §B unique-drain).
	var j12_consumers: Array = []
	for rec in RecipeDB.all_recipes():
		var inputs: Array = rec.get("inputs", [])
		for inp in inputs:
			if ItemDB.resolve_id(String(inp)) == "J12":
				j12_consumers.append(String(rec.get("id", "?")))
	_check("A2 J12 소비 레시피 = 봉헌 체인(EX-L2-R08)뿐 (막다른 데코 미사용)",
		j12_consumers == ["EX-L2-R08"], "consumers=%s" % str(j12_consumers))


# ---- A3: 촉매 체인 무결 (R08→R09 완주) ------------------------------------

func _test_a3_chain_intact() -> void:
	print("--- A3: J12 1개로 GB4 체인 R08→R09 완주 → D263 ---")
	Inventory.clear()
	# 사원/회랑에서 확보하는 재료 한 벌 + 유니크 정수 1개.
	Inventory.add("J12", 1)
	Inventory.add("J8", 1)
	Inventory.add("J10", 1)
	var ok := true
	for step in CHAIN:
		var res := Fusion.fuse(String(step["a"]), String(step["b"]))
		if not bool(res.get("matched", false)) or Inventory.count(String(step["out"])) < 1:
			ok = false
			_check("A3 step %s+%s → %s" % [step["a"], step["b"], step["out"]], false,
				"matched=%s" % res.get("matched", false))
	_check("A3 체인 완주 → 복원 코어 D263 획득", ok and Inventory.count("D263") == 1)
	# 체인 완주 후에도 유니크 J12는 소모되지 않아 잔존 (촉매 미소모 무결성).
	_check("A3 체인 완주 후 유니크 J12 잔존 (촉매 미소모)", Inventory.count("J12") == 1,
		"J12 count=%d" % Inventory.count("J12"))
