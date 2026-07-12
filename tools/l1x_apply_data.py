#!/usr/bin/env python3
"""
EX-L1 데이터 반영기 (EXL1-4).
l1x_data_fragment.json(= l1x_recipes.py 산출)을 소비해
game/data/items.json(I10~I17 + D222~D254) 과 game/data/recipes.json(EX-L1-R01~R33)에
아이템/레시피를 idempotent 하게 병합한다. 손 타이핑 금지 — 이 스크립트가 유일 반영 경로.

- 아이템 스키마: {id,name,category,flavor,placeable_on,usable_on}(+ unique / key_item / placement)
- 레시피 스키마: {id,inputs,output,hint,layer:1}
- place 태그(decor/structure/functional/placement/use/chain/glows)를 placement 서브레코드로 변환.
- 유니크 I14 = unique:true (fusion.gd 촉매 규칙). 게이트 최종물(D223 배치/D225·D232 사용/D230·D235 봉헌)에 usable/placeable 부여.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
FRAG = os.path.join(ROOT, "tools", "l1x_data_fragment.json")

# 화원 데코/구조물은 파스텔 지면(T2A~T2D)+void, 심장은 뿌리결 지면 위. 게이트 배치물은 전용 타일.
GROUND = ["T1", "T2A", "T2B", "T2C", "T2D", "T0"]

# 아이템 플레이버(채집물 8종은 fragment.gathers; 조합물은 fragment.recipes[].flavor 사용)
# 게이트 열쇠 최종물의 usable_on / placeable_on 타깃(레전드 target/kind와 정합)
GATE_ITEM_META = {
    "D223": {"placeable_on": ["T5A"], "placement": {"class": "functional", "on": ["T5A"], "blocks": False}},  # 꽃돌다리 = 색의여울 배치(GA1)
    "D225": {"usable_on": ["wilted_arch"]},   # 개화의 물감 → 시든 아치 사용(GA2)
    "D226": {"placeable_on": GROUND, "placement": {"class": "functional", "on": GROUND, "blocks": False}},  # 붉은 물감 화단 배치
    "D227": {"placeable_on": GROUND, "placement": {"class": "functional", "on": GROUND, "blocks": False}},  # 노란
    "D228": {"placeable_on": GROUND, "placement": {"class": "functional", "on": GROUND, "blocks": False}},  # 푸른
    "D230": {"key_item": True},                # 색의 정수 = GA4 봉헌(무지개 분수) 핵심 아이템
    "D232": {"usable_on": ["root_gate"]},      # 소생의 수액 → 뿌리문 사용(GH1)
    "D235": {"key_item": True},                # 되살아난 심장 = GH2 봉헌(심장 봉인 목)
}
UNIQUE_GATHERS = {"I14"}


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
    gather_flavor = {g["id"]: g for g in frag["gathers"]}
    zone_of = {g["id"]: g["zone"] for g in frag["gathers"]}
    items = []
    # 채집 8종 I10~I17
    for g in frag["gathers"]:
        it = {
            "id": g["id"],
            "name": g["name"],
            "category": "gather",
            "flavor": g["flavor"],
            "placeable_on": [],
            "usable_on": [],
        }
        if g["id"] in UNIQUE_GATHERS:
            it["unique"] = True
            # unique 필드는 name 뒤(스키마상 I9와 동일 위치) — 재정렬
            it = {"id": it["id"], "name": it["name"], "category": "gather",
                  "unique": True, "flavor": it["flavor"],
                  "placeable_on": [], "usable_on": []}
        items.append(it)
    # 조합 33종 D222~D254 (fragment.recipes[].output)
    for r in frag["recipes"]:
        oid = r["output"]
        it = {
            "id": oid,
            "name": r["name"],
            "category": "craft",
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
            "layer": 1,
        })
    return out


def merge(path, key, new_records, id_key="id"):
    d = json.load(open(path, encoding="utf-8"))
    arr = d[key]
    existing = {x[id_key] for x in arr}
    # idempotent: 이미 있으면 교체, 없으면 추가(순서 = 뒤에 append)
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
    # 사후 정합: I14 unique, R33 non-unique, D222~D254 연속
    d = json.load(open(os.path.join(DATA, "items.json"), encoding="utf-8"))
    ids = {x["id"] for x in d["items"]}
    missing = [f"D{n}" for n in range(222, 255) if f"D{n}" not in ids]
    missing += [f"I{n}" for n in range(10, 18) if f"I{n}" not in ids]
    i14 = next((x for x in d["items"] if x["id"] == "I14"), {})
    print("D222~D254·I10~I17 누락:", missing or "NONE")
    print("I14 unique:", i14.get("unique") is True)
    return 0 if not missing and i14.get("unique") is True else 1


if __name__ == "__main__":
    raise SystemExit(main())
