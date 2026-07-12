extends Node
## (EXL1-I) EX-L1 유니크 촉매 어서션 A1~A3. 생명의 정수 I14(unique)는 세계수 심장 O에서 1회만
## 채집되며 GH2 봉헌 체인(R12→R13→R14)의 최초 재료다. 시작의 숲 I9(세계수 정수)의 촉매 규칙을
## 계승 — unique 입력은 present 요구·NOT consumed(미소모). 이 하네스는 실 Fusion.fuse()로 구동하여
## 유니크가 GH2 체인을 데드락시키지 않음을 증명한다:
##   A1  유니크 미소모: I14+I16 → D233 조합 후에도 I14 여전히 보유(count 불변). 출력 D233 생성.
##   A2  ×2 요구 없음: 어떤 EX-L1 레시피도 unique 아이템을 self-pair([X,X])로 요구하지 않음
##       (unique는 1개 상한 → self-pair는 영구 미충족 = softlock). 전 레시피 정적 스캔.
##   A3  촉매 체인 무결: I14를 1개만 쥔 채 R12→R13→R14 전체 체인을 실 Fusion으로 완주하여 D235
##       (되살아난 심장) 획득 — I14는 R12 이후에도 남아 이후 체인/재조합을 막지 않음.
##
## Prints PASS/FAIL per check and quits with the failure count as exit code.

var _fail := 0

# GH2 심장 소생 체인 (design §Part D): 생명의 씨눈 → 심장의 고동물 → 되살아난 심장.
const CHAIN := [
	{"a": "I14", "b": "I16", "out": "D233"},   # R12: 생명의 정수(unique)+씨눈
	{"a": "D233", "b": "I15", "out": "D234"},  # R13: 생명의 씨눈+뿌리 수액
	{"a": "D234", "b": "I17", "out": "D235"},  # R14: 심장의 고동물+심장 이끼 → 되살아난 심장
]


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L1x UNIQUE CATALYST HARNESS (I14 생명의 정수 · A1~A3) ===")
	_test_a1_not_consumed()
	_test_a2_no_double_unique()
	_test_a3_chain_intact()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A1: 유니크 미소모 ------------------------------------------------------

func _test_a1_not_consumed() -> void:
	print("--- A1: 유니크 미소모 (I14+I16 → D233, I14 잔존) ---")
	_check("I14 = unique 아이템", ItemDB.is_unique("I14"))
	Inventory.clear()
	Inventory.add("I14", 1)   # 유니크는 세계수 심장에서 딱 1회 채집 → 1개
	Inventory.add("I16", 1)
	var res := Fusion.fuse("I14", "I16")
	_check("A1 R12 조합 성립 (matched)", bool(res.get("matched", false)), "recipe=%s" % res.get("recipe_id", ""))
	_check("A1 출력 = D233 생성", Inventory.count("D233") == 1)
	_check("A1 유니크 I14 미소모 (조합 후에도 잔존)", Inventory.count("I14") == 1,
		"I14 count=%d" % Inventory.count("I14"))
	_check("A1 비유니크 I16 정상 소모", Inventory.count("I16") == 0)


# ---- A2: unique self-pair(×2) 요구 없음 ------------------------------------

func _test_a2_no_double_unique() -> void:
	print("--- A2: 어떤 EX-L1 레시피도 unique ×2(self-pair) 요구 안 함 ---")
	var offenders: Array = []
	for rec in RecipeDB.all_recipes():
		var inputs: Array = rec.get("inputs", [])
		if inputs.size() != 2:
			continue
		var ca := ItemDB.resolve_id(String(inputs[0]))
		var cb := ItemDB.resolve_id(String(inputs[1]))
		# self-pair of a unique = 두 개가 필요하지만 unique는 상한 1 → 영구 미충족.
		if ca == cb and ItemDB.is_unique(ca):
			offenders.append(String(rec.get("id", "?")))
	_check("A2 unique self-pair 레시피 0건 (softlock 없음)", offenders.is_empty(),
		"offenders=%s" % str(offenders))


# ---- A3: 촉매 체인 무결 (R12→R13→R14 완주) ---------------------------------

func _test_a3_chain_intact() -> void:
	print("--- A3: I14 1개로 GH2 체인 R12→R13→R14 완주 → D235 ---")
	Inventory.clear()
	# 회랑/최심부에서 확보하는 재료 한 벌 + 유니크 정수 1개.
	Inventory.add("I14", 1)
	Inventory.add("I16", 1)
	Inventory.add("I15", 1)
	Inventory.add("I17", 1)
	var ok := true
	for step in CHAIN:
		var res := Fusion.fuse(String(step["a"]), String(step["b"]))
		if not bool(res.get("matched", false)) or Inventory.count(String(step["out"])) < 1:
			ok = false
			_check("A3 step %s+%s → %s" % [step["a"], step["b"], step["out"]], false,
				"matched=%s" % res.get("matched", false))
	_check("A3 체인 완주 → 되살아난 심장 D235 획득", ok and Inventory.count("D235") == 1)
	# 체인 완주 후에도 유니크 I14는 소모되지 않아 잔존 (촉매 미소모 무결성).
	_check("A3 체인 완주 후 유니크 I14 잔존 (촉매 미소모)", Inventory.count("I14") == 1,
		"I14 count=%d" % Inventory.count("I14"))
