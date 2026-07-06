#!/usr/bin/env python3
"""L5-4 data generator — appends Layer 5 「응답 없는 대성당」 items + recipes.

Encodes docs/project-whisper-layer5-design-v1.md Part B verbatim:
  - B-1: S1~S7 gather elements (layer:5).
  - B-2 (a)~(f): recipes L5-R01~L5-R42, outputs D177~D218 (layer:5).
  - Placement classes per (e)/(d)/(f): structure/decor with blocks/glows flags.
  - L5-R10 「응답」(D186): whisper_cost {energy:1, mana:1, vita:1} — 3키 필수.

Idempotent: refuses to double-append (checks for S1 / L5-R01 presence).
Run: NODE-free pure python. Writes back items.json / recipes.json in-place
(2-space indent, ensure_ascii=False — matching the existing files' Godot JSON style).
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS_PATH = os.path.join(ROOT, "game", "data", "items.json")
RECIPES_PATH = os.path.join(ROOT, "game", "data", "recipes.json")

# Placement 'on' tile lists (mirror L4 D170/D176 pattern: new-layer walkable tiles
# first, then accumulate prior layers + home tiles).
L5_WALK = ["L5T-P", "L5T-L", "L5T-Q", "L5T-C", "L5T-O"]
PRIOR = ["L4T-A", "L4T-p", "L4T-R", "L4T-M", "L4T-O",
         "L3T-B", "L3T-p", "L3T-G", "L3T-M", "L3T-O",
         "L2T-M", "L2T-C", "L2T-c", "L2T-G",
         "T1", "T2A", "T2B", "T2C", "T2D", "T0"]
PLACE_ON = L5_WALK + PRIOR


def placement(cls, blocks, glows):
    return {"class": cls, "on": list(PLACE_ON), "blocks": blocks, "glows": glows}


# ------------------------------------------------------------------ S1~S7 (B-1)
S_ELEMENTS = [
    ("S1", "성수", "\"맑았던 물. 이제 아무도 이마를 적시지 않아, 그저 고여 있다.\""),
    ("S2", "빛바랜 성물", "\"무엇이었는지 알 수 없이 바랬다. 그래도 손에 쥐면, 조금 따뜻하다.\""),
    ("S3", "대리석 조각", "\"무너진 성인상의 한 조각. 누군가의 손이었을까, 옷자락이었을까.\""),
    ("S4", "기도 구슬", "\"한 알마다 기도 하나. 세던 손이 멈춘 지, 오래되었다.\""),
    ("S5", "성가 악보", "\"부를 사람이 없는 노래. 종이만, 아직 음을 기억한다.\""),
    ("S6", "재의 날개", "\"돌이 된 천사의 날개에서 떨어진 재. 날려던 방향만, 남아 있다.\""),
    ("S7", "신성한 잔불", "\"꺼지기 직전의 불씨. 이 온기가 다하면, 신도 함께 사라진다.\""),
]


def s_item(iid, nm, flavor):
    return {
        "id": iid, "name": nm, "category": "gather", "layer": 5,
        "flavor": flavor, "placeable_on": [], "usable_on": [],
    }


# ------------------------------------------------------- D177~D218 recipe specs
# Each: (recipe_id, name, [in_a, in_b], hint, flavor, out_id, extra)
#   extra: dict merged into the OUTPUT item record (key_item / usable_on /
#          placeable_on / placement) and, for whisper_cost, into the RECIPE.
# Faithful to Part B tables (a)~(f).
R = [
    # (a) gate chain L5-R01~R10 -------------------------------------------------
    ("L5-R01", "성수 등불심지", ["S1", "S5"],
     "성수에 성가 악보를 적셔 심지를 꼬면", "꺼진 등불에 넣을 심지. 아직, 불은 없다.", "D177", {}),
    ("L5-R02", "성소의 등불", ["D177", "S7"],
     "등불심지에 신성한 잔불을 옮겨 담으면", "한 점, 다시 켜진 빛. 길을 밝히기엔, 너무 작다.", "D178",
     {"key_item": True, "usable_on": ["lantern_altar"]}),
    ("L5-R03", "정화의 성수", ["S1", "S4"],
     "성수에 기도 구슬을 담가 맑히면", "흐려진 샘에 부을, 한 방울의 맑음.", "D179", {}),
    ("L5-R04", "생명의 씨", ["D179", "S3"],
     "정화의 성수를 대리석 조각에 스미게 하면", "돌 속에서, 아주 작은 초록이 움튼다.", "D180",
     {"key_item": True, "usable_on": ["life_spring"]}),
    ("L5-R05", "기도문 두루마리", ["S5", "S2"],
     "성가 악보를 빛바랜 성물로 봉인해 말면", "소리 내지 않고 읽는 글. 회랑이, 그 침묵을 허락한다.", "D181", {}),
    ("L5-R06", "침묵의 성가", ["D181", "S4"],
     "기도문 두루마리에 기도 구슬을 꿰면 성가가 된다", "입술을 움직이지 않아도, 울리는 노래.", "D182",
     {"key_item": True}),
    ("L5-R07", "봉헌의 그릇", ["S3", "S2"],
     "대리석 조각을 빛바랜 성물로 깎아 그릇을 뜨면", "비어 있는 그릇. 무엇을 담을지, 아직 모른다.", "D183", {}),
    ("L5-R08", "응답의 불씨", ["S7", "S6"],
     "신성한 잔불을 재의 날개로 감싸 지피면", "꺼져 가던 잔불이, 마지막으로 한 번 크게 흔들린다.", "D184", {}),
    ("L5-R09", "대성당의 종", ["S6", "S4"],
     "재의 날개에 기도 구슬을 달아 흔들면", "소리 없는 종. 그래도, 누군가는 듣는다.", "D185", {}),
    ("L5-R10", "응답", ["D183", "D183"],
     "봉헌의 그릇 둘에, 에너지·마력·생명 세 속삭임을 모두 담으면",
     "세계가 창조자에게 걸어온 말에, 처음으로 대답한다. \"…나 여기 있어.\"", "D186",
     {"key_item": True, "usable_on": ["offering_altar"],
      "_whisper_cost": {"energy": 1, "mana": 1, "vita": 1}}),

    # (b) basic 7-way L5-R11~R20 ------------------------------------------------
    ("L5-R11", "겹 대리석판", ["S3", "S3"],
     "대리석 조각 둘을 맞대어 갈면", "같은 돌 둘. 마주 세우면, 기둥이 된다.", "D187", {}),
    ("L5-R12", "두 겹 성가", ["S5", "S5"],
     "성가 악보 둘을 포개어 합창으로 만들면", "혼자선 가늘던 소리가, 둘이 되니 겨우 들린다.", "D188", {}),
    ("L5-R13", "묵주", ["S4", "S4"],
     "기도 구슬 둘을 실로 이어 꿰면", "헤아리는 손. 한 알마다, 이름 없는 기도 하나.", "D189", {}),
    ("L5-R14", "은빛 성유", ["S1", "S6"],
     "성수에 재의 날개를 개어 성유를 만들면", "바르면 서늘하다. 이마에 긋는, 마지막 표식.", "D190", {}),
    ("L5-R15", "성물 먼지", ["S2", "S6"],
     "빛바랜 성물을 재의 날개와 함께 빻으면", "한때 성했던 것의 가루. 쓸어 담아, 다시 쓴다.", "D191", {}),
    ("L5-R16", "재의 성수", ["S6", "S3"],
     "재의 날개를 대리석 성반에 풀어 적시면", "회색이 번진 맑은 물. 슬픔도, 씻기면 옅어진다.", "D192", {}),
    ("L5-R17", "잔불 초", ["S7", "S4"],
     "신성한 잔불에 기도 구슬 심지를 세우면", "작은 불 하나. 대성당의 어둠에, 한 뼘의 온기.", "D193", {}),
    ("L5-R18", "성가 지도", ["S5", "S3"],
     "성가 악보를 대리석에 새겨 음표를 남기면", "읽을 수 없는 악보. 그래도, 어느 제단을 가리킨다.", "D194", {}),
    ("L5-R19", "기도의 재", ["S6", "S5"],
     "재의 날개에 성가 악보를 얹어 사르면", "다 타고 남은 것. 이 재가, 다음 불을 품는다.", "D195", {}),
    ("L5-R20", "봉인된 성구", ["S2", "S7"],
     "빛바랜 성물에 신성한 잔불을 봉인해 넣으면", "잔불을 가둔 성물. 흔들면, 안에서 희미하게 탄다.", "D196", {}),

    # (c) S 2nd-order L5-R21~R24 -----------------------------------------------
    ("L5-R21", "성유 등", ["D190", "D193"],
     "은빛 성유를 잔불 초로 밝히면", "성유가 타며, 향이 번진다. 아무도 없는 회랑에.", "D197", {}),
    ("L5-R22", "봉헌 화관", ["D183", "S3"],
     "봉헌의 그릇 가장자리를 대리석으로 두르면", "그릇에 두른 관. 담길 것을, 미리 기린다.", "D198", {}),
    ("L5-R23", "묵주 성가", ["D189", "D188"],
     "묵주를 두 겹 성가에 맞춰 헤아리면", "한 알, 한 소절. 세다 보면, 밤이 지난다.", "D199", {}),
    ("L5-R24", "성수 각인석", ["D180", "S3"],
     "생명의 씨를 대리석에 심어 각인하면", "돌에 깃든 초록. 죽은 세계에도, 뿌리는 내린다.", "D200", {}),

    # (d) L1~L4 cross L5-R25~R31 -----------------------------------------------
    ("L5-R25", "세계수 성수", ["D19", "S1"],
     "생명수를 성수와 섞어 성반에 담으면", "두 세계의 물이 만난다. 자연의 것과, 신의 것.", "D201", {}),
    ("L5-R26", "태엽 성가 오르간", ["D110", "S5"],
     "태엽 문자판에 성가 악보를 물리면", "태엽이 돌 때마다, 한 소절씩 성가가 흘러나온다.", "D202",
     {"placement_flags": ("decor", False, True)}),
    ("L5-R27", "룬 봉헌등", ["D141", "S7"],
     "룬 다리석에 신성한 잔불을 얹으면", "금색 룬 위로, 호박빛 잔불이 깜빡인다.", "D203",
     {"placement_flags": ("decor", False, True)}),
    ("L5-R28", "네온 성상", ["D73", "S2"],
     "네온관을 빛바랜 성물에 둘러 세우면", "옛 세계의 빛으로 밝힌 성인. 표정은, 지워졌다.", "D204",
     {"placement_flags": ("decor", False, True)}),
    ("L5-R29", "세계수 묘목 제단", ["D22", "S4"],
     "어린 세계수 곁에 기도 구슬을 묻으면", "나무에게 비는 기도. 나무는, 대답 대신 자란다.", "D205",
     {"placement_flags": ("structure", True, False)}),
    ("L5-R30", "봉인된 성물함", ["D148", "S2"],
     "최심부 봉인구를 빛바랜 성물로 감싸면", "봉해 둔 힘 위에, 신의 표식을 덧새긴다.", "D206",
     {"placement_flags": ("structure", True, False)}),
    ("L5-R31", "에너지 성반", ["D69", "S1"],
     "파워 코어를 성수에 담가 식히면", "뜨겁던 심장이, 성수 속에서 고요해진다.", "D207",
     {"placement_flags": ("structure", True, False)}),

    # (e) placement decor/structure L5-R32~R38 ---------------------------------
    ("L5-R32", "성소 오벨리스크", ["D187", "S3"],
     "겹 대리석판을 대리석으로 세우면", "바랜 광장에, 하얀 기둥 하나를 세워 둔다.", "D208",
     {"placement_flags": ("structure", True, False)}),
    ("L5-R33", "호박빛 성등", ["D193", "S7"],
     "잔불 초를 신성한 잔불로 키우면", "따뜻한 호박빛이 발밑을 겨우 비춘다. 꺼져 가는 잔불처럼.", "D209",
     {"placement_flags": ("decor", False, True)}),
    ("L5-R34", "생명의 화단", ["D180", "S1"],
     "생명의 씨에 성수를 주면", "바랜 돌 틈에, 초록 한 뼘. 이 세계에도, 아직.", "D210",
     {"placement_flags": ("structure", True, True)}),
    ("L5-R35", "봉헌 제단", ["D183", "D181"],
     "봉헌의 그릇을 기도문 두루마리 위에 놓으면", "무엇이든 바칠 수 있는 자리. 무엇도, 강요하지 않는.", "D211",
     {"placement_flags": ("structure", True, False)}),
    ("L5-R36", "침묵의 종탑", ["D185", "S3"],
     "대성당의 종을 대리석 탑에 매달면", "소리 없이 흔들리는 종. 그래도, 시간은 흐른다.", "D212",
     {"placement_flags": ("structure", True, False)}),
    ("L5-R37", "성가대석", ["D188", "S2"],
     "두 겹 성가를 빛바랜 성물 자리에 펼치면", "아무도 앉지 않은 성가대석. 악보만, 펼쳐진 채.", "D213",
     {"placement_flags": ("structure", True, False)}),
    ("L5-R38", "기도 촛대", ["D189", "S7"],
     "묵주에 신성한 잔불을 켜 얹으면", "한 알마다 불 하나. 다 켜지면, 누군가 온다고 했다.", "D214",
     {"placement_flags": ("decor", False, True)}),

    # (f) dead-end leaf L5-R39~R42 ---------------------------------------------
    ("L5-R39", "돌이 된 기도손", ["D198", "S6"],
     "봉헌 화관에 재의 날개가 내려앉으면", "기도하던 손. 돌이 되어도, 여전히 모으고 있다.", "D215",
     {"placement_flags": ("decor", False, False)}),
    ("L5-R40", "바랜 성상", ["D191", "S2"],
     "성물 먼지가 빛바랜 성물 위에 쌓이면", "얼굴이 지워진 성인. 무엇을 굽어보던, 눈이었을까.", "D216",
     {"placement_flags": ("decor", False, False)}),
    ("L5-R41", "식은 향로", ["D195", "S3"],
     "기도의 재를 대리석 향로에 담으면", "불씨가 죽은 향로. 재만, 아직 향을 기억한다.", "D217",
     {"placement_flags": ("decor", False, False)}),
    ("L5-R42", "응답 없는 유리", ["D184", "S6"],
     "응답의 불씨에 재의 날개를 비추면", "유리 속에 세계가 비친다. 말을 걸어도, 대답이 없던.", "D218",
     {"placement_flags": ("decor", False, False)}),
]


def build_item(rid, name, inputs, hint, flavor, out_id, extra):
    it = {
        "id": out_id, "name": name, "category": "craft", "layer": 5,
        "flavor": flavor, "placeable_on": [], "usable_on": [],
    }
    if extra.get("key_item"):
        it["key_item"] = True
    if extra.get("usable_on"):
        it["usable_on"] = list(extra["usable_on"])
    if "placement_flags" in extra:
        cls, blocks, glows = extra["placement_flags"]
        it["placement"] = placement(cls, blocks, glows)
        # Match existing convention (D08/D24/D33 etc.): placeable_on stays []; the
        # placement.on list drives placement, not placeable_on.
    return it


def build_recipe(rid, name, inputs, hint, flavor, out_id, extra):
    rec = {"id": rid, "inputs": list(inputs), "output": out_id, "hint": hint, "layer": 5}
    if "_whisper_cost" in extra:
        rec["whisper_cost"] = dict(extra["_whisper_cost"])
        rec["_note"] = ("「응답」 = 봉헌의 그릇(D183) 둘 + 에너지·마력·생명 Whisper 각 1 소모 "
                        "(3속성 컬미네이션, 유일한 vita sink). whisper_cost 3키 절대 누락 금지 (설계 §B-2/C-3).")
    return rec


def main():
    items_doc = json.load(open(ITEMS_PATH, encoding="utf-8"))
    recipes_doc = json.load(open(RECIPES_PATH, encoding="utf-8"))
    items = items_doc["items"]
    recipes = recipes_doc["recipes"]

    existing_item_ids = {i["id"] for i in items}
    existing_recipe_ids = {r["id"] for r in recipes}

    if "S1" in existing_item_ids or "L5-R01" in existing_recipe_ids:
        print("REFUSING: L5 data already present (S1 or L5-R01 found). No-op.")
        return 0

    # append gather S1~S7
    for iid, nm, fl in S_ELEMENTS:
        items.append(s_item(iid, nm, fl))

    # append craft outputs D177~D218 + recipes L5-R01~R42
    for spec in R:
        rid, name, inputs, hint, flavor, out_id, extra = spec
        items.append(build_item(rid, name, inputs, hint, flavor, out_id, extra))
        recipes.append(build_recipe(rid, name, inputs, hint, flavor, out_id, extra))

    # write back (Godot JSON style: 1-space or 2-space? existing uses 1-space indent for items,
    # detect from raw)
    with open(ITEMS_PATH, "w", encoding="utf-8") as f:
        json.dump(items_doc, f, ensure_ascii=False, indent=1)
        f.write("\n")
    with open(RECIPES_PATH, "w", encoding="utf-8") as f:
        json.dump(recipes_doc, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("items: +%d (now %d)  recipes: +%d (now %d)" % (
        7 + len(R), len(items), len(R), len(recipes)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
