#!/usr/bin/env python3
# L4-4 — Inject Layer-4 items (P1~P7 gather + D140~D176 craft) and recipes (L4-R01~L4-R37) into
# data/items.json + data/recipes.json, exactly per design doc §B-1/§B-2. Idempotent: strips any
# existing P*/D140+/L4-R* entries first, then re-appends, so re-running is safe. Verifies pair
# uniqueness (no dup input-pair vs the existing 141 recipes and among the new set) and dangling
# D-refs before writing. Mirrors tools_gen_l3_data.py exactly with L4 ids/palette.
# ⚠️ CRITICAL (QA §B-2): L4-R09 = inputs [D146,D146] + whisper_cost {mana:1} — the ONLY mana sink.
#    whisper_cost MUST NOT be dropped (L2-R08 파워코어 / L3-R09 태엽심장 패턴).
# Run: python3 tools_gen_l4_data.py
import json, os, sys

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ---- P1~P7 gather elements (§B-1) ----
P = [
    ("P1", "룬석", "글자를 새기면 힘이 깃든다고 했다. 아무것도 안 새겨진 지금이, 차라리 안심이다."),
    ("P2", "마력 결정", "쥐면 손끝이 저릿하다. 이 작은 조각 하나가, 탑 하나를 무너뜨렸을지도."),
    ("P3", "은가루", "룬을 또렷하게 만드는 가루. 잘못 새긴 글자도, 또렷하게 만든다."),
    ("P4", "양피지", "무엇이든 적을 수 있는 빈 종이. 봉인문이든, 마지막 유언이든."),
    ("P5", "봉인 밀랍", "눌러 찍으면 약속이 된다. 식으면, 무를 수 없는 약속."),
    ("P6", "별빛 이슬", "무너지는 세계에도 밤은 온다. 이슬은, 그 밤이 남긴 것."),
    ("P7", "공허 파편", "봉인 너머에서 새어 나온 조각. 만지면 차갑고, 아무 무게도 없다."),
]

# L4 amethyst placement tiles (+ prior layers so cross-craft decor can sit on any floor, same as L3
# BRASS_TILES pattern which listed L3+L2 tiles). L4 tile ids per l4_map_legend.json.
L4_TILES = ["L4T-A", "L4T-p", "L4T-R", "L4T-M", "L4T-O",
            "L3T-B", "L3T-p", "L3T-G", "L3T-M", "L3T-O",
            "L2T-M", "L2T-C", "L2T-c", "L2T-G", "T1", "T2A", "T2B", "T2C", "T2D", "T0"]


def struct(blocks=True, glows=False):
    return {"placement": {"class": "structure", "on": L4_TILES, "blocks": blocks, "glows": glows}}
def decor(glows=False):
    return {"placement": {"class": "decor", "on": L4_TILES, "blocks": False, "glows": glows}}
def key(usable=None):
    d = {"key_item": True}
    if usable is not None:
        d["usable_on"] = usable
    return d


# ---- D140~D176 craft outputs (§B-2). (id, name, flavor, extra) ----
D = [
    # (a) gate chain L4-R01~R09 → D140~D148
    ("D140", "룬 각인석", "비어 있던 돌에, 처음으로 한 글자가 앉는다.", {}),
    ("D141", "룬 다리석", "끊긴 곳과 끊긴 곳 사이. 빛으로, 한 발판을 놓는다.", key(["rune_altar"])),
    ("D142", "결계 부적", "새어 나온 것이, 이 종이 한 장을 넘지 못한다.", {}),
    ("D143", "정화의 물", "흐려진 샘에, 맑음을 한 방울.", key(["mana_spring"])),
    ("D144", "봉인 인장", "닫는다는 약속. 밀랍이 식으면, 무를 수 없다.", {}),
    ("D145", "보호 부적", "균열 너머로 한 걸음. 이 부적이 붙든 숨만큼만.", key()),
    ("D146", "봉인구 뼈대", "봉인이 될 그릇. 아직은 밀랍만 굳어 있다.", {}),
    ("D147", "룬 문장", "풀려난 것의 이름. 다시 부르면, 다시 갇힌다.", {}),
    ("D148", "최심부 봉인구", "풀려난 세계를, 마지막으로 한 번 더 봉한다. 온기가 아니라, 침묵을.", key(["seal_mount"])),
    # (b) basic 7 inter-combos L4-R10~R19 → D149~D158
    ("D149", "룬 원판", "같은 돌 둘. 마주 보면, 울림이 깊어진다.", {}),
    ("D150", "응축 마력핵", "두 빛이 하나로. 너무 밝아, 손이 떨린다.", {}),
    ("D151", "겹 양피지", "한 장으론 찢겼을 말을, 두 장이 견딘다.", {}),
    ("D152", "은박 룬", "빛을 되비추는 글자. 어둠 속에서도, 읽힌다.", {}),
    ("D153", "마력 잉크", "쓰는 대로 빛나는 잉크. 지워도, 자국이 남는다.", {}),
    ("D154", "밀랍 초", "작은 불 하나. 무너지는 세계에도, 밤은 온다.", {}),
    ("D155", "공허 가루", "손에 쥐면 차갑다. 아무것도 아닌 것의, 무게.", {}),
    ("D156", "별 양피지", "읽을 수 없는 지도. 그래도, 어딘가를 가리킨다.", {}),
    ("D157", "봉인 붓", "한 획으로 닫는 붓. 쓰는 손이, 자꾸 멈칫한다.", {}),
    ("D158", "공허 결정", "깨진 자리에 맺힌 이슬. 텅 빈 것도, 빛을 담는다.", {}),
    # (c) P secondary combos L4-R20~R23 → D159~D162
    ("D159", "룬 회로", "글자와 글자가, 서로에게 빛을 건넨다.", {}),
    ("D160", "결계 등불", "금 그은 자리마다, 작은 등이 켜진다.", {}),
    ("D161", "봉인 두루마리", "펼치면 열리고, 말면 닫힌다. 조심스럽게.", {}),
    ("D162", "룬 정수", "새긴 글자에 힘이 깃든다. 읽으면, 손끝이 저리다.", {}),
    # (d) cross-layer combos L4-R24~R26 → D163~D165
    ("D163", "이끼 낀 룬석", "금기의 글자도, 오래 두면 숲이 덮는다.", decor(False)),
    ("D164", "네온 룬등", "옛 빛과 새 빛이, 한 등 안에서 다툰다.", decor(True)),
    ("D165", "태엽 룬시계", "시간과 봉인이, 같은 축으로 돈다.", {}),
    # (e) placement/decor L4-R27~R33 → D166~D172
    ("D166", "룬 오벨리스크", "무너지는 거리에, 한 글자를 세워 둔다.", struct(True, False)),
    ("D167", "마력 가로등", "보랏빛이 발밑을 겨우 비춘다. 금색 룬이 맴돈다.", decor(True)),
    ("D168", "정화의 분수", "맑은 물이 돈다. 봉인이 풀린 자리에도, 한 뼘의 고요.", struct(True, True)),
    ("D169", "결계 문", "여닫을 때마다, 균열 하나가 아문다.", struct(True, False)),
    ("D170", "봉인된 마도서", "읽지 마라 적힌 책. 그래서 더, 펴 보고 싶은.", struct(True, False)),
    ("D171", "마력 화로", "온기가 아니라 빛을 내는 불. 손을 쬐어도, 차갑다.", struct(True, True)),
    ("D172", "룬 간판", "무슨 탑이었을까. 이제는 룬 하나만 빛난다.", decor(True)),
    # (f) dead-end leaf L4-R34~R37 → D173~D176
    ("D173", "식은 마력핵", "다 타 버린 힘. 쥐면, 재처럼 부스러진다.", decor(False)),
    ("D174", "금 간 봉인석", "닫으려 한 자국 위로, 다시 금이 간다.", decor(False)),
    ("D175", "꺼진 룬등", "불이 죽은 등. 룬만, 아직 형태를 기억한다.", decor(False)),
    ("D176", "잔영의 유리", "유리 속에 누군가 서 있다. 돌아보면, 아무도 없다.", decor(False)),
]

# ---- L4-R01~R37 recipes (§B-2). (id, [in1,in2], output, hint, extra) ----
R = [
    # (a) gate chain
    ("L4-R01", ["P1", "P3"], "D140", "룬석에 은가루로 룬을 새기면", {}),
    ("L4-R02", ["D140", "P6"], "D141", "각인석에 별빛 이슬을 먹이면 빛난다", {}),
    ("L4-R03", ["P4", "P1"], "D142", "양피지에 룬석 가루로 결계를 그리면", {}),
    ("L4-R04", ["P2", "P6"], "D143", "마력 결정을 별빛 이슬에 녹이면", {}),
    ("L4-R05", ["P5", "P4"], "D144", "봉인 밀랍을 양피지에 눌러 찍으면", {}),
    ("L4-R06", ["D142", "P6"], "D145", "결계 부적에 별빛 이슬을 적시면 몸을 감싼다", {}),
    ("L4-R07", ["P1", "P5"], "D146", "룬석을 밀랍으로 이어 틀을 뜨면", {}),
    ("L4-R08", ["P7", "P2"], "D147", "공허 파편에 마력 결정을 박으면", {}),
    ("L4-R09", ["D146", "D146"], "D148", "봉인구 뼈대에 속삭임(마력)을 불어넣으면",
     {"whisper_cost": {"mana": 1},
      "_note": "최심부 봉인구 = 봉인구 뼈대(D146) 둘 + 마력 Whisper 1 소모(§보완, 유일한 마력 sink). "
               "2입력 시스템 유지(L2-R08/L3-R09 동형). D146 ← (P1,P5) 상부 회랑·부유 파편 정원. "
               "⚠️ whisper_cost.mana:1 절대 누락 금지 (QA §B-2)."}),
    # (b) basic 7 inter-combos
    ("L4-R10", ["P1", "P1"], "D149", "룬석 둘을 겹쳐 갈면", {}),
    ("L4-R11", ["P2", "P2"], "D150", "마력 결정 둘을 맞대어 응결시키면", {}),
    ("L4-R12", ["P4", "P4"], "D151", "양피지 둘을 붙여 두껍게 하면", {}),
    ("L4-R13", ["P3", "P6"], "D152", "은가루를 별빛 이슬에 개어 입히면", {}),
    ("L4-R14", ["P3", "P2"], "D153", "은가루를 마력 결정에 개면", {}),
    ("L4-R15", ["P5", "P6"], "D154", "봉인 밀랍에 별빛 이슬 심지를 꽂으면", {}),
    ("L4-R16", ["P7", "P3"], "D155", "공허 파편을 은가루와 함께 빻으면", {}),
    ("L4-R17", ["P4", "P6"], "D156", "양피지에 별빛 이슬로 별자리를 그리면", {}),
    ("L4-R18", ["P5", "P3"], "D157", "밀랍을 은가루로 굳혀 붓을 만들면", {}),
    ("L4-R19", ["P7", "P6"], "D158", "공허 파편에 별빛 이슬을 얼려 맺으면", {}),
    # (c) P secondary combos
    ("L4-R20", ["D152", "D153"], "D159", "은박 룬에 마력 잉크로 길을 이으면", {}),
    ("L4-R21", ["D142", "D154"], "D160", "결계 부적을 밀랍초로 밝히면", {}),
    ("L4-R22", ["D144", "D151"], "D161", "봉인 인장을 겹 양피지에 말면", {}),
    ("L4-R23", ["D140", "P2"], "D162", "룬 각인석에 마력 결정을 물리면", {}),
    # (d) cross-layer combos
    ("L4-R24", ["D07", "P1"], "D163", "버려진 룬석에 이끼가 내려앉으면", {}),
    ("L4-R25", ["D73", "P2"], "D164", "네온관에 마력 결정을 물려 밝히면", {}),
    ("L4-R26", ["D110", "P1"], "D165", "태엽 문자판에 룬석을 박으면", {}),
    # (e) placement/decor
    ("L4-R27", ["D140", "P1"], "D166", "각인석을 룬석 기둥에 세우면", {}),
    ("L4-R28", ["D149", "P2"], "D167", "룬 원판에 마력 결정을 얹으면", {}),
    ("L4-R29", ["D143", "P6"], "D168", "정화의 물을 별빛 이슬로 돌리면", {}),
    ("L4-R30", ["D142", "D144"], "D169", "결계 부적과 봉인 인장을 문틀에 걸면", {}),
    ("L4-R31", ["D146", "D151"], "D170", "봉인구 뼈대를 겹 양피지로 감싸면", {}),
    ("L4-R32", ["D154", "P2"], "D171", "밀랍초를 마력 결정으로 되살리면", {}),
    ("L4-R33", ["D140", "D152"], "D172", "각인석에 은박 룬을 물리면", {}),
    # (f) dead-end leaf
    ("L4-R34", ["D150", "P7"], "D173", "응축 마력핵에 공허 파편이 스며들면", {}),
    ("L4-R35", ["D144", "P7"], "D174", "봉인 인장에 공허 파편이 금을 내면", {}),
    ("L4-R36", ["D160", "P7"], "D175", "결계 등불에 공허 파편을 넣어도 빛나지 않는다", {}),
    ("L4-R37", ["D147", "P6"], "D176", "룬 문장에 별빛 이슬을 얹으면 얼굴이 비친다", {}),
]


def pair_key(inputs):
    a, b = inputs
    if a == b:
        return ("SAME", a)
    return frozenset(inputs)


def main():
    items_doc = json.load(open(os.path.join(DATA, "items.json")))
    recipes_doc = json.load(open(os.path.join(DATA, "recipes.json")))
    items = items_doc["items"]
    recipes = recipes_doc["recipes"]

    # strip prior L4 injections (idempotent): P1..P7 gather + D140+ craft + L4-R* recipes.
    def is_l4_item(i):
        iid = i["id"]
        if iid.startswith("P") and iid[1:].isdigit():
            return True
        return iid.startswith("D") and iid[1:].isdigit() and int(iid[1:]) >= 140
    items = [i for i in items if not is_l4_item(i)]
    recipes = [r for r in recipes if not str(r.get("id", "")).startswith("L4-R")]

    # build P items
    for pid, name, flavor in P:
        items.append({"id": pid, "name": name, "category": "gather", "layer": 4,
                      "flavor": flavor, "placeable_on": [], "usable_on": []})
    # build D items
    for did, name, flavor, extra in D:
        it = {"id": did, "name": name, "category": "craft", "layer": 4, "flavor": flavor,
              "placeable_on": [], "usable_on": []}
        it.update(extra)
        items.append(it)

    new_item_ids = {i["id"] for i in items}

    # ---- verify recipes ----
    existing_pairs = {}
    for r in recipes:
        existing_pairs[pair_key(r["inputs"])] = r["id"]

    errors = []
    new_pairs = {}
    for rid, inputs, out, hint, extra in R:
        for inp in inputs:
            if inp not in new_item_ids:
                errors.append(f"{rid}: dangling input {inp}")
        if out not in new_item_ids:
            errors.append(f"{rid}: dangling output {out}")
        # pair-dup check — skip the whisper-fusion R09 (재화 융합, 페어검사 제외 per §B-3)
        if rid == "L4-R09":
            # sanity: R09 MUST carry whisper_cost.mana:1 (the only mana sink).
            if int(extra.get("whisper_cost", {}).get("mana", 0)) != 1:
                errors.append(f"{rid}: MISSING whisper_cost.mana:1 (유일한 마력 sink — 절대 누락 금지)")
            continue
        pk = pair_key(inputs)
        if pk in existing_pairs:
            errors.append(f"{rid}: pair {inputs} collides with existing {existing_pairs[pk]}")
        if pk in new_pairs:
            errors.append(f"{rid}: pair {inputs} collides with new {new_pairs[pk]}")
        new_pairs[pk] = rid

    if errors:
        print("VERIFY FAILED:")
        for e in errors:
            print("  ", e)
        sys.exit(1)

    # append recipes
    for rid, inputs, out, hint, extra in R:
        rec = {"id": rid, "inputs": inputs, "output": out, "hint": hint, "layer": 4}
        rec.update(extra)
        recipes.append(rec)

    items_doc["items"] = items
    recipes_doc["recipes"] = recipes
    json.dump(items_doc, open(os.path.join(DATA, "items.json"), "w"), ensure_ascii=False, indent=1)
    json.dump(recipes_doc, open(os.path.join(DATA, "recipes.json"), "w"), ensure_ascii=False, indent=1)

    print(f"items: {len(items)} total (+{len(P)+len(D)} L4)")
    print(f"recipes: {len(recipes)} total (+{len(R)} L4)")
    print("VERIFY PASS: pair-dup 0, dangling 0 (R09 whisper-fusion excluded; whisper_cost.mana:1 confirmed)")


if __name__ == "__main__":
    main()
