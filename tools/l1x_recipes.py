#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l1x_recipes.py — EX-L1 확장 레시피(구역2 고요의 화원 + 구역3 생명의 심장) 생성·무결성 검증.

프리픽스: 신규 L1 채집 = I10~I17, 신규 조합 산출 = D222~ (기존 items.json D≤221 뒤에 연속).
게이트 체인이 최우선 계약 — Part A §A-4/§A-6이 요구하는 최종물·다단 순서를 못 박는다.

검증:
  (1) 페어 중복 없음 (기존 220 recipes.json 대조 + 신규 내부)
  (2) softlock 불가 (게이트 재료 ⊆ 게이트 앞 누적 지대)
  (3) 산출 D 연속·dangling 0

재현: python3 tools/l1x_recipes.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")

# ---- 신규 채집 원소 (구역2: I10~I13, 구역3: I14 유니크 정수 + I15~I17) ----
GATHERS = [
    ("I10", "희귀 꽃", "garden", "고요의 화원 곳곳. 색을 잃고도, 형태만은 꽃이다."),
    ("I11", "꽃 이슬", "garden", "꽃잎 끝에 맺힌 한 방울. 아침이 오지 않아도, 늘 거기 있다."),
    ("I12", "색 모래", "garden", "한때 벽화였을 가루. 손에 묻으면, 지워진 색이 살짝 남는다."),
    ("I13", "꽃가루", "garden", "노랗게 날리던 것. 이제 바람이 없어, 발밑에 고여 있다."),
    ("I14", "생명의 정수", "heart", "세계수 심장에서 꺼낸 온기. I9보다 깊고, 더 무겁다."),  # unique
    ("I15", "뿌리 수액", "heart", "세계수 뿌리를 타고 흐르던 것. 아직, 아주 느리게 돈다."),
    ("I16", "세계수 씨눈", "heart", "심장 곁에 맺힌 눈. 심으면 자랄까, 아무도 심어보지 않았다."),
    ("I17", "심장 이끼", "heart", "가장 깊은 곳에서 자란 초록. 어둠에 익숙한 생명."),
]

# ---- 레시피 (id, 이름, 재료리스트, 힌트, 플레이버, placement/key, 산출) ----
# placement/key 문자열은 문서용. whisper_cost 는 dict(있으면).
R = []
DOUT = 222  # 다음 산출 D 번호


def rec(rid, name, inputs, hint, flavor, place="", whisper=None):
    global DOUT
    out = f"D{DOUT}"
    DOUT += 1
    R.append({"id": rid, "name": name, "inputs": inputs, "hint": hint,
              "flavor": flavor, "place": place, "output": out, "whisper": whisper})
    return out


# =========================================================
# 구역 2 「고요의 화원」 게이트 체인 (EX-L1-G01 ~ )
#   GA1 색의 여울: 꽃돌다리(D223) 배치 = 색 모래+돌(I8 기존)  →  ★I8은 시작의 숲에서 확보 가능(진입 전제)
#   GA2 시든 아치: 꽃즙 물감(D224) 사용
#   GA3 색의 문(3색 퍼즐): 빨/노/파 물감 3종 배치
#   GA4 색의 봉헌: 무지개 정수(체인) 봉헌 = 화원 클리어
# =========================================================
# GA1 — 꽃돌다리 (배치형): 색 모래 굳혀 만든 징검다리
d_dye_base = rec("EX-L1-R01", "색 모래 반죽", ["I12", "I11"],
                 "색 모래에 꽃 이슬을 개면", "손끝에 색이 밴다. 아직 굳지 않은.", "")
rec("EX-L1-R02", "꽃돌다리", [d_dye_base, "I8"],  # D223
    "색 반죽을 돌에 발라 굳히면", "여울 위에 놓을, 색이 밴 돌. 물살에도 지워지지 않게.",
    "placement · 색의 여울 K 배치(GA1)")
# GA2 — 꽃즙 물감 (사용형): 시든 아치에 뿌려 개화
d_nectar = rec("EX-L1-R03", "꽃즙", ["I10", "I11"],
               "희귀 꽃을 이슬에 짓이겨 즙을 내면", "진한 즙 한 방울. 마른 것을, 다시 적실 수 있을까.", "")
rec("EX-L1-R04", "개화의 물감", [d_nectar, "I13"],  # D225
    "꽃즙에 꽃가루를 풀면", "뿌리면 색이 번지는 물감. 시든 것에 색을 돌려준다.",
    "use · 시든 아치에 사용(GA2)")
# GA3 — 3색 물감 (배치 미니퍼즐): 빨/노/파 화단에 각각
d_red = rec("EX-L1-R05", "붉은 물감", ["I10", "I12"],
            "붉은 꽃을 색 모래에 개면", "선명한 빨강. 잊고 있던 색.", "placement · 색맞춤 화단(빨)")
d_yellow = rec("EX-L1-R06", "노란 물감", ["I13", "I11"],
               "꽃가루를 이슬에 풀면", "따뜻한 노랑. 볕이 없어도, 볕의 색.", "placement · 색맞춤 화단(노)")
d_blue = rec("EX-L1-R07", "푸른 물감", [d_dye_base, "I13"],  # 색 모래 반죽(D222)+꽃가루
             "색 모래 반죽에 꽃가루를 가라앉혀 맑은 색을 얻으면", "서늘한 파랑. 물이 기억하던 색.", "placement · 색맞춤 화단(파)")
# GA4 — 무지개 정수 (체인형): 3색 물감 합성 → 봉헌
d_rainbow = rec("EX-L1-R08", "무지개 물감", [d_red, d_yellow],
                "붉은 물감과 노란 물감을 겹쳐 섞으면", "두 색이 만나 새 색이 된다. 색은, 섞일수록 늘어난다.", "")
d_color_essence = rec("EX-L1-R09", "색의 정수", [d_rainbow, d_blue],  # D230
    "무지개 물감에 푸른 물감을 마지막으로 더하면", "모든 색이 한 점에 모였다. 화원에 색을 돌려줄, 마지막 한 방울.",
    "chain · 무지개 분수 봉헌(GA4=화원 클리어)")

# =========================================================
# 구역 3 「생명의 심장」 게이트 체인
#   GH1 뒤엉킨 뿌리문: 소생의 수액(D231계열) 사용
#   GH2 심장 봉인 목: 심장 소생 체인 → 봉인 해제 = 심장 정화(클리어)
#     ★생명 Whisper(vita)는 E 생명의 샘물에서 재획득(idempotent). 최종 봉헌엔 소비 안 함(재획득처=엔딩 대비 순수 보상)
# =========================================================
# GH1 — 소생의 수액 (사용형): 마른 뿌리문에 부어 소생
d_sap = rec("EX-L1-R10", "맑은 수액", ["I15", "I17"],
            "뿌리 수액을 심장 이끼로 거르면", "탁하던 것이 맑아진다. 뿌리에게 돌려줄 물.", "")
rec("EX-L1-R11", "소생의 수액", [d_sap, "I16"],  # D233
    "맑은 수액에 세계수 씨눈을 담그면", "한 방울에 싹의 기억이 깃든다. 죽은 뿌리도, 다시 감길지 몰라.",
    "use · 뒤엉킨 뿌리문에 사용(GH1)")
# GH2 — 심장 소생 (체인형): 생명의 정수(I14 유니크) → 심장 정화
d_heartseed = rec("EX-L1-R12", "생명의 씨눈", ["I14", "I16"],
                  "생명의 정수를 세계수 씨눈에 불어넣으면", "심장에서 꺼낸 온기가, 작은 눈 속으로 옮겨간다.", "")
d_heartsap = rec("EX-L1-R13", "심장의 고동물", [d_heartseed, "I15"],  # D235
                 "생명의 씨눈을 뿌리 수액에 녹이면", "느리게, 다시 뛰기 시작하는 무언가.", "")
rec("EX-L1-R14", "되살아난 심장", [d_heartsap, "I17"],  # D236
    "심장의 고동물을 심장 이끼로 감싸면", "세계수의 심장이 다시 뛴다. 이 세계에, 아직 남은 온기.",
    "chain · 심장 봉인 목 봉헌(GH2=심장 정화/클리어) · 컷신")

# =========================================================
# 유효 상호 조합 — 구역2 (말 되는 것만) EX-L1-R15~R20
# =========================================================
rec("EX-L1-R15", "꽃 목걸이", ["I10", "I10"], "희귀 꽃 둘을 엮으면", "색을 잃은 꽃도, 둘이면 조금 화사하다.", "decor")
rec("EX-L1-R16", "이슬 유리", ["I11", "I11"], "이슬 둘을 한데 얼리면", "맺힌 물방울이 작은 렌즈가 된다.", "decor · glows")
rec("EX-L1-R17", "모래 그림판", ["I12", "I12"], "색 모래 둘을 켜켜이 쌓으면", "지워진 벽화를, 서툴게 다시 그려본다.", "decor")
rec("EX-L1-R18", "꽃가루 향낭", ["I13", "I10"], "꽃가루를 희귀 꽃에 싸면", "흔들면 옅은 향. 향기마저, 색처럼 바랬다.", "decor")
rec("EX-L1-R19", "색 이슬차", [d_nectar, "I11"],  # 꽃즙(D224)+이슬
    "꽃즙을 이슬에 풀어 우리면", "마시면 혀끝에 색이 도는 듯도 하고.", "")
rec("EX-L1-R20", "물든 모래병", [d_red, "I11"],  # 붉은 물감(D226)+이슬
    "붉은 물감을 이슬에 재워 모래에 물들이면", "병 속에 갇힌 봄. 열지 않아야, 색이 산다.", "decor")

# =========================================================
# 유효 상호 조합 — 구역3 EX-L1-R21~R26
# =========================================================
rec("EX-L1-R21", "쌍뿌리 매듭", ["I15", "I15"], "뿌리 수액 둘을 꼬아 매면", "두 갈래가 한 매듭으로. 뿌리는, 서로를 붙든다.", "structure")
rec("EX-L1-R22", "겹씨눈", ["I16", "I16"], "세계수 씨눈 둘을 맞붙이면", "쌍둥이 눈. 하나가 시들면, 하나가 대신 튼다.", "")
rec("EX-L1-R23", "이끼 방석", ["I17", "I17"], "심장 이끼 둘을 눌러 다지면", "폭신한 초록. 깊은 곳에서도, 앉을 자리 하나.", "decor")
rec("EX-L1-R24", "수액 등불", ["I15", "I16"], "뿌리 수액에 씨눈을 띄워 밝히면", "느리게 도는 수액이 은은히 빛난다.", "decor · glows")
rec("EX-L1-R25", "심장 이끼차", [d_sap, "I17"],  # 맑은 수액(D231)+이끼
    "맑은 수액에 심장 이끼를 우리면", "깊은 초록빛 물. 마시면, 아주 오래된 숨 냄새.", "")
rec("EX-L1-R26", "생명의 눈꽃", ["I16", "I17"], "씨눈을 이끼로 덮어 틔우면", "돌 틈에 핀 작은 눈. 어둠에도 굴하지 않는.", "decor · glows")

# =========================================================
# 교차 조합 — 시작의 숲(L1 기존) 산물 활용 EX-L1-R27~R30
#   ★게이트 체인엔 절대 안 씀(구역 단독 클리어 가능). 전부 수집/장식.
#   D19=생명수, D22=어린 세계수, D21=정령꽃(기존 L1 산물)
# =========================================================
rec("EX-L1-R27", "색을 되찾은 꽃밭", [d_color_essence, "I10"],  # 색의 정수(D230)+희귀 꽃
    "색의 정수를 희귀 꽃에 부으면", "바랜 꽃에 색이 돌아온다. 화원이, 처음으로 웃는 것 같다.",
    "structure · glows")
rec("EX-L1-R28", "세계수 묘목 화분", ["D22", "I17"],
    "어린 세계수를 심장 이끼에 옮겨 심으면", "숲의 나무가, 심장의 흙에 뿌리내린다. 두 곳이 이어진다.",
    "structure")
rec("EX-L1-R29", "생명수 성수반", ["D19", "I15"],
    "생명수를 뿌리 수액과 한 그릇에 담으면", "숲의 물과 뿌리의 물. 같은 세계수에서 났으니, 섞여도 좋다.",
    "structure · glows")
rec("EX-L1-R30", "정령꽃 등롱", ["D21", "I11"],
    "정령꽃을 꽃 이슬로 감싸면", "이슬 속에 갇힌 빛. 흔들면, 정령이 깨어날 것도 같다.",
    "decor · glows")

# =========================================================
# 막다른 재미 leaf — 정원사 석상 / 첫 실험 흔적 톤 EX-L1-R31~R34
# =========================================================
rec("EX-L1-R31", "색을 잃은 화관", [d_dye_base, "I10"],  # 색 모래 반죽(D222)+희귀 꽃
    "색 모래 반죽에 희귀 꽃이 굳어 붙으면", "정원사가 쓰던 화관. 색은, 손이 멈춘 그날 함께 굳었다.", "decor")
rec("EX-L1-R32", "지워진 팔레트", ["I12", "I13"],
    "색 모래와 꽃가루를 섞으면… 그냥 회색이 된다", "모든 색을 섞으면 남는 것. 정원사가 마지막에 본 색.", "decor")
rec("EX-L1-R33", "첫 실험의 잔재", [d_sap, "I15"],  # 맑은 수액(D231)+뿌리 수액 = 억지로 뭉친 실패작
    # QA 수정(멤쵸 EX-L1 §B-2): 원안 I14→I15로 교체. 유니크(I14)를 막다른 데코가 소모하면 GH2 영구 softlock.
    # 유니크 채집물은 막다른 데코 레시피 사용 금지 — 게이트 체인(R12) 촉매(미소모)로만.
    # 2차 정합: {I15,I17}은 R10(맑은 수액)과 페어 중복 → 게이트 체인 R10 불변, 데코 R33만 이동.
    #   {D231,I15}로 재배치(맑은 수액에 수액을 더 억지로 밀어넣어 굳힘) = I15 소모·I14 미사용·중복 0 유지.
    "맑은 수액에 수액을 더 밀어넣으면… 억지로 굳어버린다", "선배가 남긴 실패작. 생명을 서두르면, 이렇게 굳는다.", "decor")


def build():
    return R, GATHERS


# ---- 무결성 검증 ----
def existing_pairs():
    # Compare the newly-generated EX-L1 set against the PRE-EXISTING baseline only.
    # Once the 33 EX-L1 recipes are merged into recipes.json (post-implementation), a naive
    # scan would report each new recipe as "conflicting" with its own merged copy. Excluding
    # ids that begin with "EX-L1-" keeps this an idempotent regression check both before and
    # after the data is committed.
    recs = [x for x in json.load(open(os.path.join(DATA, "recipes.json"), encoding="utf-8"))["recipes"]
            if not str(x.get("id", "")).startswith("EX-L1-")]
    pairs = {}
    for x in recs:
        inp = x["inputs"]
        if len(inp) == 2 and inp[0] == inp[1]:
            k = ("SAME", inp[0])
        else:
            k = frozenset(inp)
        pairs.setdefault(k, x["id"])
    return pairs, recs


def pair_key(inp):
    if len(inp) == 2 and inp[0] == inp[1]:
        return ("SAME", inp[0])
    return frozenset(inp)


def main():
    ex_pairs, ex_recs = existing_pairs()
    print("=== EX-L1 레시피 무결성 검증 ===")
    print(f"기존 recipes.json (EX-L1 제외 baseline): {len(ex_recs)}종")
    print(f"신규 채집: I10~I17 = {len(GATHERS)}종")
    print(f"신규 레시피: {len(R)}종")

    # 산출 연속성
    outs = [r["output"] for r in R]
    nums = [int(o[1:]) for o in outs]
    cont = nums == list(range(222, 222 + len(nums)))
    print(f"산출 연속성 D222~D{221 + len(nums)}: {'OK' if cont else 'FAIL: ' + str(nums)}")

    # 페어검사: whisper-only 없음(EX-L1은 3속성 소비 게이트 없음 → 전 레시피 페어검사 대상)
    seen = {}
    internal_dup = []
    ext_conflict = []
    for r in R:
        k = pair_key(r["inputs"])
        if k in seen:
            internal_dup.append((r["id"], seen[k]))
        else:
            seen[k] = r["id"]
        if k in ex_pairs:
            ext_conflict.append((r["id"], ex_pairs[k]))
    print(f"내부 중복: {len(internal_dup)}  {internal_dup if internal_dup else ''}")
    print(f"기존 220종과 충돌: {len(ext_conflict)}  {ext_conflict if ext_conflict else ''}")

    # dangling: 모든 D-입력이 신규 산출 또는 기존 ≤D221 이어야
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
    #   지대 원소 분포(맵 §A-4/A-6): garden 안뜰(진입 전 확보)·화단·안뜰(퍼즐)·신전
    #   heart 뿌리어귀(진입)·회랑·최심부
    #   ★I8(돌)은 시작의 숲에서 확보(구역2 진입 전제) → GA1 재료로 order-safe.
    #   ★I14(생명의 정수)는 GH2 앞 최심부에서만? → 아니오: I14는 세계수 심장 O(GH2 셀 gate)에서
    #     채집하지만 GH2 최종 봉헌 재료이므로 '그 게이트 자신의 최종물'. GH1은 I14 불사용(order-safe).
    def gathers_of(item, idx, seen2=None):
        if seen2 is None:
            seen2 = set()
        if item[0] in "IJKPS" and item[1:].isdigit():
            return {item}
        if item in seen2:
            return set()
        seen2.add(item)
        out = set()
        for inputs in idx.get(item, []):      # inputs = list of input items
            for inp in inputs:
                out |= gathers_of(inp, idx, seen2)
        return out
    idx = {}
    for r in R:
        idx.setdefault(r["output"], []).append(r["inputs"])
    # 지대 누적 원소 집합
    cum = {
        # 구역2: I8(시작의 숲, 진입 전 확보)를 진입 전제로 포함
        "GA1": {"I8", "I10", "I11", "I12", "I13"},         # 안뜰(진입 지대) + 시작의 숲 I8
        "GA2": {"I8", "I10", "I11", "I12", "I13"},         # +화단(GA1 뒤 누적)
        "GA3": {"I8", "I10", "I11", "I12", "I13"},         # +안뜰/퍼즐(GA2 뒤 누적)
        "GA4": {"I8", "I10", "I11", "I12", "I13"},         # +신전(GA3 뒤 누적)
        # 구역3: I14는 세계수 심장(GH2 최종 봉헌 대상)이므로 GH2 최종물엔 허용(자기 게이트)
        "GH1": {"I15", "I16", "I17"},                       # 뿌리 어귀+회랑(진입 지대)
        "GH2": {"I14", "I15", "I16", "I17"},               # +최심부(I14 = GH2 자신의 최종 봉헌물)
    }
    gate_final = {
        "GA1": "D223", "GA2": "D225", "GA3": None, "GA4": "D230",
        "GH1": "D232", "GH2": "D235",
    }
    # GA3 = 3색 물감 배치(D226 붉은/D227 노란/D228 푸른)
    gate_multi = {"GA3": ["D226", "D227", "D228"]}
    print("--- softlock (게이트 재료 ⊆ 게이트 앞 누적 지대) ---")
    sl_ok = True
    for g in ["GA1", "GA2", "GA3", "GA4", "GH1", "GH2"]:
        finals = gate_multi.get(g) or ([gate_final[g]] if gate_final[g] else [])
        need = set()
        for f in finals:
            need |= gathers_of(f, idx)
        miss = need - cum[g]
        status = "OK" if not miss else f"MISSING {miss}"
        if miss:
            sl_ok = False
        print(f"  {g} {sorted(need)} ⊆ cum[{g}] : {status}")

    passed = cont and not internal_dup and not ext_conflict and not dangling and sl_ok
    print(f"RESULT: {'PASS' if passed else 'FAIL'}")

    # emit JSON fragments for the doc / data agent
    outdir = os.path.join(ROOT, "tools")
    frag = {
        "gathers": [{"id": i, "name": n, "zone": z, "flavor": fl} for (i, n, z, fl) in GATHERS],
        "recipes": [{"id": r["id"], "name": r["name"], "inputs": r["inputs"],
                     "output": r["output"], "hint": r["hint"], "flavor": r["flavor"],
                     "place": r["place"]} for r in R],
    }
    with open(os.path.join(outdir, "l1x_data_fragment.json"), "w", encoding="utf-8") as f:
        json.dump(frag, f, ensure_ascii=False, indent=2)
    print(f"산출 아이템: I10~I17(채집8) + D222~D{221 + len(nums)}(조합{len(nums)}) = {8 + len(nums)}종")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
