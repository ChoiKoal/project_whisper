#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l3x_bfs.py — EX-L3 구역 「태엽 광산」 게이트 순서 강제 BFS 증명.

스폰에서 4방향 BFS. 벽 = void(V) + 암반(~ 붕락 낙석 협곡) + '현재 닫힌' 게이트 병목 셀.
게이트를 공간 순서대로 하나씩 열며 도달 구역 확장 → 각 게이트가 그 앞 게이트를
풀어야만 통과 가능함을 표로 증명(우회 반증 = 순서 건너뛰기 전부 X여야 PASS).

채집/기능 오브젝트 셀은 인접 채집이므로 통과 허용(벽 아님). 게이트 강제는
순수하게 void/암반/게이트 병목으로만.

l2x_bfs.py 문법 계승(단일 구역판).

재현: python3 tools/l3x_map_gen.py && python3 tools/l3x_bfs.py
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
    walls = set()
    for sym, t in legend["tiles"].items():
        if isinstance(t, dict) and (t.get("void") or (t.get("walkable") is False and "gate" not in t)):
            walls.add(sym)
    return walls


def bfs(rows, walls, blocked, gate_cells):
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
                if (nx, ny) not in gate_cells and rows[ny][nx] in walls:
                    continue
                seen.add((nx, ny))
                dq.append((nx, ny))
    return seen, start


def cells_of(legend, gate):
    return {(int(c[0]), int(c[1])) for c in legend["gates"][gate].get("cells", [])}


def reach(rows, walls, all_gate_cells, open_gates, legend):
    blocked = set(all_gate_cells)
    open_cells = set()
    for g in open_gates:
        gc = cells_of(legend, g)
        blocked -= gc
        open_cells |= gc
    seen, _ = bfs(rows, walls, blocked, open_cells)
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


def audit(layer, gate_order, zone_probes, title):
    rows, legend = load(layer)
    walls = wall_syms(legend)
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
        seen = reach(rows, walls, all_gc, opened, legend)
        cells = []
        for name, cell in zone_probes.items():
            cells.append("O" if tuple(cell) in seen else "X")
        print(label + "\t" + "\t".join(cells))
        rows_out.append((label, cells))
    print(f"\n--- 우회 반증 (전부 X여야 순서강제 성립) ---")
    ok = True
    probe_names = list(zone_probes.keys())
    for i, g in enumerate(gate_order):
        seen = reach(rows, walls, all_gc, [g], legend)
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
    seen_all = reach(rows, walls, all_gc, gate_order, legend)
    print(f"\n전 게이트 개방 walkable = {len(seen_all)}칸")
    orphan = check_orphans(rows, legend, seen_all)
    print(f"orphan objects: {'NONE' if not orphan else orphan}")
    forced = ok and all(rows_out[-1][1][i] == "O" for i in range(len(probe_names)))
    print(f"ORDER-FORCED: {'PASS' if forced else 'FAIL'}")
    return forced and not orphan, len(seen_all)


def main():
    print("========================================================")
    print(" EX-L3 SPATIAL ORDER PROOF — 태엽 광산")
    print("========================================================")
    # GM1(붕락 낙석 협곡)→GM2(막힌 통풍문)→GM3(광차문)→GM4(대굴착기 재점화)
    # probes: spawn / corridor(GM1북) / branch(GM2북 분기실) / deepest(GM3북 갱도) / altar(GM4목)
    probes = {
        "spawn": [19, 39],
        "corridor(GM1북)": [19, 28],
        "branch(GM2북)": [19, 16],
        "deepest(GM3북)": [19, 5],
        "altar(GM4목)": [19, 3],
    }
    ok, w = audit("l3m", ["GM1", "GM2", "GM3", "GM4"], probes, "태엽 광산")

    print("\n========================================================")
    print(f" 태엽 광산 : {'PASS' if ok else 'FAIL'}  (walkable {w})")
    print(f" RESULT: {'PASS' if ok else 'FAIL'}")
    print("========================================================")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
