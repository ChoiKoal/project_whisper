#!/usr/bin/env python3
# L3-4 — Inject Layer-3 items (K1~K7 gather + D103~D139 craft) and recipes (L3-R01~L3-R37) into
# data/items.json + data/recipes.json, exactly per design doc §B-1/§B-2. Idempotent: strips any
# existing K*/D103+/L3-R* entries first, then re-appends, so re-running is safe. Verifies pair
# uniqueness (no dup input-pair vs the existing 104 recipes and among the new set) and dangling
# D-refs before writing. Run: python3 tools_gen_l3_data.py
import json, os, sys

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

# ---- K1~K7 gather elements (§B-1) ----
K = [
    ("K1", "태엽", "끝까지 감겼다가, 끝까지 풀렸다. 이제 아무것도 밀어내지 않는다."),
    ("K2", "톱니", "이 하나가 맞물릴 곳을, 아직 찾고 있는 듯하다."),
    ("K3", "황동", "닦으면 아직 빛난다. 누군가 정성껏 깎아 만든 것."),
    ("K4", "증기응축수", "김이 식어 맺힌 물방울. 뜨거웠던 시절의 흔적."),
    ("K5", "가죽 벨트", "힘을 옮기던 띠. 이제 걸릴 축이 없어 늘어져 있다."),
    ("K6", "석탄", "태우려고 캐 두었을 것이다. 태울 화로가, 먼저 식었다."),
    ("K7", "기름때 유리", "계기판의 얼굴. 기름때 너머로, 멈춘 바늘이 비친다."),
]

# ---- D103~D139 craft outputs (§B-2). name + flavor + optional key_item/usable_on/placement. ----
# tuples: (id, name, flavor, extra) where extra dict merges into the item.
BRASS_TILES = ["L3T-B", "L3T-p", "L3T-G", "L3T-M", "L3T-O",
               "L2T-M", "L2T-C", "L2T-c", "L2T-G", "T1", "T2A", "T2B", "T2C", "T2D", "T0"]

def struct(blocks=True, glows=False):
    return {"placement": {"class": "structure", "on": BRASS_TILES, "blocks": blocks, "glows": glows}}
def decor(glows=False):
    return {"placement": {"class": "decor", "on": BRASS_TILES, "blocks": False, "glows": glows}}
def key(usable=None):
    d = {"key_item": True}
    if usable is not None:
        d["usable_on"] = usable
    return d

D = [
    ("D103", "황동 톱니 원판", "이가 빠진 자리를, 새 이로 채운다.", {}),
    ("D104", "맞물림 톱니", "혼자서는 아무것도 아니다. 맞물려야, 비로소 힘이 된다.", key(["gear_assembly"])),
    ("D105", "압력 밸브", "새어 나가려는 것을, 붙든다.", key(["boiler"])),
    ("D106", "젖은 석탄", "축축해도 탄다. 마지막 불씨는 늘 그렇다.", {}),
    ("D107", "강철 케이블", "끊어지면, 모든 게 떨어진다. 그러니 겹겹이 꼰다.", {}),
    ("D108", "평형추", "한쪽이 오르려면, 다른 쪽이 가라앉아야 한다.", key(["elevator_ctrl"])),
    ("D109", "심장 뼈대", "심장이 될 뼈대. 아직은 태엽만 감겨 있다.", {}),
    ("D110", "태엽 문자판", "몇 시에 멈췄는지, 이 유리는 알고 있다.", {}),
    ("D111", "태엽심장", "멈춘 도시의 마지막 심장. 여기에 온기를, 마지막으로 한 번.", key(["clock_mount"])),
    ("D112", "강철 톱니바퀴", "혼자 돌던 것들이, 함께 돌기 시작한다.", {}),
    ("D113", "연마 유리알", "닦을수록, 비친 얼굴이 낯설어진다.", {}),
    ("D114", "황동관", "속이 빈 채로도, 증기를 나른다.", {}),
    ("D115", "그을린 벨트", "타다 만 채로도, 아직 돌아간다.", {}),
    ("D116", "기름 헝겊", "닦아 낼수록, 손이 더 검어진다.", {}),
    ("D117", "태엽 감개", "감아 둔 힘. 언젠가 풀릴 것을 알면서.", {}),
    ("D118", "황동 볼트", "조이는 것. 풀리지 않기를 바라며 만든 것.", {}),
    ("D119", "연료 벽돌", "네모반듯한 불. 태우기 좋게, 슬프도록 정갈하게.", {}),
    ("D120", "응결 렌즈", "물방울 하나에, 멈춘 도시가 거꾸로 담긴다.", {}),
    ("D121", "벨트 도르래", "힘을 옮긴다. 제 것은 하나도 남기지 않고.", {}),
    ("D122", "구동 모듈", "돌아가려는 의지를, 멀리까지 전한다.", {}),
    ("D123", "압력 계기", "바늘이 붉은 선을 향한다. 아무도 보지 않아도.", {}),
    ("D124", "증기 파이프", "쉭 — 도시가 마지막 숨을 내쉰다.", {}),
    ("D125", "태엽 인형", "감아 주면 춤을 췄다. 감아 줄 손이, 이제 없다.", {}),
    ("D126", "이끼 낀 톱니", "기계도 오래 멈추면, 결국 숲이 데려간다.", decor(False)),
    ("D127", "네온 태엽등", "감긴 만큼만, 빛난다. 풀리면 다시 어둠.", decor(True)),
    ("D128", "강철 태엽 도끼", "자르는 리듬마저, 태엽이 정한다.", {}),
    ("D129", "멈춘 가로 태엽시계", "이 죽은 거리에, 시간을 다시 세워 둔다.", struct(True, False)),
    ("D130", "증기 가로등", "주황빛 증기가, 발밑을 겨우 비춘다.", decor(True)),
    ("D131", "태엽 분수", "물이 돈다. 갈 곳도 없이, 그저 돈다.", struct(True, True)),
    ("D132", "황동 톱니 문", "여닫을 때마다, 도시가 앓는 소리를 낸다.", struct(True, False)),
    ("D133", "멈춘 로봇 좌상", "마지막 명령을 기다리는 자세로, 태엽이 다 풀렸다.", struct(True, False)),
    ("D134", "연료 화로", "온기가 필요했던 건, 도시가 아니라 나였을지도.", struct(True, True)),
    ("D135", "태엽 간판", "무슨 가게였을까. 이제는 태엽 소리만 남았다.", decor(True)),
    ("D136", "녹슨 태엽 훈장", "누군가는 이걸 자랑스러워했다. 그 손도, 멈췄다.", decor(False)),
    ("D137", "말라붙은 기름병", "마지막으로 무엇을 적으려 했을까.", decor(False)),
    ("D138", "부서진 태엽 오르골", "감아도, 이제 아무 곡도 나오지 않는다.", decor(False)),
    ("D139", "꺼진 신호 톱니", "돌아가긴 한다. 아무 신호도 없이.", decor(False)),
]

# ---- L3-R01~R37 recipes (§B-2). (id, [in1,in2], output, hint, extra). ----
R = [
    ("L3-R01", ["K2", "K3"], "D103", "톱니를 황동판에 대고 벼리면", {}),
    ("L3-R02", ["D103", "K1"], "D104", "톱니 원판에 태엽을 물리면 돈다", {}),
    ("L3-R03", ["K3", "K5"], "D105", "황동에 벨트를 감아 조이면", {}),
    ("L3-R04", ["K6", "K4"], "D106", "석탄에 응축수를 먹이면", {}),
    ("L3-R05", ["K5", "K2"], "D107", "벨트 심에 톱니 강선을 꼬면", {}),
    ("L3-R06", ["D107", "K3"], "D108", "케이블 끝에 황동 덩이를 매달면", {}),
    ("L3-R07", ["K1", "K3"], "D109", "태엽을 황동 틀에 겹겹이 앉히면", {}),
    ("L3-R08", ["K7", "K1"], "D110", "기름때 유리 뒤에서 태엽이 돈다", {}),
    ("L3-R09", ["D109", "D109"], "D111", "심장 뼈대에 속삭임(에너지)을 불어넣으면",
     {"whisper_cost": {"energy": 1},
      "_note": "태엽심장 = 심장 뼈대(D109) 둘 + 에너지 Whisper 1 소모(§보완). 2입력 시스템 유지(L2-R08 동형: 코어조각² + 에너지). D109 ← (K1,K3) 상부 플랫폼."}),
    ("L3-R10", ["K2", "K2"], "D112", "톱니 둘을 겹쳐 벼리면", {}),
    ("L3-R11", ["K7", "K7"], "D113", "기름때 유리를 갈고 겹치면", {}),
    ("L3-R12", ["K3", "K3"], "D114", "황동을 두드려 말면", {}),
    ("L3-R13", ["K5", "K6"], "D115", "벨트에 석탄재를 문지르면", {}),
    ("L3-R14", ["K5", "K4"], "D116", "벨트 조각을 응축수에 적시면", {}),
    ("L3-R15", ["K1", "K2"], "D117", "태엽을 톱니에 물려 감으면", {}),
    ("L3-R16", ["K2", "K7"], "D118", "톱니 틀에 유리 가루를 섞어 찍으면", {}),
    ("L3-R17", ["K6", "K3"], "D119", "석탄을 황동 틀에 굳히면", {}),
    ("L3-R18", ["K4", "K7"], "D120", "응축수를 유리에 얼려 맺으면", {}),
    ("L3-R19", ["K5", "K1"], "D121", "벨트를 태엽 축에 걸면", {}),
    ("L3-R20", ["D112", "D107"], "D122", "톱니바퀴에 케이블을 이으면", {}),
    ("L3-R21", ["D105", "D110"], "D123", "밸브에 문자판을 얹으면", {}),
    ("L3-R22", ["D103", "K4"], "D124", "황동 원판을 말아 응축수를 통과시키면", {}),
    ("L3-R23", ["D109", "D110"], "D125", "심장 뼈대에 문자판 얼굴을 달면", {}),
    ("L3-R24", ["D07", "K2"], "D126", "버려진 톱니에 이끼가 내려앉으면", {}),
    ("L3-R25", ["D73", "K1"], "D127", "네온관에 태엽을 물려 밝히면", {}),
    ("L3-R26", ["D88", "K3"], "D128", "강철 도끼날에 황동 태엽을 박으면", {}),
    ("L3-R27", ["D110", "K3"], "D129", "문자판을 황동 기둥에 세우면", {}),
    ("L3-R28", ["D103", "D106"], "D130", "황동관에 젖은 석탄을 지피면", {}),
    ("L3-R29", ["D107", "K4"], "D131", "케이블 도르래로 응축수를 퍼 올리면", {}),
    ("L3-R30", ["D112", "D105"], "D132", "톱니바퀴와 밸브를 문틀에 걸면", {}),
    ("L3-R31", ["D109", "K5"], "D133", "심장 뼈대에 가죽을 씌워 앉히면", {}),
    ("L3-R32", ["D106", "K3"], "D134", "젖은 석탄을 황동 화로에 담으면", {}),
    ("L3-R33", ["D110", "D103"], "D135", "문자판에 황동 글자를 물리면", {}),
    ("L3-R34", ["K1", "K6"], "D136", "태엽에 석탄재로 광을 내면", {}),
    ("L3-R35", ["D110", "K5"], "D137", "유리 문자판에 검은 기름이 굳어 있다", {}),
    ("L3-R36", ["D109", "K7"], "D138", "심장 뼈대에 유리를 얹어도 소리가 없다", {}),
    ("L3-R37", ["D112", "K7"], "D139", "톱니바퀴에 유리창을 달아도 깜빡이지 않는다", {}),
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

    # strip prior L3 injections (idempotent)
    def is_l3_item(i):
        iid = i["id"]
        return iid.startswith("K") or (iid.startswith("D") and iid[1:].isdigit() and int(iid[1:]) >= 103)
    items = [i for i in items if not is_l3_item(i)]
    recipes = [r for r in recipes if not str(r.get("id", "")).startswith("L3-R")]

    existing_item_ids = {i["id"] for i in items}

    # build K items
    for kid, name, flavor in K:
        items.append({"id": kid, "name": name, "category": "gather", "layer": 3,
                      "flavor": flavor, "placeable_on": [], "usable_on": []})
    # build D items
    for did, name, flavor, extra in D:
        it = {"id": did, "name": name, "category": "craft", "layer": 3, "flavor": flavor,
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
        # dangling input check
        for inp in inputs:
            if inp not in new_item_ids:
                errors.append(f"{rid}: dangling input {inp}")
        if out not in new_item_ids:
            errors.append(f"{rid}: dangling output {out}")
        # pair-dup check — skip the whisper-fusion R09 (재화 융합, 페어검사 제외 per §B-3)
        if rid == "L3-R09":
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
        rec = {"id": rid, "inputs": inputs, "output": out, "hint": hint, "layer": 3}
        rec.update(extra)
        recipes.append(rec)

    items_doc["items"] = items
    recipes_doc["recipes"] = recipes
    json.dump(items_doc, open(os.path.join(DATA, "items.json"), "w"), ensure_ascii=False, indent=1)
    json.dump(recipes_doc, open(os.path.join(DATA, "recipes.json"), "w"), ensure_ascii=False, indent=1)

    print(f"items: {len(items)} total (+{len(K)+len(D)} L3)")
    print(f"recipes: {len(recipes)} total (+{len(R)} L3)")
    print("VERIFY PASS: pair-dup 0, dangling 0 (R09 whisper-fusion excluded from pair check)")


if __name__ == "__main__":
    main()
