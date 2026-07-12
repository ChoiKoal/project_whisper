#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools_spatial_audit.py — 전 레이어(L2~L5) 공간 진행(spatial progression) 감사.

각 레이어에 대해:
  1. layout(txt) + legend(json) 로드, 스폰 셀·게이트 병목 셀·비워커블 타일을 파싱.
  2. 스폰에서 '모든 게이트 닫힘' 상태로 4방향 BFS → 초기 도달 구역.
  3. 게이트를 **공간 통과 순서**(스폰에서 BFS로 처음 닿는 게이트부터)대로 하나씩 열며 구역 확장.
  4. 각 게이트의 열쇠 아이템(gate_controller에서 확인한 매핑)을 recipes.json에서 역추적 →
     재귀적으로 gather 원소(I*/J*/K*/P*/S*)까지 전개.
  5. **그 gather 원소 전부가 '해당 게이트를 열기 직전 구역'에서 소스(≥1개) 도달 가능**한지 검증.
     (소스 = legend objects/tiles의 gatherable item_id 위치. 오브젝트는 인접 채집이므로
      셀 자체 또는 4-이웃 중 하나가 도달 구역이면 확보 가능으로 판정.)

위반(뒤 지대 재료로 앞 게이트를 여는 순환 의존 = softlock)을 전수 출력.

BFS 벽 규칙: void(V) + 물(W, coolant) + '현재 닫힌' 게이트 병목 셀.
오브젝트-only 비워커블 셀(발전기/배전반/관제탑 등)은 스파인 병목이 아니고 인접 채집 대상이라
BFS에서 통과 가능으로 둔다(디자인 §A-2 오브젝트 walkable 규약과 일치). 게이트 강제는 순수하게
void/물/게이트 병목으로만 이뤄진다.
"""

import json
import os
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")

# 게이트 열쇠 아이템 (각 *_gate_controller.gd에서 확인).
# G3 소지형/부적/성가 held-item은 legend gates.item / *_gate_controller const에서 확인.
GATE_KEYS = {
    "l2": {"G1": "D64", "G3": "D65", "G2": "D66", "G4": "D69"},
    "l3": {"G1": "D104", "G2": "D105", "G3": "D108", "G4": "D111"},
    "l4": {"G1": "D141", "G2": "D143", "G3": "D145", "G4": "D148"},
    "l5": {"G1": "D178", "G2": "D180", "G3": "D182", "G4": "D186"},
    # EX-L1 신규 두 구역(고요의 화원 l1g / 생명의 심장 l1h). GA3은 색맞춤 미니 퍼즐 = 3색 물감을
    # 동시에 요구하므로 list-key. GA4/GH2(chain·offering)는 병목 셀이 없어 no_cell_gates로 처리.
    "l1g": {"GA1": "D223", "GA2": "D225", "GA3": ["D226", "D227", "D228"], "GA4": "D230"},
    "l1h": {"GH1": "D232", "GH2": "D235"},
    # EX-L2 신규 구역(지하 데이터 성소 l2s). GB3은 데이터 조각 정합 미니 퍼즐 = 3조각을 동시에
    # 요구하므로 list-key. GB4(chain·offering)는 봉헌 목 H 셀이 있어 keyed 게이트이며 J12(유니크)는
    # self-offering(GB4 자신이 여는 사원에서 채집).
    "l2s": {"GB1": "D256", "GB2": "D258", "GB3": ["D259", "D260", "D261"], "GB4": "D263"},
    # EX-L3 신규 SUB-zone(태엽 광산 l3m). GM3은 레일 전환 미니 퍼즐 = 전환 레버 3개(D282/D283/D284)를
    # 3 슬롯에 동시 배치하므로 list-key(l2s GB3 동형). GM4(chain·offering)는 봉헌 목 H 셀이 있는 keyed
    # 게이트이며 K12(심층 태엽정·유니크)는 self-offering(GM4 자신이 여는 최심부에서 채집).
    "l3m": {"GM1": "D279", "GM2": "D281", "GM3": ["D282", "D283", "D284"], "GM4": "D286"},
    # EX-L4 신규 SUB-zone(부유 서고 l4a). GW3은 금서 봉인 순서 퍼즐 = 봉인 서판 3장(D305/D306/D307)을
    # 3 슬롯에 순서대로 배치하므로 list-key(l3m GM3 동형). GW4(chain·offering)는 봉헌 목 H 셀이 있는
    # keyed 게이트이며 P12(금기 정수·유니크)는 self-offering(GW4 자신이 여는 최심부 코어에서 채집).
    "l4a": {"GW1": "D302", "GW2": "D304", "GW3": ["D305", "D306", "D307"], "GW4": "D309"},
    # EX-L5 신규 SUB-zone(침묵의 종탑 l5b). GB3은 타종 울림 순서 퍼즐 = 울림 종 3종(D328/D329/D330)을
    # 3 슬롯에 순서대로 배치하므로 list-key(l4a GW3 동형). GB4(chain·offering)는 봉헌 목 H 셀(great_bell_altar)
    # 이 있는 keyed 게이트이며 S12(신의 마지막 음·유니크 촉매)는 self-offering(GB4 자신이 여는 종탑 정점
    # 큰 종 o에서 채집). GB4 봉헌 체인 D331(R08)→D332(R09) = S12 유일 소비처(촉매 미소모).
    "l5b": {"GB1": "D325", "GB2": "D327", "GB3": ["D328", "D329", "D330"], "GB4": "D332"},
}
# G2가 추가 소지 재료를 요구하는 경우(예: L3 boiler에 젖은석탄 D106 동시 소지).
GATE_EXTRA_KEYS = {
    "l3": {"G2": ["D106"]},
}

# 구역 진입 전 이미 확보 가능한 '전제(premise)' gather 원소 — 그 구역 legend에 소스가 없어도
# 도달 가능으로 취급한다. EX-L1 두 구역은 시작의 숲을 클리어해야 개방되므로 시작의 숲 gather
# (I1~I9)는 진입 시 이미 확보됨(예: GA1의 돌 I8 — design §A-6 order-safe). I14(유니크)는 이 구역
# 안(세계수 심장 O)에서 채집되므로 premise 아님 — 실제 소스 도달성으로 판정한다.
PREMISE_GATHERS = {
    "l1g": {"I1", "I2", "I3", "I4", "I5", "I6", "I7", "I8", "I9"},
    "l1h": {"I1", "I2", "I3", "I4", "I5", "I6", "I7", "I8", "I9"},
}

# 게이트 '자기 봉헌(self-offering)' 재료 — 그 게이트가 스스로 여는 최종 구역 안에서만 채집되며,
# 오직 그 게이트 자신의 열쇠에만 쓰이는 재료. design §A-6.2 order-safe 규약:
#   시작의 숲 I9(세계수 정수)는 G4(최종 봉헌 목) 자신에게만 쓰이고 G4가 여는 구역에서 채집된다.
#   EX-L1 I14(생명의 정수·유니크)도 동형 — 세계수 심장 O(코어, GH2 통과 후)에서만 채집되고
#   D233→D234→D235(되살아난 심장) = GH2 자신의 봉헌 체인에만 쓰인다.
# 이 재료는 "게이트 통과 전 구역"이 아니라 "게이트가 여는 구역"에서 도달성을 판정한다.
# (검증: I14를 쓰는 레시피는 GH2 열쇠 파생 D233/D234/D235 뿐 — 뒤 게이트 없음 = 데드락 불가.)
# 전제: 해당 게이트가 order상 마지막이어야 함(뒤에 다른 게이트를 막지 않음). audit이 실측한다.
SELF_OFFERING_GATHERS = {
    "l1h": {"GH2": {"I14"}},
    # EX-L2 J12(코어 정수·유니크): 마지막 백업 코어 O(GB4 통과 사원)에서만 채집되고 복원 코어
    # D262→D263 = GB4 자신의 봉헌 체인에만 쓰인다(design §A-6.2). GB4가 마지막 게이트 = 데드락 불가.
    "l2s": {"GB4": {"J12"}},
    # EX-L3 K12(심층 태엽정·유니크): 광차문 너머 최심부 태엽 노심 O(excavator_core, (20,2))에서만
    # 채집되고 D285→D286 = GM4 자신의 봉헌 체인(태엽 노심 봉헌)에만 쓰인다(K12 소비 레시피 = D285 뿐,
    # D285 소비 = D286 뿐). GM4가 최종 게이트 = 데드락 불가. l2s GB4/J12 동형.
    "l3m": {"GM4": {"K12"}},
    # EX-L4 P12(금기 정수·유니크): 금서고 통로 너머 최심부 코어 o(archive_core, (20,2))에서만 채집되고
    # D308→D309 = GW4 자신의 봉헌 체인(금기 봉인구 봉헌)에만 쓰인다. 유니크 촉매 프레임 v1.1:
    # P12는 R08에서 미소모(촉매)이므로 D308 두 개를 P12 1개로 제조 → D309(R09) → GW4. GW4가 최종
    # 게이트 = 데드락 불가. l3m GM4/K12 동형이되 P12는 소모조차 안 됨(존재 판정만).
    "l4a": {"GW4": {"P12"}},
    # EX-L5 S12(신의 마지막 음·유니크): 종탑 정점 큰 종 o((20,2), GB3 상층문 통과 후 정점실)에서만
    # 채집되고 D331(R08=S12+S8)→D332(R09=D331²) = GB4 자신의 봉헌 체인(응답의 타종구)에만 쓰인다.
    # 유니크 촉매 프레임 v1.1(l4a P12 동형): S12는 R08에서 미소모(촉매)이므로 D331 두 개를 S12 1개로
    # 제조 → D332 → GB4. GB4가 최종 게이트 = 데드락 불가. S12 소비 레시피 = R08 뿐, R08 소비 = R09 뿐.
    "l5b": {"GB4": {"S12"}},
}

GATE_CELL_FIELDS = [
    "bridge_cells", "door_cells", "cells", "lift_cells", "neck_cells",
    "crack_cells", "gate_cells",
]


def load_layout(layer):
    path = os.path.join(DATA, f"{layer}_map_layout.txt")
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line == "":
                continue
            rows.append(line)
    return rows


def load_legend(layer):
    with open(os.path.join(DATA, f"{layer}_map_legend.json"), "r", encoding="utf-8") as f:
        return json.load(f)


def load_recipes():
    with open(os.path.join(DATA, "recipes.json"), "r", encoding="utf-8") as f:
        return json.load(f)["recipes"]


def build_recipe_index(recipes):
    idx = {}
    for r in recipes:
        idx.setdefault(r["output"], []).append(r["inputs"])
    return idx


def is_gather(item):
    # gather 원소: 접두 I/J/K/P/S + 숫자. 조합 산출물은 D + 숫자.
    return len(item) >= 2 and item[0] in "IJKPS" and item[1:].isdigit()


def expand_to_gathers(item, recipe_idx, seen=None):
    """item을 재귀적으로 전개해 필요한 gather 원소 집합 반환."""
    if seen is None:
        seen = set()
    if is_gather(item):
        return {item}
    if item in seen:
        return set()
    seen.add(item)
    out = set()
    for inputs in recipe_idx.get(item, []):
        for inp in inputs:
            out |= expand_to_gathers(inp, recipe_idx, seen)
    return out


def non_walkable_tiles(legend):
    """void + 물(coolant/water) 심볼. 게이트 병목이 아닌 오브젝트-only 비워커블은 제외한다."""
    walls = set()
    for sym, t in legend.get("tiles", {}).items():
        if not isinstance(t, dict):
            continue
        if t.get("void"):
            walls.add(sym)
        elif t.get("walkable") is False:
            tid = str(t.get("tile_id", ""))
            # 물/냉각수만 진짜 지형 벽으로 취급. dark-sealed는 게이트 병목이라 별도 토글.
            # 오브젝트-only 비워커블(발전기 e/배전반 K/관제탑 O 등)은 인접 채집 → 통과 허용.
            if "W" in tid or "coolant" in tid.lower() or "water" in tid.lower():
                walls.add(sym)
            # EX-L1 물 밴드 `~`(색의 여울 T5A / 뿌리 도랑 T5M): 게이트 필드가 없는 순수 물 지형 벽.
            # (게이트 병목 셀 K/A/M/L/H 은 `gate` 필드를 달고 있어 여기서 제외되고, all_gate_cells
            #  로 별도 토글된다.)
            elif sym == "~" and not t.get("gate"):
                walls.add(sym)
    return walls


def gate_cells_of(legend):
    """게이트별 병목 셀 목록(Vector2i tuples). ramp('/') 는 워커블이라 제외."""
    out = {}
    for gid, gd in legend.get("gates", {}).items():
        cells = []
        for field in GATE_CELL_FIELDS:
            for c in gd.get(field, []):
                cells.append((int(c[0]), int(c[1])))
        if cells:
            out[gid] = cells
    return out


def gather_sources(layer, layout, legend):
    """item_id -> [cells] 소스 위치. 타일 gather + 오브젝트 gatherable."""
    src = {}
    tile_gather = {}
    for sym, t in legend.get("tiles", {}).items():
        if isinstance(t, dict) and t.get("gather"):
            tile_gather[sym] = t["gather"]
    obj_gather = {}
    for sym, o in legend.get("objects", {}).items():
        if isinstance(o, dict) and isinstance(o.get("gatherable"), dict):
            iid = o["gatherable"].get("item_id")
            if iid:
                obj_gather[sym] = iid
    # L2 parts_box(s) / parts_box_tut(4) 셀 패리티 분기: (x+y)%2==1 → J4, else J2.
    # (map_loader._l2_gather_item_id 와 동일. 초기 스폰·리스폰 rebuild 모두 이 분기 적용.)
    parity_syms = {}
    for sym, o in legend.get("objects", {}).items():
        if isinstance(o, dict) and o.get("l2_id") in ("parts_box", "parts_box_tut"):
            parity_syms[sym] = True
    h = len(layout)
    for y in range(h):
        row = layout[y]
        for x in range(len(row)):
            ch = row[x]
            # object spec takes precedence for the source glyph.
            if ch in parity_syms:
                iid = "J4" if ((x + y) % 2 == 1) else "J2"
                src.setdefault(iid, []).append((x, y))
            elif ch in obj_gather:
                src.setdefault(obj_gather[ch], []).append((x, y))
            elif ch in tile_gather:
                src.setdefault(tile_gather[ch], []).append((x, y))
    return src


def find_spawn(layout, legend):
    spawn_sym = None
    for sym, t in legend.get("tiles", {}).items():
        if isinstance(t, dict) and t.get("spawn"):
            spawn_sym = sym
    for y in range(len(layout)):
        x = layout[y].find(spawn_sym)
        if x >= 0:
            return (x, y)
    return None


def bfs(layout, walls, open_cells, closed_gate_cells):
    """스폰 없이: 도달 집합 계산은 호출부에서 start 지정."""
    raise NotImplementedError


def reachable_from(start, layout, wall_syms, blocked_cells):
    h = len(layout)
    w = max(len(r) for r in layout)
    seen = set()
    if start is None:
        return seen
    dq = deque([start])
    seen.add(start)
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or ny >= h or nx >= len(layout[ny]):
                continue
            if (nx, ny) in seen:
                continue
            if (nx, ny) in blocked_cells:
                continue
            if layout[ny][nx] in wall_syms:
                continue
            seen.add((nx, ny))
            dq.append((nx, ny))
    return seen


def source_reachable(item, sources, region):
    """오브젝트는 인접 채집: 소스 셀 자체 또는 4-이웃이 region 안이면 확보 가능."""
    for (x, y) in sources.get(item, []):
        if (x, y) in region:
            return True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) in region:
                return True
    return False


def _key_items(key_val):
    """게이트 열쇠는 단일 아이템(str) 또는 다중(list, 예: GA3 3색)일 수 있다."""
    return list(key_val) if isinstance(key_val, list) else [key_val]


def audit_layer(layer, recipe_idx):
    layout = load_layout(layer)
    legend = load_legend(layer)
    walls = non_walkable_tiles(legend)
    gcells = gate_cells_of(layer_legend := legend)
    spawn = find_spawn(layout, legend)
    sources = gather_sources(layer, layout, legend)
    keys = GATE_KEYS[layer]
    extra = GATE_EXTRA_KEYS.get(layer, {})
    premise = PREMISE_GATHERS.get(layer, set())
    self_offer = SELF_OFFERING_GATHERS.get(layer, {})

    # 모든 게이트 병목 셀 초기 차단.
    all_gate_cells = set()
    for gid, cells in gcells.items():
        for c in cells:
            all_gate_cells.add(c)

    # 스폰에서 게이트 전부 닫힌 초기 도달 구역.
    region = reachable_from(spawn, layout, walls, all_gate_cells)

    # 공간 통과 순서 결정: 아직 안 연 게이트 중, 현재 region에 병목 셀이 인접한 게이트를 연다.
    opened = set()
    order = []
    violations = []
    remaining = {g: c for g, c in gcells.items() if g in keys}
    # L2 G4처럼 legend gates에 병목 셀이 없는 게이트도 감사 대상: 별도 처리.
    keyed_gates = [g for g in keys if g in gcells]
    # 게이트 셀 없는 키(예: L2 G4)는 맨 마지막 구역으로 취급.
    no_cell_gates = [g for g in keys if g not in gcells]

    blocked = set(all_gate_cells)

    def adjacent_to_region(cells, reg):
        for (x, y) in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) in reg:
                    return True
        return False

    while len(opened) < len(keyed_gates):
        # 다음에 열 게이트 = region에 인접한 미개방 게이트(가장 남쪽=큰 y 우선으로 tie-break).
        candidates = [g for g in keyed_gates if g not in opened
                      and adjacent_to_region(gcells[g], region)]
        if not candidates:
            # region에 인접한 게이트가 없다 → 남은 게이트 중 최남단부터(방어적).
            candidates = [g for g in keyed_gates if g not in opened]
            candidates.sort(key=lambda g: -max(c[1] for c in gcells[g]))
            if not candidates:
                break
        # tie-break: 최남단(큰 y)
        candidates.sort(key=lambda g: -max(c[1] for c in gcells[g]))
        gid = candidates[0]

        # === 이 게이트를 열기 전(region) 상태에서 재료 확보 검증 ===
        need_items = _key_items(keys[gid]) + extra.get(gid, [])
        gathers = set()
        for it in need_items:
            gathers |= expand_to_gathers(it, recipe_idx)

        # 이 게이트가 여는 구역(post-gate region) — self-offering 재료 도달성 판정용.
        post_blocked = set(blocked)
        for c in gcells[gid]:
            post_blocked.discard(c)
        post_region = reachable_from(spawn, layout, walls, post_blocked)
        # 이 게이트가 마지막인가?(뒤에 아직 안 연 keyed 게이트 = 없음) — self-offering 전제.
        is_terminal = all(g in opened or g == gid for g in keyed_gates)

        offer_gg = self_offer.get(gid, set())
        for gg in sorted(gathers):
            if gg in premise:
                continue  # 구역 진입 전 이미 확보(시작의 숲 gather 등) — order-safe.
            if gg in offer_gg:
                # 자기 봉헌 재료(예: I14): '통과 전'이 아니라 '이 게이트가 여는 구역'에서 판정.
                # + 이 게이트가 마지막이어야 함(뒤 게이트를 막지 않음 = 데드락 불가).
                if not is_terminal:
                    violations.append({
                        "layer": layer, "gate": gid, "key": keys[gid],
                        "missing_gather": gg,
                        "detail": f"{gg}(self-offering)인데 {gid}가 최종 게이트 아님 → 뒤 게이트 위험",
                    })
                elif not source_reachable(gg, sources, post_region):
                    violations.append({
                        "layer": layer, "gate": gid, "key": keys[gid],
                        "missing_gather": gg,
                        "detail": f"{gg} 소스가 {gid} 개방 구역에도 없음(자기 봉헌 채집 불가)",
                    })
                continue
            if not source_reachable(gg, sources, region):
                violations.append({
                    "layer": layer, "gate": gid, "key": keys[gid],
                    "missing_gather": gg,
                    "detail": f"{gg} 소스가 {gid} 도달 전 구역에 없음(뒤-지대 의존=softlock)",
                })

        # 게이트 열고 region 확장.
        opened.add(gid)
        order.append(gid)
        blocked = post_blocked
        region = post_region

    # 셀 없는 게이트(L2 G4 등): 전 게이트 개방 후 region에서 검증.
    for gid in no_cell_gates:
        need_items = _key_items(keys[gid]) + extra.get(gid, [])
        gathers = set()
        for it in need_items:
            gathers |= expand_to_gathers(it, recipe_idx)
        for gg in sorted(gathers):
            if gg in premise:
                continue
            if not source_reachable(gg, sources, region):
                violations.append({
                    "layer": layer, "gate": gid, "key": keys[gid],
                    "missing_gather": gg,
                    "detail": f"{gg} 소스가 최종 구역에도 없음",
                })
        order.append(gid)

    return {
        "layer": layer, "spawn": spawn, "order": order,
        "gate_keys": {g: keys[g] for g in keys},
        "violations": violations,
        "source_counts": {k: len(v) for k, v in sorted(sources.items())},
    }


def main():
    recipes = load_recipes()
    recipe_idx = build_recipe_index(recipes)
    total_viol = 0
    print("=== SPATIAL PROGRESSION AUDIT (EX-L1 + EX-L2 + EX-L3 + EX-L4 + EX-L5 + L2~L5) ===")
    for layer in ["l1g", "l1h", "l2s", "l3m", "l4a", "l5b", "l2", "l3", "l4", "l5"]:
        res = audit_layer(layer, recipe_idx)
        print(f"\n--- {layer.upper()} ---")
        print(f"  spawn={res['spawn']}  gate open order(공간 순서)={res['order']}")
        print(f"  gate keys={res['gate_keys']}")
        print(f"  gather source counts={res['source_counts']}")
        if res["violations"]:
            print(f"  !! VIOLATIONS ({len(res['violations'])}):")
            for v in res["violations"]:
                print(f"     [{v['gate']} key={v['key']}] MISSING {v['missing_gather']}: {v['detail']}")
        else:
            print("  OK — 모든 게이트 재료가 게이트 앞 구역에서 확보 가능(softlock 없음).")
        total_viol += len(res["violations"])
    print(f"\n=== TOTAL VIOLATIONS: {total_viol} ===")
    return 1 if total_viol else 0


if __name__ == "__main__":
    sys.exit(main())
