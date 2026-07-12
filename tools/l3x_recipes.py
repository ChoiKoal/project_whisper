#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l3x_recipes.py — EX-L3 확장 레시피(구역 「태엽 광산」) 생성·무결성 검증.

프리픽스: 신규 L3 채집 = K8~K12 (기존 items.json K1~K7 뒤 연속),
         신규 조합 산출 = D278~ (기존 items.json D≤221 + 실 recipes.json D≤218 + EX-L1 예약 D222~D254 + EX-L2 예약 D255~D277 뒤에 연속).
게이트 체인이 최우선 계약 — Part A §A-3/§A-6이 요구하는 최종물·다단 순서를 못 박는다.

검증:
  (1) 페어 중복 없음 (기존 recipes.json 대조 + EX-L1(D222~) + EX-L2(D255~) 예약 대조 + 신규 내부)
  (2) softlock 불가 (게이트 재료 ⊆ 게이트 앞 누적 지대)
  (3) 산출 D 연속·dangling 0
  (4) unique-drain 금지 (유니크 K12 = 게이트 체인 전용, 막다른 데코 사용 금지)

★기존 EX-L1이 D222~D254, EX-L2가 D255~D277을 예약하므로 EX-L3 산출은 D278~. 채집은 K8~.
★게이트 체인은 EX-L1·EX-L2와 페어중복 0 실측(두 확장 예약 레시피도 대조 대상에 포함).

재현: python3 tools/l3x_recipes.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
TOOLS = os.path.join(ROOT, "tools")

# ---- 신규 채집 원소 (K8~K11 + K12 유니크 대굴착기 코어 태엽정) ----
GATHERS = [
    ("K8", "태엽 광석", "mine", "gather", "채굴하다 만 광맥. 태엽이 감기던 원석이, 반쯤 캐낸 채 굳었다."),
    ("K9", "녹슨 톱니축", "mine", "gather", "부러진 굴착 드릴의 축. 이가 다 닳도록 돌다, 마지막에 멈췄다."),
    ("K10", "갱도 석탄", "mine", "gather", "가장 깊은 갱에서 캔 검은 덩이. 태울 화로도, 실어 낼 광차도 이제 없다."),
    ("K11", "응결 수정", "mine", "gather", "갱도 벽에 맺힌 수정. 지열이 식으며 물방울이 그대로 굳었다."),
    ("K12", "심층 태엽정", "mine", "gather_unique", "대굴착기 코어에서 꺼낸 원태엽. 도시를 감던 모든 태엽의 첫 마디."),  # unique
]

R = []
DOUT = 278  # EX-L1 D222~D254 + EX-L2 D255~D277 예약 → EX-L3는 D278~


def rec(rid, name, inputs, hint, flavor, place="", whisper=None):
    global DOUT
    out = f"D{DOUT}"
    DOUT += 1
    R.append({"id": rid, "name": name, "inputs": inputs, "hint": hint,
              "flavor": flavor, "place": place, "output": out, "whisper": whisper})
    return out


# =========================================================
# 게이트 체인 — GM1~GM4 (EX-L3-R01 ~ R09)
#   GM1 붕락 낙석 협곡: 궤도판(D280) 배치 = 태엽 광석 정련판 + 녹슨 톱니축(구조재)
#   GM2 막힌 통풍문: 감압 밸브 젤(D282) 사용 = 응결 수정으로 압력 복원
#   GM3 광차문(3레버 전환): 전환 레버 3종 배치(순서 무관)
#   GM4 대굴착기 재점화: 태엽 노심(체인) 봉헌 = 구역 정화 + 컷신
#   ★K12(심층 태엽정, 유니크)는 GM4 최종 봉헌물에만 사용 = 마지막 게이트 자기 재료(order-safe)
# =========================================================
# GM1 — 궤도판 (배치형): 태엽 광석을 정련한 방진 궤도판
d_ore_plate = rec("EX-L3-R01", "정련 광석판", ["K8", "K9"],
                  "태엽 광석을 녹슨 톱니축 위에 펴서 벼리면", "무른 광석이 판이 된다. 낙석 위에 걸쳐도 버티게.", "")
rec("EX-L3-R02", "붕락 궤도판", [d_ore_plate, "K10"],  # D279
    "정련 광석판을 갱도 석탄으로 그을려 굳히면", "무너진 협곡 위에 놓을, 광차가 지나갈 궤도판.",
    "placement · 붕락 낙석 협곡 K 배치(GM1)")
# GM2 — 감압 밸브 젤 (사용형): 막힌 통풍문에 주입해 압력 복원
d_seal_gel = rec("EX-L3-R03", "응결 밀봉재", ["K11", "K8"],
                 "응결 수정을 태엽 광석 가루에 개면", "틈을 메우는 반투명 반죽. 새는 압력을 붙든다.", "")
rec("EX-L3-R04", "감압 밸브 젤", [d_seal_gel, "K10"],  # D281
    "응결 밀봉재를 갱도 석탄 열로 데워 밸브에 채우면", "통풍문의 잠긴 밸브를 밀어 여는 열쇠 젤. 주입하면 문이 스스로 물러난다.",
    "use · 막힌 통풍문에 사용(GM2)")
# GM3 — 전환 레버 3종 (배치 미니퍼즐): 분기실 슬롯 3개에 각각
d_lever_a = rec("EX-L3-R05", "전환 레버 α", ["K8", "K10"],
                "태엽 광석에 갱도 석탄 심을 박아 무게추를 달면", "레일을 옮길 첫 레버. 홀로는 아무 갈래도 못 연다.", "placement · 레일 전환 레버 슬롯(α)")
d_lever_b = rec("EX-L3-R06", "전환 레버 β", ["K9", "K11"],
                "녹슨 톱니축에 응결 수정을 물려 축을 세우면", "둘째 레버. 첫 레버와 갈래가 맞물린다.", "placement · 레일 전환 레버 슬롯(β)")
d_lever_c = rec("EX-L3-R07", "전환 레버 γ", [d_seal_gel, "K9"],  # 응결 밀봉재(D281)+녹슨 톱니축
                "응결 밀봉재로 녹슨 톱니축을 굳혀 마지막 레버를 세우면", "셋째 레버. 이제 셋을 다 넘기면, 광차문이 갈래를 튼다.", "placement · 레일 전환 레버 슬롯(γ)")
# GM4 — 태엽 노심 (체인형): 유니크 심층 태엽정(K12) → 재점화 = 구역 정화
d_core_seed = rec("EX-L3-R08", "감긴 태엽 씨", ["K12", "K8"],
                  "심층 태엽정을 태엽 광석에 감아 다시 조이면", "첫 마디 태엽이, 새 원석에 힘을 옮겨 감긴다.", "")
d_wound_core = rec("EX-L3-R09", "태엽 노심", [d_core_seed, "K10"],  # D286
    "감긴 태엽 씨를 갱도 석탄으로 데워 노심에 물리면", "멈춘 대굴착기가 다시 감길 준비를 마친다. 도시를 감던 첫 태엽을, 여기 되돌린다.",
    "chain · 태엽 노심 봉헌 목 봉헌(GM4=구역 정화/클리어) · 컷신")

# =========================================================
# 유효 상호 조합 — 태엽 광산 (말 되는 것만) EX-L3-R10~R16
# =========================================================
rec("EX-L3-R10", "광석 무리", ["K8", "K8"], "태엽 광석 둘을 겹쳐 쌓으면", "반쯤 감긴 원석 둘. 캐다 만 채로 나란히.", "decor · glows")
rec("EX-L3-R11", "축 무더기", ["K9", "K9"], "녹슨 톱니축 둘을 눌러 뭉치면", "부러진 축이 축을 부른다. 무거운 고철 더미.", "structure")
rec("EX-L3-R12", "석탄 더미", ["K10", "K10"], "갱도 석탄 둘을 틀에 눌러 굳히면", "실어 낼 곳 없는 검은 벽돌. 태울 화로가 먼저 식었다.", "structure")
rec("EX-L3-R13", "수정 군집", ["K11", "K11"], "응결 수정 둘을 붙여 키우면", "차게 맺힌 수정이 서로 얼어붙는다. 갱도의 마지막 물기.", "decor · glows")
rec("EX-L3-R14", "석탄 수정 등불", ["K10", "K11"], "갱도 석탄에 응결 수정을 박아 손등불로 굳히면", "손안의 작은 갱. 들면 검은 결 사이로 수정이 희미하게 빛난다.", "decor · glows")
rec("EX-L3-R15", "방진 밀봉판", [d_ore_plate, "K11"],  # 정련 광석판(D278)+응결 수정
    "정련 광석판에 응결 수정을 촘촘히 박으면", "먼지도 물기도 새지 않는 판. 오래 지키려는 손길.", "structure")
rec("EX-L3-R16", "톱니 부적", [d_lever_a, "K11"],  # 전환 레버 α(D282)+응결 수정
    "전환 레버를 응결 수정으로 감싸 목에 걸면", "다 옮기지 못한 갈래를, 부적처럼. 언젠가 트일 길을 믿으며.", "decor")

# =========================================================
# 교차 조합 — 시계탑 도시(L3 구역1) 산물 활용 EX-L3-R17~R20
#   ★게이트 체인엔 절대 안 씀(구역 단독 클리어 가능). 전부 수집/장식.
#   D103=황동 톱니 원판, D110=태엽 문자판, D112=강철 톱니바퀴, D122=구동 모듈(기존 L3 구역1 산물)
# =========================================================
rec("EX-L3-R17", "노심 등명", [d_wound_core, "K8"],  # 태엽 노심(D286)+태엽 광석
    "태엽 노심의 여분 힘을 태엽 광석에 옮겨 담으면", "갱도를 밝히는 등명. 되감은 첫 태엽의 온기를, 곁에 둔다.",
    "structure · glows")
rec("EX-L3-R18", "광산 톱니탑", ["D112", "K8"],  # 강철 톱니바퀴(기존 L3)+태엽 광석
    "강철 톱니바퀴에 태엽 광석을 층층이 물리면", "지상 도시의 톱니와, 지하의 원석이 한 탑에 선다.",
    "structure · glows")
rec("EX-L3-R19", "채굴 구동함", ["D122", "K9"],  # 구동 모듈(기존 L3)+녹슨 톱니축
    "구동 모듈에 녹슨 톱니축을 이어 함에 넣으면", "멈춘 굴착 팔에 예비 힘을 한 칸. 다시 캘 날을 위한.",
    "structure")
rec("EX-L3-R20", "광부 시계등", ["D110", "K11"],  # 태엽 문자판(기존 L3)+응결 수정
    "태엽 문자판에 응결 수정을 얹어 갱을 비추면", "몇 시에 무너졌는지, 이 수정 너머로 바늘이 비친다.",
    "decor · glows")

# =========================================================
# 막다른 재미 leaf — 굴착 로봇 / 광부 로그 톤 EX-L3-R21~R23
#   게이트/진행 무관, 조합 트리의 잎. 도감·톤 전달 전용. 유니크(K12) 미사용(EX-L1 QA 원칙).
# =========================================================
rec("EX-L3-R21", "지워진 광부 명패", [d_lever_b, "K10"],  # 전환 레버 β(D283)+갱도 석탄
    "전환 레버에 석탄재를 문질러 이름을 읽으려 하면… 글자가 검게 뭉개진다", "마지막 교대 명패. 누구였는지, 그을음 속으로 번져버렸다.", "decor")
rec("EX-L3-R22", "굳은 굴착 로봇", [d_ore_plate, "K9"],  # 정련 광석판(D278)+녹슨 톱니축
    "정련 광석판에 녹슨 톱니축을 앉히면… 팔이 굳어 멈춘 굴착 로봇이 된다", "갱도를 파던 로봇의 말로. 드릴을 든 자세로 굳었다.", "structure")
rec("EX-L3-R23", "타버린 표창 태엽", ["K10", "K9"],  # 갱도 석탄+녹슨 톱니축 = 타버린 기록
    "갱도 석탄을 녹슨 톱니축에 억지로 감으면… 과부하로 새까맣게 탄다", "누군가는 이 채굴량을 자랑스러워했다. 이제는 탄 자국뿐.", "decor")


def build():
    return R, GATHERS


# ---- 무결성 검증 ----
def existing_pairs():
    # post-merge 정합: EX-L3 산출(EX-L3-R*)이 이미 recipes.json에 반영된 경우
    # 자기 자신과의 self-conflict를 제외한다(l1x/l2x_recipes.py 전례, l1x 5cd9332).
    recs = [x for x in json.load(open(os.path.join(DATA, "recipes.json"), encoding="utf-8"))["recipes"]
            if not str(x.get("id", "")).startswith("EX-L3-")]
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
    """확장 예약 레시피(EX-L1/EX-L2 fragment)도 페어중복 대조 대상(과제 계약: 페어중복 0)."""
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
    print("=== EX-L3 레시피 무결성 검증 ===")
    print(f"기존 recipes.json: {len(ex_recs)}종 / EX-L1 예약: {len(l1_pairs)}쌍 / EX-L2 예약: {len(l2_pairs)}쌍")
    print(f"신규 채집 K8~K12 = {len(GATHERS)}종 / 신규 레시피 {len(R)}종")

    outs = [r["output"] for r in R]
    nums = [int(o[1:]) for o in outs]
    cont = nums == list(range(278, 278 + len(nums)))
    print(f"산출 연속성 D278~D{277 + len(nums)}: {'OK' if cont else 'FAIL: ' + str(nums)}")

    seen = {}
    internal_dup = []
    ext_conflict = []
    l1_conflict = []
    l2_conflict = []
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
        if k in l2_pairs:
            l2_conflict.append((r["id"], l2_pairs[k]))
    print(f"내부 중복: {len(internal_dup)}  {internal_dup if internal_dup else ''}")
    print(f"기존 recipes.json과 충돌: {len(ext_conflict)}  {ext_conflict if ext_conflict else ''}")
    print(f"EX-L1 예약분과 충돌: {len(l1_conflict)}  {l1_conflict if l1_conflict else ''}")
    print(f"EX-L2 예약분과 충돌: {len(l2_conflict)}  {l2_conflict if l2_conflict else ''}")

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
    #   갱구(GM1 前) → 회랑(GM2 前) → 분기실(GM3 前) → 갱도(GM4)
    #   K8~K11 전부 갱구부터 채집 가능(진입 지대). K12(심층 태엽정)는 갱도(GM4 자기 봉헌물)에서만.
    cum = {
        "GM1": {"K8", "K9", "K10", "K11"},
        "GM2": {"K8", "K9", "K10", "K11"},
        "GM3": {"K8", "K9", "K10", "K11"},
        "GM4": {"K8", "K9", "K10", "K11", "K12"},  # +갱도(K12 = GM4 자신의 최종 봉헌물)
    }
    # 게이트 최종물은 rec() 반환 변수로 참조(번호 하드코딩 회피).
    gate_final = {"GM1": "D279", "GM2": "D281", "GM3": None, "GM4": d_wound_core}
    gate_multi = {"GM3": [d_lever_a, d_lever_b, d_lever_c]}
    print("--- softlock (게이트 재료 ⊆ 게이트 앞 누적 지대) ---")
    sl_ok = True
    for g in ["GM1", "GM2", "GM3", "GM4"]:
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
    #   유니크 채집물(K12)은 '게이트 체인 최종물'로 이어지는 레시피에서만 소비 가능.
    unique_gathers = {gg[0] for gg in GATHERS if gg[3] == "gather_unique"}  # {"K12"}
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
    gate_final_recipes = ancestors_of_final(d_wound_core)  # GM4 봉헌 체인 전체
    unique_ok = True
    unique_violations = []
    for r in R:
        if unique_gathers & set(r["inputs"]):
            if r["id"] not in gate_final_recipes:
                unique_ok = False
                unique_violations.append((r["id"], r["name"], r["place"] or "leaf"))
    print("--- unique-drain 금지 (유니크 K12 = 게이트 체인 전용, 막다른 데코 사용 금지) ---")
    if unique_violations:
        for uid, un, up in unique_violations:
            print(f"  VIOLATION {uid} {un} ({up}) — 유니크를 막다른 레시피에서 소모")
    else:
        print(f"  유니크 {sorted(unique_gathers)} 소비 레시피 전부 게이트 체인(태엽 노심 조상) : OK")

    passed = (cont and not internal_dup and not ext_conflict and not l1_conflict
              and not l2_conflict and not dangling and sl_ok and unique_ok)
    print(f"RESULT: {'PASS' if passed else 'FAIL'}")

    frag = {
        "gathers": [{"id": i, "name": n, "zone": z, "kind": k, "flavor": fl} for (i, n, z, k, fl) in GATHERS],
        "recipes": [{"id": r["id"], "name": r["name"], "inputs": r["inputs"],
                     "output": r["output"], "hint": r["hint"], "flavor": r["flavor"],
                     "place": r["place"]} for r in R],
    }
    with open(os.path.join(TOOLS, "l3x_data_fragment.json"), "w", encoding="utf-8") as f:
        json.dump(frag, f, ensure_ascii=False, indent=2)
    print(f"산출 아이템: K8~K12(채집5) + D278~D{277 + len(nums)}(조합{len(nums)}) = {5 + len(nums)}종")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
