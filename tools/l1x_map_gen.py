#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l1x_map_gen.py — Layer 1 확장(EX-L1) 구역 2 「고요의 화원」·구역 3 「생명의 심장」
40x40 ASCII 맵 + legend 병렬 생성.

설계 문서: docs/project-whisper-expansion-l1-design-v1.md (Part A).
좌표 규약: (col,row), 좌상단(0,0). row 0 = 북, row 39 = 남. col 0 = 서.
게이트 강제는 순수하게 void(V) + 게이트 병목 셀 + (구역3) 뿌리 도랑(물 R2W)로만.
채집/기능 오브젝트는 리스폰되므로 게이트로 쓰지 않는다(인접 reach).

출력:
  game/data/l1g_map_layout.txt   (구역2 고요의 화원)
  game/data/l1g_map_legend.json
  game/data/l1h_map_layout.txt   (구역3 생명의 심장)
  game/data/l1h_map_legend.json
  game/data/l1h_map_height.txt   (구역3 뿌리 지하감 = -1 개념은 틴트지만, 최심부 이벤트 목만 밴드 기록)

BFS 검증은 l1x_bfs.py 가 이 산출물을 소비.
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
# 구역 2 — 고요의 화원 (Quiet Garden) 40x40
#   테마: 꽃/색. 물감·꽃즙 주역. 신규 채집 3~4종(희귀 꽃/이슬/색 모래/꽃가루).
#   게이트 3개: GA1 색의 여울(배치/디딤돌형 미니퍼즐 후보), GA2 시든 아치(사용형),
#              GA3 색맞춤 화단(배치형 미니 퍼즐 = 3색 배치).
#   잔재 NPC 1기: 색을 잃은 정원사 석상.
#   진입: 남(시작의 숲 북쪽 세계수 구역에서 연결) → 북(신전 안뜰).
# ============================================================
def gen_garden():
    g = blank()
    # --- 남부: 진입 안뜰 (시작의 숲 연결) row 31..38  (구역: courtyard, 고도 0)
    rect(g, 8, 31, 31, 38, "P")          # 화원 안뜰 바닥(꽃잎 포장)
    put(g, 19, 39, "S")                  # 스폰(남 연결점, 시작의 숲 북쪽에서 진입)
    put(g, 19, 38, "P")
    put(g, 18, 39, "P"); put(g, 20, 39, "P")
    put(g, 20, 38, "C")                  # 솥단지(스폰 인접)
    # 안뜰 채집: 희귀 꽃 f, 이슬 d, 색 모래 z, 꽃가루 y
    for (x, y, c) in [(11, 32, "f"), (24, 32, "f"), (13, 35, "f"), (27, 35, "f"),
                      (10, 34, "d"), (28, 33, "d"), (16, 36, "z"), (23, 36, "z"),
                      (14, 33, "y"), (26, 37, "y"), (9, 37, "z"), (30, 32, "d")]:
        put(g, x, y, c)
    put(g, 12, 37, "4")                  # 랜드마크: 첫 꽃 군락(튜토리얼 채집)

    # --- GA1 색의 여울 (배치형/미니퍼즐): 물 여울 R2W 밴드가 길을 끊음, 디딤돌 배치 K로 통과
    #     row 29..30 전폭 물, col18-19에 배치 슬롯 K. 좌우 void.
    rect(g, 8, 29, 31, 30, "~")          # 색의 여울(꽃물 흐르는 얕은 물, walkable=false)
    put(g, 18, 29, "K"); put(g, 19, 29, "K")
    put(g, 18, 30, "K"); put(g, 19, 30, "K")
    # 여울 양옆 void 벽 확정
    for y in (29, 30):
        for x in range(0, 8):
            g[y][x] = "V"
        for x in range(32, 40):
            g[y][x] = "V"

    # --- 중부: 색의 화단 (보상 포켓 + 채집 밀집) row 21..28 (고도 0)
    rect(g, 8, 21, 31, 28, "G")          # 화단 바닥(풀+꽃)
    for (x, y, c) in [(10, 22, "f"), (14, 23, "f"), (18, 22, "f"), (22, 24, "f"),
                      (26, 23, "f"), (29, 25, "f"), (12, 26, "d"), (20, 27, "d"),
                      (28, 27, "d"), (11, 24, "z"), (24, 26, "z"), (16, 25, "y"),
                      (21, 22, "y"), (27, 21, "z"), (9, 26, "y")]:
        put(g, x, y, c)
    put(g, 19, 21, "2")                  # 랜드마크: 정원사 석상 실루엣(북쪽 아치 시야)

    # --- GA2 시든 아치 (사용형): 마른 꽃 아치가 1칸 통로를 막음. 꽃즙/색물 사용→개화.
    #     row 19..20 void 벽, col18-19 아치 A만 열림.
    for y in (19, 20):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 19, "A"); put(g, 19, 19, "A")
    put(g, 18, 20, "P"); put(g, 19, 20, "P")   # 아치 앞 발판

    # --- 상부: 정원사의 안뜰 (미니 퍼즐 존) row 11..18 (고도 0)
    rect(g, 8, 11, 31, 18, "G")
    # 색맞춤 화단 미니퍼즐: 3개의 화단 슬롯(빨/노/파) — 색 조합물 배치
    put(g, 14, 14, "1"); put(g, 19, 14, "2b"[0]); put(g, 24, 14, "1")  # placeholder markers overwritten below
    # 재-배치: 화단 슬롯 3개 = 심볼 'x' (place slot), 정원사 석상 = 'N'
    for (x, y) in [(14, 14), (19, 14), (24, 14)]:
        put(g, x, y, "x")
    put(g, 19, 12, "N")                  # 잔재 NPC: 색을 잃은 정원사 석상
    # 채집 잔여(퍼즐 재료 근처)
    for (x, y, c) in [(11, 16, "f"), (28, 16, "f"), (12, 13, "y"), (27, 13, "y"),
                      (10, 17, "d"), (29, 17, "d"), (16, 17, "z"), (23, 17, "z")]:
        put(g, x, y, c)

    # --- GA3 색의 문 (배치형 미니퍼즐 결과 게이트): 3색 화단 완성 시 개방.
    #     row 9..10 void 벽, col18-19 문 M만 열림(퍼즐 성공 후).
    for y in (9, 10):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 9, "M"); put(g, 19, 9, "M")
    put(g, 18, 10, "G"); put(g, 19, 10, "G")

    # --- 최북: 무지개 신전 안뜰(구역 클리어 = 화원 정화) row 1..8
    rect(g, 12, 1, 27, 8, "B")           # 신전 바닥(색을 되찾는 곳)
    put(g, 19, 3, "1")                   # 랜드마크: 무지개 분수(정화 지점 = 색 봉헌)
    put(g, 19, 4, "H")                   # 봉헌 목(색의 정수 봉헌 = 화원 클리어)
    # 신전 주변 희귀 채집(색의 원천)
    for (x, y, c) in [(14, 6, "z"), (24, 6, "z"), (15, 2, "y"), (23, 2, "y"),
                      (13, 5, "f"), (26, 5, "f")]:
        put(g, x, y, c)
    return g


GARDEN_LEGEND = {
    "_comment": "EX-L1 구역2 고요의 화원 legend. Symbol->(source,object). map_loader 재사용(L1 파서). 게이트 강제=void+게이트셀. 좌표 (col,row).",
    "_coord_note": "row0=북(신전), row39=남(시작의 숲 연결 스폰). col0=서.",
    "tiles": {
        "P": {"source": 2, "tile_id": "T2A", "_note": "꽃잎 포장(안뜰)"},
        "G": {"source": 2, "tile_id": "T2A", "variants": ["T2B", "T2C", "T2D"], "variant_random": True, "_note": "화단 풀"},
        "B": {"source": 2, "tile_id": "T2A", "_note": "신전 바닥(무지개, 리컬러)"},
        "~": {"source": 8, "tile_id": "T5A", "walkable": False, "_note": "색의 여울(꽃물)"},
        "V": {"source": 0, "tile_id": "T0", "walkable": False, "void": True},
        "S": {"source": 2, "tile_id": "T2A", "spawn": True},
        "C": {"source": 2, "tile_id": "T2A"},
        "K": {"source": 8, "tile_id": "T5A", "walkable": False, "gate": "GA1", "place_slot": "D223", "_note": "GA1 디딤돌 배치 슬롯(꽃돌다리)"},
        "A": {"source": 2, "tile_id": "T2A", "gate": "GA2", "walkable": False, "_note": "시든 아치 병목(사용 후 개화 walkable)"},
        "M": {"source": 2, "tile_id": "T2A", "gate": "GA3", "walkable": False, "_note": "색의 문(3색 퍼즐 성공 후 walkable)"},
        "x": {"source": 2, "tile_id": "T2A", "place_slot": "COLOR_BED", "_note": "GA3 색맞춤 화단 슬롯(3개)"},
        "H": {"source": 2, "tile_id": "T2A", "gate": "GA4", "_note": "색의 봉헌 목(화원 클리어)"},
        "N": {"source": 2, "tile_id": "T2A"},
        "1": {"source": 2, "tile_id": "T2A"},
        "2": {"source": 2, "tile_id": "T2A"},
        "4": {"source": 2, "tile_id": "T2A"},
        "f": {"source": 2, "tile_id": "T2A"},
        "d": {"source": 2, "tile_id": "T2A"},
        "z": {"source": 2, "tile_id": "T2A"},
        "y": {"source": 2, "tile_id": "T2A"},
    },
    "objects": {
        "C": {"scene": "cauldron.tscn", "object_id": "cauldron"},
        "N": {"scene": "npc_remnant.tscn", "object_id": "gardener_statue", "_note": "잔재 NPC: 색을 잃은 정원사 석상(GP-4 NPC 라인)"},
        "A": {"scene": "wilted_arch.tscn", "object_id": "wilted_arch", "gate": "GA2"},
        "H": {"scene": "color_font.tscn", "object_id": "rainbow_font", "gate": "GA4"},
        "f": {"scene": "rare_flower.tscn", "gatherable": {"item_id": "I10"}, "variants": ["O1A", "O1B", "O1C", "O1D", "O1E"], "_note": "희귀 꽃"},
        "d": {"scene": "dew.tscn", "gatherable": {"item_id": "I11"}, "_note": "꽃 이슬"},
        "z": {"scene": "color_sand.tscn", "gatherable": {"item_id": "I12"}, "_note": "색 모래"},
        "y": {"scene": "pollen.tscn", "gatherable": {"item_id": "I13"}, "_note": "꽃가루"},
    },
    "landmarks": {"1": "rainbow_font", "2": "gardener_statue_silhouette", "4": "tutorial_flower"},
    "gates": {
        "GA1": {"type": "placement", "kind": "stepping", "place_item": "D223",
                 "cells": [[18, 29], [19, 29], [18, 30], [19, 30]]},
        "GA2": {"type": "use", "item": "I7_or_D224", "target": "wilted_arch",
                 "cells": [[18, 19], [19, 19]]},
        "GA3": {"type": "placement", "kind": "puzzle", "puzzle": "color_bed_3",
                 "slot_cells": [[14, 14], [19, 14], [24, 14]],
                 "cells": [[18, 9], [19, 9]]},
        "GA4": {"type": "chain", "kind": "offering", "node_id": "rainbow_font",
                 "mount": [19, 4]}
    }
}


# ============================================================
# 구역 3 — 생명의 심장 (Heart of Life) 40x40
#   세계수 심부. L1 정화 후 개방되는 후반 구역.
#   세계수 뿌리 지형(지하감=틴트). 생명 Whisper 재획득처(엔딩 3속성 대비).
#   진상 조각 서사(선배 컨스트럭터의 첫 실험 흔적). 게이트 2개 + 최심부 이벤트.
#   잔재 NPC 1기: 첫 컨스트럭터의 잔향(세계수에 얽힘).
#   진입: 남(시작의 숲 세계수에서 뿌리로 하강) → 북(심장 = 최심부).
# ============================================================
def gen_heart():
    g = blank()
    # --- 남부: 뿌리 어귀(진입) row 31..38 (고도 0, 뿌리 지하감 틴트)
    rect(g, 8, 31, 31, 38, "P")          # 뿌리 바닥(나무 결)
    put(g, 19, 39, "S")                  # 스폰(시작의 숲 세계수에서 하강 진입)
    put(g, 19, 38, "P"); put(g, 18, 39, "P"); put(g, 20, 39, "P")
    put(g, 20, 38, "C")                  # 솥단지
    # 뿌리 채집: 뿌리 수액 j, 세계수 씨눈 e, 심장 이끼 q
    for (x, y, c) in [(11, 32, "j"), (24, 32, "j"), (13, 35, "q"), (27, 35, "q"),
                      (10, 34, "e"), (28, 33, "e"), (16, 36, "j"), (23, 36, "q"),
                      (14, 33, "q"), (26, 37, "j"), (30, 34, "e")]:
        put(g, x, y, c)
    put(g, 12, 37, "4")                  # 랜드마크: 첫 뿌리 매듭(튜토리얼)

    # --- GH1 뒤엉킨 뿌리문 (사용형): 뿌리 도랑 물이 길을 끊음 + 마른 뿌리가 병목.
    #     row 29..30 뿌리 도랑(물), col18-19 뿌리문 e만 열림(수액 사용→소생).
    rect(g, 8, 29, 31, 30, "~")          # 뿌리 도랑(생명수 잔재, walkable=false)
    for y in (29, 30):
        for x in range(0, 8):
            g[y][x] = "V"
        for x in range(32, 40):
            g[y][x] = "V"
    put(g, 18, 29, "L"); put(g, 19, 29, "L")   # 뿌리문 병목(게이트 셀)
    put(g, 18, 30, "P"); put(g, 19, 30, "P")

    # --- 중부: 뿌리 회랑 (보상 포켓 + 생명 Whisper 재획득처) row 19..28 (고도 0)
    rect(g, 8, 20, 31, 28, "G")          # 뿌리 회랑 바닥(생명 이끼)
    put(g, 18, 19, "G"); put(g, 19, 19, "G")   # GH2 남 접근 목(회랑→봉인 목 연결)
    for (x, y, c) in [(10, 22, "j"), (14, 23, "e"), (22, 24, "q"), (26, 23, "j"),
                      (29, 25, "e"), (12, 26, "q"), (20, 27, "j"), (28, 27, "q"),
                      (11, 24, "e"), (24, 26, "q"), (16, 25, "j"), (9, 27, "e")]:
        put(g, x, y, c)
    put(g, 12, 22, "E")                  # 생명의 샘물(생명 Whisper 재획득처, idempotent)
    put(g, 19, 21, "2")                  # 랜드마크: 세계수 심장 실루엣
    put(g, 27, 22, "3")                  # 랜드마크: 선배의 첫 실험 흔적(진상 조각)

    # --- GH2 심장 봉인 목 (체인형): 최심부 진입 목. 정화 조합 = 심장 소생.
    #     row 17..18 void 벽, col18-19 봉인 목 H만 열림.
    for y in (17, 18):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 17, "H"); put(g, 19, 17, "H")
    put(g, 18, 18, "G"); put(g, 19, 18, "G")

    # --- 상부: 심장 최심부 (컷신 존) row 1..16 (고도 0, 심부 발광)
    rect(g, 10, 6, 29, 16, "B")          # 최심부 바닥(심장 광장)
    rect(g, 16, 1, 23, 5, "B")           # 심장 코어 방(세계수 심장)
    put(g, 19, 3, "O")                   # 세계수 심장(생명 Whisper 원천 / 컷신 앵커)
    put(g, 20, 3, "O")
    put(g, 19, 8, "1")                   # 랜드마크: 세계수 심장 코어
    # 최심부 채집(생명의 원천)
    for (x, y, c) in [(12, 10, "e"), (27, 10, "e"), (14, 14, "q"), (25, 14, "q"),
                      (11, 13, "j"), (28, 13, "j"), (19, 12, "e"), (22, 9, "q")]:
        put(g, x, y, c)
    # 선배 컨스트럭터의 잔향(NPC) — 심부 코어 근처
    put(g, 15, 8, "N")
    return g


HEART_LEGEND = {
    "_comment": "EX-L1 구역3 생명의 심장 legend. L1 정화 후 개방. 뿌리 지하감=틴트. 생명 Whisper 재획득처 E. 좌표 (col,row).",
    "_coord_note": "row0=북(최심부/세계수 심장), row39=남(시작의 숲 세계수 하강 스폰).",
    "tiles": {
        "P": {"source": 2, "tile_id": "T2A", "_note": "뿌리 바닥(나무결)"},
        "G": {"source": 2, "tile_id": "T2A", "variants": ["T2B", "T2C", "T2D"], "variant_random": True, "_note": "뿌리 회랑(생명 이끼)"},
        "B": {"source": 2, "tile_id": "T2A", "_note": "최심부 바닥(심장 광장, 발광 리컬러)"},
        "~": {"source": 10, "tile_id": "T5M", "walkable": False, "glow": "violet", "_note": "뿌리 도랑(생명수 잔재)"},
        "V": {"source": 0, "tile_id": "T0", "walkable": False, "void": True},
        "S": {"source": 2, "tile_id": "T2A", "spawn": True},
        "C": {"source": 2, "tile_id": "T2A"},
        "L": {"source": 2, "tile_id": "T2A", "gate": "GH1", "walkable": False, "_note": "뒤엉킨 뿌리문(수액 사용 후 walkable)"},
        "H": {"source": 2, "tile_id": "T2A", "gate": "GH2", "walkable": False, "_note": "심장 봉인 목(정화 체인 후 walkable)"},
        "E": {"source": 2, "tile_id": "T2A", "_note": "생명의 샘물(생명 Whisper 재획득처)"},
        "O": {"source": 2, "tile_id": "T2A"},
        "N": {"source": 2, "tile_id": "T2A"},
        "1": {"source": 2, "tile_id": "T2A"},
        "2": {"source": 2, "tile_id": "T2A"},
        "3": {"source": 2, "tile_id": "T2A"},
        "4": {"source": 2, "tile_id": "T2A"},
        "j": {"source": 2, "tile_id": "T2A"},
        "e": {"source": 2, "tile_id": "T2A"},
        "q": {"source": 2, "tile_id": "T2A"},
    },
    "objects": {
        "C": {"scene": "cauldron.tscn", "object_id": "cauldron"},
        "N": {"scene": "npc_remnant.tscn", "object_id": "first_constructor_echo", "_note": "잔재 NPC: 선배 컨스트럭터의 잔향"},
        "E": {"scene": "life_spring.tscn", "object_id": "heart_life_spring", "_note": "생명 Whisper 재획득처(idempotent, add_vita)"},
        "O": {"scene": "world_tree_heart.tscn", "object_id": "tree_heart", "gatherable": {"item_id": "I14", "unique": True}, "gate": "GH2", "_note": "세계수 심장(생명의 정수, 유니크)"},
        "H": {"scene": "heart_seal.tscn", "object_id": "heart_seal", "gate": "GH2"},
        "j": {"scene": "root_sap.tscn", "gatherable": {"item_id": "I15"}, "_note": "뿌리 수액"},
        "e": {"scene": "tree_bud.tscn", "gatherable": {"item_id": "I16"}, "_note": "세계수 씨눈"},
        "q": {"scene": "heart_moss.tscn", "gatherable": {"item_id": "I17"}, "_note": "심장 이끼"},
    },
    "landmarks": {"1": "tree_heart_core", "2": "heart_silhouette", "3": "first_experiment_shard", "4": "tutorial_root"},
    "gates": {
        "GH1": {"type": "use", "item": "D231", "target": "root_gate",
                 "cells": [[18, 29], [19, 29]]},
        "GH2": {"type": "chain", "kind": "purify", "node_id": "heart_seal",
                 "cells": [[18, 17], [19, 17]], "mount": [19, 3]}
    }
}


def main():
    garden = gen_garden()
    heart = gen_heart()
    with open(os.path.join(DATA, "l1g_map_layout.txt"), "w", encoding="utf-8") as f:
        f.write(to_text(garden))
    with open(os.path.join(DATA, "l1g_map_legend.json"), "w", encoding="utf-8") as f:
        json.dump(GARDEN_LEGEND, f, ensure_ascii=False, indent=2)
    with open(os.path.join(DATA, "l1h_map_layout.txt"), "w", encoding="utf-8") as f:
        f.write(to_text(heart))
    with open(os.path.join(DATA, "l1h_map_legend.json"), "w", encoding="utf-8") as f:
        json.dump(HEART_LEGEND, f, ensure_ascii=False, indent=2)
    # 심장 고도(밴드): 전 구역 0(뿌리 지하감은 틴트로만). 최심부만 마커.
    ht = [["0"] * W for _ in range(H)]
    with open(os.path.join(DATA, "l1h_map_height.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join("".join(r) for r in ht) + "\n")
    print("wrote l1g/l1h layout+legend (+l1h height)")
    # quick dims check
    for name, gg in (("garden", garden), ("heart", heart)):
        assert len(gg) == 40 and all(len(r) == 40 for r in gg), name
    print("dims OK 40x40 both")


if __name__ == "__main__":
    main()
