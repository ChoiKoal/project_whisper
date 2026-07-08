# Project Whisper — 확장 기획 EX-L3: 제3세계 「기계의 세계」 확장 설계 v1.0

> 작성: Kana (레벨·콘텐츠 디자인 담당) / 2026-07-08
> 대상: **Layer 3(기계) 확장 — 신규 구역 「태엽 광산」** (40×40, 구역 1개)
> **스코프 선언: 이 문서는 설계(기획)만 확정한다. 구현은 금지** — KOAL은 전 레이어 확장의 **기획 선행**만 지시했다. 데이터/맵/코드 반영은 별도 구현 마일스톤이 이 문서와 생성 스크립트를 소비해 수행.
> 상위/Canon:
> - **L3 구역 프레임 원안**: `docs/project-whisper-layer3-design-v1.md`(구역 1 「태엽이 멈춘 도시」 = 시계탑 도시, 40×40, 게이트 G1 톱니 맞물림→G2 증기 보일러→G3 멈춘 승강기→G4 대시계 재가동, 채집 K1~K7, 조합 D103~D139, 퍼즐 축 = **동력 전달(맞물리기)**, 무드 = 구리/황동/갈색 + 주황 증기 발광). 본 확장은 그 **지하 광산**을 신설한다. 구역 표준 5요소·게이트 타입 분류·"한 구역 같은 타입 2연속 금지"는 `docs/project-whisper-level-design-v1.md` Part B 계승.
> - **직전 산출 정본 포맷**: `docs/project-whisper-expansion-l2-design-v1.md`(21099e8) — Part A(맵·게이트·BFS·재료 도달성·페이싱) / Part B(원소·레시피·무결성) / Part C(재사용·구현·컷신) 3부 구조 + 증명 방식(BFS 순서 강제 + 재료 도달성 이중 증명) + 분할 작성 패턴을 그대로 계승. `tools/l2x_*`를 `tools/l3x_*`로 복제·적응.
> - **데이터 정합**: `game/data/recipes.json`(총 **220 레시피**, 산출 D≤D218) · `game/data/items.json`(K1~K7=L3 채집, D≤D221). **EX-L1이 D222~D254를 예약**(자연) · **EX-L2가 D255~D277을 예약**(과학) → **EX-L3 신규 조합 산출 = D278~**(연속). **신규 채집 = K8~K12**(L3 기존 K1~K7 뒤 연속). 모든 신규 항목 `layer:3` 병기.
> - **공간 감사**: `tools/tools_spatial_audit.py`(L2~L5 커버) 문법 계승 **`tools/l3x_bfs.py`**(신규 구역 전용 BFS)로 순서 강제 재현 증명. 맵/레시피 표는 **파이썬 생성**(`tools/l3x_map_gen.py`·`tools/l3x_recipes.py`) — 손 타이핑 금지.
> - **NPC 문법**: `docs/project-whisper-gameplay-pass-v1.md` §1(잔재 NPC = 레이어당 1~2기, 3유형 퀘스트 체인, 정답 아이템명 직접 호명 금지). **신규 구역 잔재 NPC 1기**.
> - **재화**: `docs/project-whisper-economy-design-v1.md`(에너지 Whisper = **L3 기계** 계열 정통 소유) · `docs/project-whisper-endgame-design-v1.md`(빛의 문·E1/E2·Balance 4축 = 자연/**에너지**/마력/생명). 본 구역이 **에너지 Whisper 재획득처**를 제공해 엔딩 Balance를 대비(idempotent).
> - **세계관**: `docs/project-whisper-storyline-v1.md` §2 — L3 기계 설계 사상 **효율**, 멸망 방식 **"영원한 에너지는 없다 → 고갈"**. 광산 = 그 **고갈의 근원지**(도시를 감던 태엽의 원천이 다 풀린 마지막 갱).
> 상태: **EX-L3 설계 완료** — 「태엽 광산」 단일 기준(Part A·B·C). 구현 에이전트는 이 문서 + 생성 스크립트를 소비한다. 변경은 이 파일 갱신으로만.

---

## 0. 이 문서가 결정하는 것 (요약)

| # | 결정 | 근거 |
|---|---|---|
| 1 | L3를 **신규 구역 「태엽 광산」**(40×40)로 확장. 시계탑 도시(구역 1)의 **지하 광산** — 도시를 감던 태엽의 원천, 멈춘 굴착 기계들과 마지막 갱도. 도시가 "동력을 되살리는 곳"이었다면 광산은 **에너지 고갈의 근원지를 마주하는 곳**(L3 정체성 = 효율→고갈) | layer3 원안 프레임 + 스토리라인 §2 "영원한 에너지는 없다 → 고갈" 계승. 구역 1 대시계가 지상의 태엽을 다시 감았다면, 그 태엽이 **어디서 왔고 왜 다 풀렸는지**를 지하에서 마주하는 다음 심화 |
| 2 | 게이트는 구역 1·L1~L5 문법 계승 — **void 벽 + 2칸 병목**으로 물리 강제. 냉각수 대신 **붕락 낙석 협곡**이 우회 차단. 게이트 4종(타입 비반복): **GM1 붕락 낙석 협곡**(배치/궤도판)→**GM2 막힌 통풍문**(사용)→**GM3 광차 레일 전환**(전환 미니 퍼즐, 신규 술어 `rail_routed`)→**GM4 대굴착기 재점화**(체인·컷신) | level-design B-2 게이트 타입 분류("같은 타입 2연속 금지") 준수. GM1·GM3은 둘 다 '배치'지만 GM3는 3레버 전환 미니 퍼즐로 조작 결이 다름(사용형 GM2가 사이). §A-6 BFS로 순서 강제 증명(`l3x_bfs.py`, `ORDER-FORCED: PASS`) |
| 3 | 신규 채집 **5종**: K8 태엽 광석·K9 녹슨 톱니축·K10 갱도 석탄·K11 응결 수정 + **K12 심층 태엽정(유니크)**. 신규 조합 **23종**(EX-L3-R01~R23, 산출 D278~D300) | L3 기존 K1~K7 뒤 연속, EX-L2 예약 D277 뒤 연속. 기존 220 레시피 + **EX-L1·EX-L2 예약분 대비 페어 중복 0**·내부 중복 0·softlock 0 실측(§B-3) |
| 4 | **에너지 Whisper 재획득처**(잔류 태엽 발전기 E, idempotent `add_energy`). 구역 1 G2(증기 보일러)가 준 에너지를 엔딩 Balance(4축)에서 소진했을 세이브를 위해 L3 내부 재확보 수단 제공 | economy 4축 Balance + endgame E1/E2. 구역 1 G2 보상(에너지 첫 획득지)의 소진 안전망. 신규 재화 0(에너지=이미 WhisperCurrency 자릿수 구현) |
| 5 | **진상 조각 서사 보강 1점** — 「광부 로그 석판」(마지막 교대 광부가 남긴, 태엽이 다 풀려가던 마지막 날의 기록). 잔재 NPC = **갱도에 갇힌 줄 모르는 굴착 로봇**. L1~L5 유산 조각(세계수/로그/로봇/마법사 잔영/석상) 계보에 **L3 심부 조각** 추가 | gameplay-pass §1 잔재 NPC 문법 + endgame 진상 5조각 구조. 구역당 NPC 1기. 로봇의 마지막 로그 = 스토리라인 §2 진상 회수 문법의 L3판 |
| 6 | **§A-6 공간 도달성 표 = 필수 계약** — 각 게이트 열쇠 재료의 채집 소스가 게이트 **前** 지대임을 좌표로 명시(L2 기름 사고 재발 방지 — 설계 단계에서 증명). BFS 순서 증명 + 재료 도달성 스크립트 실측 포함 | L2 구역 1 기름 softlock 전례. `l3x_bfs.py`(순서 강제) + `l3x_recipes.py`(재료 누적 지대 논증) 이중 증명 |
| 7 | 진입: **시계탑 도시(구역 1) 대시계 광장 아래 낡은 광차 승강로에서 하강** → 광산 남쪽 스폰 (19,39). **L3 구역 1 정화 후 개방**(대시계 재가동 = 승강로 활성) | 구역 1과 물리 연결. 왕래는 홈/구역 포탈 패턴 재사용(§Part C) |

---

# Part A — 「태엽 광산」 40×40 타일 설계

## A-1. 컨셉

시계탑 도시에서 대시계를 되살린 방랑자가, 대시계 광장 아래로 내려가는 낡은 광차 승강로를 따라 다다르는 곳. **도시를 감던 태엽의 원천이 잠든 지하 광산**이다. 대시계가 지상의 "지금"을 다시 감았다면, 그 아래에는 문명이 캐다 만 태엽의 광맥이 — 반쯤 캐낸 원석과 멈춘 굴착기와 마지막 갱도가 — 다 풀린 채 식어 있다. 방랑자는 **끊긴 갱도를 한 마디씩 다시 이어** 최심부의 대굴착기 코어에 도달하고, 도시를 감던 첫 태엽을 되돌린다.

시계탑 도시가 "동력을 복구하는 곳(기계의 정지)"이었다면, 광산은 그 아래에서 **에너지 고갈의 근원지를 마주하는 곳** — 태엽 광석·녹슨 톱니축·갱도 석탄이 주역이 되는, L3 안의 지하 **채굴 챕터**다. 구역 1의 구리+황동+주황 무드를 **더 어둡게(지하)** 가라앉히되, 살아 있는 것은 오직 태엽 광석과 대굴착기 코어의 주황 발광뿐이다. 스토리라인 §2의 "효율→고갈"이 화면 안에서 드러난다: 여기가 바로 **영원한 동력이 없다는 사실을 캐다 멈춘 자리**다.

무드: 구역 1 구리/황동 base 위에 **지하의 심연 어둠 + 태엽 주황 발광**. 심부로 내려갈수록(북으로 올라갈수록 = 최심부) 화면이 어둑해지고 대굴착기의 주황 명멸이 강해지는 CanvasModulate 커브. **엔진 틴트(CanvasModulate) + 리컬러**로 팔레트를 늘리지 않고 표현(아트가이드 §2·§3). "지하 -1 고도"는 이 틴트로만 표현(실제 고도 미사용 — 로더 무수정, L2 확장 성소 구역·L1 확장 심장 구역 방식 계승. 구역 1의 G3 승강기 고도 시스템은 여기서 미사용 — 광산은 단일 하강 평면).

**진입점**: 시계탑 도시 대시계 광장(row 0~3 O 블록) 하부의 **낡은 광차 승강로** → 광산 남쪽 스폰 (19,39). 시계탑 도시 클리어(G4 대시계 재가동) 후 개방(승강로에 잔류 태엽 동력이 돌기 시작 = 개방 신호). 왕래는 홈/구역 포탈 패턴 재사용(§Part C).

## A-2. ASCII 맵 (40행 × 40열)

- **좌표 규약**: `(col, row)`, 좌상단 = (0,0). row 0 = **북(최심부 갱도 / 멈춘 대굴착기)**, row 39 = **남(시계탑 도시 하강 스폰)**. col 0 = 서.
- **읽는 방향**: 플레이어는 아래(남, 도시에서 하강)에서 위(북, 최심부 대굴착기)로 올라가며 **갱도를 복구한다**. 구역 1의 수직 여정 문법 계승(남 스폰→북 정점).
- 아래 40자×40행은 **`tools/l3x_map_gen.py`가 생성**(구역 사각형·병목·채집 배치를 코드화, 손 타이핑 금지) → 그대로 `game/data/l3m_map_layout.txt`가 된다. ruler/행번호는 문서 표기용, 파일엔 제외.

```
col: 0         1         2         3
     0123456789012345678901234567890123456789
  0  VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
  1  VVVVVVVVVVVVBBBoBBBBBBBoBBBBVVVVVVVVVVVV
  2  VVVVVVVVVVVVBBBBBBB1OBBBBBBBVVVVVVVVVVVV
  3  VVVVVVVVVVVVBhBBBBBHBBBBBBhBVVVVVVVVVVVV
  4  VVVVVVVVVVVVBBkBBBBBBBBBkBBBVVVVVVVVVVVV
  5  VVVVVVVVVVVVBBBBBBBBBBBBBBBBVVVVVVVVVVVV
  6  VVVVVVVVVVVVVVVVVVMMVVVVVVVVVVVVVVVVVVVV
  7  VVVVVVVVVVVVVVVVVVGGVVVVVVVVVVVVVVVVVVVV
  8  VVVVVVVVVVVVVVVVVVGGVVVVVVVVVVVVVVVVVVVV
  9  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 10  VVVVVVVVGGGGGGGGGGGNGGGGGGGGGGGGVVVVVVVV
 11  VVVVVVVVGGGGoGGGGGGGGGGGGGGoGGGGVVVVVVVV
 12  VVVVVVVVGGGGGGxGGGGxGGGGxGGGGGGGVVVVVVVV
 13  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 14  VVVVVVVVGGGhGGGGGGGGGGGGGGGGhGGGVVVVVVVV
 15  VVVVVVVVGGkGGGGGbGGGGGGbGGGGGkGGVVVVVVVV
 16  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 17  VVVVVVVVVVVVVVVVVVDDVVVVVVVVVVVVVVVVVVVV
 18  VVVVVVVVVVVVVVVVVVGGVVVVVVVVVVVVVVVVVVVV
 19  VVVVVVVVVVVVVVVVVVGGVVVVVVVVVVVVVVVVVVVV
 20  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 21  VVVVVVVVGGGGGGGGGGG2GGGGGGGGGGGGVVVVVVVV
 22  VVVVVVVVGGhGEGGGGGGGGGGGGGG3GGGGVVVVVVVV
 23  VVVVVVVVGGGGGGkGGGGGGGGGGGhGGGGGVVVVVVVV
 24  VVVVVVVVGGGbGGGGGGGGGGoGGGGGGGGGVVVVVVVV
 25  VVVVVVVVGGGGGGGGoGGGGGGGGGGGGkGGVVVVVVVV
 26  VVVVVVVVGGGGbGGGGGGGGGGGkGGGGGGGVVVVVVVV
 27  VVVVVVVVGbGGGGGGGGGGhGGGGGGGoGGGVVVVVVVV
 28  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 29  VVVVVVVV~~~~~~~~~~KK~~~~~~~~~~~~VVVVVVVV
 30  VVVVVVVV~~~~~~~~~~PP~~~~~~~~~~~~VVVVVVVV
 31  VVVVVVVVPPPPPPPPPPPPPPPPPPPPPPPPVVVVVVVV
 32  VVVVVVVVPPPhPPPPPPPPPPPPhPPPPPPPVVVVVVVV
 33  VVVVVVVVPPPPPPkPPPPPPPPPPPPPoPPPVVVVVVVV
 34  VVVVVVVVPPoPPPPPPPPPPPPPPPPPPPoPVVVVVVVV
 35  VVVVVVVVPPPPPkPPPPPPPPPPPPPkPPPPVVVVVVVV
 36  VVVVVVVVPPPPPPPPbPPPPPPbPPPPPPPPVVVVVVVV
 37  VVVVVVVVPPPP4PPPPPPPPPPPPPhPPPPPVVVVVVVV
 38  VVVVVVVVPPPPPPPPPPPPCPPPPPPPPPPPVVVVVVVV
 39  VVVVVVVVVVVVVVVVVVPSPVVVVVVVVVVVVVVVVVVV
```

> 위 맵은 §A-6 BFS 검증 통과 확정본(전 게이트 개방 walkable = **699칸**, orphan 0). `x`(레일 전환 레버 슬롯 3개)·`N`(굴착 로봇)은 GM3 앞 분기실 지대에 놓여 인접 상호작용.

### Legend

| 기호 | 의미 | 타일/오브젝트 | walkable | 채집 |
|---|---|---|---|---|
| `P` | 갱구 격자 강판 바닥(진입 지대) | source2 L3T-B(구리 리컬러) | O | — |
| `G` | 채굴 회랑(광차 궤도) | source2 L3T-G(+변형) | O | — |
| `B` | 최심부 갱도 바닥(대굴착기 갱, 주황 발광 리컬러) | source2 L3T-B | O | — |
| `~` | 붕락 낙석 협곡(무너진 암반, GM1 협곡 밴드) | source8 L3T-rubble | X | — |
| `V` | 경계 void | source0 T0 | X | — |
| `S` | 스폰(남, 시계탑 도시 하강) | L3T-B | O | — |
| `C` | 정비대(L3 crafting station) | workbench.tscn | 인접 | — |
| `K` | **GM1** 붕락 낙석 협곡 궤도판 배치 슬롯 | 암반 위 배치 슬롯(place_slot D279) | X→붕락 궤도판 배치 후 O | — |
| `D` | **GM2** 막힌 통풍문 병목 | vent_door.tscn | X→감압 밸브 젤 사용 후 O | — |
| `x` | **GM3** 레일 전환 레버 슬롯(3개, 미니 퍼즐) | 배치 슬롯(α/β/γ) | 배치 대상 | — |
| `M` | **GM3** 광차문 병목 | 문(3레버 전환 후 walkable) | X→퍼즐 성공 후 O | — |
| `H` | **GM4** 태엽 노심 봉헌 목 | excavator_altar.tscn | 인접(봉헌=클리어) | — |
| `O` | 대굴착기 코어(GM4 봉헌 대상 겸 K12 유니크 채집원) | excavator_core.tscn | X(인접) | **K12 심층 태엽정**(유니크) |
| `E` | 잔류 태엽 발전기(**에너지 Whisper 재획득처**) | spring_dynamo.tscn | X(인접) | — (add_energy) |
| `N` | 잔재 NPC: 갱도에 갇힌 줄 모르는 굴착 로봇 | npc_remnant.tscn | X(인접 대화) | — |
| `h` | 태엽 광석 | spring_ore.tscn | X(인접) | **K8 태엽 광석** |
| `k` | 녹슨 톱니축 | rusted_axle.tscn | X(인접) | **K9 녹슨 톱니축** |
| `o` | 갱도 석탄 | mine_coal.tscn | X(인접) | **K10 갱도 석탄** |
| `b` | 응결 수정 | condensate_crystal.tscn | X(인접) | **K11 응결 수정** |
| `1`~`4` | 랜드마크(대굴착기/실루엣/광부 로그 석판/튜토리얼 광석 수레) | — | 문맥별 | — |

- **오브젝트 walkable 규약**(L3 구역 1 계승): 채집/기능 오브젝트는 셀이 충돌체(X)지만 인접 칸에서 `OBJECT_REACH`로 채집·상호작용. §A-6 BFS의 **게이트 강제는 순수하게 void(V)·암반(~)·게이트 병목 셀(K/D/M)로만** 이뤄지며, 채집 오브젝트는 리스폰되므로 게이트로 안 쓴다(orphan 0 확인).
- **대굴착기 코어 O 특례**: `O`는 (a) K12(심층 태엽정, 유니크) 채집원이자 (b) GM4 최종 봉헌 대상이다. 최심부 갱도 방(row 1~5)에 있어 GM3 통과 후 도달. GM4 봉헌 목 H(19,3)는 offering 게이트라 지형 벽이 아니라 '클리어 행동'(구역 1 G4 대시계 = 태엽심장 설치와 동형).

## A-3. 게이트 / 랜드마크 / NPC 배치표

**게이트** (공간 통과 순서: 남→북 = GM1 → GM2 → GM3 → GM4). 게이트 타입 **4종 모두 다름**(배치→사용→전환퍼즐→체인봉헌 — level-design B "같은 타입 2연속 금지" 준수. GM1·GM3는 둘 다 '배치'지만 GM3는 3레버 전환 미니 퍼즐로 조작 결이 다르고, 사용형 GM2가 사이에 있어 비인접).

| 게이트 | 타입 | 좌표(col,row) | 이름 | 열쇠(제작 체인) | 연출 | 플레이버 |
|---|---|---|---|---|---|---|
| **GM1** | 배치형 | 병목 K (18,29)(19,29), 협곡 (8~31,29)(8~31,30) | **붕락 낙석 협곡** | **붕락 궤도판(D279)** = 정련 광석판(D278: 태엽 광석 K8 + 녹슨 톱니축 K9) + 갱도 석탄(K10) → 협곡 K에 배치 → 무너진 암반 위에 광차 궤도판이 놓이며 통행 | 낙석이 갱도를 끊었다. 정련한 궤도판을 놓으면 광차가 지나갈 길이 이어진다. `stepping_stone_placed(cell)` 재사용 | "낙석이 길을 삼켰어. …광차가 지날 판을 놓으면, 건널 수 있을까." |
| **GM2** | 사용형 | 통풍문 D (18,17)(19,17) | **막힌 통풍문** | **감압 밸브 젤(D281)** = 응결 밀봉재(D280: 태엽 광석 K8 + 응결 수정 K11) + 갱도 석탄(K10) → 막힌 통풍문에 사용(주입) → 압력이 복원되며 문 개방 | 낙석과 부식으로 잠긴 통풍문. 밸브 젤을 채우면 압력이 되살아 문이 스스로 물러난다. `item_used_on_object` | "통풍문이 막혔어. 압력이 다 새 잠금이 굳었어. …새는 압력을, 다시 붙들어야 해." |
| **GM3** | 배치형(미니 퍼즐) | 전환 레버 슬롯 x (14,12)(19,12)(24,12), 광차문 M (18,6)(19,6) | **광차 레일 전환** | **전환 레버 3종**(α D282·β D283·γ D284)을 전환 슬롯 3개에 각각 배치 → 세 레버를 다 넘기면 광차 레일이 갈래를 틀고 광차문 M 개방 | 갱도가 세 갈래로 갈라진 분기실. α/β/γ를 제자리에 세우면 레일이 옮겨지며 문이 열린다. **미니 퍼즐 1개**(3레버 전환, 순서 무관) | "갱도가 세 갈래로 갈라졌어. 레버 하나로는 아무 갈래도 못 열어. …셋을 다 넘겨야, 광차가 지나갈 길이 생겨." |
| **GM4** | 체인형 | 봉헌 목 H (19,3), 대굴착기 코어 O (20,2) | **대굴착기 재점화 = 구역 정화** | **태엽 노심(D286)** ← 감긴 태엽 씨(D285: **심층 태엽정 K12**[유니크] + 태엽 광석 K8) → 대굴착기 코어에 봉헌 | 태엽 노심을 봉헌하면, 멈췄던 대굴착기가 마지막으로 한 번 감기며 갱도 전체에 태엽의 온기가 번지고 정화 완료 → 짧은 컷신 | "여기가 마지막 갱이야. 이 노심을 대굴착기에 돌려주면… 도시를 감던 첫 태엽이, 마지막으로 한 번 감겨." |

- **GM1 재료 전부 어귀(진입 지대) 확보** — K8(태엽 광석)·K9(녹슨 톱니축)·K10(갱도 석탄)은 광산 남부 갱구 어귀(row 31~38)에서 즉시 채집. order-safe(§A-6).
- **GM3 미니 퍼즐**: 3레버 전환은 **순서 무관·재배치 가능**(gameplay-pass §3 미니 퍼즐 = 스킵 가능 원칙 계승 — 3레버를 다 만들 재료가 회랑·분기실에 충분하므로 강제 스킵 불필요, 단 재배치 허용으로 실수 복구). 퍼즐 성공 시그널 `rail_routed` → M 셀 walkable 스왑. **신규 술어 1개**(구역 1 소지형 G3처럼 저비용 조건 체크 — 3슬롯 레버 매칭, EX-L2 `data_shard_matched`와 동형·아이템 id만 교체).

**랜드마크 / NPC**

| 기호 | 좌표 | 이름 | 역할 | 플레이버 |
|---|---|---|---|---|
| `1` | (19,2) | **멈춘 대굴착기**(GM4 봉헌 지점 인접) | 최북 시각 앵커. 태엽을 되감는 곳. 정화 후 주황 발광 | "가장 깊은 갱의 굴착기. 지금은 태엽이 다 풀린 채, 아주 약하게 명멸한다." |
| `2` | (19,21) | 대굴착기 실루엣 | 중간 지대 방향 앵커(회랑에서 북쪽 굴착기가 보임) | "저 위, 어둠 속에서 거대한 무언가가 희미하게 명멸한다." |
| `3` | (27,22) | **광부 로그 석판**(진상 조각) | 회고 트리거 존. 마지막 교대 광부가 남긴, 태엽이 풀려가던 마지막 날의 기록 | "누군가 여기에 마지막 채굴 일지를 새겼다. …읽으면, 우리가 왜 멈췄는지 보인다." |
| `4` | (12,37) | 튜토리얼 광석 수레 | 첫 채집 유도 하이라이트 | "버려진 광석 수레. 태엽 광석이 하나, 아직 반쯤 감긴 채 빛나고 있다." |
| `N` | (19,10) | **잔재 NPC: 갱도에 갇힌 줄 모르는 굴착 로봇** | 광산 NPC 라인(프리픽스 `N-`). 3유형 체인(제작/배치/회고) | "…채굴 할당량, 확인 중… 오류. 다음 광차가, 왜 안 오지. 나는… 계속 파야 하는데. 교대는, 언제 오나." |

- **굴착 로봇 NPC 체인 초안**(gameplay-pass §1 3유형, 정답 아이템명 직접 호명 금지):
  - (A 제작) *"…드릴 축이 부러졌어. 성한 축을 갈아 끼워 줘. 다시 팔 수 있게."* → 정련 광석판(D278) 제작.
  - (B 배치) *"이 갱은 너무 어두워. 빛나는 걸 하나, 내가 볼 수 있는 곳에 놔 줘. 오래 캤어, 여기서."* → 발광 배치물(예: 석탄 수정 등불 D291) 1회.
  - (C 회고) *"저기 석판에… 마지막 일지가 있어. 가서 봐. 다음 광차가 왜 안 왔는지, 거기 적혀 있을 거야."* → 광부 로그 석판(3) 진상 조사(자기가 갇힌 줄 모르는 톤 = 로봇/잔영 계열의 광산판. 진상: 다음 광차는 오지 않았다 — 태엽이 다 풀려 도시가 멈췄으니까). 체인 마지막 = 광산과의 "작별".

---
