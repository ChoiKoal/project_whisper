#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l5x_map_gen.py — Layer 5 확장(EX-L5) 구역 「침묵의 종탑」 40x40 ASCII 맵 + legend(+height) 생성.

설계 문서: docs/project-whisper-expansion-l5-design-v1.md (Part A).
좌표 규약: (col,row), 좌상단(0,0). row 0 = 북(종탑 정점 = 큰 종 = 재타종/응답 지점, 고도 +2),
          row 39 = 남(대성당 연결 착지 스폰, 고도 0). col 0 = 서.
게이트 강제는 순수하게 void(V=바래 사라진 허공/종탑 층 사이) + 게이트 병목 셀 + 고도차(경사로)로만.
채집/기능 오브젝트는 리스폰되므로 게이트로 쓰지 않는다(인접 reach).

l4x_map_gen.py 문법 계승(rect/put/blank), 테마만 L5 확장 「침묵의 종탑」으로 적응.
종탑 상층 지형(고도 +1~2), 균열 타일(x, 금 간 종석) 통행(부적 소지) L4/L5 재사용.

출력:
  game/data/l5x_map_layout.txt   (EX-L5 침묵의 종탑; l5x = layer5 belfry expansion)
  game/data/l5x_map_legend.json
  game/data/l5x_map_height.txt   (O/H=2, C/Q=1, / 경사로, 그 외 0)

BFS 검증은 l5x_bfs.py 가 이 산출물을 소비.
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
# EX-L5 — 침묵의 종탑 (Silent Belfry) 40x40
#   테마: 대성당(L5 구역1 「응답 없는 대성당」) 위로 이어지는 종탑 상층.
#         신이 마지막으로 목소리를 낸 곳 — 그 뒤로 울리지 않은 종이 걸린 정점.
#         마지막 확장 구역: 엔딩(빛의 문)·진상 조각·"응답" 주제와 직결.
#         종을 다시 울리는 것 = 세계에게 보내는 가장 큰 대답.
#   진입: 남(대성당 대제단 곁 종탑 계단 = 종탑 착지) → 북(종탑 정점의 큰 종).
#   게이트 4종(타입 비반복): GB1 무너진 종탑 계단(배치형 종석 잔교) → GB2 흐려진 종음 결계(사용형)
#                          → GB3 타종 울림 순서(신규 술어 chime_ordered — 성가와 차별: 성가='기억 재현',
#                            타종='울림 조합' 순서로 세 종을 울려 공명을 맞춤)
#                          → GB4 큰 종 재타종(체인형 = 구역 정화 = '응답' + 컷신, 3속성 Whisper 소비)
#   잔재 NPC 1기: 아직도 종을 지키는 종지기의 그림자(bellkeeper_shade).
#   신규 채집 4종: S8 종 파편 / S9 종탑 밧줄 / S10 울림 청동 / S11 잔향 가루.
#   생명 Whisper 재획득처 1(idempotent): 잔향 성수반 V-life(엔딩 Balance 대비, 3속성 완결=생명).
#   신규 유니크 채집: S12 신의 마지막 음(종탑 정점 큰 종, GB4 자기 재타종물).
#
#   고도: 종탑은 통째로 "성당 위 상층". 남 착지(0) → 종실 회랑(+1) → 타종 회랑(+1)
#         → 종탑 정점 큰 종(+2). 고도차(0→+1, +1→+2)를 GB2·GB4가 겸해 강제(구역1/L5 방식 계승).
# ============================================================
def gen_belfry():
    g = blank()
    # --- 남부: 종탑 착지 계단참(진입 지대, 대성당에서 이어진 종탑 하단) row 31..38 (고도 0)
    rect(g, 8, 31, 31, 38, "A")          # 착지 계단참 바닥(상아 포장)
    put(g, 19, 39, "S")                  # 스폰(남, 대성당 대제단 곁 종탑 계단 착지)
    put(g, 19, 38, "A"); put(g, 18, 39, "A"); put(g, 20, 39, "A")
    put(g, 20, 38, "C")                  # 정비대(주종대, 스폰 인접)
    # 착지 계단참 채집: 종 파편 s, 종탑 밧줄 j, 울림 청동 z, 잔향 가루 d
    for (x, y, c) in [(11, 32, "s"), (24, 32, "s"), (13, 35, "j"), (27, 35, "j"),
                      (10, 34, "z"), (28, 33, "z"), (16, 36, "d"), (23, 36, "d"),
                      (14, 33, "j"), (26, 37, "s"), (30, 34, "z"), (9, 36, "s")]:
        put(g, x, y, c)
    put(g, 12, 37, "4")                  # 랜드마크: 첫 걸린 종(튜토리얼 채집)

    # --- GB1 무너진 종탑 계단 (배치형/종석 잔교): 착지 계단참과 종실 회랑 사이가 허공으로 무너짐.
    #     row 29..30 전폭 허공(V), col18-19 종석 잔교 배치 슬롯 g. 좌우 void. 제단 X는 착지측.
    for y in (29, 30):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 29, "g"); put(g, 19, 29, "g")
    put(g, 18, 30, "g"); put(g, 19, 30, "g")
    put(g, 17, 31, "X")                  # 종석 제단(무너진 계단 종석 설치 슬롯, 착지측 인접)

    # --- 중부: 종실 회랑 (보상 포켓 + 채집 밀집 + 생명 재획득처) row 20..28 (고도 +1)
    rect(g, 8, 20, 31, 28, "Q")          # 종실 회랑 바닥(상층, +1)
    put(g, 18, 19, "Q"); put(g, 19, 19, "Q")   # GB2 남 접근 목
    for (x, y, c) in [(10, 22, "s"), (14, 23, "j"), (22, 24, "z"), (26, 23, "s"),
                      (29, 25, "j"), (12, 26, "d"), (20, 27, "s"), (28, 27, "z"),
                      (11, 24, "d"), (24, 26, "j"), (16, 25, "z"), (9, 27, "d")]:
        put(g, x, y, c)
    put(g, 12, 22, "F")                  # 잔향 성수반(생명 Whisper 재획득처, idempotent)
    put(g, 19, 21, "2")                  # 랜드마크: 종탑 정점 큰 종 실루엣(북쪽 시야)
    put(g, 27, 22, "3")                  # 랜드마크: 신의 마지막 기록(진상 조각)
    # 균열 타일 x(금 간 종석, 부적 소지 시 지름길, 지대 단절 아님 — L4/L5 균열 재사용)
    put(g, 15, 25, "x"); put(g, 23, 25, "x")

    # --- GB2 흐려진 종음 결계 (사용형): 응답 잃은 침묵에 종음 결계가 흐려짐. 정음의 물 사용으로 개방.
    #     row 17..18 void 벽, col18-19 결계문 e만 열림(사용 후) + 고도차 0..+1 접점(경사로).
    for y in (17, 18):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 17, "e"); put(g, 19, 17, "e")
    put(g, 18, 18, "/"); put(g, 19, 18, "/")   # 경사로(종실 회랑 +1 진입)
    put(g, 17, 19, "E")        # 종음 결계 본체(사용 대상, 인접)

    # --- 상부: 타종 울림 순서 퍼즐실 (순서 있는 타종 미니퍼즐) row 9..16 (고도 +1)
    rect(g, 8, 9, 31, 16, "C")
    put(g, 18, 8, "C"); put(g, 19, 8, "C")   # GB3 북 접근 목
    # 타종 울림 순서 미니퍼즐: 3개의 종 슬롯(순서 있음! 저→중→고 울림 순서로 타종해야 함)
    #   신규 술어 chime_ordered — 성가(기억 재현)/색맞춤/조각정합/레일전환/봉인순서와 다른 술어.
    #   L5 본편 성가는 '기억해서 재현', 타종은 '울림 조합'(공명 순서) 으로 차별화.
    for (x, y) in [(14, 12), (19, 12), (24, 12)]:
        put(g, x, y, "y")                # 타종 종 슬롯(울림 순서 있음)
    put(g, 19, 10, "N")                  # 잔재 NPC: 종을 지키는 종지기의 그림자(퍼즐실 배회)
    put(g, 21, 11, "5")                  # 랜드마크: 세 울림 종(순서 앵커)
    # 채집 잔여(퍼즐 재료 근처)
    for (x, y, c) in [(11, 14, "s"), (28, 14, "s"), (12, 11, "z"), (27, 11, "z"),
                      (10, 15, "j"), (29, 15, "j"), (16, 15, "d"), (23, 15, "d")]:
        put(g, x, y, c)
    # 균열 타일 x(금 간 종석 지름길, 상부 — 지대 단절 아님)
    put(g, 13, 13, "x"); put(g, 26, 13, "x")

    # --- GB3 종탑 상층문 (타종 울림 순서 퍼즐 결과 게이트): 순서대로 3종 울림 시 개방.
    #     row 6..7 void 벽, col18-19 상층문 L만 열림(퍼즐 성공 후).
    for y in (6, 7):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 6, "L"); put(g, 19, 6, "L")
    put(g, 18, 7, "C"); put(g, 19, 7, "C")

    # --- 최북: 종탑 정점 큰 종(재타종 = 구역 정화 = 응답) row 1..5 (고도 +2)
    rect(g, 12, 1, 27, 5, "O")           # 종탑 정점 바닥(종실 정점, +2)
    put(g, 18, 4, "/"); put(g, 19, 4, "/")   # 경사로(+1→+2 정점 오름, GB4 목 하단)
    put(g, 19, 2, "1")                   # 랜드마크: 종탑 정점 큰 종(정화 지점 = 재타종 봉헌)
    put(g, 19, 3, "H")                   # 타종 목(응답의 타종구 봉헌 = 구역 클리어)
    put(g, 20, 2, "o")                   # 큰 종 오브젝트(유니크 S12 채집원 겸 타종 대상)
    # 정점 주변 희귀 채집(최북)
    for (x, y, c) in [(14, 4, "j"), (24, 4, "j"), (15, 1, "z"), (23, 1, "z"),
                      (13, 3, "s"), (26, 3, "s")]:
        put(g, x, y, c)
    return g


BELFRY_LEGEND = {
    "_comment": "EX-L5 침묵의 종탑 legend. Symbol->(source,object). map_loader 재사용(L5 파서). 게이트 강제=void(바래 사라진 허공)+게이트셀+고도차. 좌표 (col,row).",
    "_coord_note": "row0=북(종탑 정점 큰 종/재타종=응답, +2), row39=남(대성당 연결 착지 스폰, 0). col0=서.",
    "tiles": {
        "A": {"source": 5, "tile_id": "L5T-A", "_note": "종탑 착지 계단참 바닥(상아 포장, 고도 0)"},
        "Q": {"source": 5, "tile_id": "L5T-Q", "_note": "종실 회랑 바닥(상층, 고도 +1)"},
        "C": {"source": 5, "tile_id": "L5T-C", "_note": "타종 울림 회랑 바닥(상층, 고도 +1)"},
        "O": {"source": 5, "tile_id": "L5T-O", "_note": "종탑 정점 큰 종 바닥(정점, 고도 +2)"},
        "V": {"source": 0, "tile_id": "T0", "walkable": False, "void": True, "_note": "바래 사라진 허공/종탑 층 사이"},
        "S": {"source": 5, "tile_id": "L5T-A", "spawn": True},
        "/": {"source": 5, "tile_id": "L5T-ramp", "ramp": True, "_note": "경사로(종실 회랑 +1 진입 / 정점 +2 오름)"},
        "g": {"source": 5, "tile_id": "L5T-A", "gate": "GB1", "walkable": False, "place_slot": "D325", "_note": "GB1 무너진 종탑 계단 종석 잔교 슬롯(허공 위, 종석 설치 후 walkable)"},
        "e": {"source": 5, "tile_id": "L5T-A", "gate": "GB2", "walkable": False, "_note": "흐려진 종음 결계문(정음의 물 사용 후 walkable)"},
        "L": {"source": 5, "tile_id": "L5T-A", "gate": "GB3", "walkable": False, "_note": "종탑 상층문(타종 울림 순서 퍼즐 성공 후 walkable)"},
        "y": {"source": 5, "tile_id": "L5T-A", "place_slot": "CHIME_BELL", "_note": "GB3 타종 종 슬롯(3개, 울림 순서 있음: chime_ordered)"},
        "x": {"source": 5, "tile_id": "L5T-crack", "walkable": False, "crack": True, "_note": "금 간 종석 균열 타일(부적 소지 시 통과 = 지름길/연출, 지대 단절 아님). L4/L5 균열 재사용"},
        "H": {"source": 5, "tile_id": "L5T-O", "gate": "GB4", "_note": "응답의 타종구 봉헌 목(큰 종 재타종 = 구역 클리어)"},
        "N": {"source": 5, "tile_id": "L5T-C"},
        "1": {"source": 5, "tile_id": "L5T-O"},
        "2": {"source": 5, "tile_id": "L5T-Q"},
        "3": {"source": 5, "tile_id": "L5T-Q"},
        "4": {"source": 5, "tile_id": "L5T-A"},
        "5": {"source": 5, "tile_id": "L5T-C"},
        "F": {"source": 5, "tile_id": "L5T-Q", "_note": "잔향 성수반(생명 Whisper 재획득처)"},
        "E": {"source": 5, "tile_id": "L5T-Q", "_note": "흐려진 종음 결계 본체(GB2 사용 대상)"},
        "o": {"source": 5, "tile_id": "L5T-O"},
        "s": {"source": 5, "tile_id": "L5T-A"},
        "j": {"source": 5, "tile_id": "L5T-A"},
        "z": {"source": 5, "tile_id": "L5T-A"},
        "d": {"source": 5, "tile_id": "L5T-A"},
    },
    "objects": {
        "C": {"scene": "workbench.tscn", "object_id": "bell_forge", "_note": "정비대(주종대, L5 crafting station)"},
        "N": {"scene": "npc_remnant.tscn", "object_id": "bellkeeper_shade", "_note": "잔재 NPC: 아직도 종을 지키는 종지기의 그림자(GP-4 NPC 라인)"},
        "E": {"scene": "mana_spring.tscn", "object_id": "chime_ward", "gate": "GB2", "_note": "흐려진 종음 결계(정음의 물 사용 대상)"},
        "H": {"scene": "seal_altar.tscn", "object_id": "great_bell_altar", "gate": "GB4", "_note": "응답의 타종구 봉헌 목(재타종 = 구역 정화)"},
        "F": {"scene": "life_spring.tscn", "object_id": "belfry_reverb_font", "_note": "생명 Whisper 재획득처(idempotent, add_vita)"},
        "o": {"scene": "archive_core.tscn", "object_id": "great_bell", "gatherable": {"item_id": "S12", "unique": True}, "gate": "GB4", "_note": "종탑 정점 큰 종(신의 마지막 음, 유니크)"},
        "s": {"scene": "bell_shard.tscn", "gatherable": {"item_id": "S8"}, "_note": "종 파편"},
        "j": {"scene": "belfry_rope.tscn", "gatherable": {"item_id": "S9"}, "_note": "종탑 밧줄"},
        "z": {"scene": "resonant_bronze.tscn", "gatherable": {"item_id": "S10"}, "_note": "울림 청동"},
        "d": {"scene": "reverb_dust.tscn", "gatherable": {"item_id": "S11"}, "_note": "잔향 가루"},
    },
    "landmarks": {"1": "great_bell", "2": "great_bell_silhouette", "3": "gods_last_record_slab", "4": "tutorial_hung_bell", "5": "three_chime_bells"},
    "gates": {
        "GB1": {"type": "placement", "kind": "bridge", "place_item": "D325",
                "cells": [[18, 29], [19, 29], [18, 30], [19, 30]], "altar": [17, 31]},
        "GB2": {"type": "use", "item": "D327", "target": "chime_ward",
                "cells": [[18, 17], [19, 17]]},
        "GB3": {"type": "placement", "kind": "puzzle", "puzzle": "chime_ordered_3",
                "slot_cells": [[14, 12], [19, 12], [24, 12]],
                "cells": [[18, 6], [19, 6]]},
        "GB4": {"type": "chain", "kind": "offering", "node_id": "great_bell_altar",
                "cells": [[19, 3]], "mount": [19, 3]}
    },
    "special": {
        "bell_forge_cell": [20, 38],
        "reverb_font_cell": [12, 22],
        "_life_note": "잔향 성수반 F = 생명 Whisper 재획득처(idempotent add_vita). GB1 뒤·GB2 앞 회랑 유일 경로에 배치 → 엔딩 Balance(4축) 대비. 최초 생명 획득처(L5 구역1 G2 생명의 샘)의 소진 세이브 안전망. 마지막 확장답게 3속성 완결=생명 재확보처를 종탑에 둠.",
        "entry_from": "cathedral",
        "entry_note": "대성당(l5 구역1) 대제단 곁, 종탑으로 이어지는 계단 → 종탑 착지. 개방 조건 = L5 구역1 정화 완료(대제단 봉헌='응답'/layer5_purified) 후 종탑 계단 활성. 좌표: 대성당 대제단(row0-3 O블록) 곁 → 침묵의 종탑 스폰 S(19,39)."
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
                ht[y][x] = "2"          # 종탑 정점 큰 종(+2)
            elif ch in ("Q", "C", "N", "2", "3", "5", "F", "E", "y") and 8 <= y <= 28:
                ht[y][x] = "1"          # 종탑 상층 회랑(+1): 종실·타종 회랑
            elif ch in ("s", "j", "z", "d") and 8 <= y <= 28:
                ht[y][x] = "1"          # 상층 회랑 채집물(+1)
            elif ch == "x":
                ht[y][x] = "1"          # 균열 타일은 상층 회랑(+1) 안
    return ht


def main():
    m = gen_belfry()
    with open(os.path.join(DATA, "l5x_map_layout.txt"), "w", encoding="utf-8") as f:
        f.write(to_text(m))
    with open(os.path.join(DATA, "l5x_map_legend.json"), "w", encoding="utf-8") as f:
        json.dump(BELFRY_LEGEND, f, ensure_ascii=False, indent=2)
    ht = height_of(m)
    with open(os.path.join(DATA, "l5x_map_height.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join("".join(r) for r in ht) + "\n")
    print("wrote l5x layout+legend+height (침묵의 종탑)")
    assert len(m) == 40 and all(len(r) == 40 for r in m), "dims"
    print("dims OK 40x40")


if __name__ == "__main__":
    main()
