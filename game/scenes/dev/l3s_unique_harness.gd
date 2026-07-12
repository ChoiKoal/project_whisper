extends Node
## (EXL3-I) EX-L3 유니크 촉매 어서션 A1~A3. 심층 태엽정 K12(unique)는 대굴착기 코어 O에서 1회만
## 채집되며 GM4 봉헌 체인(R08→R09)의 최초 재료다. J12/I14 촉매 규칙 계승 — unique 입력은 present
## 요구·NOT consumed(미소모). 실 Fusion.fuse()로 구동하여 유니크가 GM4 체인을 데드락시키지 않음을 증명:
##   A1  유니크 미소모: K12+K8 → D285(감긴 태엽 씨) 조합 후에도 K12 여전히 보유(count 불변). 출력 생성.
##   A2  ×2 요구 없음: 어떤 EX-L3 레시피도 unique 아이템을 self-pair([X,X])로 요구하지 않음
##       (unique 상한 1 → self-pair 영구 미충족 = softlock). 전 레시피 정적 스캔.
##   A3  촉매 체인 무결: K12 1개만 쥔 채 R08→R09 전체 체인을 실 Fusion으로 완주하여 D286(태엽 노심)
##       획득 — K12는 R08 이후에도 남아 이후 체인/재조합을 막지 않음. 막다른 데코(R21~R23) K12 미사용.
##
## Prints PASS/FAIL per check and quits with the failure count as exit code.

var _fail := 0

# GM4 태엽 노심 봉헌 체인 (design §B): 심층 태엽정(unique)+태엽 광석 → 감긴 태엽 씨 → 태엽 노심.
const CHAIN := [
	{"a": "K12", "b": "K8", "out": "D285"},    # R08: 심층 태엽정(unique)+태엽 광석 → 감긴 태엽 씨
	{"a": "D285", "b": "K10", "out": "D286"},  # R09: 감긴 태엽 씨+갱도 석탄 → 태엽 노심
]


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L3s UNIQUE CATALYST HARNESS (K12 심층 태엽정 · A1~A3) ===")
	_test_a1_not_consumed()
	_test_a2_no_double_unique()
	_test_a3_chain_intact()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A1: 유니크 미소모 ------------------------------------------------------

func _test_a1_not_consumed() -> void:
	print("--- A1: 유니크 미소모 (K12+K8 → D285, K12 잔존) ---")
	_check("K12 = unique 아이템", ItemDB.is_unique("K12"))
	Inventory.clear()
	Inventory.add("K12", 1)   # 유니크는 대굴착기 코어에서 딱 1회 채집 → 1개
	Inventory.add("K8", 1)
	var res := Fusion.fuse("K12", "K8")
	_check("A1 R08 조합 성립 (matched)", bool(res.get("matched", false)), "recipe=%s" % res.get("recipe_id", ""))
	_check("A1 출력 = D285 생성", Inventory.count("D285") == 1)
	_check("A1 유니크 K12 미소모 (조합 후에도 잔존)", Inventory.count("K12") == 1,
		"K12 count=%d" % Inventory.count("K12"))
	_check("A1 비유니크 K8 정상 소모", Inventory.count("K8") == 0)


# ---- A2: unique self-pair(×2) 요구 없음 ------------------------------------

func _test_a2_no_double_unique() -> void:
	print("--- A2: 어떤 EX-L3 레시피도 unique ×2(self-pair) 요구 안 함 ---")
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
	# 추가: K12는 GM4 봉헌 체인(R08 조상)에만 소비 — 막다른 데코/상호 조합에 미사용(설계 §B unique-drain).
	var k12_consumers: Array = []
	for rec in RecipeDB.all_recipes():
		var inputs: Array = rec.get("inputs", [])
		for inp in inputs:
			if ItemDB.resolve_id(String(inp)) == "K12":
				k12_consumers.append(String(rec.get("id", "?")))
	_check("A2 K12 소비 레시피 = 봉헌 체인(EX-L3-R08)뿐 (막다른 데코 미사용)",
		k12_consumers == ["EX-L3-R08"], "consumers=%s" % str(k12_consumers))


# ---- A3: 촉매 체인 무결 (R08→R09 완주) ------------------------------------

func _test_a3_chain_intact() -> void:
	print("--- A3: K12 1개로 GM4 체인 R08→R09 완주 → D286 ---")
	Inventory.clear()
	# 갱도/회랑에서 확보하는 재료 한 벌 + 유니크 태엽정 1개.
	Inventory.add("K12", 1)
	Inventory.add("K8", 1)
	Inventory.add("K10", 1)
	var ok := true
	for step in CHAIN:
		var res := Fusion.fuse(String(step["a"]), String(step["b"]))
		if not bool(res.get("matched", false)) or Inventory.count(String(step["out"])) < 1:
			ok = false
			_check("A3 step %s+%s → %s" % [step["a"], step["b"], step["out"]], false,
				"matched=%s" % res.get("matched", false))
	_check("A3 체인 완주 → 태엽 노심 D286 획득", ok and Inventory.count("D286") == 1)
	# 체인 완주 후에도 유니크 K12는 소모되지 않아 잔존 (촉매 미소모 무결성).
	_check("A3 체인 완주 후 유니크 K12 잔존 (촉매 미소모)", Inventory.count("K12") == 1,
		"K12 count=%d" % Inventory.count("K12"))
