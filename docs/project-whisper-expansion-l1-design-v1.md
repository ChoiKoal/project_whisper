# Project Whisper — 확장 기획 EX-L1: 제1세계 「자연의 세계」 확장 설계 v1.0

> 작성: Kana (레벨·콘텐츠 디자인 담당) / 2026-07-08
> 대상: **Layer 1(자연) 확장 — 구역 2 「고요의 화원」 + 구역 3 「생명의 심장」** (L1은 확장 기획 5부작 중 **유일하게 2개 구역**)
> **스코프 선언: 이 문서는 설계(기획)만 확정한다. 구현은 금지** — KOAL은 전 레이어 확장의 **기획 선행**만 지시했다. 데이터/맵/코드 반영은 별도 구현 마일스톤이 이 문서와 생성 스크립트를 소비해 수행.
> 상위/Canon:
> - **L1 구역 프레임 원안**: `docs/project-whisper-level-design-v1.md` — Part A(시작의 숲 40×40 reference implementation), Part B(구역 표준 5요소·게이트 타입 분류), **B-3 나머지 4구역 스케치**(구역 2 「고요의 화원」·구역 3 「생명의 심장(허브)」의 프레임 취지). 원안이 스케치까지만 정의 → 이 문서가 **프레임 취지를 계승해 40×40 타일 단위로 구체화**한다.
> - **문서 포맷 최신 정본**: `docs/project-whisper-layer5-design-v1.md` (Part A 맵/게이트/BFS+softlock/페이싱 / Part B 원소+레시피+무결성 / Part C 아트+구현). 이 3부 구조를 계승.
> - **데이터 정합**: `game/data/recipes.json`(총 **220 레시피** + fail_recipes 3, 산출 D≤D218 / 아이템 D≤D221) · `game/data/items.json`(I=L1 채집 I1~I9, J=L2, K=L3, P=L4, S=L5, D=조합 D01~D221). **EX-L1 신규 채집 = I10~I17**(시작의 숲 I1~I9 뒤 연속), **신규 조합 산출 = D222~D254**(기존 D221 뒤 연속). 모든 신규 항목 `layer:1` 병기.
> - **공간 감사**: `tools/tools_spatial_audit.py`(L2~L5 커버) 문법을 계승한 **`tools/l1x_bfs.py`**(신규 2구역 전용 BFS)로 순서 강제 재현 증명. 맵/레시피 표는 **파이썬 생성**(`tools/l1x_map_gen.py`·`tools/l1x_recipes.py`) — 손 타이핑 금지.
> - **NPC 문법**: `docs/project-whisper-gameplay-pass-v1.md` §1(잔재 NPC = 레이어당 1~2기, 3유형 퀘스트 체인, 정답 아이템명 직접 호명 금지). **신규 구역마다 잔재 NPC 1기** 배치.
> - **재화**: `docs/project-whisper-economy-design-v1.md`(생명 Vita = L1 자연/L5 신성 계열) · `docs/project-whisper-endgame-design-v1.md`(빛의 문·E1/E2·Balance 4축 = 자연/에너지/마력/**생명**). 구역 3이 **생명 Whisper 재획득처**를 제공해 엔딩 3속성 Balance를 대비.
> 상태: **EX-L1 구역 2·3 단일 기준.** 구현 에이전트는 이 문서 + 생성 스크립트를 소비한다. 변경은 이 파일 갱신으로만.

---

## 0. 이 문서가 결정하는 것 (요약)

| # | 결정 | 근거 |
|---|---|---|
| 1 | L1을 **2개 신규 구역**으로 확장: **구역 2 「고요의 화원」**(꽃/색 테마, 40×40) + **구역 3 「생명의 심장」**(세계수 심부, L1 정화 후 개방, 40×40). 각 구역은 시작의 숲과 **별도 40×40 맵**(포탈/연결점으로 왕래) | level-design B-3 그래프(심장=허브, 화원=심장 북) 취지 계승. 시작의 숲 40×40을 물리적으로 늘리지 않고 **구역 추가**로 확장(맵 로더가 이미 다중 layout 지원) |
| 2 | 게이트는 시작의 숲·L2~L5 문법 계승 — **void 벽 + 2칸 병목**으로 물리 강제. 화원 = 게이트 3개 + 봉헌(GA1 배치→GA2 사용→GA3 배치 미니퍼즐→GA4 봉헌), 심장 = 게이트 2개 + 최심부 이벤트(GH1 사용→GH2 체인 정화) | Part B-2 게이트 타입 분류(**한 구역 같은 타입 2연속 금지**) 준수. §A-5 BFS로 순서 강제 증명(`l1x_bfs.py`, `ORDER-FORCED: PASS`) |
| 3 | 신규 채집 **8종**: 화원 I10~I13(희귀 꽃·꽃 이슬·색 모래·꽃가루), 심장 I14~I17(생명의 정수[유니크]·뿌리 수액·세계수 씨눈·심장 이끼). 신규 조합 **33종**(EX-L1-R01~R33, 산출 D222~D254) | 시작의 숲 I1~I9 뒤 연속, D221 뒤 연속. 기존 220 레시피 대비 페어 중복 0·내부 중복 0·softlock 0 실측(§B-3) |
| 4 | **구역 3 = 생명(Vita) Whisper 재획득처**(생명의 샘물 E, idempotent). 시작의 숲 G4가 준 생명을 엔딩 Balance(자연/에너지/마력/생명 4축)에서 소진했을 세이브를 위해 L1 내부 재확보 수단 제공 | economy 4축 Balance + endgame E1/E2. L5 재획득처 A/B 패턴(idempotent add) 복제. 생명은 이미 구현(L5 vita 자릿수) → 신규 재화 0 |
| 5 | **구역 3 = 진상 조각 서사 확장** — 「선배 컨스트럭터의 첫 실험 흔적」(잔재 NPC = 첫 컨스트럭터의 잔향). L1~L5 유산 조각(세계수/로그/로봇/마법사 잔영/석상) 계보에 **L1 심부 조각** 추가. 화원 NPC = 「색을 잃은 정원사 석상」 | gameplay-pass §1 잔재 NPC 문법 + endgame 진상 5조각 구조. 구역당 NPC 1기 |
| 6 | **§A-6 공간 도달성 표 = 필수 계약** — 각 게이트 열쇠 재료의 채집 소스가 게이트 **前** 구역임을 좌표로 명시(L2 기름 사고 재발 방지 — 설계 단계에서 증명). BFS 순서 증명 포함 | L2 softlock 전례. `l1x_bfs.py`(순서 강제) + `l1x_recipes.py`(재료 누적 지대 논증) 이중 증명 |
| 7 | 플레이타임: L1 합계 **30~40분 → 70~90분** (시작의 숲 40~60 + 화원 ~20 + 심장 ~15) | KOAL 확장 목표. 게이트 밀도·채집 분량으로 환산(§A-7) |

---

# Part A — 구역 2 「고요의 화원」 40×40 타일 설계

## A-1. 컨셉

시작의 숲에서 세계수를 정화한 방랑자가, 숲 북쪽 오솔길을 따라 다다르는 곳. **반쯤 무너진 꽃의 신전과 그 안뜰**이다. 한때 온갖 색으로 피어 있던 정원은 색을 잃었다 — 꽃은 형태만 남고 잿빛으로 바랬으며, 벽화는 가루가 되어 색 모래로 흩어졌고, 물감을 개던 정원사는 손을 멈춘 채 석상이 되었다. 이 세계에 **색을 돌려주는 것**이 화원의 정화다.

시작의 숲이 "생명(자연)을 되살리는 곳"이었다면, 화원은 그 자연에 **색을 입히는 곳** — 물감·꽃즙 계열이 주역이 되는, L1 안의 작은 색채 챕터다. level-design B-3의 "붉은 꽃 신전·나비 추적·물 반사 눈속임" 취지를 계승하되, MVP 부담이 큰 나비 추적·왜곡 연출은 빼고 **색 조합(물감) 퍼즐**로 구체화한다(정적 스프라이트 눈속임 전제, GDD §3.2 경고 준수).

무드: 시작의 숲 초록 base 위에 **바랜 파스텔**(잿빛 섞인 분홍·연보라). 정화가 진행될수록(게이트를 풀수록) 채도가 돌아온다 — GA1 앞은 거의 무채색, 신전(최북)은 무지개. **엔진 틴트(CanvasModulate) + 리컬러**로 팔레트를 늘리지 않고 표현(아트가이드 §2·§3). 시작의 숲과 뚜렷이 구분되는 **"색이 빠졌다가 돌아오는" 구역**.

**진입점**: 시작의 숲 세계수 구역(북쪽)에서 오솔길로 연결 → 화원 남쪽 스폰 (19,39). 시작의 숲 클리어(G4) 후 개방(북쪽 오솔길에 색이 어렴풋이 비치기 시작 = 개방 신호). 왕래는 홈/구역 포탈 패턴 재사용(§Part C).

## A-2. ASCII 맵 (40행 × 40열)

- **좌표 규약**: `(col, row)`, 좌상단 = (0,0). row 0 = **북(무지개 신전)**, row 39 = **남(시작의 숲 연결 스폰)**. col 0 = 서.
- **읽는 방향**: 플레이어는 아래(남, 숲에서 진입)에서 위(북, 신전)로 올라가며 **색을 되찾는다**. 시작의 숲의 수직 여정 문법 계승.
- 아래 40자×40행은 **`tools/l1x_map_gen.py`가 생성**(구역 사각형·병목·채집 배치를 코드화, 손 타이핑 금지) → 그대로 `game/data/l1g_map_layout.txt`가 된다. ruler/행번호는 문서 표기용, 파일엔 제외.

```
col: 0         1         2         3
     0123456789012345678901234567890123456789
  0  VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
  1  VVVVVVVVVVVVBBBBBBBBBBBBBBBBVVVVVVVVVVVV
  2  VVVVVVVVVVVVBBByBBBBBBByBBBBVVVVVVVVVVVV
  3  VVVVVVVVVVVVBBBBBBB1BBBBBBBBVVVVVVVVVVVV
  4  VVVVVVVVVVVVBBBBBBBHBBBBBBBBVVVVVVVVVVVV
  5  VVVVVVVVVVVVBfBBBBBBBBBBBBfBVVVVVVVVVVVV
  6  VVVVVVVVVVVVBBzBBBBBBBBBzBBBVVVVVVVVVVVV
  7  VVVVVVVVVVVVBBBBBBBBBBBBBBBBVVVVVVVVVVVV
  8  VVVVVVVVVVVVBBBBBBBBBBBBBBBBVVVVVVVVVVVV
  9  VVVVVVVVVVVVVVVVVVMMVVVVVVVVVVVVVVVVVVVV
 10  VVVVVVVVVVVVVVVVVVGGVVVVVVVVVVVVVVVVVVVV
 11  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 12  VVVVVVVVGGGGGGGGGGGNGGGGGGGGGGGGVVVVVVVV
 13  VVVVVVVVGGGGyGGGGGGGGGGGGGGyGGGGVVVVVVVV
 14  VVVVVVVVGGGGGGxGGGGxGGGGxGGGGGGGVVVVVVVV
 15  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 16  VVVVVVVVGGGfGGGGGGGGGGGGGGGGfGGGVVVVVVVV
 17  VVVVVVVVGGdGGGGGzGGGGGGzGGGGGdGGVVVVVVVV
 18  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 19  VVVVVVVVVVVVVVVVVVAAVVVVVVVVVVVVVVVVVVVV
 20  VVVVVVVVVVVVVVVVVVPPVVVVVVVVVVVVVVVVVVVV
 21  VVVVVVVVGGGGGGGGGGG2GGGGGGGzGGGGVVVVVVVV
 22  VVVVVVVVGGfGGGGGGGfGGyGGGGGGGGGGVVVVVVVV
 23  VVVVVVVVGGGGGGfGGGGGGGGGGGfGGGGGVVVVVVVV
 24  VVVVVVVVGGGzGGGGGGGGGGfGGGGGGGGGVVVVVVVV
 25  VVVVVVVVGGGGGGGGyGGGGGGGGGGGGfGGVVVVVVVV
 26  VVVVVVVVGyGGdGGGGGGGGGGGzGGGGGGGVVVVVVVV
 27  VVVVVVVVGGGGGGGGGGGGdGGGGGGGdGGGVVVVVVVV
 28  VVVVVVVVGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVV
 29  VVVVVVVV~~~~~~~~~~KK~~~~~~~~~~~~VVVVVVVV
 30  VVVVVVVV~~~~~~~~~~KK~~~~~~~~~~~~VVVVVVVV
 31  VVVVVVVVPPPPPPPPPPPPPPPPPPPPPPPPVVVVVVVV
 32  VVVVVVVVPPPfPPPPPPPPPPPPfPPPPPdPVVVVVVVV
 33  VVVVVVVVPPPPPPyPPPPPPPPPPPPPdPPPVVVVVVVV
 34  VVVVVVVVPPdPPPPPPPPPPPPPPPPPPPPPVVVVVVVV
 35  VVVVVVVVPPPPPfPPPPPPPPPPPPPfPPPPVVVVVVVV
 36  VVVVVVVVPPPPPPPPzPPPPPPzPPPPPPPPVVVVVVVV
 37  VVVVVVVVPzPP4PPPPPPPPPPPPPyPPPPPVVVVVVVV
 38  VVVVVVVVPPPPPPPPPPPPCPPPPPPPPPPPVVVVVVVV
 39  VVVVVVVVVVVVVVVVVVPSPVVVVVVVVVVVVVVVVVVV
```

> 위 맵은 §A-5 BFS 검증 통과 확정본(전 게이트 개방 walkable = **719칸**, orphan 0). `x`(색맞춤 화단 슬롯 3개)·`N`(정원사 석상)은 GA3 앞 안뜰 지대에 놓여 인접 상호작용.

### Legend

| 기호 | 의미 | 타일/오브젝트 | walkable | 채집 |
|---|---|---|---|---|
| `P` | 꽃잎 포장(안뜰 바닥) | source2 T2A(리컬러) | O | — |
| `G` | 화단 풀 | source2 T2A(+변형) | O | — |
| `B` | 신전 바닥(무지개, 리컬러) | source2 T2A | O | — |
| `~` | 색의 여울(꽃물, GA1 물 밴드) | source8 T5A | X | — |
| `V` | 경계 void | source0 T0 | X | — |
| `S` | 스폰(남, 시작의 숲 연결) | T2A | O | — |
| `C` | 솥단지 | cauldron.tscn | 인접 | — |
| `K` | **GA1** 색의 여울 디딤돌 배치 슬롯 | 물 위 배치 슬롯(place_slot D223) | X→꽃돌다리 배치 후 O | — |
| `A` | **GA2** 시든 아치 병목 | wilted_arch.tscn | X→개화 물감 사용 후 O | — |
| `x` | **GA3** 색맞춤 화단 슬롯(3개, 미니 퍼즐) | 배치 슬롯(빨/노/파) | 배치 대상 | — |
| `M` | **GA3** 색의 문 병목 | 문(3색 완성 후 walkable) | X→퍼즐 성공 후 O | — |
| `H` | **GA4** 색의 봉헌 목(무지개 분수) | color_font.tscn | 인접(봉헌=클리어) | — |
| `N` | 잔재 NPC: 색을 잃은 정원사 석상 | npc_remnant.tscn | X(인접 대화) | — |
| `f` | 희귀 꽃 | rare_flower.tscn | X(인접) | **I10 희귀 꽃** |
| `d` | 꽃 이슬 | dew.tscn | X(인접) | **I11 꽃 이슬** |
| `z` | 색 모래 | color_sand.tscn | X(인접) | **I12 색 모래** |
| `y` | 꽃가루 | pollen.tscn | X(인접) | **I13 꽃가루** |
| `1`~`4` | 랜드마크(무지개 분수/정원사 석상 실루엣/튜토리얼 꽃) | — | 문맥별 | — |

- **오브젝트 walkable 규약**(시작의 숲 계승): 채집/기능 오브젝트는 셀이 충돌체(X)지만 인접 칸에서 `OBJECT_REACH`로 채집·상호작용. §A-5 BFS의 **게이트 강제는 순수하게 void(V)·물(~)·게이트 병목 셀(K/A/M)로만** 이뤄지며, 채집 오브젝트는 리스폰되므로 게이트로 안 쓴다(orphan 0 확인).

## A-3. 게이트 / 랜드마크 / NPC 배치표 (고요의 화원)

**게이트** (공간 통과 순서: 남→북 = GA1 → GA2 → GA3 → GA4). 게이트 타입 **4종 모두 다름**(배치→사용→배치퍼즐→체인봉헌 — B-2 "같은 타입 2연속 금지" 준수. GA1·GA3는 둘 다 '배치'지만 GA3는 3색 미니 퍼즐로 조작 결이 다름).

| 게이트 | 타입 | 좌표(col,row) | 이름 | 열쇠(제작 체인) | 연출 | 플레이버 |
|---|---|---|---|---|---|---|
| **GA1** | 배치형 | 병목 K (18,29)(19,29)(18,30)(19,30) | **색의 여울** | **꽃돌다리(D223)** = 색 모래 반죽(D222)+돌(I8) → 색의 여울 K에 배치 → 물 위에 색 밴 징검다리가 놓이며 통행 | 잿빛 꽃물이 흐르는 얕은 여울. 색 밴 돌을 놓으면 다리가 생기고, 물살에 색이 살짝 번진다. `stepping_stone_placed(cell)` 재사용 | "물에 색이 다 씻겨 나갔어. …근처에 색 밴 모래가 있네. 돌에 발라 굳히면, 건널 수 있을까." |
| **GA2** | 사용형 | 아치 A (18,19)(19,19) | **시든 아치** | **개화의 물감(D225)** = 꽃즙(D224)+꽃가루(I13) → 시든 아치에 사용 → 마른 꽃이 개화하며 통로 개방 | 색을 잃고 오므라든 꽃 아치. 개화의 물감을 뿌리면 꽃이 색을 되찾으며 활짝 열린다. `item_used_on_object` | "아치의 꽃이 다 오므라들었어. 목말라 보여. …색을, 다시 먹여줘." |
| **GA3** | 배치형(미니 퍼즐) | 화단 슬롯 x (14,14)(19,14)(24,14), 문 M (18,9)(19,9) | **색맞춤 화단** | **3색 물감**(붉은 D226·노란 D227·푸른 D228)을 화단 슬롯 3개에 각각 배치 → 세 색이 갖춰지면 색의 문 M 개방 | 정원사가 색을 맞추던 화단 셋. 빨/노/파를 제자리에 놓으면 문이 색으로 물들며 열린다. **미니 퍼즐 1개**(3색 배치, 순서 무관) | "화단이 셋인데, 다 비었어. 빨강, 노랑, 파랑… 정원사가 색을 맞추던 자리야. 세 색을 다 채워야, 문이 열려." |
| **GA4** | 체인형 | 봉헌 목 H (19,4), 무지개 분수 (19,3) | **색의 봉헌 = 화원 정화** | **색의 정수(D230)** = 무지개 물감(D229: 붉은+노란) + 푸른 물감(D228) → 무지개 분수에 봉헌 | 색의 정수를 분수에 부으면, 화원 전체에 색이 물결처럼 번지며 정화 완료 → 짧은 컷신 | "여기가 마지막이야. 이 정수를 분수에 부으면… 화원에, 색이 전부 돌아와." |

- **GA1 재료 I8(돌)은 시작의 숲에서 확보** — 화원 진입 전제(시작의 숲 클리어 후 개방)이므로 order-safe(§A-6). 색 모래 반죽(D222)은 화원 진입 지대(안뜰)에서 I12+I11로 즉시 제작.
- **GA3 미니 퍼즐**: 3색 배치는 **순서 무관·재배치 가능**(gameplay-pass §3 미니 퍼즐 = 스킵 가능 원칙 계승 — 3색을 다 만들 재료가 안뜰에 충분하므로 강제 스킵 불필요, 단 재배치 허용으로 실수 복구). 퍼즐 성공 시그널 `color_bed_solved` → M 셀 walkable 스왑.

**랜드마크 / NPC**

| 기호 | 좌표 | 이름 | 역할 | 플레이버 |
|---|---|---|---|---|
| `1` | (19,3) | **무지개 분수**(GA4 봉헌 지점) | 최북 시각 앵커. 색을 돌려주는 곳. 정화 후 무지개 발광 | "색이 솟던 분수. 지금은 잿빛 물만 고여 있다." |
| `2` | (19,21) | 정원사 석상 실루엣 | 중간 지대 방향 앵커(북쪽 안뜰의 석상이 여기서 보임) | "저 위에, 누군가 서 있는 것 같다. …움직이지는 않는다." |
| `4` | (11,37) | 튜토리얼 꽃 군락 | 첫 채집 유도 하이라이트 | "바랜 꽃 무더기. 색은 없어도, 꽃은 꽃이니까." |
| `N` | (19,12) | **잔재 NPC: 색을 잃은 정원사 석상** | 화원 NPC 라인(프리픽스 `N-`). 3유형 체인(제작/배치/회고) | "…물감이, 어디 갔더라. 색을 맞춰야 하는데. 손이, 굳어서." |

- **정원사 석상 NPC 체인 초안**(gameplay-pass §1 3유형, 정답 아이템명 직접 호명 금지):
  - (A 제작) *"…이슬에 노란 걸 풀면, 볕의 색이 나와. 그걸 한 통."* → 노란 물감(D227) 제작.
  - (B 배치) *"내가 보이는 곳에, 붉은 걸 하나 놓아줘. 오래 못 봤어, 그 색을."* → 붉은 계열 배치물 1회.
  - (C 회고) *"…저 석상, 낯이 익어. 손 모양이… 나랑 똑같잖아. 왜 저기 서 있지."* → 정원사 석상 진상 조사(자기가 석화된 걸 모르는 톤 = 마법사 잔영 계열의 화원판). 체인 마지막 = 화원과의 "작별".


