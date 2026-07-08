#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l5x_recipes.py — EX-L5 확장 레시피(구역 「침묵의 종탑」) 생성·무결성 검증.

프리픽스: 신규 L5 채집 = S8~S12 (기존 items.json S1~S7 = L5 구역1 뒤 연속),
         신규 조합 산출 = D324~ (기존 items.json D≤221 + EX-L1 예약 D222~D254
                                + EX-L2 예약 D255~D277 + EX-L3 예약 D278~D300
                                + EX-L4 예약 D301~D323 뒤에 연속).
게이트 체인이 최우선 계약 — Part A §A-3/§A-6이 요구하는 최종물·다단 순서를 못 박는다.

검증:
  (1) 페어 중복 없음 (기존 recipes.json 대조 + EX-L1/L2/L3/L4 예약 fragment 대조 + 신규 내부)
  (2) softlock 불가 (게이트 재료 ⊆ 게이트 앞 누적 지대)
  (3) 산출 D 연속·dangling 0
  (4) unique-drain 금지 (유니크 S12 = 게이트 체인 전용, 막다른 데코 사용 금지)

★기존 EX-L1 D222~254, EX-L2 D255~277, EX-L3 D278~300, EX-L4 D301~323 예약 → EX-L5 산출은 D324~. 채집 S8~.
★게이트 체인은 EX-L1·L2·L3·L4와 페어중복 0 실측(네 확장 예약 레시피도 대조 대상에 포함 = 102쌍).
★GB4 응답의 타종구 = 3속성 Whisper(energy+mana+vita 각1) 소비 = L5 구역1 D186「응답」 컬미네이션 계승.
  마지막 확장답게 '가장 큰 응답' = 3속성 전부 반납의 대칭(재획득처 F=생명 idempotent add_vita).

재현: python3 tools/l5x_recipes.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
TOOLS = os.path.join(ROOT, "tools")

# ---- 신규 채집 원소 (S8~S11 + S12 유니크 큰 종 신의 마지막 음) ----
GATHERS = [
    ("S8", "종 파편", "belfry", "gather", "울리다 만 종의 깨진 조각. 두드리면, 아주 짧게 떨림이 남는다."),
    ("S9", "종탑 밧줄", "belfry", "gather", "큰 종을 당기던 밧줄. 오래 당겨지지 않아, 매듭이 굳었다."),
    ("S10", "울림 청동", "belfry", "gather", "종을 부어 만든 청동의 남은 조각. 안에 아직 울림이 잠들어 있다."),
    ("S11", "잔향 가루", "belfry", "gather", "마지막 타종의 잔향이 내려앉아 굳은 가루. 스치면 옛 소리가 인다."),
    ("S12", "신의 마지막 음", "belfry", "gather_unique", "큰 종에서 꺼낸 단 하나의 음. 신이 세계에게 마지막으로 낸 소리."),  # unique
]

R = []
DOUT = 324  # EX-L1 D222~254 + EX-L2 D255~277 + EX-L3 D278~300 + EX-L4 D301~323 예약 → EX-L5는 D324~


def rec(rid, name, inputs, hint, flavor, place="", whisper=None):
    global DOUT
    out = f"D{DOUT}"
    DOUT += 1
    R.append({"id": rid, "name": name, "inputs": inputs, "hint": hint,
              "flavor": flavor, "place": place, "output": out, "whisper": whisper})
    return out


# =========================================================
# 게이트 체인 — GB1~GB4 (EX-L5-R01 ~ R09)
#   GB1 무너진 종탑 계단: 종석 잔교(D325) 배치 = 종석 다리(구역1/L4 배치 계승)
#   GB2 흐려진 종음 결계: 정음의 물(D327) 사용 = 결계 정화(구역1 정화의 물 계승)
#   GB3 타종 울림 순서(3종, 순서 있음! chime_ordered): 울림 종 α/β/γ 배치(울림 순서 강제)
#      ★L5 본편 성가(기억 재현)와 차별 — 타종은 '울림 조합'(공명 순서) 술어.
#   GB4 큰 종 재타종: 응답의 타종구(체인) 봉헌 + 3속성 Whisper 소비 = 구역 정화 = 응답 + 컷신
#   ★S12(신의 마지막 음, 유니크)는 GB4 최종 재타종물에만 사용 = 마지막 게이트 자기 재료(order-safe)
# =========================================================
# GB1 — 종석 잔교(배치형): 종 파편을 밧줄로 엮어 허공에 종석 다리
d_bell_anchor = rec("EX-L5-R01", "종석 이음쇠", ["S8", "S9"],
                    "종 파편을 종탑 밧줄로 엮어 이으면", "깨진 종 조각에 밧줄이 감긴다. 허공을 딛을 첫 이음.", "")
rec("EX-L5-R02", "종석 잔교", [d_bell_anchor, "S10"],  # D325
    "종석 이음쇠에 울림 청동을 부어 잔교를 굳히면", "무너진 계단과 계단 사이. 청동 종석으로, 딛을 다리를 놓는다.",
    "placement · 무너진 종탑 계단 종석 제단 X 설치(GB1)")
# GB2 — 정음의 물(사용형): 흐려진 종음 결계에 부어 결계 복원
d_clear_dust = rec("EX-L5-R03", "정음 가루", ["S11", "S8"],
                   "잔향 가루를 종 파편의 떨림으로 골라내면", "흐린 소리를 걷어내는 맑은 가루. 결계에 스밀 만큼 곱게.", "")
rec("EX-L5-R04", "정음의 물", [d_clear_dust, "S10"],  # D327
    "정음 가루를 울림 청동에 풀어 정음의 물로 만들면", "흐려진 종음 결계를 다시 맑히는 물. 부으면 결계가 다시 운다.",
    "use · 흐려진 종음 결계에 사용(GB2)")
# GB3 — 울림 종 3종(순서 있는 배치 미니퍼즐 chime_ordered): 저→중→고 울림 순서로 타종
d_chime_a = rec("EX-L5-R05", "울림 종 하나", ["S10", "S11"],
                "울림 청동에 잔향 가루를 입혀 첫 울림을 벼리면", "첫째 종. 울림의 처음. 이것부터 울려야 다음이 공명한다.", "placement · 타종 종 슬롯(1)")
d_chime_b = rec("EX-L5-R06", "울림 종 둘", ["S8", "S10"],
                "종 파편을 울림 청동에 붙여 둘째 울림을 벼리면", "둘째 종. 첫 종이 울린 뒤라야 소리가 앉는다.", "placement · 타종 종 슬롯(2)")
d_chime_c = rec("EX-L5-R07", "울림 종 셋", [d_clear_dust, "S9"],  # 정음 가루(D326)+종탑 밧줄
                "정음 가루를 종탑 밧줄에 먹여 마지막 울림을 굳히면", "셋째 종. 순서대로 셋을 울리면, 종탑 상층문이 열린다.", "placement · 타종 종 슬롯(3)")
# GB4 — 응답의 타종구(체인형 + 3속성 소비): 유니크 신의 마지막 음(S12) → 재타종 = 구역 정화 = 응답
d_toll_seed = rec("EX-L5-R08", "타종구 씨", ["S12", "S8"],
                  "신의 마지막 음을 종 파편으로 감싸 타종구의 씨를 뜨면", "마지막으로 낸 그 소리를, 새 타종에 감아 다시 울릴 씨.", "")
d_final_toll = rec("EX-L5-R09", "응답의 타종구", [d_toll_seed, d_toll_seed],  # D332; 타종구 씨² + 3속성 Whisper
    "타종구 씨 둘에 세 속삭임(에너지·마력·생명)을 모두 불어넣어 응답의 타종구를 완성하면",
    "세계에게 보내는 가장 큰 대답. 세 속삭임을 모아, 큰 종을 다시 울린다.",
    "chain · 응답의 타종구 봉헌 목 봉헌(GB4=구역 정화/클리어) · whisper_cost {energy,mana,vita} 각1 · 컷신",
    whisper={"energy": 1, "mana": 1, "vita": 1})

# =========================================================
# 유효 상호 조합 — 침묵의 종탑 (말 되는 것만) EX-L5-R10~R16
# =========================================================
rec("EX-L5-R10", "종 파편 무리", ["S8", "S8"], "종 파편 둘을 겹쳐 묶으면", "울리다 만 두 조각이 나란히. 서로의 떨림을 겨우 이어 받는다.", "decor · glows")
rec("EX-L5-R11", "밧줄 종렬", ["S9", "S9"], "종탑 밧줄 둘을 꼬아 종렬을 짜면", "매듭이 매듭을 받친다. 당길 종이 이제 걸리지 않은 밧줄.", "structure")
rec("EX-L5-R12", "청동 무더기", ["S10", "S10"], "울림 청동 둘을 부어 뭉치면", "다 식은 종물의 자리. 부어지다 만 울림들이 굳었다.", "structure")
rec("EX-L5-R13", "잔향 군집", ["S11", "S11"], "잔향 가루 둘을 모아 응결시키면", "잔향을 두 번 모은 가루. 너무 짙어, 어떤 소리든 삼킨다.", "decor · glows")
rec("EX-L5-R14", "잔향 등명", ["S9", "S10"], "종탑 밧줄 심지를 울림 청동에 담아 등을 켜면", "손안의 작은 종탑. 청동 등에 밧줄 심지가 옛 울림으로 은은히 빛난다.", "decor · glows")
rec("EX-L5-R15", "봉음 종판", [d_bell_anchor, "S11"],  # 종석 이음쇠(D324)+잔향 가루
    "종석 이음쇠에 잔향 가루를 발라 울림을 재우면", "누구도 못 울리게 덮은 판. 오래 지키려는 손길.", "structure")
rec("EX-L5-R16", "타종 부적", [d_chime_a, "S9"],  # 울림 종 하나(D328)+종탑 밧줄
    "울림 종을 밧줄로 감아 목에 걸면", "다 울리지 못한 순서를, 부적처럼. 언젠가 마저 울릴 믿음으로.", "decor")

# =========================================================
# 교차 조합 — 대성당(L5 구역1) 산물 활용 EX-L5-R17~R20
#   ★게이트 체인엔 절대 안 씀(구역 단독 클리어 가능). 전부 수집/장식.
#   D177=성소의 등불, D186="응답", D184=재의 기도(기존 L5 구역1 산물)
# =========================================================
rec("EX-L5-R17", "종탑 등명", [d_final_toll, "S8"],  # 응답의 타종구(D332)+종 파편
    "응답의 타종구의 여분 울림을 종 파편에 옮겨 담으면", "다시 울린 종탑을 밝히는 등명. 응답의 여운을, 곁에 둔다.",
    "structure · glows")
rec("EX-L5-R18", "등불 종탑", ["D177", "S9"],  # 성소의 등불(기존 L5)+종탑 밧줄
    "성소의 등불을 종탑 밧줄에 매달아 층층이 올리면", "대성당의 등불과, 종탑의 밧줄이 한 탑에 걸린다.",
    "structure · glows")
rec("EX-L5-R19", "응답의 종함", ["D186", "S10"],  # "응답"(기존 L5)+울림 청동
    "「응답」을 울림 청동에 이어 종함에 넣으면", "대제단에 바친 응답을, 종의 그릇에 한 번 더.",
    "structure")
rec("EX-L5-R20", "재의 종렬", ["D184", "S11"],  # 재의 기도(기존 L5)+잔향 가루
    "재의 기도에 잔향 가루를 얹어 종탑을 울리면", "무엇을 빌었는지, 이 잔향 너머로 종이 운다.",
    "decor · glows")

# =========================================================
# 막다른 재미 leaf — 종지기 잔영 / 침묵 톤 EX-L5-R21~R23
#   게이트/진행 무관, 조합 트리의 잎. 도감·톤 전달 전용. 유니크(S12) 미사용(EX-L1 QA 원칙).
# =========================================================
rec("EX-L5-R21", "지워진 타종 명부", [d_chime_b, "S11"],  # 울림 종 둘(D329)+잔향 가루
    "울림 종에 잔향 가루를 흘려 이름을 들으려 하면… 타종자 명부가 잔향에 번진다", "마지막 타종자 명부. 누가 종을 울렸는지, 잔향 아래로 지워졌다.", "decor")
rec("EX-L5-R22", "굳은 종지기 잔영", [d_bell_anchor, "S9"],  # 종석 이음쇠(D324)+종탑 밧줄
    "종석 이음쇠에 종탑 밧줄을 걸면… 종을 당기려던 자세로 굳은 종지기 잔영이 된다", "종탑을 지키던 종지기의 말로. 밧줄을 당기려던 자세로 굳었다.", "structure")
rec("EX-L5-R23", "식은 종", ["S9", "S11"],  # 종탑 밧줄+잔향 가루 = 다시 울리지 못한 종
    "종탑 밧줄에 잔향 가루를 억지로 문질러 새기면… 울림이 새까맣게 식는다", "누군가는 이 종을 다시 울리고 싶어 했다. 이제는 식은 잔향뿐.", "decor")


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


def frag_pairs(name):
    """확장 예약 레시피(EX-L1/L2/L3/L4 fragment)도 페어중복 대조 대상(과제 계약: 페어중복 0)."""
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
    l4_pairs = frag_pairs("l4x_data_fragment.json")
    print("=== EX-L5 레시피 무결성 검증 ===")
    print(f"기존 recipes.json: {len(ex_recs)}종 / EX-L1 예약: {len(l1_pairs)}쌍 / EX-L2 예약: {len(l2_pairs)}쌍 / EX-L3 예약: {len(l3_pairs)}쌍 / EX-L4 예약: {len(l4_pairs)}쌍")
    print(f"신규 채집 S8~S12 = {len(GATHERS)}종 / 신규 레시피 {len(R)}종")

    outs = [r["output"] for r in R]
    nums = [int(o[1:]) for o in outs]
    cont = nums == list(range(324, 324 + len(nums)))
    print(f"산출 연속성 D324~D{323 + len(nums)}: {'OK' if cont else 'FAIL: ' + str(nums)}")

    seen = {}
    internal_dup = []
    ext_conflict = []
    frag_conflict = {"L1": [], "L2": [], "L3": [], "L4": []}
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
        if k in l4_pairs:
            frag_conflict["L4"].append((r["id"], l4_pairs[k]))
    print(f"내부 중복: {len(internal_dup)}  {internal_dup if internal_dup else ''}")
    print(f"기존 recipes.json과 충돌: {len(ext_conflict)}  {ext_conflict if ext_conflict else ''}")
    for lv in ("L1", "L2", "L3", "L4"):
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
        # 채집 프리픽스: I(L1) J(L2) K(L3) P(L4) S(L5) — 숫자 이어짐
        if item and item[0] in "IJKPS" and item[1:].isdigit():
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
    #   착지 계단참(GB1 前) → 종실 회랑(GB2 前) → 타종 울림 퍼즐실(GB3 前) → 종탑 정점(GB4)
    #   S8~S11 전부 착지 계단참부터 채집 가능(진입 지대). S12(신의 마지막 음)는 정점(GB4 자기 재타종물)에서만.
    cum = {
        "GB1": {"S8", "S9", "S10", "S11"},
        "GB2": {"S8", "S9", "S10", "S11"},
        "GB3": {"S8", "S9", "S10", "S11"},
        "GB4": {"S8", "S9", "S10", "S11", "S12"},  # +정점(S12 = GB4 자신의 최종 재타종물)
    }
    gate_final = {"GB1": "D325", "GB2": "D327", "GB3": None, "GB4": d_final_toll}
    gate_multi = {"GB3": [d_chime_a, d_chime_b, d_chime_c]}
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
    unique_gathers = {gg[0] for gg in GATHERS if gg[3] == "gather_unique"}  # {"S12"}

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
    gate_final_recipes = ancestors_of_final(d_final_toll)  # GB4 봉헌 체인 전체
    unique_ok = True
    unique_violations = []
    for r in R:
        if unique_gathers & set(r["inputs"]):
            if r["id"] not in gate_final_recipes:
                unique_ok = False
                unique_violations.append((r["id"], r["name"], r["place"] or "leaf"))
    print("--- unique-drain 금지 (유니크 S12 = 게이트 체인 전용, 막다른 데코 사용 금지) ---")
    if unique_violations:
        for uid, un, up in unique_violations:
            print(f"  VIOLATION {uid} {un} ({up}) — 유니크를 막다른 레시피에서 소모")
    else:
        print(f"  유니크 {sorted(unique_gathers)} 소비 레시피 전부 게이트 체인(응답의 타종구 조상) : OK")

    # 3속성 Whisper sink 확인: whisper_cost는 GB4 최종물에만, 3키(energy/mana/vita) 전부
    mana_sinks = [r["id"] for r in R if r.get("whisper")]
    keys_ok = all(set(r["whisper"].keys()) == {"energy", "mana", "vita"} for r in R if r.get("whisper"))
    print(f"--- 3속성 Whisper sink (GB4 응답의 타종구 유일, energy+mana+vita) ---")
    print(f"  whisper_cost 레시피: {mana_sinks}  (유일={'OK' if mana_sinks == ['EX-L5-R09'] else 'CHECK'} / 3키={'OK' if keys_ok else 'CHECK'})")

    passed = (cont and not internal_dup and not ext_conflict
              and not frag_conflict["L1"] and not frag_conflict["L2"]
              and not frag_conflict["L3"] and not frag_conflict["L4"]
              and not dangling and sl_ok and unique_ok
              and mana_sinks == ["EX-L5-R09"] and keys_ok)
    print(f"RESULT: {'PASS' if passed else 'FAIL'}")

    frag = {
        "gathers": [{"id": i, "name": n, "zone": z, "kind": k, "flavor": fl} for (i, n, z, k, fl) in GATHERS],
        "recipes": [{"id": r["id"], "name": r["name"], "inputs": r["inputs"],
                     "output": r["output"], "hint": r["hint"], "flavor": r["flavor"],
                     "place": r["place"], **({"whisper": r["whisper"]} if r["whisper"] else {})} for r in R],
    }
    with open(os.path.join(TOOLS, "l5x_data_fragment.json"), "w", encoding="utf-8") as f:
        json.dump(frag, f, ensure_ascii=False, indent=2)
    print(f"산출 아이템: S8~S12(채집5) + D324~D{323 + len(nums)}(조합{len(nums)}) = {5 + len(nums)}종")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
