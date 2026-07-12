#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
l3x_map_gen.py — Layer 3 확장(EX-L3) 구역 「태엽 광산」 40x40 ASCII 맵 + legend 생성.

설계 문서: docs/project-whisper-expansion-l3-design-v1.md (Part A).
좌표 규약: (col,row), 좌상단(0,0). row 0 = 북(최심부 마지막 갱도/멈춘 대굴착기), row 39 = 남(시계탑 도시 하강 스폰). col 0 = 서.
게이트 강제는 순수하게 void(V) + 게이트 병목 셀 + 붕락 낙석 협곡(암반 ~)으로만.
채집/기능 오브젝트는 리스폰되므로 게이트로 쓰지 않는다(인접 reach).

l2x_map_gen.py 문법 계승(rect/put/blank), 테마만 기계 지하 광산으로 적응.

출력:
  game/data/l3m_map_layout.txt   (EX-L3 태엽 광산)
  game/data/l3m_map_legend.json
  game/data/l3m_map_height.txt   (전 셀 0; 지하감은 틴트로만, height 파서 병렬 요구 대비 균일 0)

BFS 검증은 l3x_bfs.py 가 이 산출물을 소비.
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
# EX-L3 — 태엽 광산 (Clockwork Mine) 40x40
#   테마: 시계탑 도시(L3 구역1 「태엽이 멈춘 도시」)의 지하 광산.
#         도시를 감던 태엽의 원천 = 에너지 고갈의 근원지. 멈춘 굴착 기계들, 마지막 갱도.
#   진입: 남(대시계 광장 아래 낡은 광차 승강로에서 하강) → 북(최심부 갱도 = 대굴착기 코어).
#   게이트 4종(타입 비반복): GM1 붕락 낙석 협곡(배치형 궤도판) → GM2 막힌 통풍문(사용형)
#                          → GM3 광차 레일 전환(전환 미니 퍼즐, 신규 술어 rail_routed)
#                          → GM4 대굴착기 재점화(체인형 = 구역 정화 + 컷신)
#   잔재 NPC 1기: 갱도에 갇힌 줄 모르는 굴착 로봇(digger_bot).
#   신규 채집 4종: K8 태엽 광석 / K9 녹슨 톱니축 / K10 갱도 석탄 / K11 응결 수정.
#   에너지 Whisper 재획득처 1(idempotent): 잔류 태엽 발전기 E (엔딩 대비).
#   신규 유니크 채집: K12 심층 태엽정(대굴착기 코어, GM4 자기 봉헌물).
# ============================================================
def gen_mine():
    g = blank()
    # --- 남부: 갱구 광장(진입 지대, 대시계 광장에서 하강) row 31..38 (고도 0, 지하 광산 틴트)
    rect(g, 8, 31, 31, 38, "P")          # 갱구 바닥(황동 격자 강판, 리컬러)
    put(g, 19, 39, "S")                  # 스폰(남, 대시계 광장 광차 승강로 하강)
    put(g, 19, 38, "P"); put(g, 18, 39, "P"); put(g, 20, 39, "P")
    put(g, 20, 38, "C")                  # 정비대(정비 작업대, 스폰 인접)
    # 갱구 채집: 태엽 광석 h, 녹슨 톱니축 k, 갱도 석탄 o, 응결 수정 b
    for (x, y, c) in [(11, 32, "h"), (24, 32, "h"), (13, 35, "k"), (27, 35, "k"),
                      (10, 34, "o"), (28, 33, "o"), (16, 36, "b"), (23, 36, "b"),
                      (14, 33, "k"), (26, 37, "h"), (30, 34, "o")]:
        put(g, x, y, c)
    put(g, 12, 37, "4")                  # 랜드마크: 첫 광석 수레(튜토리얼 채집)

    # --- GM1 붕락 낙석 협곡 (배치형/궤도판): 붕락한 암반이 갱도를 끊음. 궤도판 배치로 통과.
    #     row 29..30 전폭 암반 협곡(~), col18-19 배치 슬롯 K. 좌우 void.
    rect(g, 8, 29, 31, 30, "~")          # 붕락 낙석 협곡(무너진 암반, walkable=false)
    for y in (29, 30):
        for x in range(0, 8):
            g[y][x] = "V"
        for x in range(32, 40):
            g[y][x] = "V"
    put(g, 18, 29, "K"); put(g, 19, 29, "K")
    put(g, 18, 30, "P"); put(g, 19, 30, "P")

    # --- 중부: 채굴 회랑 (보상 포켓 + 채집 밀집 + 에너지 재획득처) row 20..28 (고도 0)
    rect(g, 8, 20, 31, 28, "G")          # 채굴 회랑 바닥(광차 궤도)
    put(g, 18, 19, "G"); put(g, 19, 19, "G")   # GM2 남 접근 목
    for (x, y, c) in [(10, 22, "h"), (14, 23, "k"), (22, 24, "o"), (26, 23, "h"),
                      (29, 25, "k"), (12, 26, "b"), (20, 27, "h"), (28, 27, "o"),
                      (11, 24, "b"), (24, 26, "k"), (16, 25, "o"), (9, 27, "b")]:
        put(g, x, y, c)
    put(g, 12, 22, "E")                  # 잔류 태엽 발전기(에너지 Whisper 재획득처, idempotent)
    put(g, 19, 21, "2")                  # 랜드마크: 대굴착기 실루엣(북쪽 시야)
    put(g, 27, 22, "3")                  # 랜드마크: 광부 로그 석판(진상 조각)

    # --- GM2 막힌 통풍문 (사용형): 낙석·부식으로 잠긴 통풍문. 감압 밸브 사용으로 열림.
    #     row 17..18 void 벽, col18-19 통풍문 D만 열림(사용 후).
    for y in (17, 18):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 17, "D"); put(g, 19, 17, "D")
    put(g, 18, 18, "G"); put(g, 19, 18, "G")

    # --- 상부: 분기실 (레일 전환 미니 퍼즐 존) row 9..16 (고도 0)
    rect(g, 8, 9, 31, 16, "G")
    put(g, 18, 8, "G"); put(g, 19, 8, "G")   # GM3 북 접근 목(전환 성공 후 광차문으로 연결)
    # 광차 레일 전환 미니퍼즐: 3개의 전환 레버 슬롯(전환 순서 무관, 3레버 다 맞추면 개방)
    for (x, y) in [(14, 12), (19, 12), (24, 12)]:
        put(g, x, y, "x")
    put(g, 19, 10, "N")                  # 잔재 NPC: 굴착 로봇(분기실 배회)
    # 채집 잔여(퍼즐 재료 근처)
    for (x, y, c) in [(11, 14, "h"), (28, 14, "h"), (12, 11, "o"), (27, 11, "o"),
                      (10, 15, "k"), (29, 15, "k"), (16, 15, "b"), (23, 15, "b")]:
        put(g, x, y, c)

    # --- GM3 광차문 (전환 미니퍼즐 결과 게이트): 3레버 전환 완성 시 개방.
    #     row 6..7 void 벽, col18-19 광차문 M만 열림(퍼즐 성공 후).
    for y in (6, 7):
        for x in range(W):
            g[y][x] = "V"
    put(g, 18, 6, "M"); put(g, 19, 6, "M")
    put(g, 18, 7, "G"); put(g, 19, 7, "G")

    # --- 최북: 최심부 갱도(대굴착기 코어 = 구역 정화) row 1..5
    rect(g, 12, 1, 27, 5, "B")           # 갱도 바닥(발광 리컬러, 대굴착기 갱)
    put(g, 19, 2, "1")                   # 랜드마크: 멈춘 대굴착기(정화 지점 = 재점화 봉헌)
    put(g, 19, 3, "H")                   # 봉헌 목(태엽 노심 봉헌 = 구역 클리어)
    put(g, 20, 2, "O")                   # 대굴착기 코어 오브젝트(유니크 K-정 채집원 겸 봉헌 대상)
    # 갱도 주변 희귀 채집(마지막 갱)
    for (x, y, c) in [(14, 4, "k"), (24, 4, "k"), (15, 1, "o"), (23, 1, "o"),
                      (13, 3, "h"), (26, 3, "h")]:
        put(g, x, y, c)
    return g


#   loader 소스 규약(L3 구역1 계승): 20=L3T-B(황동 바닥, walkable) · 22=L3T-G(궤도 회랑) ·
#   24=L3T-O(주황 발광 코어 바닥) · 25=L3T-dark(봉인/암반, non-walkable) · 0=T0 void.
#   지하 -1 감·주황 발광은 CanvasModulate 틴트 + 오브젝트 additive glow로만(로더 무수정).
#   붕락 낙석 협곡(~)·닫힌 게이트 병목(K/D/M)은 25(L3T-dark, non-walkable)로 seal.
#   오브젝트는 l2s와 동일한 kind:l3xobj 데이터 구동(art=l3m_*, glow=orange). 게이트 lit/dark_source 병기.
MINE_LEGEND = {
    "_comment": "EX-L3 태엽 광산 legend. Symbol->(source,object). map_loader 재사용(kind:l3xobj). 게이트 강제=void+게이트셀+붕락 낙석 협곡(암반, source25). 좌표 (col,row).",
    "_coord_note": "row0=북(최심부 갱도/멈춘 대굴착기), row39=남(시계탑 도시 하강 스폰). col0=서.",
    "tiles": {
        "P": {"source": 20, "tile_id": "L3T-B", "_note": "갱구 바닥(황동 격자 강판, 구리 리컬러)"},
        "G": {"source": 22, "tile_id": "L3T-G", "_note": "채굴 회랑(광차 궤도)"},
        "B": {"source": 24, "tile_id": "L3T-O", "_note": "최심부 갱도 바닥(대굴착기 갱, 주황 발광 리컬러)"},
        "~": {"source": 25, "tile_id": "L3T-dark", "walkable": False, "_note": "붕락 낙석 협곡(무너진 암반, GM1 협곡 밴드)"},
        "V": {"source": 0, "tile_id": "T0", "walkable": False, "void": True},
        "S": {"source": 20, "tile_id": "L3T-B", "spawn": True},
        "C": {"source": 20, "tile_id": "L3T-B"},
        "K": {"source": 25, "tile_id": "L3T-dark", "walkable": False, "gate": "GM1", "lit_source": 20, "dark_source": 25, "place_slot": "D279", "_note": "GM1 궤도판 배치 슬롯(붕락 궤도판)"},
        "D": {"source": 25, "tile_id": "L3T-dark", "gate": "GM2", "walkable": False, "lit_source": 20, "dark_source": 25, "_note": "막힌 통풍문(감압 밸브 사용 후 walkable)"},
        "M": {"source": 25, "tile_id": "L3T-dark", "gate": "GM3", "walkable": False, "lit_source": 22, "dark_source": 25, "_note": "광차문(3레버 전환 성공 후 walkable)"},
        "x": {"source": 22, "tile_id": "L3T-G", "place_slot": "RAIL_LEVER", "_note": "GM3 광차 레일 전환 레버 슬롯(3개)"},
        "H": {"source": 24, "tile_id": "L3T-O", "gate": "GM4", "_note": "태엽 노심 봉헌 목(구역 클리어)"},
        "N": {"source": 22, "tile_id": "L3T-G"},
        "1": {"source": 24, "tile_id": "L3T-O"},
        "2": {"source": 22, "tile_id": "L3T-G"},
        "3": {"source": 22, "tile_id": "L3T-G"},
        "4": {"source": 20, "tile_id": "L3T-B"},
        "E": {"source": 22, "tile_id": "L3T-G", "_note": "잔류 태엽 발전기(에너지 Whisper 재획득처)"},
        "O": {"source": 24, "tile_id": "L3T-O"},
        "h": {"source": 20, "tile_id": "L3T-B"},
        "k": {"source": 20, "tile_id": "L3T-B"},
        "o": {"source": 22, "tile_id": "L3T-G"},
        "b": {"source": 22, "tile_id": "L3T-G"},
    },
    "objects": {
        "C": {"kind": "l3xobj", "l2_id": "mine_workbench", "art": "l3m_workbench", "offset": [0, -40], "blocks": True, "block_radius": 16, "glow": "orange", "glow_scale": 0.4, "_note": "정비대(L3 crafting station)"},
        "N": {"kind": "l3xobj", "l2_id": "digger_bot", "art": "l3m_digger_bot", "offset": [0, -44], "blocks": True, "block_radius": 14, "glow": "orange", "glow_scale": 0.5, "_note": "잔재 NPC: 갱도에 갇힌 줄 모르는 굴착 로봇(GP-4 NPC 라인)"},
        "D": {"kind": "l3xobj", "l2_id": "vent_door", "art": "l3m_vent_door", "offset": [0, -40], "blocks": True, "block_radius": 16, "gate": "GM2", "_note": "GM2 막힌 통풍문(사용형=감압 밸브 젤 주입)"},
        "H": {"kind": "l3xobj", "l2_id": "excavator_altar", "art": "l3m_excavator_altar", "offset": [0, -40], "blocks": True, "block_radius": 16, "glow": "orange", "glow_scale": 0.6, "gate": "GM4", "_note": "GM4 태엽 노심 봉헌 목(대굴착기 재점화 = 구역 정화)"},
        "E": {"kind": "l3xobj", "l2_id": "mine_residual_dynamo", "art": "l3m_spring_dynamo", "offset": [0, -24], "blocks": False, "glow": "orange", "glow_scale": 0.7, "_note": "에너지 Whisper 재획득처(idempotent, add_energy)"},
        "O": {"kind": "l3xobj", "l2_id": "excavator_core", "art": "l3m_excavator_core", "offset": [0, -48], "blocks": False, "glow": "orange", "glow_scale": 1.0, "gatherable": {"item_id": "K12", "unique": True}, "gate": "GM4", "_note": "멈춘 대굴착기 코어(심층 태엽정, 유니크)"},
        "h": {"kind": "l3xobj", "l2_id": "spring_ore", "art": "l3m_spring_ore", "art_variants": ["l3m_spring_ore_b", "l3m_spring_ore_c"], "offset": [0, -16], "blocks": False, "glow": "orange", "glow_scale": 0.35, "gatherable": {"item_id": "K8"}, "_note": "태엽 광석"},
        "k": {"kind": "l3xobj", "l2_id": "rusted_axle", "art": "l3m_rusted_axle", "art_variants": ["l3m_rusted_axle_b", "l3m_rusted_axle_c"], "offset": [0, -14], "blocks": False, "gatherable": {"item_id": "K9"}, "_note": "녹슨 톱니축"},
        "o": {"kind": "l3xobj", "l2_id": "mine_coal", "art": "l3m_mine_coal", "art_variants": ["l3m_mine_coal_b", "l3m_mine_coal_c"], "offset": [0, -12], "blocks": False, "gatherable": {"item_id": "K10"}, "_note": "갱도 석탄"},
        "b": {"kind": "l3xobj", "l2_id": "condensate_crystal", "art": "l3m_condensate_crystal", "art_variants": ["l3m_condensate_crystal_b", "l3m_condensate_crystal_c"], "offset": [0, -12], "blocks": False, "glow": "orange", "glow_scale": 0.4, "gatherable": {"item_id": "K11"}, "_note": "응결 수정"},
    },
    "landmarks": {"1": "excavator", "2": "excavator_silhouette", "3": "miner_log_slab", "4": "tutorial_ore_cart"},
    "gates": {
        "GM1": {"type": "placement", "kind": "stepping", "place_item": "D279",
                "lit_source": 20, "dark_source": 25,
                "cells": [[18, 29], [19, 29]]},
        "GM2": {"type": "use", "item": "D281", "target": "vent_door",
                "lit_source": 20, "dark_source": 25,
                "cells": [[18, 17], [19, 17]]},
        "GM3": {"type": "placement", "kind": "puzzle", "puzzle": "rail_route_3",
                "lit_source": 22, "dark_source": 25,
                "slot_cells": [[14, 12], [19, 12], [24, 12]],
                "cells": [[18, 6], [19, 6]]},
        "GM4": {"type": "chain", "kind": "offering", "node_id": "excavator_altar",
                "cells": [[19, 3]], "mount": [19, 3]}
    },
    "special": {
        "workbench_cell": [20, 38],
        "power_residue_cell": [12, 22],
        "_energy_note": "잔류 태엽 발전기 E = 에너지 Whisper 재획득처(idempotent add_energy). GM1 뒤·GM2 앞 회랑 유일 경로에 배치 → 엔딩 Balance 대비, 최초 획득처(L3 구역1 G2 보일러 보상)의 소진 세이브 안전망.",
        "entry_from": "clockwork_city",
        "entry_note": "시계탑 도시(l3 구역1) 대시계 광장 아래 낡은 광차 승강로에서 하강. 개방 조건 = L3 구역1 정화 완료(대시계 재가동/clock_restarted) 후 승강로 활성. 좌표: 대시계 광장(row0-3 O블록) 하부 → 광산 스폰 S(19,39)."
    }
}


def main():
    m = gen_mine()
    with open(os.path.join(DATA, "l3m_map_layout.txt"), "w", encoding="utf-8") as f:
        f.write(to_text(m))
    with open(os.path.join(DATA, "l3m_map_legend.json"), "w", encoding="utf-8") as f:
        json.dump(MINE_LEGEND, f, ensure_ascii=False, indent=2)
    ht = [["0"] * W for _ in range(H)]
    with open(os.path.join(DATA, "l3m_map_height.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join("".join(r) for r in ht) + "\n")
    print("wrote l3m layout+legend (+l3m height)")
    assert len(m) == 40 and all(len(r) == 40 for r in m), "dims"
    print("dims OK 40x40")


if __name__ == "__main__":
    main()
