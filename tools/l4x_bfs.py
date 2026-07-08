#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l4x_bfs.py — EX-L4 구역 「부유 서고」 게이트 순서 강제 BFS 증명.

스폰에서 4방향 BFS. 벽 = void(V=갈라진 허공/부유 파편 사이) + '현재 닫힌' 게이트 병목 셀
     + 균열 타일(x, 부적 미소지 기본). 게이트를 공간 순서대로 하나씩 열며 도달 구역 확장 →
각 게이트가 그 앞 게이트를 풀어야만 통과 가능함을 표로 증명(우회 반증 = 순서 건너뛰기 전부 X여야 PASS).

채집/기능 오브젝트 셀은 인접 채집이므로 통과 허용(벽 아님). 게이트 강제는
순수하게 void/게이트 병목/고도차(경사로 접점)로만.
균열 타일 x는 부적 소지 시 통과(지름길) — 지대 단절 없음(severed 0) 별도 검증.

l3x_bfs.py 문법 계승(단일 구역판) + L4 구역1 균열 검증(severed) 추가.

재현: python3 tools/l4x_map_gen.py && python3 tools/l4x_bfs.py
"""
import json
import os
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")


def load(layer):
    rows = [l.rstrip("\n") for l in open(os.path.join(DATA, f"{layer}_map_layout.txt"), encoding="utf-8") if l.strip("\n")]
    legend = json.load(open(os.path.join(DATA, f"{layer}_map_legend.json"), encoding="utf-8"))
    return rows, legend


def wall_syms(legend):
    """벽 = void + (walkable False 이고 게이트도 균열도 아닌 것). 균열 x는 별도 취급."""
    walls = set()
    for sym, t in legend["tiles"].items():
        if isinstance(t, dict) and (t.get("void") or (t.get("walkable") is False and "gate" not in t and not t.get("crack"))):
            walls.add(sym)
    return walls


def crack_syms(legend):
    return {sym for sym, t in legend["tiles"].items() if isinstance(t, dict) and t.get("crack")}


def bfs(rows, walls, blocked, gate_cells, cracks, ward):
    start = None
    for y, r in enumerate(rows):
        x = r.find("S")
        if x >= 0:
            start = (x, y)
    seen = {start}
    dq = deque([start])
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= ny < len(rows) and 0 <= nx < len(rows[ny]):
                if (nx, ny) in seen or (nx, ny) in blocked:
                    continue
                sym = rows[ny][nx]
                if (nx, ny) not in gate_cells:
                    if sym in walls:
                        continue
                    if sym in cracks and not ward:   # 균열은 부적 소지 시에만 통과
                        continue
                seen.add((nx, ny))
                dq.append((nx, ny))
    return seen, start


def cells_of(legend, gate):
    return {(int(c[0]), int(c[1])) for c in legend["gates"][gate].get("cells", [])}


def reach(rows, walls, all_gate_cells, open_gates, legend, cracks, ward=False):
    blocked = set(all_gate_cells)
    open_cells = set()
    for g in open_gates:
        gc = cells_of(legend, g)
        blocked -= gc
        open_cells |= gc
    seen, _ = bfs(rows, walls, blocked, open_cells, cracks, ward)
    return seen


def check_orphans(rows, legend, reachable):
    obj_syms = set(legend.get("objects", {}).keys())
    gate_wall_syms = set()
    for sym, t in legend["tiles"].items():
        if isinstance(t, dict) and t.get("gate") and t.get("walkable") is False:
            gate_wall_syms.add(sym)
    orphans = []
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in obj_syms and ch not in gate_wall_syms and ch not in ("S", "C"):
                if (x, y) in reachable:
                    continue
                adj = any((x + dx, y + dy) in reachable for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if not adj:
                    orphans.append((ch, x, y))
    return orphans


def check_severed(rows, legend, walls, all_gc, gate_order, cracks):
    """균열 타일이 지대를 단절하지 않음: 부적 없이 전 게이트 개방 도달 == 부적 소지 도달(바닥 셀)."""
    no_ward = reach(rows, walls, all_gc, gate_order, legend, cracks, ward=False)
    ward = reach(rows, walls, all_gc, gate_order, legend, cracks, ward=True)
    floor_syms = {sym for sym, t in legend["tiles"].items()
                  if isinstance(t, dict) and not t.get("void") and t.get("walkable") is not False}
    severed = 0
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in floor_syms and (x, y) in ward and (x, y) not in no_ward:
                severed += 1
    return severed, len(no_ward), len(ward)


def audit(layer, gate_order, zone_probes, title):
    rows, legend = load(layer)
    walls = wall_syms(legend)
    cracks = crack_syms(legend)
    all_gc = set()
    for g in gate_order:
        all_gc |= cells_of(legend, g)
    print(f"\n=== {title} ({layer}) — 게이트 순서 강제 (BFS) ===")
    header = "상태\t" + "\t".join(zone_probes.keys())
    print(header)
    rows_out = []
    states = [("초기", [])]
    for i, g in enumerate(gate_order):
        states.append((("+".join(gate_order[:i + 1])), gate_order[:i + 1]))
    for label, opened in states:
        # 부적(GW3)이 열린 상태부터 ward=True(균열/L 통과). 순서 강제는 병목이 담당.
        ward = "GW3" in opened
        seen = reach(rows, walls, all_gc, opened, legend, cracks, ward=ward)
        cells = []
        for name, cell in zone_probes.items():
            cells.append("O" if tuple(cell) in seen else "X")
        print(label + "\t" + "\t".join(cells))
        rows_out.append((label, cells))
    print(f"\n--- 우회 반증 (전부 X여야 순서강제 성립) ---")
    ok = True
    probe_names = list(zone_probes.keys())
    for i, g in enumerate(gate_order):
        # 단일 게이트만 개방(부적은 GW3 단독 시나리오에서만 소지 가정)
        ward = (g == "GW3")
        seen = reach(rows, walls, all_gc, [g], legend, cracks, ward=ward)
        target_name = probe_names[i + 1]
        target_cell = tuple(zone_probes[target_name])
        got = target_cell in seen
        if i == 0:
            verdict = "O(정상: 첫 게이트)" if got else "X(!! 첫 게이트가 안 열림)"
            if not got:
                ok = False
            pred = ["(선행 없음)"]
        else:
            verdict = "X" if not got else "O(!! 우회 성립)"
            pred = gate_order[:i]
            if got:
                ok = False
        print(f"  {g}만 열고(선행 {'+'.join(pred)} 무시) {target_name} 도달? {verdict}")
    seen_all = reach(rows, walls, all_gc, gate_order, legend, cracks, ward=True)
    print(f"\n전 게이트 개방+부적 walkable = {len(seen_all)}칸")
    orphan = check_orphans(rows, legend, seen_all)
    print(f"orphan objects: {'NONE' if not orphan else orphan}")
    severed, nw, wd = check_severed(rows, legend, walls, all_gc, gate_order, cracks)
    print(f"균열이 단절하는 바닥 셀(severed, 0이어야 함): {severed}  (부적無 {nw} / 부적有 {wd})")
    forced = ok and all(rows_out[-1][1][i] == "O" for i in range(len(probe_names)))
    print(f"ORDER-FORCED: {'PASS' if forced else 'FAIL'}")
    return forced and not orphan and severed == 0, len(seen_all)


def main():
    print("========================================================")
    print(" EX-L4 SPATIAL ORDER PROOF — 부유 서고")
    print("========================================================")
    # GW1(부유 서가 다리)→GW2(흐려진 열람 결계)→GW3(금서 봉인 순서 퍼즐 통로문)→GW4(금서고 코어 재봉인)
    # probes: spawn / lower(GW1북) / puzzle(GW2북 퍼즐실) / core-approach(GW3북) / altar(GW4목)
    probes = {
        "spawn": [19, 39],
        "lower(GW1북)": [19, 28],
        "puzzle(GW2북)": [19, 16],
        "core(GW3북)": [19, 5],
        "altar(GW4목)": [19, 3],
    }
    ok, w = audit("l4a", ["GW1", "GW2", "GW3", "GW4"], probes, "부유 서고")

    print("\n========================================================")
    print(f" 부유 서고 : {'PASS' if ok else 'FAIL'}  (walkable {w})")
    print(f" RESULT: {'PASS' if ok else 'FAIL'}")
    print("========================================================")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
