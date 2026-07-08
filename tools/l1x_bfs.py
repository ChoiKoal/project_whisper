#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l1x_bfs.py — EX-L1 구역2(고요의 화원)·구역3(생명의 심장) 게이트 순서 강제 BFS 증명.

각 구역: 스폰에서 4방향 BFS. 벽 = void(V) + 물(~) + '현재 닫힌' 게이트 병목 셀.
게이트를 공간 순서대로 하나씩 열며 도달 구역 확장 → 각 게이트가 그 앞 게이트를
풀어야만 통과 가능함을 표로 증명(우회 반증 = 순서 건너뛰기 전부 X여야 PASS).

채집/기능 오브젝트 셀은 인접 채집이므로 통과 허용(벽 아님). 게이트 강제는
순수하게 void/물/게이트 병목으로만.

재현: python3 tools/l1x_map_gen.py && python3 tools/l1x_bfs.py
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
    # find spawn S
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
                # 게이트 병목 셀은 '열림 상태'(blocked에서 제거됨)면 wall 심볼이어도 통행.
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
    # 열린 게이트 셀만 wall-override 허용(닫힌 것은 blocked에 남아 어차피 차단).
    seen, _ = bfs(rows, walls, blocked, open_cells)
    return seen


def audit(layer, gate_order, zone_probes, title):
    rows, legend = load(layer)
    walls = wall_syms(legend)
    all_gc = set()
    for g in gate_order:
        all_gc |= cells_of(legend, g)
    print(f"\n=== {title} ({layer}) — 게이트 순서 강제 (BFS) ===")
    header = "상태\t" + "\t".join(zone_probes.keys())
    print(header)
    # cumulative open
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
    # 우회 반증: 각 게이트를 그 선행 없이 열었을 때 다음 지대 도달 X 확인
    print(f"\n--- 우회 반증 (전부 X여야 순서강제 성립) ---")
    ok = True
    probe_names = list(zone_probes.keys())
    for i, g in enumerate(gate_order):
        # open only this gate (skip predecessors)
        seen = reach(rows, walls, all_gc, [g], legend)
        # the zone this gate leads into = probe index i+1 (probe[0]=spawn)
        target_name = probe_names[i + 1]
        target_cell = tuple(zone_probes[target_name])
        got = target_cell in seen
        if i == 0:
            # 첫 게이트는 선행이 없음 — 열면 다음 지대 도달이 정상(O 기대).
            verdict = "O(정상: 첫 게이트)" if got else "X(!! 첫 게이트가 안 열림)"
            if not got:
                ok = False
            pred = ["(선행 없음)"]
        else:
            # 선행 게이트를 건너뛰면 도달 불가여야 순서강제 성립(X 기대).
            verdict = "X" if not got else "O(!! 우회 성립)"
            pred = gate_order[:i]
            if got:
                ok = False
        print(f"  {g}만 열고(선행 {'+'.join(pred)} 무시) {target_name} 도달? {verdict}")
    # walkable count (all open)
    seen_all = reach(rows, walls, all_gc, gate_order, legend)
    print(f"\n전 게이트 개방 walkable = {len(seen_all)}칸")
    # orphan objects: every gatherable/functional object cell adjacent to reachable floor
    orphan = check_orphans(rows, legend, seen_all)
    print(f"orphan objects: {'NONE' if not orphan else orphan}")
    forced = ok and all(rows_out[-1][1][i] == "O" for i in range(len(probe_names)))
    print(f"ORDER-FORCED: {'PASS' if forced else 'FAIL'}")
    return forced and not orphan, len(seen_all)


def check_orphans(rows, legend, reachable):
    """채집/기능 오브젝트 심볼 셀이 인접 바닥으로 reach 가능한지."""
    obj_syms = set(legend.get("objects", {}).keys())
    # exclude gate-cell objects that are meant to be walls until opened (A/M/L/H handled as gates)
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


def main():
    print("========================================================")
    print(" EX-L1 SPATIAL ORDER PROOF — 고요의 화원 / 생명의 심장")
    print("========================================================")
    # 구역2 고요의 화원: GA1(색의 여울)→GA2(시든 아치)→GA3(색의 문)→GA4(색 봉헌)
    # probes: spawn / 화단(GA1북) / 안뜰(GA2북) / 퍼즐북(GA3북) / 신전(GA4앞)
    g_probes = {
        "spawn": [19, 39],
        "garden(GA1북)": [19, 28],
        "court(GA2북)": [19, 18],
        "puzzle(GA3북)": [19, 8],
        "shrine(GA4목)": [19, 4],
    }
    ok1, w1 = audit("l1g", ["GA1", "GA2", "GA3", "GA4"], g_probes, "고요의 화원")

    # 구역3 생명의 심장: GH1(뿌리문)→GH2(심장 봉인 목)
    h_probes = {
        "spawn": [19, 39],
        "corridor(GH1북)": [19, 28],
        "core(GH2북)": [19, 16],
    }
    ok2, w2 = audit("l1h", ["GH1", "GH2"], h_probes, "생명의 심장")

    print("\n========================================================")
    print(f" 고요의 화원 : {'PASS' if ok1 else 'FAIL'}  (walkable {w1})")
    print(f" 생명의 심장 : {'PASS' if ok2 else 'FAIL'}  (walkable {w2})")
    print(f" RESULT: {'PASS' if (ok1 and ok2) else 'FAIL'}")
    print("========================================================")
    return 0 if (ok1 and ok2) else 1


if __name__ == "__main__":
    raise SystemExit(main())
