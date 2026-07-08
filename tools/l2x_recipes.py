#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l2x_recipes.py — EX-L2 확장 레시피(구역 「지하 데이터 성소」) 생성·무결성 검증.

프리픽스: 신규 L2 채집 = J8~J12 (기존 items.json J1~J7 뒤 연속),
         신규 조합 산출 = D255~ (기존 items.json D≤221 + EX-L1 예약 D222~D254 뒤에 연속).
게이트 체인이 최우선 계약 — Part A §A-3/§A-6이 요구하는 최종물·다단 순서를 못 박는다.

검증:
  (1) 페어 중복 없음 (기존 220 recipes.json 대조 + 신규 내부)
  (2) softlock 불가 (게이트 재료 ⊆ 게이트 앞 누적 지대)
  (3) 산출 D 연속·dangling 0

★기존 EX-L1이 D222~D254를 예약하므로 EX-L2 산출은 D255~. 채집은 J8~.
★게이트 체인은 EX-L1과 페어중복 0 실측(EX-L1 레시피도 대조 대상에 포함).

재현: python3 tools/l2x_recipes.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
TOOLS = os.path.join(ROOT, "tools")

# ---- 신규 채집 원소 (J8~J11 + J12 유니크 백업 코어 정수) ----
GATHERS = [
    ("J8", "데이터 결정", "sanctum", "gather", "서버 랙에 맺힌 결정. 지워지지 못한 기록이, 빛으로 굳었다."),
    ("J9", "부식 코어", "sanctum", "gather", "녹슨 연산 조각. 무슨 생각을 하다 부식됐는지, 이제 읽히지 않는다."),
    ("J10", "광섬유 다발", "sanctum", "gather", "끊긴 채 늘어진 실. 아직 어딘가로 신호를 보내고 싶은 듯 미약하게 떤다."),
    ("J11", "냉각 젤", "sanctum", "gather", "굳어가는 반투명 젤. 열을 식히던 것. 이제 식힐 열조차 남지 않았다."),
    ("J12", "코어 정수", "sanctum", "gather_unique", "마지막 백업 코어에서 꺼낸 기억의 씨앗. 문명이 남긴 단 하나의 온전한 기록."),  # unique
]

R = []
DOUT = 255  # EX-L1이 D222~D254 예약 → EX-L2는 D255~


def rec(rid, name, inputs, hint, flavor, place="", whisper=None):
    global DOUT
    out = f"D{DOUT}"
    DOUT += 1
    R.append({"id": rid, "name": name, "inputs": inputs, "hint": hint,
              "flavor": flavor, "place": place, "output": out, "whisper": whisper})
    return out


# =========================================================
# 게이트 체인 — GB1~GB4 (EX-L2-R01 ~ R09)
#   GB1 냉각 침수로: 방수 디딤돌(D256) 배치 = 냉각 젤 굳힌 판 + 부식 코어(구조재)
#   GB2 봉인 격벽: 디코더 젤(D258) 사용 = 데이터 결정 + 광섬유로 신호 복원
#   GB3 데이터 문(3조각 정합): 정합 조각 3종 배치(순서 무관)
#   GB4 백업 봉헌: 복원 코어(체인) 봉헌 = 구역 정화 + 컷신
#   ★J12(코어 정수, 유니크)는 GB4 최종 봉헌물에만 사용 = 마지막 게이트 자기 재료(order-safe)
# =========================================================
# GB1 — 방수 디딤돌 (배치형): 냉각 젤을 굳혀 만든 방수판
d_gel_slab = rec("EX-L2-R01", "굳은 냉각 젤판", ["J11", "J9"],
                 "냉각 젤을 부식 코어 조각에 부어 굳히면", "물러 있던 젤이 판이 된다. 밟아도 스미지 않게.", "")
rec("EX-L2-R02", "방수 디딤돌", [d_gel_slab, "J8"],  # D256
    "굳은 젤판에 데이터 결정을 박아 무게를 더하면", "침수로 위에 놓을, 가라앉지 않는 발판.",
    "placement · 냉각 침수로 K 배치(GB1)")
# GB2 — 디코더 젤 (사용형): 봉인 격벽에 주입해 급전 복호
d_signal = rec("EX-L2-R03", "복원 신호선", ["J8", "J10"],
               "데이터 결정을 광섬유에 이으면", "끊겼던 선에 다시 신호가 흐른다. 아주 약하게.", "")
rec("EX-L2-R04", "디코더 젤", [d_signal, "J11"],  # D258
    "복원 신호선을 냉각 젤에 재워 안정시키면", "격벽의 잠금을 풀어낼 열쇠 젤. 주입하면 격벽이 스스로 물러난다.",
    "use · 봉인 격벽에 사용(GB2)")
# GB3 — 정합 조각 3종 (배치 미니퍼즐): 정합실 슬롯 3개에 각각
d_shard_a = rec("EX-L2-R05", "정합 조각 α", ["J8", "J9"],
                "데이터 결정을 부식 코어에 정합하면", "깨진 기록의 첫 조각. 홀로는 아무 뜻이 없다.", "placement · 데이터 정합 슬롯(α)")
d_shard_b = rec("EX-L2-R06", "정합 조각 β", ["J10", "J11"],
                "광섬유를 냉각 젤에 담가 데이터를 안정시켜 붙이면", "둘째 조각. 첫 조각과 결이 맞물린다.", "placement · 데이터 정합 슬롯(β)")
d_shard_c = rec("EX-L2-R07", "정합 조각 γ", [d_signal, "J9"],  # 복원 신호선(D257)+부식 코어
                "복원 신호선을 부식 코어에 감아 마지막 조각을 잇면", "셋째 조각. 이제 셋을 제자리에 놓으면, 문이 읽어낸다.", "placement · 데이터 정합 슬롯(γ)")
# GB4 — 복원 코어 (체인형): 유니크 코어 정수(J12) → 복원 = 구역 정화
d_mem_seed = rec("EX-L2-R08", "기억의 씨앗", ["J12", "J8"],
                 "코어 정수를 데이터 결정에 새겨 넣으면", "마지막 기록이, 작은 결정 속으로 옮겨 앉는다.", "")
d_restored_core = rec("EX-L2-R09", "복원 코어", [d_mem_seed, "J10"],  # D263
    "기억의 씨앗을 광섬유로 코어에 다시 이으면", "잠들었던 백업이 깨어날 준비를 마친다. 문명의 마지막 숨을, 여기 봉헌한다.",
    "chain · 백업 봉헌 목 봉헌(GB4=구역 정화/클리어) · 컷신")

# =========================================================
# 유효 상호 조합 — 지하 데이터 성소 (말 되는 것만) EX-L2-R10~R16
# =========================================================
rec("EX-L2-R10", "결정 무리", ["J8", "J8"], "데이터 결정 둘을 겹쳐 쌓으면", "빛이 조금 더 밝아진다. 지워지지 않으려는 두 기억.", "decor · glows")
rec("EX-L2-R11", "부식 덩이", ["J9", "J9"], "부식 코어 둘을 눌러 뭉치면", "녹이 녹을 부른다. 무거운 침묵의 덩이.", "structure")
rec("EX-L2-R12", "광섬유 타래", ["J10", "J10"], "광섬유 다발 둘을 한데 감으면", "실이 실을 붙든다. 어디로도 닿지 못한 채.", "decor")
rec("EX-L2-R13", "냉각 젤 블록", ["J11", "J11"], "냉각 젤 둘을 틀에 부어 굳히면", "반투명한 벽돌. 안에 옛 열기가 갇힌 듯도 하다.", "structure")
rec("EX-L2-R14", "결정 랜턴", ["J8", "J11"], "데이터 결정을 냉각 젤에 재워 손등불로 굳히면", "손안의 작은 서버. 들면 지난 기록이 희미하게 명멸한다.", "decor · glows")
rec("EX-L2-R15", "젤 절연판", [d_gel_slab, "J10"],  # 굳은 젤판(D255)+광섬유
    "굳은 젤판에 광섬유를 촘촘히 깔면", "열도 신호도 새지 않는 판. 무언가를 오래 지키려는 손길.", "structure")
rec("EX-L2-R16", "부식 부적", [d_shard_a, "J10"],  # 정합 조각 α(D259)+광섬유
    "정합 조각을 광섬유로 꿰어 목에 걸면", "읽히지 않는 기록을 부적처럼. 뜻은 몰라도, 지니고 싶은 것.", "decor")

# =========================================================
# 교차 조합 — 터미널 스테이션(L2 구역1) 산물 활용 EX-L2-R17~R20
#   ★게이트 체인엔 절대 안 씀(구역 단독 클리어 가능). 전부 수집/장식.
#   D64=전지, D65=네온 랜턴, D69=파워 코어, D73=네온관(기존 L2 산물)
# =========================================================
rec("EX-L2-R17", "백업 등명", [d_restored_core, "J8"],  # 복원 코어(D264)+데이터 결정
    "복원 코어의 여분 빛을 데이터 결정에 담으면", "성소를 밝히는 등명. 되살린 기억의 한 조각을, 곁에 둔다.",
    "structure · glows")
rec("EX-L2-R18", "네온 서버탑", ["D73", "J8"],  # 네온관(기존 L2)+데이터 결정
    "네온관에 데이터 결정을 층층이 쌓으면", "죽은 도시의 불빛과, 지하의 기록이 한 탑에 선다.",
    "structure · glows")
rec("EX-L2-R19", "충전된 코어함", ["D64", "J11"],  # 전지(기존 L2)+냉각 젤
    "전지를 냉각 젤에 재워 코어함에 넣으면", "식은 심장에 온기를 한 칸. 다시 뛸 날을 위한 예비.",
    "structure")
rec("EX-L2-R20", "기록 랜턴", ["D65", "J10"],  # 네온 랜턴(기존 L2)+광섬유
    "네온 랜턴에 광섬유를 이어 기록을 흘려보내면", "들고 걸으면 벽에 옛 문장이 스친다. 아무도 읽지 않을, 그러나 남은.",
    "decor · glows")

# =========================================================
# 막다른 재미 leaf — 관리 드론 / 전쟁 기록 톤 EX-L2-R21~R23
# =========================================================
rec("EX-L2-R21", "지워진 로그", [d_shard_b, "J9"],  # 정합 조각 β(D260)+부식 코어
    "정합 조각을 부식 코어에 겹쳐 읽으려 하면… 문자가 녹슬어 지워진다", "마지막 로그. 무엇을 기록하려 했는지, 녹 속으로 번져버렸다.", "decor")
rec("EX-L2-R22", "굳은 관리 드론", [d_gel_slab, "J9"],  # 굳은 젤판(D255)+부식 코어
    "젤판에 부식 코어를 앉히면… 팔다리가 굳어 멈춘 드론이 된다", "성소를 지키던 관리 드론의 말로. 명령을 기다리는 자세로 굳었다.", "structure")
rec("EX-L2-R23", "타버린 훈장 데이터", ["J10", "J9"],  # 광섬유+부식 코어 = 타버린 기록 (유니크 J12 미사용: EX-L1 QA 원칙)
    "광섬유를 부식 코어에 억지로 이으면… 과부하로 새까맣게 탄다", "누군가는 이 기록을 자랑스러워했다. 이제는 탄 자국만 남았다.", "decor")


def build():
    return R, GATHERS


# ---- 무결성 검증 ----
def existing_pairs():
    recs = json.load(open(os.path.join(DATA, "recipes.json"), encoding="utf-8"))["recipes"]
    pairs = {}
    for x in recs:
        inp = x["inputs"]
        if len(inp) == 2 and inp[0] == inp[1]:
            k = ("SAME", inp[0])
        else:
            k = frozenset(inp)
        pairs.setdefault(k, x["id"])
    return pairs, recs


def exl1_pairs():
    """EX-L1 예약 레시피도 페어중복 대조 대상(과제 계약: EX-L1과 페어중복 0)."""
    frag = os.path.join(TOOLS, "l1x_data_fragment.json")
    pairs = {}
    if os.path.exists(frag):
        data = json.load(open(frag, encoding="utf-8"))
        for x in data.get("recipes", []):
            inp = x["inputs"]
            if len(inp) == 2 and inp[0] == inp[1]:
                k = ("SAME", inp[0])
            else:
                k = frozenset(inp)
            pairs.setdefault(k, x["id"])
    return pairs


def pair_key(inp):
    if len(inp) == 2 and inp[0] == inp[1]:
        return ("SAME", inp[0])
    return frozenset(inp)


def main():
    ex_pairs, ex_recs = existing_pairs()
    l1_pairs = exl1_pairs()
    print("=== EX-L2 레시피 무결성 검증 ===")
    print(f"기존 recipes.json: {len(ex_recs)}종 / EX-L1 예약(대조용): {len(l1_pairs)}쌍")
    print(f"신규 채집 J8~J12 = {len(GATHERS)}종 / 신규 레시피 {len(R)}종")

    outs = [r["output"] for r in R]
    nums = [int(o[1:]) for o in outs]
    cont = nums == list(range(255, 255 + len(nums)))
    print(f"산출 연속성 D255~D{254 + len(nums)}: {'OK' if cont else 'FAIL: ' + str(nums)}")

    seen = {}
    internal_dup = []
    ext_conflict = []
    l1_conflict = []
    for r in R:
        k = pair_key(r["inputs"])
        if k in seen:
            internal_dup.append((r["id"], seen[k]))
        else:
            seen[k] = r["id"]
        if k in ex_pairs:
            ext_conflict.append((r["id"], ex_pairs[k]))
        if k in l1_pairs:
            l1_conflict.append((r["id"], l1_pairs[k]))
    print(f"내부 중복: {len(internal_dup)}  {internal_dup if internal_dup else ''}")
    print(f"기존 220종과 충돌: {len(ext_conflict)}  {ext_conflict if ext_conflict else ''}")
    print(f"EX-L1 예약분과 충돌: {len(l1_conflict)}  {l1_conflict if l1_conflict else ''}")

    new_outs = set(outs)
    ex_item_ids = {x["id"] for x in json.load(open(os.path.join(DATA, "items.json"), encoding="utf-8"))["items"]}
    dangling = []
    for r in R:
        for inp in r["inputs"]:
            if inp.startswith("D"):
                if inp not in new_outs and inp not in ex_item_ids:
                    dangling.append((r["id"], inp))
    print(f"dangling D-참조: {len(dangling)}  {dangling if dangling else ''}")

    # softlock: 게이트 재료 ⊆ 게이트 앞 누적 지대
    def gathers_of(item, idx, seen2=None):
        if seen2 is None:
            seen2 = set()
        if item[0] in "IJKPS" and item[1:].isdigit():
            return {item}
        if item in seen2:
            return set()
        seen2.add(item)
        out = set()
        for inputs in idx.get(item, []):
            for inp in inputs:
                out |= gathers_of(inp, idx, seen2)
        return out
    idx = {}
    for r in R:
        idx.setdefault(r["output"], []).append(r["inputs"])
    # 지대 누적 원소 집합 (맵 §A-2/A-6):
    #   어귀(GB1 前) → 회랑(GB2 前) → 정합실(GB3 前) → 사원(GB4)
    #   J8~J11 전부 어귀부터 채집 가능(진입 지대). J12(코어 정수)는 사원(GB4 자기 봉헌물)에서만.
    cum = {
        "GB1": {"J8", "J9", "J10", "J11"},
        "GB2": {"J8", "J9", "J10", "J11"},
        "GB3": {"J8", "J9", "J10", "J11"},
        "GB4": {"J8", "J9", "J10", "J11", "J12"},  # +사원(J12 = GB4 자신의 최종 봉헌물)
    }
    # 게이트 최종물은 rec() 반환 변수로 참조(번호 하드코딩 회피).
    gate_final = {"GB1": "D256", "GB2": "D258", "GB3": None, "GB4": d_restored_core}
    gate_multi = {"GB3": [d_shard_a, d_shard_b, d_shard_c]}
    print("--- softlock (게이트 재료 ⊆ 게이트 앞 누적 지대) ---")
    sl_ok = True
    for g in ["GB1", "GB2", "GB3", "GB4"]:
        finals = gate_multi.get(g) or ([gate_final[g]] if gate_final[g] else [])
        need = set()
        for f in finals:
            need |= gathers_of(f, idx)
        miss = need - cum[g]
        status = "OK" if not miss else f"MISSING {miss}"
        if miss:
            sl_ok = False
        print(f"  {g} {sorted(need)} ⊆ cum[{g}] : {status}")

    # unique-drain 금지 (EX-L1 QA 원칙, R33 I14 전례):
    #   유니크 채집물(J12)은 '게이트 체인 최종물'로 이어지는 레시피에서만 소비 가능.
    #   막다른 데코/상호 leaf에서 유니크를 소비하면 먼저 만든 플레이어가 GB4 영구 softlock.
    #   → 유니크를 입력으로 쓰는 모든 레시피는 반드시 게이트 최종물(복원 코어 D263)의 조상이어야 한다.
    unique_gathers = {g[0] for g in GATHERS if g[3] == "gather_unique"}  # {"J12"}
    def ancestors_of_final(final, idx):
        """final 산출로 이어지는 모든 중간 산출 D + 그 레시피 집합."""
        chain_recipes = set()
        stack = [final]
        seen3 = set()
        while stack:
            cur = stack.pop()
            if cur in seen3:
                continue
            seen3.add(cur)
            for r in R:
                if r["output"] == cur:
                    chain_recipes.add(r["id"])
                    stack.extend(r["inputs"])
        return chain_recipes
    gate_final_recipes = ancestors_of_final(d_restored_core, idx)  # GB4 봉헌 체인 전체
    unique_ok = True
    unique_violations = []
    for r in R:
        if unique_gathers & set(r["inputs"]):
            if r["id"] not in gate_final_recipes:
                unique_ok = False
                unique_violations.append((r["id"], r["name"], r["place"] or "leaf"))
    print("--- unique-drain 금지 (유니크 J12 = 게이트 체인 전용, 막다른 데코 사용 금지) ---")
    if unique_violations:
        for uid, un, up in unique_violations:
            print(f"  VIOLATION {uid} {un} ({up}) — 유니크를 막다른 레시피에서 소모")
    else:
        print(f"  유니크 {sorted(unique_gathers)} 소비 레시피 전부 게이트 체인(복원 코어 조상) : OK")

    passed = (cont and not internal_dup and not ext_conflict and not l1_conflict
              and not dangling and sl_ok and unique_ok)
    print(f"RESULT: {'PASS' if passed else 'FAIL'}")

    frag = {
        "gathers": [{"id": i, "name": n, "zone": z, "kind": k, "flavor": fl} for (i, n, z, k, fl) in GATHERS],
        "recipes": [{"id": r["id"], "name": r["name"], "inputs": r["inputs"],
                     "output": r["output"], "hint": r["hint"], "flavor": r["flavor"],
                     "place": r["place"]} for r in R],
    }
    with open(os.path.join(TOOLS, "l2x_data_fragment.json"), "w", encoding="utf-8") as f:
        json.dump(frag, f, ensure_ascii=False, indent=2)
    print(f"산출 아이템: J8~J12(채집5) + D255~D{254 + len(nums)}(조합{len(nums)}) = {5 + len(nums)}종")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
