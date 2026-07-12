#!/usr/bin/env python3
"""
EX-L4 데이터 반영기 (EXL4-4).
l4x_data_fragment.json(= l4x_recipes.py 산출)을 소비해
game/data/items.json(P8~P12 + D301~D323) 과 game/data/recipes.json(EX-L4-R01~R23)에
아이템/레시피를 idempotent 하게 병합한다. 손 타이핑 금지 — 이 스크립트가 유일 반영 경로.
l3x_apply_data.py 패턴 계승(스키마·place 태그 변환·병합 로직 동일, id/타깃만 L4 교체).

- 아이템 스키마: {id,name,category,flavor,placeable_on,usable_on}(+ unique / key_item / placement)
- 레시피 스키마: {id,inputs,output,hint,layer:4}(+ whisper 재화 융합 시 whisper:{mana:N})
- place 태그(decor/structure/functional/placement/use/chain/glows)를 placement 서브레코드로 변환.
- 유니크 P12 = unique:true (fusion.gd 촉매 규칙, R08에서 미소모). 게이트 최종물에 usable/placeable/key 부여.
- P12 소모 필드 금지(어서션 A2): unique:true 외 소모 카운트 override 없음. R09만 whisper_cost.mana:1(GW4 유일 sink).
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
FRAG = os.path.join(ROOT, "tools", "l4x_data_fragment.json")

# 부유 서고 = 자수정/보라 리컬러 지면(L4T-A/L4T-M/L4T-O) + void. 게이트 배치물은 전용 타깃 타일/슬롯.
GROUND = ["L4T-A", "L4T-M", "L4T-O", "T0"]

# 게이트 열쇠 최종물의 usable_on / placeable_on 타깃(레전드 gate 셀/타입과 정합, l4a legend 대조).
#   GW1 부유 서가 다리석 D302 → 룬 제단 X(부유 서가 다리 배치 슬롯, place_slot)
#   GW2 열람 정화의 물   D304 → 흐려진 열람 결계 reading_ward 사용(GW2)
#   GW3 봉인 서판 1/2/3  D305/D306/D307 → 봉인 서판 슬롯 z x3 (순서 강제 seal_ordered)
#   GW4 금기 봉인구      D309 → 금서고 코어 봉헌(archive_core_altar) = 구역 정화/클리어
GATE_ITEM_META = {
    "D302": {"placeable_on": ["SEAL_BRIDGE"], "placement": {"class": "functional", "on": ["SEAL_BRIDGE"], "blocks": False}},  # 부유 서가 다리석 = 룬 제단 X 배치(GW1)
    "D304": {"usable_on": ["reading_ward"]},  # 열람 정화의 물 → 흐려진 열람 결계 사용(GW2)
    "D305": {"placeable_on": ["SEAL_TABLET"], "placement": {"class": "functional", "on": ["SEAL_TABLET"], "blocks": False}},  # 봉인 서판 1장 → 봉인 서판 슬롯(GW3, 순서 1)
    "D306": {"placeable_on": ["SEAL_TABLET"], "placement": {"class": "functional", "on": ["SEAL_TABLET"], "blocks": False}},  # 2장(순서 2)
    "D307": {"placeable_on": ["SEAL_TABLET"], "placement": {"class": "functional", "on": ["SEAL_TABLET"], "blocks": False}},  # 3장(순서 3)
    "D309": {"key_item": True},  # 금기 봉인구 = GW4 봉헌(금서고 코어 봉헌 목)
}
UNIQUE_GATHERS = {"P12"}


def placement_from_place(place: str):
    """fragment place 문자열 → placement 서브레코드(or None) + glows 플래그."""
    if not place:
        return None
    toks = [t.strip() for t in place.split("·")]
    glows = any("glows" in t for t in toks)
    cls = None
    for t in toks:
        if t.startswith("decor"):
            cls = "decor"
        elif t.startswith("structure"):
            cls = "structure"
    if cls is None:
        return None
    rec = {"class": cls, "on": GROUND, "blocks": cls == "structure"}
    if glows:
        rec["glows"] = True
    return rec


def build_items(frag):
    items = []
    # 채집 5종 P8~P12 (모든 신규 항목 layer:4 병기 — 설계 §B, L4 도메인)
    for g in frag["gathers"]:
        if g["id"] in UNIQUE_GATHERS:
            it = {"id": g["id"], "name": g["name"], "category": "gather", "layer": 4,
                  "unique": True, "flavor": g["flavor"],
                  "placeable_on": [], "usable_on": []}
        else:
            it = {"id": g["id"], "name": g["name"], "category": "gather", "layer": 4,
                  "flavor": g["flavor"], "placeable_on": [], "usable_on": []}
        items.append(it)
    # 조합 23종 D301~D323 (fragment.recipes[].output)
    for r in frag["recipes"]:
        oid = r["output"]
        it = {
            "id": oid,
            "name": r["name"],
            "category": "craft",
            "layer": 4,
            "flavor": r.get("flavor", ""),
            "placeable_on": [],
            "usable_on": [],
        }
        meta = GATE_ITEM_META.get(oid)
        if meta:
            if "key_item" in meta:
                it["key_item"] = True
            it["placeable_on"] = meta.get("placeable_on", [])
            it["usable_on"] = meta.get("usable_on", [])
            if "placement" in meta:
                it["placement"] = meta["placement"]
        else:
            p = placement_from_place(r.get("place", ""))
            if p:
                it["placement"] = p
        items.append(it)
    return items


def build_recipes(frag):
    out = []
    for r in frag["recipes"]:
        rec = {
            "id": r["id"],
            "inputs": list(r["inputs"]),
            "output": r["output"],
            "hint": r["hint"],
            "layer": 4,
        }
        # 마력 Whisper 재화 융합(GW4 R09만) — whisper_cost.mana:1 sink. 별도 소모 필드 아님(A2).
        # 엔진 RecipeDB.whisper_cost()는 `whisper_cost` 키를 읽는다(L4-R09 등 기존 계승) → 그 키로 병기.
        if r.get("whisper"):
            rec["whisper_cost"] = r["whisper"]
        out.append(rec)
    return out


def merge(path, key, new_records, id_key="id"):
    d = json.load(open(path, encoding="utf-8"))
    arr = d[key]
    by_id = {x[id_key]: i for i, x in enumerate(arr)}
    added, replaced = 0, 0
    for rec in new_records:
        rid = rec[id_key]
        if rid in by_id:
            arr[by_id[rid]] = rec
            replaced += 1
        else:
            arr.append(rec)
            added += 1
    with open(path, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return added, replaced, len(arr)


def main():
    frag = json.load(open(FRAG, encoding="utf-8"))
    items = build_items(frag)
    recipes = build_recipes(frag)
    ia, ir, itot = merge(os.path.join(DATA, "items.json"), "items", items)
    ra, rr, rtot = merge(os.path.join(DATA, "recipes.json"), "recipes", recipes)
    print(f"items.json:  +{ia} 추가 / {ir} 교체 / 총 {itot}")
    print(f"recipes.json: +{ra} 추가 / {rr} 교체 / 총 {rtot}")
    # 사후 정합: P12 unique, D301~D323 연속, P8~P12 존재, R09 whisper sink 유일
    d = json.load(open(os.path.join(DATA, "items.json"), encoding="utf-8"))
    ids = {x["id"] for x in d["items"]}
    missing = [f"D{n}" for n in range(301, 324) if f"D{n}" not in ids]
    missing += [f"P{n}" for n in range(8, 13) if f"P{n}" not in ids]
    p12 = next((x for x in d["items"] if x["id"] == "P12"), {})
    # P12 소모 필드 금지 어서션 A2
    forbidden = [k for k in ("consume", "qty", "stack_cost") if k in p12]
    rd = json.load(open(os.path.join(DATA, "recipes.json"), encoding="utf-8"))
    manasinks = [r["id"] for r in rd["recipes"] if r.get("whisper_cost") and r["id"].startswith("EX-L4")]
    print("D301~D323·P8~P12 누락:", missing or "NONE")
    print("P12 unique:", p12.get("unique") is True, "| P12 소모필드(금지):", forbidden or "NONE")
    print("EX-L4 마력 sink 레시피(R09 유일이어야):", manasinks)
    ok = (not missing and p12.get("unique") is True and not forbidden
          and manasinks == ["EX-L4-R09"])
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
