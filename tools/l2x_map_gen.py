#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l2x_map_gen.py — Layer 2 확장(EX-L2) 구역 「지하 데이터 성소」 40x40 ASCII 맵 + legend 생성.

설계 문서: docs/project-whisper-expansion-l2-design-v1.md (Part A).
좌표 규약: (col,row), 좌상단(0,0). row 0 = 북(최심부 코어 사원/마지막 백업), row 39 = 남(터미널 스테이션 하강 스폰). col 0 = 서.
게이트 강제는 순수하게 void(V) + 게이트 병목 셀 + 냉각 침수로(물 ~)로만.
채집/기능 오브젝트는 리스폰되므로 게이트로 쓰지 않는다(인접 reach).

l1x_map_gen.py 문법 계승(rect/put/blank), 테마만 과학 지하 사원으로 적응.

출력:
  game/data/l2s_map_layout.txt   (EX-L2 지하 데이터 성소)
  game/data/l2s_map_legend.json
  game/data/l2s_map_height.txt   (전 셀 0; 지하감은 틴트로만, height 파서 병렬 요구 대비 균일 0)

BFS 검증은 l2x_bfs.py 가 이 산출물을 소비.
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
# EX-L2 — 지하 데이터 성소 (Underground Data Sanctum) 40x40
#   테마: 터미널 스테이션(L2 구역1)의 지하. 마지막 백업이 잠든 서버 사원.
#         정전된 문명의 "기억"을 다루는 챕터(L2 정체성 = 진보→전쟁→폐허의 기록).
#   진입: 남(터미널 스테이션 관제탑 아래 정비 승강로에서 하강) → 북(코어 사원 = 마지막 백업).
#   게이트 4종(타입 비반복): GB1 냉각 침수로(배치형 디딤돌) → GB2 봉인 격벽(사용형)
#                          → GB3 데이터 조각 정합(배치 미니 퍼즐, 신규 술어 data_shard_matched)
#                          → GB4 백업 봉헌(체인형 = 구역 정화 + 컷신)
#   잔재 NPC 1기: 마지막 백업을 지키는 관리 드론(archivist_drone).
#   신규 채집 4종: J8 데이터 결정 / J9 부식 코어 / J10 광섬유 다발 / J11 냉각 젤.
#   에너지 Whisper 재획득처 1(idempotent): 잔류 전력 노드 E (엔딩 대비).
# ============================================================
def gen_sanctum():
    g = blank()
    # --- 남부: 아카이브 어귀(진입 지대, 터미널 스테이션에서 하강) row 31..38 (고도 0, 지하 어둠 틴트)
    rect(g, 8, 31, 31, 38, "P")          # 서버실 바닥(격자 강판, 리컬러)
    put(g, 19, 39, "S")                  # 스폰(남, 터미널 스테이션 정비 승강로 하강)
    put(g, 19, 38, "P"); put(g, 18, 39, "P"); put(g, 20, 39, "P")
    put(g, 20, 38, "C")                  # 정비대(솥단지 등가, 스폰 인접)
    # 어귀 채집: 데이터 결정 h, 부식 코어 k, 광섬유 다발 o, 냉각 젤 g
    for (x, y, c) in [(11, 32, "h"), (24, 32, "h"), (13, 35, "k"), (27, 35, "k"),
                      (10, 34, "o"), (28, 33, "o"), (16, 36, "b"), (23, 36, "b"),
                      (14, 33, "k"), (26, 37, "h"), (30, 34, "o")]:
        put(g, x, y, c)
    put(g, 12, 37, "4")                  # 랜드마크: 첫 서버 랙(튜토리얼 채집)

    # --- GB1 냉각 침수로 (배치형/디딤돌): 냉각수 범람로가 길을 끊음. 방수 디딤돌 배치로 통과.
    #     row 29..30 전폭 물(냉각 침수), col18-19 배치 슬롯 K. 좌우 void.
    rect(g, 8, 29, 31, 30, "~")          # 냉각 침수로(범람한 냉각수, walkable=false)
    for y in (29, 30):
        for x in range(0, 8):
            g[y][x] = "V"
        for x in range(32, 40):
            g[y][x] = "V"
    put(g, 18, 29, "K"); put(g, 19, 29, "K")
    put(g, 18, 30, "P"); put(g, 19, 30, "P")

    # --- 중부: 랙 회랑 (보상 포켓 + 채집 밀집 + 에너지 재획득처) row 20..28 (고도 0)
    rect(g, 8, 20, 31, 28, "G")          # 랙 회랑 바닥(케이블 트레이)
    put(g, 18, 19, "G"); put(g, 19, 19, "G")   # GB2 남 접근 목
    for (x, y, c) in [(10, 22, "h"), (14, 23, "k"), (22, 24, "o"), (26, 23, "h"),
                      (29, 25, "k"), (12, 26, "b"), (20, 27, "h"), (28, 27, "o"),
                      (11, 24, "b"), (24, 26, "k"), (16, 25, "o"), (9, 27, "b")]:
        put(g, x, y, c)
    put(g, 12, 22, "E")                  # 잔류 전력 노드(에너지 Whisper 재획득처, idempotent)
    put(g, 19, 21, "2")                  # 랜드마크: 코어 사원 실루엣(북쪽 시야)
    put(g, 27, 22, "3")                  # 랜드마크: 전쟁 기록 단말(진상 조각)

    # --- GB2 봉인 격벽 (사용형): 정전으로 잠긴 격벽. 급전 키(디코더 젤)로 열림.
    #     row 17..18 void 벽, col18-19 격벽 D만 열림(사용 후).
    for y in (17, 18):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 17, "D"); put(g, 19, 17, "D")
    put(g, 18, 18, "G"); put(g, 19, 18, "G")

    # --- 상부: 정합실 (미니 퍼즐 존) row 9..16 (고도 0)
    rect(g, 8, 9, 31, 16, "G")
    put(g, 18, 8, "G"); put(g, 19, 8, "G")   # GB3 북 접근 목(퍼즐 성공 후 문으로 연결)
    # 데이터 조각 정합 미니퍼즐: 3개의 슬롯(정합 순서 무관, 3조각 다 맞추면 개방)
    for (x, y) in [(14, 12), (19, 12), (24, 12)]:
        put(g, x, y, "x")
    put(g, 19, 10, "N")                  # 잔재 NPC: 관리 드론(정합실 수호)
    # 채집 잔여(퍼즐 재료 근처)
    for (x, y, c) in [(11, 14, "h"), (28, 14, "h"), (12, 11, "o"), (27, 11, "o"),
                      (10, 15, "k"), (29, 15, "k"), (16, 15, "b"), (23, 15, "b")]:
        put(g, x, y, c)

    # --- GB3 데이터 문 (배치형 미니퍼즐 결과 게이트): 3조각 정합 완성 시 개방.
    #     row 6..7 void 벽, col18-19 문 M만 열림(퍼즐 성공 후).
    for y in (6, 7):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 6, "M"); put(g, 19, 6, "M")
    put(g, 18, 7, "G"); put(g, 19, 7, "G")

    # --- 최북: 코어 사원(마지막 백업 = 구역 정화) row 1..5
    rect(g, 12, 1, 27, 5, "B")           # 사원 바닥(발광 리컬러, 백업 코어 광장)
    put(g, 19, 2, "1")                   # 랜드마크: 마지막 백업 코어(정화 지점 = 백업 봉헌)
    put(g, 19, 3, "H")                   # 봉헌 목(복원 코어 봉헌 = 구역 클리어)
    put(g, 20, 2, "O")                   # 백업 코어 오브젝트(유니크 J-정수 채집원 겸 봉헌 대상)
    # 사원 주변 희귀 채집(기억의 원천)
    for (x, y, c) in [(14, 4, "k"), (24, 4, "k"), (15, 1, "o"), (23, 1, "o"),
                      (13, 3, "h"), (26, 3, "h")]:
        put(g, x, y, c)
    return g


SANCTUM_LEGEND = {
    "_comment": "EX-L2 지하 데이터 성소 legend. Symbol->(source,object). map_loader 재사용(L2 파서). 게이트 강제=void+게이트셀+냉각 침수로(물). 좌표 (col,row).",
    "_coord_note": "row0=북(코어 사원/마지막 백업), row39=남(터미널 스테이션 하강 스폰). col0=서.",
    "tiles": {
        "P": {"source": 2, "tile_id": "T2A", "_note": "서버실 격자 강판 바닥(금속 리컬러)"},
        "G": {"source": 2, "tile_id": "T2A", "variants": ["T2B", "T2C", "T2D"], "variant_random": True, "_note": "랙 회랑(케이블 트레이)"},
        "B": {"source": 2, "tile_id": "T2A", "_note": "코어 사원 바닥(백업 광장, 시안 발광 리컬러)"},
        "~": {"source": 8, "tile_id": "T5A", "walkable": False, "_note": "냉각 침수로(범람한 냉각수, GB1 물 밴드)"},
        "V": {"source": 0, "tile_id": "T0", "walkable": False, "void": True},
        "S": {"source": 2, "tile_id": "T2A", "spawn": True},
        "C": {"source": 2, "tile_id": "T2A"},
        "K": {"source": 8, "tile_id": "T5A", "walkable": False, "gate": "GB1", "place_slot": "D256", "_note": "GB1 디딤돌 배치 슬롯(방수 디딤돌)"},
        "D": {"source": 2, "tile_id": "T2A", "gate": "GB2", "walkable": False, "_note": "봉인 격벽(디코더 젤 사용 후 walkable)"},
        "M": {"source": 2, "tile_id": "T2A", "gate": "GB3", "walkable": False, "_note": "데이터 문(3조각 정합 성공 후 walkable)"},
        "x": {"source": 2, "tile_id": "T2A", "place_slot": "DATA_SHARD", "_note": "GB3 데이터 조각 정합 슬롯(3개)"},
        "H": {"source": 2, "tile_id": "T2A", "gate": "GB4", "_note": "백업 봉헌 목(구역 클리어)"},
        "N": {"source": 2, "tile_id": "T2A"},
        "1": {"source": 2, "tile_id": "T2A"},
        "2": {"source": 2, "tile_id": "T2A"},
        "3": {"source": 2, "tile_id": "T2A"},
        "4": {"source": 2, "tile_id": "T2A"},
        "E": {"source": 2, "tile_id": "T2A", "_note": "잔류 전력 노드(에너지 Whisper 재획득처)"},
        "O": {"source": 2, "tile_id": "T2A"},
        "h": {"source": 2, "tile_id": "T2A"},
        "k": {"source": 2, "tile_id": "T2A"},
        "o": {"source": 2, "tile_id": "T2A"},
        "b": {"source": 2, "tile_id": "T2A"},
    },
    "objects": {
        "C": {"scene": "workbench.tscn", "object_id": "workbench", "_note": "정비대(L2 crafting station)"},
        "N": {"scene": "npc_remnant.tscn", "object_id": "archivist_drone", "_note": "잔재 NPC: 마지막 백업을 지키는 관리 드론(GP-4 NPC 라인)"},
        "D": {"scene": "sealed_bulkhead.tscn", "object_id": "sealed_bulkhead", "gate": "GB2"},
        "H": {"scene": "backup_altar.tscn", "object_id": "backup_altar", "gate": "GB4"},
        "E": {"scene": "power_residue.tscn", "object_id": "sanctum_power_residue", "_note": "에너지 Whisper 재획득처(idempotent, add_energy)"},
        "O": {"scene": "backup_core.tscn", "object_id": "backup_core", "gatherable": {"item_id": "J12", "unique": True}, "gate": "GB4", "_note": "마지막 백업 코어(코어 정수, 유니크)"},
        "h": {"scene": "data_crystal.tscn", "gatherable": {"item_id": "J8"}, "_note": "데이터 결정"},
        "k": {"scene": "corroded_core.tscn", "gatherable": {"item_id": "J9"}, "_note": "부식 코어"},
        "o": {"scene": "fiber_bundle.tscn", "gatherable": {"item_id": "J10"}, "_note": "광섬유 다발"},
        "b": {"scene": "coolant_gel.tscn", "gatherable": {"item_id": "J11"}, "_note": "냉각 젤"},
    },
    "landmarks": {"1": "backup_core", "2": "core_sanctum_silhouette", "3": "war_record_terminal", "4": "tutorial_server_rack"},
    "gates": {
        "GB1": {"type": "placement", "kind": "stepping", "place_item": "D256",
                 "cells": [[18, 29], [19, 29]]},
        "GB2": {"type": "use", "item": "D258", "target": "sealed_bulkhead",
                 "cells": [[18, 17], [19, 17]]},
        "GB3": {"type": "placement", "kind": "puzzle", "puzzle": "data_shard_3",
                 "slot_cells": [[14, 12], [19, 12], [24, 12]],
                 "cells": [[18, 6], [19, 6]]},
        "GB4": {"type": "chain", "kind": "offering", "node_id": "backup_altar",
                 "cells": [[19, 3]], "mount": [19, 3]}
    },
    "special": {
        "workbench_cell": [20, 38],
        "power_residue_cell": [12, 22],
        "_energy_note": "잔류 전력 노드 E = 에너지 Whisper 재획득처(idempotent add_energy). GB1 뒤·GB2 앞 회랑 유일 경로에 배치 → 엔딩 Balance 대비, 최초 획득처(L2 구역1 G2 보상)의 소진 세이브 안전망.",
        "entry_from": "terminal_station",
        "entry_note": "터미널 스테이션(l2 구역1) 관제탑 아래 정비 승강로에서 하강. 개방 조건 = L2 구역1 정화 완료(control_core 급전) 후 승강로 활성. 좌표: 터미널 스테이션 관제탑단(row0-3 O블록) 하부 → 성소 스폰 S(19,39)."
    }
}


def main():
    s = gen_sanctum()
    with open(os.path.join(DATA, "l2s_map_layout.txt"), "w", encoding="utf-8") as f:
        f.write(to_text(s))
    with open(os.path.join(DATA, "l2s_map_legend.json"), "w", encoding="utf-8") as f:
        json.dump(SANCTUM_LEGEND, f, ensure_ascii=False, indent=2)
    ht = [["0"] * W for _ in range(H)]
    with open(os.path.join(DATA, "l2s_map_height.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join("".join(r) for r in ht) + "\n")
    print("wrote l2s layout+legend (+l2s height)")
    assert len(s) == 40 and all(len(r) == 40 for r in s), "dims"
    print("dims OK 40x40")


if __name__ == "__main__":
    main()
