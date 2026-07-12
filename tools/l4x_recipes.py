#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l4x_recipes.py — EX-L4 확장 레시피(구역 「부유 서고」) 생성·무결성 검증.

프리픽스: 신규 L4 채집 = P8~P12 (기존 items.json P1~P7 = L4 구역1 뒤 연속),
         신규 조합 산출 = D301~ (기존 items.json D≤221 + EX-L1 예약 D222~D254
                                + EX-L2 예약 D255~D277 + EX-L3 예약 D278~D300 뒤에 연속).
게이트 체인이 최우선 계약 — Part A §A-3/§A-6이 요구하는 최종물·다단 순서를 못 박는다.

검증:
  (1) 페어 중복 없음 (기존 recipes.json 대조 + EX-L1/L2/L3 예약 fragment 대조 + 신규 내부)
  (2) softlock 불가 (게이트 재료 ⊆ 게이트 앞 누적 지대)
  (3) 산출 D 연속·dangling 0
  (4) unique-drain 금지 (유니크 P12 = 게이트 체인 전용, 막다른 데코 사용 금지)

★기존 EX-L1 D222~254, EX-L2 D255~277, EX-L3 D278~300 예약 → EX-L4 산출은 D301~. 채집 P8~.
★게이트 체인은 EX-L1·EX-L2·EX-L3와 페어중복 0 실측(세 확장 예약 레시피도 대조 대상에 포함).
★마력 Whisper 소비(whisper_cost.mana:1) = L4 구역1 L4-R09 패턴 계승. GW4 봉인구 = 유일 마력 sink.

재현: python3 tools/l4x_recipes.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
TOOLS = os.path.join(ROOT, "tools")

# ---- 신규 채집 원소 (P8~P11 + P12 유니크 금서고 코어 금기 정수) ----
GATHERS = [
    ("P8", "금서 조각", "archive", "gather", "찢긴 금서의 한 장. 읽으면 안 될 글이, 아직 반쯤 남아 빛난다."),
    ("P9", "서고 룬판", "archive", "gather", "책장을 잠그던 룬판. 봉인이 풀리며, 잠금 룬이 텅 비었다."),
    ("P10", "열람 촛농", "archive", "gather", "밤새 금서를 읽던 촛불이 굳은 것. 누군가 여기서 오래 읽었다."),
    ("P11", "별지 잉크", "archive", "gather", "별을 갈아 만든 잉크. 봉인문을 쓰던 마지막 한 방울."),
    ("P12", "금기 정수", "archive", "gather_unique", "금서고 코어에서 꺼낸 원금기. 힘의 극한이 마지막으로 열람한 한 줄."),  # unique
]

R = []
DOUT = 301  # EX-L1 D222~254 + EX-L2 D255~277 + EX-L3 D278~300 예약 → EX-L4는 D301~


def rec(rid, name, inputs, hint, flavor, place="", whisper=None):
    global DOUT
    out = f"D{DOUT}"
    DOUT += 1
    R.append({"id": rid, "name": name, "inputs": inputs, "hint": hint,
              "flavor": flavor, "place": place, "output": out, "whisper": whisper})
    return out


# =========================================================
# 게이트 체인 — GW1~GW4 (EX-L4-R01 ~ R09)
#   GW1 부유 서가 다리: 부유 서가 다리석(D302) 배치 = 룬 잔교(구역1 룬 다리 계승)
#   GW2 흐려진 열람 결계: 열람 정화의 물(D304) 사용 = 결계 정화(구역1 정화의 물 계승)
#   GW3 금서 봉인 순서(3서판, 순서 있음! seal_ordered): 봉인 서판 α/β/γ 배치(순서 강제)
#   GW4 금서고 코어 재봉인: 금기 봉인구(체인) 봉헌 + 마력 Whisper 소비 = 구역 정화 + 컷신
#   ★P12(금기 정수, 유니크)는 GW4 최종 봉헌물에만 사용 = 마지막 게이트 자기 재료(order-safe)
# =========================================================
# GW1 — 부유 서가 다리석 (배치형): 금서 조각을 룬판에 각인해 허공에 잔교
d_bridge_rune = rec("EX-L4-R01", "서가 각인석", ["P8", "P9"],
                    "금서 조각을 서고 룬판에 눌러 각인하면", "빈 룬판에 금서의 한 줄이 앉는다. 허공을 딛을 첫 룬.", "")
rec("EX-L4-R02", "부유 서가 다리석", [d_bridge_rune, "P11"],  # D302
    "서가 각인석에 별지 잉크로 잔교 룬을 이으면", "끊긴 서가와 서가 사이. 금색 룬으로, 떠 있는 다리를 놓는다.",
    "placement · 부유 서가 다리 룬 제단 X 설치(GW1)")
# GW2 — 열람 정화의 물 (사용형): 흐려진 열람 결계에 부어 결계 복원
d_clear_wax = rec("EX-L4-R03", "정련 촛농", ["P10", "P8"],
                  "열람 촛농을 금서 조각의 재로 정련하면", "흐린 것을 걷어내는 맑은 밀랍. 결계에 스밀 만큼 곱게.", "")
rec("EX-L4-R04", "열람 정화의 물", [d_clear_wax, "P11"],  # D304
    "정련 촛농을 별지 잉크에 풀어 정화의 물로 만들면", "흐려진 열람 결계를 다시 맑히는 물. 부으면 결계가 다시 돈다.",
    "use · 흐려진 열람 결계에 사용(GW2)")
# GW3 — 봉인 서판 3종 (순서 있는 배치 미니퍼즐 seal_ordered): 1→2→3 순서로 봉인
d_seal_a = rec("EX-L4-R05", "봉인 서판 1장", ["P9", "P10"],
               "서고 룬판에 열람 촛농으로 첫 봉인문을 찍으면", "첫째 서판. 순서의 처음. 이것부터 봉해야 다음이 열린다.", "placement · 봉인 서판 슬롯(1)")
d_seal_b = rec("EX-L4-R06", "봉인 서판 2장", ["P8", "P11"],
               "금서 조각에 별지 잉크로 둘째 봉인문을 쓰면", "둘째 서판. 첫 서판이 봉해진 뒤라야 글이 앉는다.", "placement · 봉인 서판 슬롯(2)")
d_seal_c = rec("EX-L4-R07", "봉인 서판 3장", [d_clear_wax, "P9"],  # 정련 촛농(D303)+서고 룬판
               "정련 촛농으로 서고 룬판에 마지막 봉인문을 굳히면", "셋째 서판. 순서대로 셋을 다 봉하면, 금서고 통로가 열린다.", "placement · 봉인 서판 슬롯(3)")
# GW4 — 금기 봉인구 (체인형 + 마력 소비): 유니크 금기 정수(P12) → 재봉인 = 구역 정화
d_seal_seed = rec("EX-L4-R08", "봉인구 씨", ["P12", "P8"],
                  "금기 정수를 금서 조각으로 감싸 봉인의 씨를 뜨면", "마지막 열람의 한 줄을, 새 봉인에 감아 다시 조인다.", "")
d_final_seal = rec("EX-L4-R09", "금기 봉인구", [d_seal_seed, d_seal_seed],  # D307; 봉인구 씨² + 마력 Whisper
    "봉인구 씨 둘에 속삭임(마력)을 불어넣어 금기 봉인구를 완성하면",
    "찢겨 떠돌던 금서고를, 마지막으로 한 번 더 봉한다. 힘이 아니라, 침묵을.",
    "chain · 금기 봉인구 봉헌 목 봉헌(GW4=구역 정화/클리어) · whisper_cost.mana:1 · 컷신",
    whisper={"mana": 1})

# =========================================================
# 유효 상호 조합 — 부유 서고 (말 되는 것만) EX-L4-R10~R16
# =========================================================
rec("EX-L4-R10", "금서 무리", ["P8", "P8"], "금서 조각 둘을 겹쳐 묶으면", "읽지 못한 두 장이 나란히. 떠도는 채로 서로를 가린다.", "decor · glows")
rec("EX-L4-R11", "룬판 서가", ["P9", "P9"], "서고 룬판 둘을 세워 서가를 짜면", "빈 룬판이 룬판을 받친다. 잠글 책이 이제 없는 서가.", "structure")
rec("EX-L4-R12", "촛농 무더기", ["P10", "P10"], "열람 촛농 둘을 눌러 뭉치면", "다 녹은 촛불의 자리. 오래 읽던 밤들이 굳었다.", "structure")
rec("EX-L4-R13", "잉크 군집", ["P11", "P11"], "별지 잉크 둘을 섞어 응결시키면", "별을 두 번 간 잉크. 너무 짙어, 무슨 글자든 삼킨다.", "decor · glows")
rec("EX-L4-R14", "촛농 별등", ["P10", "P11"], "열람 촛농에 별지 잉크 심지를 꽂아 등을 켜면", "손안의 작은 서고. 별 잉크 심지가 금서를 비추듯 빛난다.", "decor · glows")
rec("EX-L4-R15", "방람 봉인판", [d_bridge_rune, "P10"],  # 서가 각인석(D301)+열람 촛농
    "서가 각인석에 열람 촛농을 발라 열람을 막으면", "누구도 못 읽게 덮은 판. 오래 지키려는 손길.", "structure")
rec("EX-L4-R16", "봉인 부적", [d_seal_a, "P11"],  # 봉인 서판 1장(D305)+별지 잉크
    "봉인 서판을 별지 잉크로 감싸 목에 걸면", "다 봉하지 못한 순서를, 부적처럼. 언젠가 마저 봉할 믿음으로.", "decor")

# =========================================================
# 교차 조합 — 마탑(L4 구역1) 산물 활용 EX-L4-R17~R20
#   ★게이트 체인엔 절대 안 씀(구역 단독 클리어 가능). 전부 수집/장식.
#   D140=룬 각인석, D148=최심부 봉인구, D162=룬 정수, D172=룬 간판(기존 L4 구역1 산물)
# =========================================================
rec("EX-L4-R17", "금서고 등명", [d_final_seal, "P8"],  # 금기 봉인구(D307)+금서 조각
    "금기 봉인구의 여분 침묵을 금서 조각에 옮겨 담으면", "떠도는 서고를 밝히는 등명. 다시 봉한 금기의 고요를, 곁에 둔다.",
    "structure · glows")
rec("EX-L4-R18", "룬 서가탑", ["D140", "P9"],  # 룬 각인석(기존 L4)+서고 룬판
    "룬 각인석에 서고 룬판을 층층이 물리면", "마탑의 각인석과, 서고의 룬판이 한 탑에 선다.",
    "structure · glows")
rec("EX-L4-R19", "봉인 서고함", ["D148", "P9"],  # 최심부 봉인구(기존 L4)+서고 룬판
    "최심부 봉인구에 서고 룬판을 이어 함에 넣으면", "마탑을 봉한 그릇에, 서고의 잠금을 한 칸 더.",
    "structure")
rec("EX-L4-R20", "금기 별등", ["D162", "P11"],  # 룬 정수(기존 L4)+별지 잉크
    "룬 정수에 별지 잉크를 얹어 서고를 비추면", "무엇을 읽었는지, 이 별 잉크 너머로 룬이 비친다.",
    "decor · glows")

# =========================================================
# 막다른 재미 leaf — 사서 잔영 / 금기 열람 톤 EX-L4-R21~R23
#   게이트/진행 무관, 조합 트리의 잎. 도감·톤 전달 전용. 유니크(P12) 미사용(EX-L1 QA 원칙).
# =========================================================
rec("EX-L4-R21", "지워진 열람 명부", [d_seal_b, "P10"],  # 봉인 서판 2장(D306)+열람 촛농
    "봉인 서판에 촛농을 흘려 이름을 읽으려 하면… 열람자 명부가 촛농에 번진다", "마지막 열람자 명부. 누가 금서를 폈는지, 촛농 아래로 지워졌다.", "decor")
rec("EX-L4-R22", "굳은 사서 잔영", [d_bridge_rune, "P9"],  # 서가 각인석(D301)+서고 룬판
    "서가 각인석에 서고 룬판을 앉히면… 책을 든 자세로 굳은 사서 잔영이 된다", "서고를 정리하던 사서의 말로. 책 한 권을 꽂으려던 자세로 굳었다.", "structure")
rec("EX-L4-R23", "타버린 금서", ["P9", "P11"],  # 서고 룬판+별지 잉크 = 타버린 기록
    "서고 룬판에 별지 잉크를 억지로 태워 새기면… 글자가 새까맣게 탄다", "누군가는 이 한 줄을 알고 싶어 했다. 이제는 탄 자국뿐.", "decor")


def build():
    return R, GATHERS


# ---- 무결성 검증 ----
def existing_pairs():
    # 멱등화(EX-L3 8a42e09 계승): l4x_apply_data.py가 EX-L4-R* 를 이미 recipes.json에 병합한
    # 뒤 재실행하면, 자기 자신과의 페어 충돌(self-conflict)로 오탐이 난다. EX-L4 자기 산출은
    # 대조 대상에서 제외해 재실행에도 PASS 유지(re-import quirk 방지).
    recs = [x for x in json.load(open(os.path.join(DATA, "recipes.json"), encoding="utf-8"))["recipes"]
            if not str(x.get("id", "")).startswith("EX-L4")]
    pairs = {}
    for x in recs:
        inp = x["inputs"]
        if len(inp) == 2 and inp[0] == inp[1]:
            k = ("SAME", inp[0])
        else:
            k = frozenset(inp)
        pairs.setdefault(k, x["id"])
    return pairs, recs


def frag_pairs(name):
    """확장 예약 레시피(EX-L1/L2/L3 fragment)도 페어중복 대조 대상(과제 계약: 페어중복 0)."""
    frag = os.path.join(TOOLS, name)
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
    l1_pairs = frag_pairs("l1x_data_fragment.json")
    l2_pairs = frag_pairs("l2x_data_fragment.json")
    l3_pairs = frag_pairs("l3x_data_fragment.json")
    print("=== EX-L4 레시피 무결성 검증 ===")
    print(f"기존 recipes.json: {len(ex_recs)}종 / EX-L1 예약: {len(l1_pairs)}쌍 / EX-L2 예약: {len(l2_pairs)}쌍 / EX-L3 예약: {len(l3_pairs)}쌍")
    print(f"신규 채집 P8~P12 = {len(GATHERS)}종 / 신규 레시피 {len(R)}종")

    outs = [r["output"] for r in R]
    nums = [int(o[1:]) for o in outs]
    cont = nums == list(range(301, 301 + len(nums)))
    print(f"산출 연속성 D301~D{300 + len(nums)}: {'OK' if cont else 'FAIL: ' + str(nums)}")

    # 페어검사 대상: whisper 융합(봉인구 씨²+마력)은 SAME-쌍이 아니라 재화 융합 → SAME 키로 검사(씨²)
    seen = {}
    internal_dup = []
    ext_conflict = []
    frag_conflict = {"L1": [], "L2": [], "L3": []}
    for r in R:
        k = pair_key(r["inputs"])
        if k in seen:
            internal_dup.append((r["id"], seen[k]))
        else:
            seen[k] = r["id"]
        if k in ex_pairs:
            ext_conflict.append((r["id"], ex_pairs[k]))
        if k in l1_pairs:
            frag_conflict["L1"].append((r["id"], l1_pairs[k]))
        if k in l2_pairs:
            frag_conflict["L2"].append((r["id"], l2_pairs[k]))
        if k in l3_pairs:
            frag_conflict["L3"].append((r["id"], l3_pairs[k]))
    print(f"내부 중복: {len(internal_dup)}  {internal_dup if internal_dup else ''}")
    print(f"기존 recipes.json과 충돌: {len(ext_conflict)}  {ext_conflict if ext_conflict else ''}")
    for lv in ("L1", "L2", "L3"):
        print(f"EX-{lv} 예약분과 충돌: {len(frag_conflict[lv])}  {frag_conflict[lv] if frag_conflict[lv] else ''}")

    new_outs = set(outs)
    ex_item_ids = {x["id"] for x in json.load(open(os.path.join(DATA, "items.json"), encoding="utf-8"))["items"]}
    dangling = []
    for r in R:
        for inp in r["inputs"]:
            if inp.startswith("D") and inp[1:].isdigit():
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
    #   착지 서가(GW1 前) → 하부 서가(GW2 前) → 봉인 순서 퍼즐실(GW3 前) → 최심부 코어(GW4)
    #   P8~P11 전부 착지 서가부터 채집 가능(진입 지대). P12(금기 정수)는 코어(GW4 자기 봉헌물)에서만.
    cum = {
        "GW1": {"P8", "P9", "P10", "P11"},
        "GW2": {"P8", "P9", "P10", "P11"},
        "GW3": {"P8", "P9", "P10", "P11"},
        "GW4": {"P8", "P9", "P10", "P11", "P12"},  # +코어(P12 = GW4 자신의 최종 봉헌물)
    }
    gate_final = {"GW1": "D302", "GW2": "D304", "GW3": None, "GW4": d_final_seal}
    gate_multi = {"GW3": [d_seal_a, d_seal_b, d_seal_c]}
    print("--- softlock (게이트 재료 ⊆ 게이트 앞 누적 지대) ---")
    sl_ok = True
    for g in ["GW1", "GW2", "GW3", "GW4"]:
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
    #   유니크 채집물(P12)은 '게이트 체인 최종물'로 이어지는 레시피에서만 소비 가능.
    # (QA ㉓ 촉매 정정) 이 검사는 '유니크가 게이트 체인에만 쓰이는가'(멤버십)만 본다 —
    #   '몇 번 소모되는가'는 세지 않는다. 엔진 fusion.gd unique-as-catalyst 규칙
    #   (game/scripts/core/fusion.gd:158~178, _consume_inputs)상 P12는 존재만 요구·소모 0인
    #   촉매이므로, R09=D308²·D308=R08(P12+P8)이라도 P12 1개로 R08을 2회 제작해 최종키에 도달한다
    #   (유니크×2 표면 모순은 런타임 softlock 아님). 따라서 아래 로직은 P12가 R08(체인 조상)에만
    #   등장함을 확인하면 PASS이며, '소모 2회'로 집계해 FAIL하지 않는다(설계 정본과 일치).
    unique_gathers = {gg[0] for gg in GATHERS if gg[3] == "gather_unique"}  # {"P12"}

    def ancestors_of_final(final):
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
    gate_final_recipes = ancestors_of_final(d_final_seal)  # GW4 봉헌 체인 전체
    unique_ok = True
    unique_violations = []
    for r in R:
        if unique_gathers & set(r["inputs"]):
            if r["id"] not in gate_final_recipes:
                unique_ok = False
                unique_violations.append((r["id"], r["name"], r["place"] or "leaf"))
    print("--- unique-drain 금지 (유니크 P12 = 게이트 체인 전용, 막다른 데코 사용 금지) ---")
    if unique_violations:
        for uid, un, up in unique_violations:
            print(f"  VIOLATION {uid} {un} ({up}) — 유니크를 막다른 레시피에서 소모")
    else:
        print(f"  유니크 {sorted(unique_gathers)} 소비 레시피 전부 게이트 체인(금기 봉인구 조상) : OK")

    # 마력 sink 확인: whisper_cost는 GW4 최종물에만
    mana_sinks = [r["id"] for r in R if r.get("whisper")]
    print(f"--- 마력 Whisper sink (GW4 봉인구 유일) ---")
    print(f"  whisper_cost 레시피: {mana_sinks}  ({'OK' if mana_sinks == ['EX-L4-R09'] else 'CHECK'})")

    passed = (cont and not internal_dup and not ext_conflict
              and not frag_conflict["L1"] and not frag_conflict["L2"] and not frag_conflict["L3"]
              and not dangling and sl_ok and unique_ok and mana_sinks == ["EX-L4-R09"])
    print(f"RESULT: {'PASS' if passed else 'FAIL'}")

    frag = {
        "gathers": [{"id": i, "name": n, "zone": z, "kind": k, "flavor": fl} for (i, n, z, k, fl) in GATHERS],
        "recipes": [{"id": r["id"], "name": r["name"], "inputs": r["inputs"],
                     "output": r["output"], "hint": r["hint"], "flavor": r["flavor"],
                     "place": r["place"], **({"whisper": r["whisper"]} if r["whisper"] else {})} for r in R],
    }
    with open(os.path.join(TOOLS, "l4x_data_fragment.json"), "w", encoding="utf-8") as f:
        json.dump(frag, f, ensure_ascii=False, indent=2)
    print(f"산출 아이템: P8~P12(채집5) + D301~D{300 + len(nums)}(조합{len(nums)}) = {5 + len(nums)}종")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
