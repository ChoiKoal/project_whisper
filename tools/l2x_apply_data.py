#!/usr/bin/env python3
"""
EX-L2 데이터 반영기 (EXL2-4).
l2x_data_fragment.json(= l2x_recipes.py 산출)을 소비해
game/data/items.json(J8~J12 + D255~D277) 과 game/data/recipes.json(EX-L2-R01~R23)에
아이템/레시피를 idempotent 하게 병합한다. 손 타이핑 금지 — 이 스크립트가 유일 반영 경로.
l1x_apply_data.py 패턴 계승(스키마·place 태그 변환·병합 로직 동일).

- 아이템 스키마: {id,name,category,flavor,placeable_on,usable_on}(+ unique / key_item / placement)
- 레시피 스키마: {id,inputs,output,hint,layer:2}
- place 태그(decor/structure/functional/placement/use/chain/glows)를 placement 서브레코드로 변환.
- 유니크 J12 = unique:true (fusion.gd 촉매 규칙, R08에서 미소모). 게이트 최종물에 usable/placeable/key 부여.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
FRAG = os.path.join(ROOT, "tools", "l2x_data_fragment.json")

# 성소 = 금속 리컬러 지면(T2A~T2D) + void. 게이트 배치물은 전용 타깃 타일.
GROUND = ["T2A", "T2B", "T2C", "T2D", "T0"]

# 게이트 열쇠 최종물의 usable_on / placeable_on 타깃(레전드 gate 셀/타입과 정합)
GATE_ITEM_META = {
    "D256": {"placeable_on": ["T5A"], "placement": {"class": "functional", "on": ["T5A"], "blocks": False}},  # 방수 디딤돌 = 냉각 침수로 K 배치(GB1)
    "D258": {"usable_on": ["sealed_bulkhead"]},  # 디코더 젤 → 봉인 격벽 사용(GB2)
    "D259": {"placeable_on": ["align_slot"], "placement": {"class": "functional", "on": ["align_slot"], "blocks": False}},  # 정합 조각 α → 정합 슬롯(GB3)
    "D260": {"placeable_on": ["align_slot"], "placement": {"class": "functional", "on": ["align_slot"], "blocks": False}},  # β
    "D261": {"placeable_on": ["align_slot"], "placement": {"class": "functional", "on": ["align_slot"], "blocks": False}},  # γ
    "D263": {"key_item": True},  # 복원 코어 = GB4 봉헌(백업 봉헌 목)
}
UNIQUE_GATHERS = {"J12"}


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
    # 채집 5종 J8~J12 (모든 신규 항목 layer:2 병기 — 설계 §B, L2 도메인)
    for g in frag["gathers"]:
        if g["id"] in UNIQUE_GATHERS:
            it = {"id": g["id"], "name": g["name"], "category": "gather", "layer": 2,
                  "unique": True, "flavor": g["flavor"],
                  "placeable_on": [], "usable_on": []}
        else:
            it = {"id": g["id"], "name": g["name"], "category": "gather", "layer": 2,
                  "flavor": g["flavor"], "placeable_on": [], "usable_on": []}
        items.append(it)
    # 조합 23종 D255~D277 (fragment.recipes[].output)
    for r in frag["recipes"]:
        oid = r["output"]
        it = {
            "id": oid,
            "name": r["name"],
            "category": "craft",
            "layer": 2,
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
            "layer": 2,
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
    # 사후 정합: J12 unique, D255~D277 연속, J8~J12 존재
    d = json.load(open(os.path.join(DATA, "items.json"), encoding="utf-8"))
    ids = {x["id"] for x in d["items"]}
    missing = [f"D{n}" for n in range(255, 278) if f"D{n}" not in ids]
    missing += [f"J{n}" for n in range(8, 13) if f"J{n}" not in ids]
    j12 = next((x for x in d["items"] if x["id"] == "J12"), {})
    print("D255~D277·J8~J12 누락:", missing or "NONE")
    print("J12 unique:", j12.get("unique") is True)
    return 0 if not missing and j12.get("unique") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())
