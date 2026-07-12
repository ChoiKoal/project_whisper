#!/usr/bin/env python3
"""
EX-L3 데이터 반영기 (EXL3-4).
l3x_data_fragment.json(= l3x_recipes.py 산출)을 소비해
game/data/items.json(K8~K12 + D278~D300) 과 game/data/recipes.json(EX-L3-R01~R23)에
아이템/레시피를 idempotent 하게 병합한다. 손 타이핑 금지 — 이 스크립트가 유일 반영 경로.
l2x_apply_data.py 패턴 계승(스키마·place 태그 변환·병합 로직 동일, id/타깃만 L3 교체).

- 아이템 스키마: {id,name,category,flavor,placeable_on,usable_on}(+ unique / key_item / placement)
- 레시피 스키마: {id,inputs,output,hint,layer:3}
- place 태그(decor/structure/functional/placement/use/chain/glows)를 placement 서브레코드로 변환.
- 유니크 K12 = unique:true (fusion.gd 촉매 규칙, R08에서 미소모). 게이트 최종물에 usable/placeable/key 부여.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
FRAG = os.path.join(ROOT, "tools", "l3x_data_fragment.json")

# 태엽 광산 = 구리/황동 리컬러 지면(L3T-B/L3T-G) + void. 게이트 배치물은 전용 타깃 타일/슬롯.
GROUND = ["L3T-B", "L3T-G", "T0"]

# 게이트 열쇠 최종물의 usable_on / placeable_on 타깃(레전드 gate 셀/타입과 정합, l3m legend 대조).
#   GM1 붕락 궤도판 D279  → 붕락 낙석 협곡 K(암반 위 배치 슬롯, place_slot)
#   GM2 감압 밸브 젤  D281 → 막힌 통풍문 vent_door 사용(GM2)
#   GM3 전환 레버 α/β/γ D282/D283/D284 → 레일 전환 레버 슬롯 x(RAIL_LEVER)
#   GM4 태엽 노심     D286 → 대굴착기 코어 봉헌(excavator_altar) = 구역 정화/클리어
GATE_ITEM_META = {
    "D279": {"placeable_on": ["L3T-rubble"], "placement": {"class": "functional", "on": ["L3T-rubble"], "blocks": False}},  # 붕락 궤도판 = 협곡 K 배치(GM1)
    "D281": {"usable_on": ["vent_door"]},  # 감압 밸브 젤 → 막힌 통풍문 사용(GM2)
    "D282": {"placeable_on": ["RAIL_LEVER"], "placement": {"class": "functional", "on": ["RAIL_LEVER"], "blocks": False}},  # 전환 레버 α → 레일 전환 슬롯(GM3)
    "D283": {"placeable_on": ["RAIL_LEVER"], "placement": {"class": "functional", "on": ["RAIL_LEVER"], "blocks": False}},  # β
    "D284": {"placeable_on": ["RAIL_LEVER"], "placement": {"class": "functional", "on": ["RAIL_LEVER"], "blocks": False}},  # γ
    "D286": {"key_item": True},  # 태엽 노심 = GM4 봉헌(대굴착기 코어 봉헌 목)
}
UNIQUE_GATHERS = {"K12"}


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
    # 채집 5종 K8~K12 (모든 신규 항목 layer:3 병기 — 설계 §B, L3 도메인)
    for g in frag["gathers"]:
        if g["id"] in UNIQUE_GATHERS:
            it = {"id": g["id"], "name": g["name"], "category": "gather", "layer": 3,
                  "unique": True, "flavor": g["flavor"],
                  "placeable_on": [], "usable_on": []}
        else:
            it = {"id": g["id"], "name": g["name"], "category": "gather", "layer": 3,
                  "flavor": g["flavor"], "placeable_on": [], "usable_on": []}
        items.append(it)
    # 조합 23종 D278~D300 (fragment.recipes[].output)
    for r in frag["recipes"]:
        oid = r["output"]
        it = {
            "id": oid,
            "name": r["name"],
            "category": "craft",
            "layer": 3,
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
        out.append({
            "id": r["id"],
            "inputs": list(r["inputs"]),
            "output": r["output"],
            "hint": r["hint"],
            "layer": 3,
        })
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
    # 사후 정합: K12 unique, D278~D300 연속, K8~K12 존재
    d = json.load(open(os.path.join(DATA, "items.json"), encoding="utf-8"))
    ids = {x["id"] for x in d["items"]}
    missing = [f"D{n}" for n in range(278, 301) if f"D{n}" not in ids]
    missing += [f"K{n}" for n in range(8, 13) if f"K{n}" not in ids]
    k12 = next((x for x in d["items"] if x["id"] == "K12"), {})
    print("D278~D300·K8~K12 누락:", missing or "NONE")
    print("K12 unique:", k12.get("unique") is True)
    return 0 if not missing and k12.get("unique") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())
