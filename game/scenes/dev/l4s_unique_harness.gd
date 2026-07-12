extends Node
## (EXL4-I) EX-L4 유니크 촉매 어서션 A1~A3. 금기 정수 P12(unique)는 최심부 금서고 코어 o에서 1회만
## 채집되며 GW4 봉헌 체인(R08→R09)의 최초 재료다. K12(L3)/J12/I14 촉매 규칙 계승 — 유니크 촉매 프레임
## v1.1: unique 입력은 present 요구·NOT consumed(미소모). 실 Fusion.fuse()로 구동하여 유니크가 GW4
## 체인을 데드락시키지 않음을 증명:
##   A1  유니크 미소모: P12+P8 → D308(봉인구 씨) 조합 후에도 P12 여전히 보유(count 불변). 출력 생성.
##   A2  ×2 요구 없음: 어떤 EX-L4 레시피도 unique 아이템을 self-pair([X,X])로 요구하지 않음
##       (unique 상한 1 → self-pair 영구 미충족 = softlock). 전 레시피 정적 스캔.
##       + P12 소비 레시피 = 봉헌 체인 조상(EX-L4-R08)뿐 (막다른 데코 R10~R23 미사용 = unique-drain 금지).
##   A3  촉매 체인 무결: P12 1개만 쥔 채 R08→R09 전체 체인을 실 Fusion으로 완주하여 D309(금기 봉인구)
##       획득 — P12는 R08 이후에도 남아 이후 체인/재조합을 막지 않음. R09=D308²는 촉매 P12로 R08을
##       2회 제작해 도달(유니크×2 표면 모순은 런타임 softlock 아님, 촉매 미소모).
##
## Prints PASS/FAIL per check and quits with the failure count as exit code.

var _fail := 0

# GW4 금기 봉인구 봉헌 체인 (design §B): 금기 정수(unique)+금서 조각 → 봉인구 씨 → (씨²+마력) 금기 봉인구.
# R09는 봉인구 씨(D308) 두 벌을 요구 → P12(촉매·미소모)로 R08을 2회 제작해 D308 2개 확보 후 융합.
const CHAIN := [
	{"a": "P12", "b": "P8", "out": "D308"},    # R08: 금기 정수(unique)+금서 조각 → 봉인구 씨
	{"a": "P12", "b": "P8", "out": "D308"},    # R08 재제작 (촉매 P12로 D308 두 벌째)
	{"a": "D308", "b": "D308", "out": "D309"}, # R09: 봉인구 씨² (+마력) → 금기 봉인구
]


func _check(label: String, cond: bool, detail: String = "") -> void:
	print("[%s] %s%s" % ["PASS" if cond else "FAIL", label, ("  (%s)" % detail) if detail != "" else ""])
	if not cond:
		_fail += 1


func _ready() -> void:
	print("=== L4S UNIQUE CATALYST HARNESS (P12 금기 정수 · A1~A3) ===")
	_test_a1_not_consumed()
	_test_a2_no_double_unique()
	_test_a3_chain_intact()
	print("=== RESULT: %s (%d failures) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(_fail)


# ---- A1: 유니크 미소모 ------------------------------------------------------

func _test_a1_not_consumed() -> void:
	print("--- A1: 유니크 미소모 (P12+P8 → D308, P12 잔존) ---")
	_check("P12 = unique 아이템", ItemDB.is_unique("P12"))
	Inventory.clear()
	Inventory.add("P12", 1)   # 유니크는 최심부 금서고 코어에서 딱 1회 채집 → 1개
	Inventory.add("P8", 1)
	var res := Fusion.fuse("P12", "P8")
	_check("A1 R08 조합 성립 (matched)", bool(res.get("matched", false)), "recipe=%s" % res.get("recipe_id", ""))
	_check("A1 출력 = D308 생성", Inventory.count("D308") == 1)
	_check("A1 유니크 P12 미소모 (조합 후에도 잔존)", Inventory.count("P12") == 1,
		"P12 count=%d" % Inventory.count("P12"))
	_check("A1 비유니크 P8 정상 소모", Inventory.count("P8") == 0)


# ---- A2: unique self-pair(×2) 요구 없음 + unique-drain 금지 -----------------

func _test_a2_no_double_unique() -> void:
	print("--- A2: 어떤 EX-L4 레시피도 unique ×2(self-pair) 요구 안 함 + P12 게이트 체인 전용 ---")
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
	# P12는 GW4 봉헌 체인(R08 조상)에만 소비 — 막다른 데코/상호 조합에 미사용(설계 §B unique-drain 금지).
	var p12_consumers: Array = []
	for rec in RecipeDB.all_recipes():
		var inputs: Array = rec.get("inputs", [])
		for inp in inputs:
			if ItemDB.resolve_id(String(inp)) == "P12":
				p12_consumers.append(String(rec.get("id", "?")))
	_check("A2 P12 소비 레시피 = 봉헌 체인(EX-L4-R08)뿐 (막다른 데코 미사용)",
		p12_consumers == ["EX-L4-R08"], "consumers=%s" % str(p12_consumers))


# ---- A3: 촉매 체인 무결 (R08×2 → R09 완주) --------------------------------

func _test_a3_chain_intact() -> void:
	print("--- A3: P12 1개로 GW4 체인 R08→R09 완주 → D309 ---")
	Inventory.clear()
	# 착지/하부 서가에서 확보하는 비유니크 재료 + 유니크 금기 정수 1개.
	# R09가 봉인구 씨 2개를 요구하므로 P8도 2개(R08 2회분). P12는 촉매라 1개면 충분.
	Inventory.add("P12", 1)
	Inventory.add("P8", 2)
	# R09(금기 봉인구)는 whisper_cost.mana:1 (GW4 유일 마력 sink). 잔류 열람 결계정 W에서 거둔 마력 상당.
	if typeof(WhisperCurrency) != TYPE_NIL:
		WhisperCurrency.reset()
		WhisperCurrency.add_mana(1)
	var ok := true
	for step in CHAIN:
		var res := Fusion.fuse(String(step["a"]), String(step["b"]))
		if not bool(res.get("matched", false)) or Inventory.count(String(step["out"])) < 1:
			ok = false
			_check("A3 step %s+%s → %s" % [step["a"], step["b"], step["out"]], false,
				"matched=%s" % res.get("matched", false))
	_check("A3 체인 완주 → 금기 봉인구 D309 획득", ok and Inventory.count("D309") == 1)
	# 체인 완주 후에도 유니크 P12는 소모되지 않아 잔존 (촉매 미소모 무결성).
	_check("A3 체인 완주 후 유니크 P12 잔존 (촉매 미소모)", Inventory.count("P12") == 1,
		"P12 count=%d" % Inventory.count("P12"))
