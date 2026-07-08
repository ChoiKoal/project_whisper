#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l4x_map_gen.py — Layer 4 확장(EX-L4) 구역 「부유 서고」 40x40 ASCII 맵 + legend(+height) 생성.

설계 문서: docs/project-whisper-expansion-l4-design-v1.md (Part A).
좌표 규약: (col,row), 좌상단(0,0). row 0 = 북(최심부 금서고 코어 = 재봉인 지점, 고도 +2),
          row 39 = 남(마탑 연결 착지 스폰, 고도 0). col 0 = 서.
게이트 강제는 순수하게 void(V=갈라진 허공/부유 파편 사이) + 게이트 병목 셀 + 고도차(경사로)로만.
채집/기능 오브젝트는 리스폰되므로 게이트로 쓰지 않는다(인접 reach).

l3x_map_gen.py 문법 계승(rect/put/blank), 테마만 L4 구역2 「부유 서고」로 적응.
부유 파편 지형 극대화(고도 +1~2), 균열 타일(x) 통행(부적 소지) L4 구역1 재사용.

출력:
  game/data/l4a_map_layout.txt   (EX-L4 부유 서고; l4a = layer4 archive)
  game/data/l4a_map_legend.json
  game/data/l4a_map_height.txt   (O/H=2, M=1, / 경사로, 그 외 0)

BFS 검증은 l4x_bfs.py 가 이 산출물을 소비.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "game", "data")
W = H = 40


def blank():
    return [["V"] * W for _ in range(H)]


def rect(g, x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch


def put(g, x, y, ch):
    g[y][x] = ch


def to_text(g):
    return "\n".join("".join(r) for r in g) + "\n"


# ============================================================
# EX-L4 — 부유 서고 (Floating Archive) 40x40
#   테마: 마탑(L4 구역1 「봉인이 풀린 마탑」)에서 찢겨나가 공중에 흩어진 금서고.
#         금기가 기록된 책들이 떠다니는 곳 — "힘의 극한"이 무엇을 열람했는지 드러나는 챕터.
#         부유 파편 지형(고도 +1~2 극대화), 균열 통행 재사용.
#   진입: 남(마탑 최심부 봉인실 곁 찢긴 서고 통로 = 부유 파편 착지) → 북(최심부 금서고 코어).
#   게이트 4종(타입 비반복): GW1 부유 서가 다리(배치형 룬 잔교) → GW2 흐려진 열람 결계(사용형)
#                          → GW3 금서 봉인 순서 미니퍼즐(신규 술어 seal_ordered)
#                          → GW4 금서고 코어 재봉인(체인형 = 구역 정화 + 컷신, 마력 소비)
#   잔재 NPC 1기: 아직도 책을 정리하는 사서 잔영(archivist_shade).
#   신규 채집 4종: P8 금서 조각 / P9 서고 룬판 / P10 열람 촛농 / P11 별지 잉크.
#   마력 Whisper 재획득처 1(idempotent): 잔류 열람 결계정 W (엔딩 Balance 대비).
#   신규 유니크 채집: P12 금기 정수(금서고 코어, GW4 자기 봉헌물).
#
#   고도: 부유 서고는 통째로 "떠 있는 땅". 남 착지(0) → 하부 서가(+1) → 상부 서가(+1)
#         → 최심부 코어(+2). 고도차(0→+1, +1→+2)를 GW2·GW4가 겸해 강제(구역1 방식 계승).
# ============================================================
def gen_archive():
    g = blank()
    # --- 남부: 착지 서가(진입 지대, 마탑에서 찢겨 온 부유 파편) row 31..38 (고도 0)
    rect(g, 8, 31, 31, 38, "A")          # 착지 서가 바닥(자수정 포장)
    put(g, 19, 39, "S")                  # 스폰(남, 마탑 최심부 곁 찢긴 통로 착지)
    put(g, 19, 38, "A"); put(g, 18, 39, "A"); put(g, 20, 39, "A")
    put(g, 20, 38, "C")                  # 정비대(제본대, 스폰 인접)
    # 착지 서가 채집: 금서 조각 q, 서고 룬판 r, 열람 촛농 c, 별지 잉크 i
    for (x, y, c) in [(11, 32, "q"), (24, 32, "q"), (13, 35, "r"), (27, 35, "r"),
                      (10, 34, "c"), (28, 33, "c"), (16, 36, "i"), (23, 36, "i"),
                      (14, 33, "r"), (26, 37, "q"), (30, 34, "c"), (9, 36, "q")]:
        put(g, x, y, c)
    put(g, 12, 37, "4")                  # 랜드마크: 첫 떠도는 금서(튜토리얼 채집)

    # --- GW1 부유 서가 다리 (배치형/룬 잔교): 착지 서가와 하부 서가 사이가 허공으로 갈라짐.
    #     row 29..30 전폭 허공(V), col18-19 룬 잔교 배치 슬롯 g. 좌우 void. 제단 X는 착지측.
    for y in (29, 30):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 29, "g"); put(g, 19, 29, "g")
    put(g, 18, 30, "g"); put(g, 19, 30, "g")
    put(g, 17, 31, "X")                  # 룬 제단(부유 서가 다리석 설치 슬롯, 착지측 인접)

    # --- 중부: 하부 서가 회랑 (보상 포켓 + 채집 밀집 + 마력 재획득처) row 20..28 (고도 +1)
    rect(g, 8, 20, 31, 28, "M")          # 하부 서가 바닥(부유 파편, +1)
    put(g, 18, 19, "M"); put(g, 19, 19, "M")   # GW2 남 접근 목
    for (x, y, c) in [(10, 22, "q"), (14, 23, "r"), (22, 24, "c"), (26, 23, "q"),
                      (29, 25, "r"), (12, 26, "i"), (20, 27, "q"), (28, 27, "c"),
                      (11, 24, "i"), (24, 26, "r"), (16, 25, "c"), (9, 27, "i")]:
        put(g, x, y, c)
    put(g, 12, 22, "W")                  # 잔류 열람 결계정(마력 Whisper 재획득처, idempotent)
    put(g, 19, 21, "2")                  # 랜드마크: 최심부 금서고 코어 실루엣(북쪽 시야)
    put(g, 27, 22, "3")                  # 랜드마크: 금기 열람 기록판(진상 조각)
    # 균열 타일 x(부적 소지 시 지름길, 지대 단절 아님 — 구역1 균열 재사용)
    put(g, 15, 25, "x"); put(g, 23, 25, "x")

    # --- GW2 흐려진 열람 결계 (사용형): 풀려난 금기 기운에 결계가 흐려짐. 정화의 물 사용으로 개방.
    #     row 17..18 void 벽, col18-19 결계문 v만 열림(사용 후) + 고도차 0..+1 접점(경사로).
    for y in (17, 18):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 17, "v"); put(g, 19, 17, "v")
    put(g, 18, 18, "/"); put(g, 19, 18, "/")   # 경사로(하부 서가 +1 진입)
    put(g, 17, 19, "E")        # 마력샘/열람 결계 본체(사용 대상, 인접)

    # --- 상부: 금서 봉인 순서 퍼즐실 (순서 있는 봉인 미니퍼즐) row 9..16 (고도 +1)
    rect(g, 8, 9, 31, 16, "M")
    put(g, 18, 8, "M"); put(g, 19, 8, "M")   # GW3 북 접근 목
    # 금서 봉인 순서 미니퍼즐: 3개의 봉인 서판 슬롯(순서 있음! 1→2→3 순서로 봉인해야 함)
    #   신규 술어 seal_ordered — 색맞춤/조각정합/레일전환과 다른 술어(순서 강제).
    for (x, y) in [(14, 12), (19, 12), (24, 12)]:
        put(g, x, y, "z")                # 봉인 서판 슬롯(순서 있음)
    put(g, 19, 10, "N")                  # 잔재 NPC: 책 정리하는 사서 잔영(퍼즐실 배회)
    put(g, 21, 11, "5")                  # 랜드마크: 거대 금서 서가(순서 앵커)
    # 채집 잔여(퍼즐 재료 근처)
    for (x, y, c) in [(11, 14, "q"), (28, 14, "q"), (12, 11, "c"), (27, 11, "c"),
                      (10, 15, "r"), (29, 15, "r"), (16, 15, "i"), (23, 15, "i")]:
        put(g, x, y, c)
    # 균열 타일 x(부적 소지 지름길, 상부 — 지대 단절 아님)
    put(g, 13, 13, "x"); put(g, 26, 13, "x")

    # --- GW3 금서고 통로문 (봉인 순서 퍼즐 결과 게이트): 순서대로 3서판 봉인 시 개방.
    #     row 6..7 void 벽, col18-19 통로문 L만 열림(퍼즐 성공 후).
    for y in (6, 7):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 6, "L"); put(g, 19, 6, "L")
    put(g, 18, 7, "M"); put(g, 19, 7, "M")

    # --- 최북: 최심부 금서고 코어(재봉인 = 구역 정화) row 1..5 (고도 +2)
    rect(g, 12, 1, 27, 5, "O")           # 금서고 코어 바닥(봉인실, +2)
    put(g, 18, 4, "/"); put(g, 19, 4, "/")   # 경사로(+1→+2 코어 오름, GW4 목 하단)
    put(g, 19, 2, "1")                   # 랜드마크: 최심부 금서고 코어(정화 지점 = 재봉인 봉헌)
    put(g, 19, 3, "H")                   # 봉인 목(금기 봉인구 봉헌 = 구역 클리어)
    put(g, 20, 2, "o")                   # 금서고 코어 오브젝트(유니크 P12 채집원 겸 봉헌 대상)
    # 코어 주변 희귀 채집(최심부)
    for (x, y, c) in [(14, 4, "r"), (24, 4, "r"), (15, 1, "c"), (23, 1, "c"),
                      (13, 3, "q"), (26, 3, "q")]:
        put(g, x, y, c)
    return g


ARCHIVE_LEGEND = {
    "_comment": "EX-L4 부유 서고 legend. Symbol->(source,object). map_loader 재사용(L4 파서). 게이트 강제=void(갈라진 허공)+게이트셀+고도차. 좌표 (col,row).",
    "_coord_note": "row0=북(최심부 금서고 코어/재봉인, +2), row39=남(마탑 연결 착지 스폰, 0). col0=서.",
    "tiles": {
        "A": {"source": 4, "tile_id": "L4T-A", "_note": "착지 서가 바닥(자수정 포장, 고도 0)"},
        "M": {"source": 4, "tile_id": "L4T-M", "_note": "부유 서가 파편 바닥(떠 있는 땅, 고도 +1)"},
        "O": {"source": 4, "tile_id": "L4T-O", "_note": "최심부 금서고 코어 바닥(봉인실, 고도 +2)"},
        "V": {"source": 0, "tile_id": "T0", "walkable": False, "void": True, "_note": "갈라진 허공/부유 파편 사이"},
        "S": {"source": 4, "tile_id": "L4T-A", "spawn": True},
        "C": {"source": 4, "tile_id": "L4T-A"},
        "/": {"source": 4, "tile_id": "L4T-ramp", "ramp": True, "_note": "경사로(부유 파편 +1 진입 / 코어 +2 오름)"},
        "g": {"source": 4, "tile_id": "L4T-A", "gate": "GW1", "walkable": False, "place_slot": "D302", "_note": "GW1 부유 서가 다리 잔교 슬롯(허공 위, 다리석 설치 후 walkable)"},
        "v": {"source": 4, "tile_id": "L4T-A", "gate": "GW2", "walkable": False, "_note": "흐려진 열람 결계문(정화의 물 사용 후 walkable)"},
        "L": {"source": 4, "tile_id": "L4T-A", "gate": "GW3", "walkable": False, "_note": "금서고 통로문(봉인 순서 퍼즐 성공 후 walkable)"},
        "z": {"source": 4, "tile_id": "L4T-A", "place_slot": "SEAL_TABLET", "_note": "GW3 금서 봉인 서판 슬롯(3개, 순서 있음: seal_ordered)"},
        "x": {"source": 4, "tile_id": "L4T-crack", "walkable": False, "crack": True, "_note": "균열 타일(부적 소지 시 통과 = 지름길/연출, 지대 단절 아님). L4 구역1 균열 재사용"},
        "H": {"source": 4, "tile_id": "L4T-O", "gate": "GW4", "_note": "금기 봉인구 봉헌 목(구역 클리어)"},
        "N": {"source": 4, "tile_id": "L4T-M"},
        "1": {"source": 4, "tile_id": "L4T-O"},
        "2": {"source": 4, "tile_id": "L4T-M"},
        "3": {"source": 4, "tile_id": "L4T-M"},
        "4": {"source": 4, "tile_id": "L4T-A"},
        "5": {"source": 4, "tile_id": "L4T-M"},
        "W": {"source": 4, "tile_id": "L4T-M", "_note": "잔류 열람 결계정(마력 Whisper 재획득처)"},
        "E": {"source": 4, "tile_id": "L4T-M", "_note": "흐려진 열람 결계 본체(GW2 사용 대상)"},
        "o": {"source": 4, "tile_id": "L4T-O"},
        "q": {"source": 4, "tile_id": "L4T-A"},
        "r": {"source": 4, "tile_id": "L4T-A"},
        "c": {"source": 4, "tile_id": "L4T-A"},
        "i": {"source": 4, "tile_id": "L4T-A"},
    },
    "objects": {
        "C": {"scene": "workbench.tscn", "object_id": "bindery", "_note": "정비대(제본대, L4 crafting station)"},
        "N": {"scene": "npc_remnant.tscn", "object_id": "archivist_shade", "_note": "잔재 NPC: 아직도 책을 정리하는 사서 잔영(GP-4 NPC 라인)"},
        "E": {"scene": "mana_spring.tscn", "object_id": "reading_ward", "gate": "GW2", "_note": "흐려진 열람 결계(정화의 물 사용 대상)"},
        "H": {"scene": "seal_altar.tscn", "object_id": "archive_core_altar", "gate": "GW4", "_note": "금기 봉인구 봉헌 목(재봉인 = 구역 정화)"},
        "W": {"scene": "mana_residue.tscn", "object_id": "archive_residual_ward", "_note": "마력 Whisper 재획득처(idempotent, add_mana)"},
        "o": {"scene": "archive_core.tscn", "object_id": "archive_core", "gatherable": {"item_id": "P12", "unique": True}, "gate": "GW4", "_note": "최심부 금서고 코어(금기 정수, 유니크)"},
        "q": {"scene": "forbidden_page.tscn", "gatherable": {"item_id": "P8"}, "_note": "금서 조각"},
        "r": {"scene": "archive_rune_slab.tscn", "gatherable": {"item_id": "P9"}, "_note": "서고 룬판"},
        "c": {"scene": "reading_wax.tscn", "gatherable": {"item_id": "P10"}, "_note": "열람 촛농"},
        "i": {"scene": "starpage_ink.tscn", "gatherable": {"item_id": "P11"}, "_note": "별지 잉크"},
    },
    "landmarks": {"1": "archive_core", "2": "archive_core_silhouette", "3": "forbidden_log_slab", "4": "tutorial_drifting_book", "5": "great_forbidden_shelf"},
    "gates": {
        "GW1": {"type": "placement", "kind": "bridge", "place_item": "D302",
                "cells": [[18, 29], [19, 29], [18, 30], [19, 30]], "altar": [17, 31]},
        "GW2": {"type": "use", "item": "D304", "target": "reading_ward",
                "cells": [[18, 17], [19, 17]]},
        "GW3": {"type": "placement", "kind": "puzzle", "puzzle": "seal_ordered_3",
                "slot_cells": [[14, 12], [19, 12], [24, 12]],
                "cells": [[18, 6], [19, 6]]},
        "GW4": {"type": "chain", "kind": "offering", "node_id": "archive_core_altar",
                "cells": [[19, 3]], "mount": [19, 3]}
    },
    "special": {
        "bindery_cell": [20, 38],
        "mana_residue_cell": [12, 22],
        "_mana_note": "잔류 열람 결계정 W = 마력 Whisper 재획득처(idempotent add_mana). GW1 뒤·GW2 앞 회랑 유일 경로에 배치 → 엔딩 Balance(4축) 대비. 최초 획득처(L4 구역1 G2 마력샘 재정화)의 소진 세이브 안전망.",
        "entry_from": "sealed_tower",
        "entry_note": "마탑(l4 구역1) 최심부 봉인실 곁, 봉인이 풀릴 때 찢겨 나간 서고 통로 → 부유 파편 착지. 개방 조건 = L4 구역1 정화 완료(최심부 봉인 재구축/seal_core_restored) 후 통로 활성. 좌표: 마탑 최심부(row0-3 O블록) 곁 → 부유 서고 스폰 S(19,39)."
    }
}


def height_of(g):
    ht = [["0"] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            ch = g[y][x]
            if ch == "/":
                ht[y][x] = "/"
            elif ch in ("O", "H", "1", "o") and 0 <= y <= 5:
                ht[y][x] = "2"          # 최심부 금서고 코어(+2)
            elif ch in ("M", "N", "2", "3", "5", "W", "E", "z") and 8 <= y <= 28:
                ht[y][x] = "1"          # 부유 서가 파편(+1): 하부·상부 서가
            elif ch in ("q", "r", "c", "i") and 8 <= y <= 28:
                ht[y][x] = "1"          # 부유 서가 채집물(+1)
            elif ch == "x":
                ht[y][x] = "1"          # 균열 타일은 부유 서가(+1) 안
    return ht


def main():
    m = gen_archive()
    with open(os.path.join(DATA, "l4a_map_layout.txt"), "w", encoding="utf-8") as f:
        f.write(to_text(m))
    with open(os.path.join(DATA, "l4a_map_legend.json"), "w", encoding="utf-8") as f:
        json.dump(ARCHIVE_LEGEND, f, ensure_ascii=False, indent=2)
    ht = height_of(m)
    with open(os.path.join(DATA, "l4a_map_height.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join("".join(r) for r in ht) + "\n")
    print("wrote l4a layout+legend+height (부유 서고)")
    assert len(m) == 40 and all(len(r) == 40 for r in m), "dims"
    print("dims OK 40x40")


if __name__ == "__main__":
    main()
