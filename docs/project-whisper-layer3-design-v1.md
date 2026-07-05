# Project Whisper — Layer 3 (제3세계) 레벨/콘텐츠 디자인 v1.0

> 작성: Kana (레벨·콘텐츠 디자인 담당) / 2026-07-06
> 대상 레이어: **제3세계 — Layer of Machine (기계의 세계)**
> 상위/Canon:
> - 세계관: `docs/project-whisper-storyline-v1.md` §2 — Layer 3 기계: 설계 사상 **효율**, 멸망 방식 **"영원한 에너지는 없다 → 고갈"**.
> - 레벨 문법·게이트 타입·40×40 포맷: `docs/project-whisper-layer2-design-v1.md`(Part A 맵+BFS+softlock, Part B 원소+레시피, Part C 아트+구현) — 그 구조를 계승.
> - 데이터 정합: `game/data/items.json`(J1–J7, D01–D102), `game/data/recipes.json`(총 104 레시피, L1 R01~ + L2 L2-R01~R42), `game/data/l2_map_legend.json`(맵 데이터 포맷).
> - 재화: `docs/project-whisper-economy-design-v1.md` A-3/B-4 — Whisper **에너지(Energy)** = L3 기계 / L2 과학, WhisperCurrency `whisper_cost` 필드.
> - Owner 확정 방향(Kana): 테마 **「태엽이 멈춘 도시」** / 구리·황동·갈색 + **주황 증기 발광**(L2 남색+시안과 대비) / 퍼즐 축 = **동력 전달(맞물리기)** / Whisper 재화 = **에너지 확장**(신규 재화 없음) / 신규 원소 7종 K1~K7(태엽·톱니·황동·증기응축수·가죽 벨트·석탄·기름때 유리).
> 상태: **Layer 3 구역1 단일 기준.** 구현 에이전트는 이 문서를 소비한다. 변경은 이 파일 갱신으로만.

---

## 0. 이 문서가 결정하는 것 (요약)

| # | 결정 | 근거 |
|---|---|---|
| 1 | 구역1 「태엽이 멈춘 도시」는 **남(스폰)→북(대시계 광장)의 수직 상승 여정**. 통과 순서는 공간상 **G1 톱니 맞물림 → G2 증기 보일러 → G3 멈춘 승강기 → G4 대시계 재가동**으로만 고정 | 스토리라인 "효율→에너지 고갈". §A-5 BFS로 강제 증명(재현 스크립트). |
| 2 | 게이트는 L1/L2와 동일하게 **void 벽 + 2칸 병목**으로 물리 강제. 냉각수 대신 **끊긴 동력선/식은 용광로 협곡**이 우회 차단 | L2 문법 계승. "우회 경로 없음"을 지오메트리로 증명(§A-5). |
| 3 | 레이어 퍼즐 축 = **동력 전달(맞물리기)**. 각 게이트는 멈춘 기계에 빠진 부품을 물려 다시 돌린다(톱니 장착/보일러 점화/승강기 재가동/대시계 심장) | Owner 확정. L1 "생명 복원"·L2 "전력 복구"의 기계적 대응물. |
| 4 | 신규 채집 원소 7종 = **K1~K7** 프리픽스(K=Layer3 채집). 기존 I=L1, J=L2 채집, D=조합. items.json `layer:3` 필드 병기 | 프리픽스로 레이어 구분, 기존 id 규칙 무충돌. |
| 5 | Whisper 재화 = **에너지(Energy) 확장**(신규 재화 0). G2 보일러 재가동이 에너지 Whisper 획득처(order-safe, G4 전), G4 태엽심장 조합이 소비 | 경제 문서상 에너지=L3 기계 계열. WhisperCurrency·`whisper_cost` 구현 재사용(§B-1 근거 1문단). |
| 6 | 신규 게이트 조작 없음 — L1/L2가 확립한 **배치형·사용형·장착형·체인형** 4종을 재사용. G3만 **고도 +1~2 상부 해금**(승강기)이라는 공간 결과가 신규 | 조작 학습량 최소화(3번째 레이어 = 리듬 최고속). 승강기는 L1 경사로/L2 고도 시스템 재사용. |

---

# Part A — Layer 3 구역1 「태엽이 멈춘 도시」 40×40 타일 설계

## A-1. 컨셉

효율의 극한을 좇던 문명이, **영원한 동력은 없다**는 한 가지 사실 앞에서 멈췄다. 도시 전체가 하나의 거대한 시계장치였고 — 대시계의 태엽이 다 풀리는 순간, 맞물려 돌던 모든 것이 동시에 정지했다. 톱니는 물린 채로, 승강기는 층과 층 사이에서, 보일러는 마지막 증기를 절반쯤 내뿜다가.

멈춘 로봇들이 거리에 서 있다. 청소부는 빗자루를 든 채로, 전령은 한 발을 내디딘 채로. 조사하면 **마지막 로그**가 흘러나온다 — 진상(선배 컨스트럭터가 세계를 "완성"하고 떠나 속삭임이 끊긴 것)의 조각이 로봇의 마지막 한 줄에 담겨 있다.

플레이어는 **동력을 한 마디씩 다시 물려** 도시 정점의 대시계에 오른다. 빠진 톱니를 깎아 끼우고, 식은 보일러에 불을 지피고, 멈춘 승강기를 평형추로 되살려 상부로 오르고, 마지막으로 대시계의 심장(태엽심장)을 꽂는다.

무드: 구리·황동·갈색 base(#3a2c1e) + **주황 증기 발광**(#ff9a3c). L2의 "기계의 정적"이 **차갑게 죽은 불빛(시안)**이었다면, L3는 **마지막 온기를 붙든 불빛(주황)** — 식어 가는 화로, 새어 나오는 증기의 잔열. 기존 L2 과학 텍스처를 **구리/황동 계열로 리컬러한 하이브리드**를 전제(§C-1).

## A-2. ASCII 맵 (40행 × 40열)

- **좌표 규약**: `(col, row)`, 좌상단 = (0,0). row 0 = **북(대시계 광장, +2)**, row 39 = **남(스폰 포탈 착지)**. col 0 = 서, col 39 = 동.
- **읽는 방향**: 플레이어는 아래(남, 포탈 착지)에서 위(북, 대시계)로 **오른다**. L1/L2와 동일한 수직 여정 문법 + 고도 상승(G3 승강기가 +1~2 상부 해금).
- 아래 40자×40행 텍스트는 **파이썬 스크립트 `/tmp/l3_map_gen.py`로 생성**(구역 사각형·병목·경로를 코드화, 손 타이핑 금지) → 그대로 `game/data/l3_map_layout.txt`가 된다. ruler/행번호는 문서 표기용이며 파일에는 제외.

```
col: 0         1         2         3
     0123456789012345678901234567890123456789
   0 VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV
   1 VVVVVVVVVVVVVOOOOOOOOOOOOOOVVVVVVVVVVVVV
   2 VVVVVVVVVVVVVOOOOO1KOOOOOOOVVVVVVVVVVVVV
   3 VVVVVVVVVVVVVOOOOO//OOOOOOOVVVVVVVVVVVVV
   4 VVVVVVVVVVVVVVVVVVHHVVVVVVVVVVVVVVVVVVVV
   5 VVVVVVVVVVVVVVVVVVHHVVVVVVVVVVVVVVVVVVVV
   6 VVVVVVVVVVVVMMMMMtMMfMtMMMMMVVVVVVVVVVVV
   7 VVVVVVVVVVVVMMtMMMMfMMMMMtMMVVVVVVVVVVVV
   8 VVVVVVVVVVVVMbMMMMMMMMMMMMbMVVVVVVVVVVVV
   9 VVVVVVVVVVVVMMMMMM//MMMMMMMMVVVVVVVVVVVV
  10 VVVVVVVVVVVVVVVVVVLLVVVVVVVVVVVVVVVVVVVV
  11 VVVVVVVVVVVVVVVVVCLLVV3VVVVVVVVVVVVVVVVV
  12 VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
  13 VVVVVVVVGGGGGbGGGGGGGGGGGGbGGGGGVVVVVVVV
  14 VVVVVVVVGGGGGGGGGrGGGGrGGGGGGGGGVVVVVVVV
  15 VVVVVVVVGGGlGGGGGGGGGGGGGGGGlGGGVVVVVVVV
  16 VVVVVVVVGGGGrGGGGGGGGGGGGGGrGGGGVVVVVVVV
  17 VVVVVVVVGGGGGGlGGGGGGGGGGlGGGGGGVVVVVVVV
  18 VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
  19 VVVVVVVVVVVVVVVVVEvvVV2VVVVVVVVVVVVVVVVV
  20 VVVVVVVVVVVVVVVVVVvvVVVVVVVVVVVVVVVVVVVV
  21 VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
  22 VVVVVVVVGGGGlGGGGkGGGGkGGGGlGGGGVVVVVVVV
  23 VVVVVVVVGGwGGGGGGGGGGGGGGGGGGwGGVVVVVVVV
  24 VVVVVVVVGGGkGGGGGGGGGGGGGGGGkGGGVVVVVVVV
  25 VVVVVVVVGGGGGwGGGGGGGGGGGGwGGGGGVVVVVVVV
  26 VVVVVVVVGGGGGGGGlGGGGGGlGGGGGGGGVVVVVVVV
  27 VVVVVVVVGGGGGGkGGGGGGGGGGkGGGGGGVVVVVVVV
  28 VVVVVVVVGGGGGGGGGGXGGGGGGGGGGGGGVVVVVVVV
  29 VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV
  30 VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV
  31 VVVVVVVVBBBBBBBBBBBBBBBBBBBBBBBBVVVVVVVV
  32 VVVVVVVVBBBtBBBBBBBBBBBBBBBBtBBBVVVVVVVV
  33 VVVVVVVVBBBBBBrBBBBBBBBBrBBBBBBBVVVVVVVV
  34 VVVVVVVVBBbBBBBBBBBBBBBBBBBBBBbBVVVVVVVV
  35 VVVVVVVVppppptpppppppppppptpppppVVVVVVVV
  36 VVVVVVVVBBBrBBBBBfBBBBfBBBBrBBBBVVVVVVVV
  37 VVVVVVVVBBBBBBBbBBBSBB4BbBBBBBBBVVVVVVVV
  38 VVVVVVVVBBrBBfBBBBBBBBBBBBfBBrBBVVVVVVVV
  39 VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
```

> 위 맵은 §A-5 BFS 검증을 통과한 확정본이다(전 게이트 개방 시 walkable ≈ 638칸, L2의 664·682와 정합).

### Legend

| 기호 | 의미 | 타일/오브젝트 | walkable | 채집 |
|---|---|---|---|---|
| `B` | 황동 포장(기어 플라자 바닥) | L3T-B | O | — |
| `p` | 황동 파이프라인 런(가로지르는 도관) | L3T-p | O | — (연출) |
| `G` | 격자 철판 바닥(보일러/용광로 지구) | L3T-G | O | — |
| `M` | 황동 상부 플랫폼(+1, 승강기 상부) | L3T-M | O | — |
| `O` | 대시계 광장/구조체(+2) | L3T-O | O | — |
| `V` | 경계 void / 끊긴 동력선 협곡 | — | X | — |
| `S` | 스폰(포탈 착지, B 위) | — | O | — |
| `g` | **G1** 톱니 맞물림 병목(빠진 톱니 자리) | 협곡 위 배치 슬롯 | X→장착 후 O | — |
| `v` | **G2** 증기 밸브문 병목 | O(valve_door) | X→점화 후 O | — |
| `L` | **G3** 멈춘 승강기 병목(고도 +1 상부행) | O(elevator) | X→재가동 후 O | — |
| `H` | **G4** 태엽심장 목(대시계 진입, +2행) | 슬롯 목 | X→설치 후 O | — |
| `X` | 기어 조립대(빠진 톱니 장착 슬롯) | O(gear_assembly) | X(인접) | — |
| `E` | 대형 증기 보일러(**에너지 Whisper 획득처**) | O(boiler) | X(인접) | — (연출) |
| `C` | 승강기 제어반(케이블/평형추 장착) | O(elevator_ctrl) | X(인접) | — |
| `K` | 대시계 배전반(태엽심장 설치 슬롯) | O(clock_mount) | X(인접) | — |
| `/` | 경사로(승강기 하차·대시계 진입) | L3T-ramp | O(등반) | — |
| `t` | 태엽 잔해(clockwork spring) | O(spring_debris) | X(인접) | **K1 태엽** |
| `r` | 톱니 더미(gear pile) | O(gear_pile) | X(인접) | **K2 톱니** |
| `b` | 황동 스크랩 | O(brass_scrap) | X(인접) | **K3 황동** |
| `w` | 증기응축수 웅덩이 | O(condensate) | X(인접) | **K4 증기응축수** |
| `l` | 가죽 벨트 스풀 | O(belt_spool) | X(인접) | **K5 가죽 벨트** |
| `k` | 석탄층(coal seam) | O(coal_seam) | X(인접) | **K6 석탄** |
| `f` | 기름때 유리 파편 | O(grimy_glass) | X(인접) | **K7 기름때 유리** |
| `1`~`4` | 랜드마크 | — | 문맥별 | — |

- **오브젝트 walkable 규약**(L1/L2 계승): 조립대/보일러/제어반/배전반/채집 오브젝트는 셀 자체가 충돌체(X)지만, 플레이어는 인접 칸에서 `OBJECT_REACH`로 채집/상호작용한다. §A-5 BFS의 **게이트 강제는 순수하게 void(V)·게이트셀(g/v/L/H)로만** 이뤄지며, 채집/기능 오브젝트는 리스폰되므로 게이트로 쓰지 않는다(경로 검증에서 벽 취급하되 주변 바닥이 감싸 고립 없음 — §A-5 orphan 0 확인).

## A-3. 고도(Elevation)

기존 고도 시스템(`map_height.txt`/`l2_map_height.txt`, 셀당 0/1/2, `/`=경사로) 재사용. **G3 승강기가 상부(+1~2) 해금의 서사·기계적 이유**를 겸한다 — 멈춘 승강기 때문에 상부에 오를 수 없다가, 재가동으로 비로소 올라간다.

| 구역 | 고도 | 행 범위 | 근거 |
|---|---|---|---|
| 대시계 광장/코어 | **+2** | row 0–3 (O), H 목 row4–5 | 도시 정점, 멀리서 보이는 대시계 실루엣 |
| 상부 플랫폼(승강기 상부) | **+1** | row 6–9 (M) | G3 승강기가 여기로 실어 올림 |
| 그 외(기어 플라자·보일러·용광로 지구) | 0 | 나머지 | 기저면(하부 도시) |

- 경사로 `/`: (18,9)(19,9)=승강기 하차 후 상부 플랫폼 진입, (18,3)(19,3)=H 목에서 대시계 코어(+2) 오름. **하부(0)→상부(+1)는 승강기 L 병목이 유일 접점**(고도 점프를 승강기가 담당), **상부(+1)→코어(+2)는 H 목 경사로가 유일 접점**. 이 이중 고도차 자체가 G3·G4의 지오메트리 강제를 겸한다(§A-5).
- `game/data/l3_map_height.txt`는 **`l3_map_gen.py`가 layout과 병렬 생성**: O셀=2, H목=2, M셀=1, `/`=경사로 문자, 그 외 0. Part C C-1 파서가 layout과 병렬로 읽음(L2 로더 무수정 재사용).

## A-4. 게이트 / 랜드마크 / 오브젝트 배치표

**게이트** (공간 통과 순서: 남→북 = G1 → G2 → G3 → G4)

| 게이트 | 타입 | 좌표(col,row) | 이름 | 열쇠(제작 체인) | 연출 | 플레이버 |
|---|---|---|---|---|---|---|
| **G1** | 배치형(장착) | 병목 g (18,29)(19,29)(18,30)(19,30), 조립대 X (18,28) | **톱니 맞물림** | **맞물림 톱니(D104)** → 기어 조립대 X에 장착 → 빠진 톱니가 물려 관문 기어 회전·개통 | 큰 관문 기어가 한 이 한 이 맞물리며 삐걱 회전, 협곡 위 잔교가 내려옴. `gear_meshed` | "관문의 톱니 하나가 빠져 있다. 이 하나가 없어서, 도시 전체가 멈춰 있다." |
| **G2** | 사용형 | 밸브문 v (18,19)(19,19)(18,20)(19,20), 보일러 E (17,19) | **증기 보일러** | **압력 밸브(D105)** → 대형 보일러 E에 사용(장착) + **젖은 석탄(D106)** 점화 | 보일러 계기판 주황 점등 → 증기 밸브문 v가 압력에 밀려 좌우 개방·증기 분출. **에너지 Whisper ×1 획득**(§보완) | "식은 보일러. 밸브 하나와 마른 석탄만 있으면… 다시 김을 뿜을 텐데." |
| **G3** | 장착형 | 승강기 L (18,10)(19,10)(18,11)(19,11), 제어반 C (17,11) | **멈춘 승강기**(고도 +1 해금) | **평형추(D108)** → 승강기 제어반 C에 장착 → 케이블 팽팽해지며 케이지 상승 | 평형추가 반대편으로 가라앉으며 승강기 케이지 상승 → 상부 플랫폼(+1) 하차 램프 전개. `elevator_running` | "승강기가 층과 층 사이에 멈춰 있다. 평형추만 걸면, 다시 오를 텐데." |
| **G4** | 체인형 | 대시계 목 H (18,4)(19,4)(18,5)(19,5), 배전반 K (19,2) | **대시계 재가동 = Layer 3 정화** | **태엽심장(D111)**(다단 조합 + 에너지 Whisper 소비) → 대시계 배전반 K에 설치 | 심장 삽입 → 대시계 문자판 주황 점등 → 도시 전역 기계가 순차 재기동하는 컷신 → Layer 3 정화 | "대시계의 심장이 비어 있다. 여기에 온기를 꽂으면, 이 멈춘 도시가 마지막으로 한 번, 째깍인다." |

**랜드마크**

| 기호 | 좌표 | 이름 | 역할 | 플레이버 |
|---|---|---|---|---|
| `1` | (17,2) | **대시계 문자판**(정점) | 최상단 시각 앵커. 스폰에서 북쪽 정면으로 보임. 바늘이 한 시각에 멈춰 있음 | "도시에서 가장 큰 시계. 바늘이 한 시각을 가리킨 채, 굳었다." |
| `2` | (21,19) | **대형 증기 보일러** | 중간 지대 방향 앵커. G2 보일러 본체의 실루엣 | "도시의 심장 대신 뛰던 것. 이제 식어 재만 남았다." |
| `3` | (21,11) | **멈춘 승강기 케이지** | G3 진입 시각 앵커. 층 사이에 매달린 철제 케이지 | "누군가 타고 있었을 케이지. 오르지도 내리지도 못한 채." |
| `4` | (21,37) | 첫 톱니 상자 군락 | 튜토리얼 채집 유도 하이라이트 | "톱니 상자. 성한 톱니가 있을까. 태엽이든, 뭐든." |

**채집원 배치 요약** (§A-6 충분성 표와 연동 · `l3_map_gen.py` `put()`이 지대별 배치)

| 원소 | id | 소스 기호/오브젝트 | 배치 지대 | 소스 개수 |
|---|---|---|---|---|
| 태엽 | K1 | `t` 태엽 잔해 | 남 기어 플라자 + 상부 플랫폼 | 남 4, 상부 4 |
| 톱니 | K2 | `r` 톱니 더미 | 남 플라자 + 용광로 지구 | 남 6, 용광로 4 |
| 황동 | K3 | `b` 황동 스크랩 | 남 + 보일러 + 용광로 + 상부(전 지대) | 남 4, 보일러(공유) , 용광로 2, 상부 2 |
| 증기응축수 | K4 | `w` 응축수 웅덩이 | 보일러 지구 | 보일러 4 |
| 가죽 벨트 | K5 | `l` 벨트 스풀 | 보일러 + 용광로 지구 | 보일러 4, 용광로 4 |
| 석탄 | K6 | `k` 석탄층 | 보일러 지구 | 보일러 6 |
| 기름때 유리 | K7 | `f` 기름때 유리 파편 | 남 플라자 + 상부 플랫폼 | 남 4, 상부 2 |

- **지대 정의**(§A-6 softlock 논증의 기준): **남 기어 플라자**(G1 앞, row31–38) / **보일러 지구**(G2 앞, row21–28) / **식은 용광로 지구**(G3 앞, row12–18) / **상부 플랫폼**(G4 앞, row6–9). 각 원소가 그 체인을 여는 게이트 **앞** 지대에 존재함을 §A-6이 증명.
