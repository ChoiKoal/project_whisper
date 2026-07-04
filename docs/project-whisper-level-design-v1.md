# Project Whisper — 레벨 디자인 v1.0 (Layer 1 · 시작의 숲 중심)

> 작성: Kana (레벨 디자인 담당) / 2026-07-05
> 상위 문서: `project-whisper-gdd-v0.1.md`(§3), `project-whisper-recipes-v1.md`(G1~G4·아이템), `project-whisper-art-style-guide.md`(§3.1)
> Canon: `attachments/message.txt`(원본 세계관), 구현 API: `project-whisper/handoff-m2.md`
> 상태: **레벨 디자인 단일 기준.** GDD의 약한 §3.2를 이 문서가 채운다. 변경은 이 파일 갱신으로만.
> 확정 시간 스펙 반영: 하루=실시간 15분(낮 9분/저녁~새벽 6분), Rest Stump 스킵, G3 힌트.

---

## 0. 이 문서가 결정하는 것 (요약)

| # | 결정 | 왜 |
|---|---|---|
| 1 | 맵은 **남서 스폰 → 북 세계수**의 수직 여정. 게이트 G1(개울)→G2(덤불)→G3(밤 꽃길) 순서로만 통과 | 원본의 "연못→시냇가→풀언덕→세계수맵" 지형 순서를 좌표로 고정. 순환 의존 없는 recipes-v1 게이트 순서와 1:1 대응 |
| 2 | 게이트는 **void 벽 + 1칸 병목**으로 물리적으로 강제 (개울=3칸 물폭, 덤불=1칸, 밤길=2칸 N) | "우회 경로 없음" 요구를 맵 지오메트리로 증명 가능하게. Part A §5 flood-fill로 검증 완료 |
| 3 | 일반 재료 **리스폰(무한)**, 세계수 정수만 유니크 1회 | GDD §2.1 재화 정책 제안 채택 + handoff-m2 `unique=true`와 일치. VOID 테마는 "채집=소비"로 유지하되 노가다 방지 |
| 4 | 낮/밤은 **GameState.game_time 기반 CanvasModulate 틴트**, 세계수 구역은 밤에만 개방 | 아트가이드 §3의 "팔레트 늘리지 말고 엔진 틴트" 방침. G3 시간 게이트를 데이터 아닌 코드로 |
| 5 | ASCII 맵을 **map_layout.txt + legend.json**으로 파싱 → 기획 수정 = 텍스트 수정 | handoff-m2의 tileset source-id 체계와 호환. 디자이너가 Godot 안 열고 지형 수정 가능 |

---

# Part A — 시작의 숲 40×40 타일 단위 설계 ★핵심★

## A-1. ASCII 맵 (40행 × 40열)

- **좌표 규약**: `(col, row)`, 좌상단 = (0,0). row 0 = **북쪽(세계수)**, row 39 = **남쪽(스폰 연못)**. col 0 = 서, col 39 = 동.
- **읽는 방향**: 플레이어는 아래(남서 스폰)에서 위(북 세계수)로 올라간다.

```
col: 0         1         2         3
     0123456789012345678901234567890123456789
 0   VVVVVVVVVVVVGGGGmmmmmmmmGGGGVVVVVVVVVVVV
 1   VVVVVVVVVVVVGGGGmmmmmmmmGGGGVVVVVVVVVVVV
 2   VVVVVVVVVVVVGGGGGGGOOGGGGGGGVVVVVVVVVVVV
 3   VVVVVVVVVVVVGGGGGGGOOGGGGGGGVVVVVVVVVVVV
 4   VVVVVVVVVVVVTGGGGGGGGGGGGGGTVVVVVVVVVVVV
 5   VVVVVVVVVVVVGTGGGGGGGGGGGGTGVVVVVVVVVVVV
 6   VVVVVVVVVVVVGGTGGGGGGGGGGTGGVVVVVVVVVVVV
 7   VVVVVVVVVVVVVVVVVVVNNVVVVVVVVVVVVVVVVVVV
 8   VVVVVVVVVVGGGGGGGGGGGGGGGGGGGGVVVVVVVVVV
 9   VVVVVVVVVVGGGGGGTGGGGGGTGGGGGGVVVVVVVVVV
10   VVVVVVVVVVGGGGTGGFGGGGFGGTGGGGVVVVVVVVVV
11   VVVVVVVVVVGGGTGGGGG3GGGGGGTGGGVVVVVVVVVV
12   VVVVVVVVVVGGTGGFGGGFGGGGFGGTGGVVVVVVVVVV
13   VVVVVVVVVVGTGGGGFGGGFGFGGGGGTGVVVVVVVVVV
14   VVVVVVVVVVVVTVVVVVFVVFVVVVVTVVVVVVVVVVVV
15   VVVVVVVVVVVVVVVVVVgVVVVVVVVVVVVVVVVVVVVV
16   VVVVVVVVVVVVVVVVVVBVVVVVVVVVVVVVVVVVVVVV
17   VVVVgggggggggggggggggggggggggggVVVVVVVVV
18   VVVVggggggggRggggggsgggggFgggggVVVVVVVVV
19   VVVVgggggFgggggTgggggsggggRggggVVVVVVVVV
20   VVVVgggggggFggggFgg2ggRggggTgggVVVVVVVVV
21   VVVVggTggggggsggggggggggFggggggVVVVVVVVV
22   VVVVgggFggRgggFgggggTgggggFggggVVVVVVVVV
23   VVVGggggggggggggggFggggggggggggVVVVVVVVV
24   VVVWWWWWWWWWWWWWKWWWWWWWWWWWWWWVVVVVVVVV
25   VVVWwwwwwwwwwwwwKwwwwwwwwwwwwwWVVVVVVVVV
26   VVVWWWWWWWWWWWWWKWWWWWWWWWWWWWWVVVVVVVVV
27   VVVGGGGGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVVV
28   VVVGGGGGGGGGGGMMGGGGGGGGGGGGGGGGVVVVVVVV
29   VVVGGGGGRGGGGGGGGGRGGGGGGGGGGGGVVVVVVVVV
30   VVVGGGGGGG4GGGGGDDDDDGFGGsGGGGGVVVVVVVVV
31   VVVGGGGGGTGGGGG4DDDDDGGFGGsGGGGVVVVVVVVV
32   VVVGGGGGGGGGSCGGGGGGGGGGGGGGGGGVVVVVVVVV
33   VVVGWWWWWWWWUGGGGGGGGGGGGGGGGGGVVVVVVVVV
34   VVVGWwwwwwWWGGGGGGGGGGGGGGGGGGGVVVVVVVVV
35   VVVGWwwwwwWWGGFGGGGGGGGGGGGGGGGVVVVVVVVV
36   VVVGWwwwwwWWGGGGTGGGGGGGGGGGGGGVVVVVVVVV
37   VVVGWwwwwwWWGGGGGGGGGGRGGGGGGGGVVVVVVVVV
38   VVVGWWWWWWWWGGTGGGGGFGGGGGGGGGGVVVVVVVVV
39   VVVGGGGGGGGGGGGGGGGGGGGGGGGGGGGVVVVVVVVV
```

> row 28은 정렬 편의로 콜론 표에 M(진흙밭 I3)을 (14,28)·(15,28)에 둔다. 위 40×40 텍스트는 그대로 `map_layout.txt`가 된다(Part C).

### Legend

| 기호 | 의미 | 타일/오브젝트 ID | walkable |
|---|---|---|---|
| `G` | 기본 풀밭 | T2A | O |
| `g` | 풀 변형 (풀언덕) | T2B/T2C/T2D 랜덤 | O |
| `D` | 흙길 | T1 | O |
| `M` | 진흙 (속도 디버프) | T4 | O (감속) |
| `W` | 물 (연못/개울) | T5A | X |
| `w` | 물 변형 (깊은 청록) | T5B | X |
| `m` | 신비의 물 (세계수 생명수) | T5B+발광 | X |
| `V` | 경계 void (지형 밖) | — | X |
| `S` | 스폰 지점 | — (T2A 위) | O |
| `C` | 솥단지 | O(cauldron) | 인접 상호작용 |
| `U` | 이끼 낀 그루터기 (Rest Stump) | O(rest_stump) | 인접 상호작용 |
| `B` | 마른 덤불 (G2 게이트) | O(bush_dry) | X→개화 후 O |
| `K` | 디딤돌 지점 (G1 게이트) | 물 위 배치 슬롯 | 배치 후 O |
| `N` | 밤 꽃길 입구 (G3 게이트) | O(night_bloom_gate) | 밤에만 O |
| `O` | 세계수 | O0 | X(인접 채집) |
| `T` | 나무 | O2A~O2F | X(인접 채집) |
| `F` | 꽃 | O1A~O1E | X(인접 채집) |
| `R` | 바위 | O3A/O3B | X(인접 채집) |
| `s` | 돌 | O6 | X(인접 채집) |
| `1`~`4` | 랜드마크(아래 표) | — | 문맥별 |

- **오브젝트 walkable 규약**: 나무/꽃/바위/돌/세계수는 셀 자체가 충돌체(X)지만, 플레이어는 인접 칸에서 `OBJECT_REACH`(140px, handoff-m2)로 채집한다. Part A §5 경로 검증에서는 "오브젝트=지형 위에 얹힌 것"으로 보고 그 셀도 통행 가능으로 취급 → 즉 **게이트 강제는 순수하게 물(W/w), void(V), 덤불(B), 밤길(N)로만** 이뤄진다(오브젝트로 길을 막지 않음. 오브젝트는 리스폰되므로 게이트로 못 씀).

## A-2. 게이트 / 랜드마크 표

| 기호 | 좌표(col,row) | 이름 | 연출 | 필요 오브젝트/조건 | 플레이버 텍스트 |
|---|---|---|---|---|---|
| `S` | (12,32) | 스폰 (여명의 연못가) | 화면 페이드 인, 캐릭터 idle, 연못 잔물결 | — | "…여기서부터 시작이다. 아직 아무것도 만들지 않은 세계." |
| `C` | (13,32) | 솥단지 | 스폰 바로 옆, 보라 발광 은은 | — | "조합하고 싶은 것을 넣어 봐." |
| `U` | (12,33) | 이끼 낀 그루터기 (Rest Stump) | 앉기 모션 → 화면 어두워짐 → 다음 저녁으로 시간 점프 | 상호작용 1회 | "잠깐 쉬어 갈까. …눈을 뜨면 저녁이겠지." |
| `1` | 세계수 (19,2)/(20,2)/(19,3)/(20,3) | 세계수 (O0) | 밤에 보라 발광 극대화, 반짝임 파티클 | G3 통과 후 도달 | "이 세계가 시작된 곳. 마지막 생명이 여기 남아 있다." |
| `2` | (19,20) | 언덕 마루 케른(돌무지) | 실루엣 랜드마크, 북쪽 덤불 병목이 여기서 보임 | — | "돌을 쌓은 흔적. 누가, 언제?" |
| `3` | (19,11) | 접근로 문턱 표석 | G3 힌트 트리거 존 | — | "꽃봉오리가 닫혀 있다… 밤을 기다리는 걸까." (**확정 힌트**) |
| `4` | (10,30)/(15,31) | 첫 나무 군락 | 튜토리얼 채집 유도 하이라이트 | — | "채집해 볼까. 나무에서 '나무'를." |
| **G1** | 디딤돌 (16,24)(16,25)(16,26) | 시냇가 개울 | 물이 길을 3칸 폭으로 끊음. 디딤돌 배치 시 물→통행 가능 스왑, `stepping_stone_placed` | **디딤돌**(D14 = 바위+돌)을 물 타일 K에 배치 | "물살에 발이 잠긴다. 바위와 돌이 쌓인 흔적이 옆에 있다." |
| **G2** | 마른 덤불 (18,16) | 언덕 북쪽 병목 | 덤불이 1칸 통로를 막음. 물 사용 시 개화 애니메이션 → 통로 개방, `item_used_on_object` | **물 아이템**(I7)을 덤불에 사용 | "말라 있다… 목말라 보인다." |
| **G3** | 밤 꽃길 입구 (19,7)(20,7) | 세계수 구역 입구 | 낮에는 꽃 닫힘(통행 X), 밤이 되면 꽃길 개화 발광 → 통행 O | **저녁~새벽 시간대** (game_time) | "꽃봉오리가 닫혀 있다… 밤을 기다리는 걸까." |
| **G4** | 세계수 채집 → VOID 심기 | 클리어 | 세계수 정수 채집(1회) → 조합 체인 → 어린 세계수를 VOID에 심기 → 컷신, `world_tree_planted` | 세계수 정수(I9)→생명수(D19)→빛나는 새싹(D20)→어린 세계수(D22) | "비워낸 자리에, 다시 생명을." |

## A-3. 동선 요구 충족 매핑

| 원본/요구 동선 | 맵상 위치 | 근거 |
|---|---|---|
| 스폰 = 남서 연못가, C·U 인접 | S(12,32), C(13,32)[동1칸], U(12,33)[남1칸], 연못 W(4~11,33~38) | 원본 "연못 주변 시작" + Rest Stump 스펙 |
| 튜토리얼 채집장 (I1,I2,I4,I5,I6,I8 = 스폰 15칸 내) | 아래 §A-4 거리표 | recipes-v1 첫 조합 재료 확보 |
| I7 = 연못 | W(4~11, 33~38), 스폰 서쪽 인접 | 원본 물 타일 |
| I3 = 진흙밭 | M(14,28)(15,28), 스폰 북 4칸 | 원본 T4 |
| 개울 가로지름 (G1) | 물 밴드 row24~26 전폭, K(16,24~26) | recipes-v1 G1 |
| 풀 언덕 (채집 풍부) | g 지대 row17~23 | 원본 "시냇가 근처 풀 언덕 많음" |
| 북쪽 길목 G2 | B(18,16) 1칸 병목 | recipes-v1 G2 |
| 세계수로 이어지는 구간 (흙길 없음·울창·꽃 많음) | 접근로 row8~13: **D(흙길) 0개**, T 다수(가장자리), F 다수(내부) | 원본 "흙타일 없음, 나무 울창, 꽃 많음" |
| G3 입구 | N(19,7)(20,7) | recipes-v1 G3 |
| 세계수 맵 (O + 뒤 m, 세계수 근처 나무 감소) | O(19~20,2~3), m(16~23,0~1) 북쪽=뒤, 나무는 가장자리(row4~6)만 sparse | 원본 "세계수 뒤 신비의 물, 가까울수록 나무 감소" |

## A-4. 튜토리얼 채집장 — 스폰 근접도 (Chebyshev 거리, 스폰 (12,32) 기준)

| 아이템 | 소스 | 대표 좌표 | 거리 | 15칸 내? |
|---|---|---|---|---|
| I7 물 | 연못 W | (11,33) | 1 | O |
| I4 나무 | 나무 군락 `4` | (10,30) | 2 | O |
| I5 꽃 | 꽃 F | (14,35) | 3 | O |
| I1 흙 | 흙길 D | (16,30) | 4 | O |
| I3 진흙 | 진흙밭 M | (14,28) | 4 | O |
| I6 바위 | 바위 R | (8,29) | 4 | O |
| I2 풀 | 풀밭 G(전역) / 풀덤불 | 스폰 발밑 | 0 | O |
| I8 돌 | 돌 s | (13,21) | 11 | O |

- I8(돌)만 언덕 초입(11칸)에 있음 — 의도적: 디딤돌(D14=바위+돌) 재료 중 돌을 개울 **바로 앞** 언덕에 배치해, "개울에 막힘 → 근처 돌 채집 → 조합 → 디딤돌" 발견 루프가 물리적으로 이어지게. (근거: recipes-v1 §4 "G1 시냇가 옆 바위와 돌이 쌓인 흔적" 환경 힌트)

## A-5. 셀프 검증 — 게이트 순서 강제 증명 (flood-fill)

스폰(12,32)에서 4방향 BFS. 통행 규칙: `W/w/m/V` = 벽, `B`=G2 열려야 통행, `K`=디딤돌 배치돼야 통행, `N`=밤이어야 통행, 그 외(풀/흙/진흙/오브젝트 셀 포함)=통행.

| 게이트 상태 | 개울 북(hill) 도달 | G2 북(approach row13) 도달 | 세계수 도달 | 판정 |
|---|---|---|---|---|
| 아무 것도 안 함 | **X** | X | **X** | 개울에서 막힘 → G1 강제 |
| K(디딤돌)만 | O | **X** | X | 언덕까진 가나 덤불에서 막힘 → G2 강제 |
| K+B(덤불 개화) | O | O | **X** | 접근로까진 가나 밤길 못 넘음 → G3 강제 |
| K+B+N(밤) | O | O | **O** | 클리어 경로 성립 |

- **결론**: 세계수는 **G1→G2→G3 순서로만** 도달 가능. 각 단계에서 앞 게이트를 풀지 않으면 다음 지대에 진입 불가. **우회 경로 없음**.
- 우회가 없는 이유(지오메트리): (a) 개울은 col3~30 전폭 물, 양옆 col0~2/31~39는 void → K(col16)만 유일 크로스. (b) G2는 row14~16이 void 벽, col18 한 칸(덤불)만 열림. (c) G3는 row6~7이 void 벽, N(col19~20)만 열림.
- recipes-v1 §2 "순환 의존 없음"과 정합: G1·G2는 기본 채집물만으로 해결(디딤돌=바위+돌, 물=연못 채집) → G3은 시간만 → G4 재료(세계수)는 G3 통과 후 획득. 시간 게이트가 재료 게이트보다 뒤에 오므로 데드락 없음.

## A-6. 페이싱 타임라인 (목표: G4 클리어 40~60분)

| 시점 | 사건 | 유도 장치 |
|---|---|---|
| 0~2분 | 이동/채집 학습 | `4`(나무 군락) 하이라이트, 첫 "+1 나무" 플로팅 라벨 |
| **≤5분** | **첫 조합** | 솥단지 C가 스폰 옆. 근처 채집물 2종(예: 풀+물=이끼)으로 즉시 성공 경험. 실패 시 미소모+힌트 게이지(recipes-v1 §4) |
| 5~10분 | 개울 도달, 막힘 인지 | 개울 앞 환경 힌트 "바위와 돌이 쌓인 흔적". 돌(I8)이 언덕 초입에 보임 |
| **~10분** | **G1 돌파** (디딤돌 배치) | 바위(R, 스폰 근처)+돌(s) 채집→D14 조합→K 배치. "배치" 조작 학습 |
| 10~20분 | 풀 언덕 채집 풍부 | 언덕(g)에 F/R/s/T 밀집 → 인벤토리 채우며 자연스레 북상. 마루 케른`2`가 다음 병목(덤불)을 시야에 넣어줌 |
| **~20분** | **G2 돌파** (물→덤불) | 덤불 "목말라 보인다" → 물(I7) 사용. "사용" 조작 학습 |
| 20~30분 | 접근로 진입, G3 앞 대기 | 표석`3`에서 힌트 "꽃봉오리가 닫혀 있다… 밤을 기다리는 걸까" 발동 |
| **~30분** | **G3: 그루터기 스킵 학습** | 낮이면 통행 불가 → 스폰의 Rest Stump `U`로 돌아가 휴식→다음 저녁 점프. "시간을 넘긴다" 학습. (돌아가는 왕복이 곧 시간 스킵의 필요성을 체감시킴) |
| 30~50분 | 세계수 맵 탐험, 세계수 채집 | 밤 발광 연출, 세계수 정수 I9 유니크 채집 |
| **40~60분** | **G4 클리어** | I9→생명수→빛나는 새싹→어린 세계수 조합 체인. 자기가 만든 VOID(채집으로 비운 셀)에 심기 → 컷신 |

- 첫 조합 ≤5분 보장 근거: 솥단지가 **스폰 인접(1칸)**, 조합 재료 2종이 반경 3칸 내. 튜토리얼 프롬프트로 유도.
- G3에서 그루터기 스킵을 "왕복"으로 학습시키는 이유: 시간 시스템을 강제 튜토리얼 팝업 대신 **필요에 의해 스스로 발견**하게. 낮 9분/밤 6분(확정 스펙)이라, 처음 낮에 도착하면 최대 ~9분 대기 대신 스킵을 택하게 됨.

## A-7. 오브젝트 밀도 & 리스폰 정책

**밀도 (walkable 100칸당, 맵 전체 walkable ≈ 673칸 기준)**

| 오브젝트 | 총 개수 | 100칸당 | 배치 원칙 |
|---|---|---|---|
| 나무 T | 25 | 3.7 | 접근로/세계수맵 가장자리에 집중(울창감). 세계수 근처는 sparse |
| 꽃 F | 23 | 3.4 | 접근로 내부·언덕에 집중(원본 "꽃 많음") |
| 바위 R | 7 | 1.0 | 언덕·스폰에 산재(디딤돌 재료) |
| 돌 s | 5 | 0.7 | 언덕 초입·스폰(디딤돌 재료). 희소 = 조합 발견 유도 |
| 풀 | 전역(g/G) | — | 타일 채집이므로 개수 무의미. 무한 |

- 구역별 편차(의도적): 스폰=중밀도(튜토리얼), 언덕=**고밀도**(채집 풍부 요구), 접근로=나무/꽃 고밀도·바위/돌 0(흙길 없고 울창한 원시림 톤), 세계수맵=저밀도(정적·신성).

**리스폰 정책 (추천)**

| 대상 | 정책 | 근거 |
|---|---|---|
| 일반 오브젝트(T/F/R/s) | **채집 후 실시간 ~하루(15분) 뒤 같은 셀에 리스폰** | GDD §2.1 "일반 재료 리스폰(무한)". Echo 미구현(MVP)이라 재채집 노가다를 리스폰이 완화. 하루 주기로 묶으면 밤낮 사이클과 리듬 일치 |
| 타일 채집(풀/흙/진흙/물) | **리스폰 안 함 → VOID로 영구** | recipes-v1 테마 핵심("채집=세계를 비움"). 타일이 되살아나면 VOID 딜레마가 죽음. 클리어용 VOID를 플레이어가 직접 만들게 함 |
| 세계수 정수(I9) | 유니크, **리스폰 없음**, 채집 후에도 세계수 오브젝트는 잔존 | 원본 "1회만 채집, 채집 후 사라지지 않는 유니크템" + handoff-m2 `unique=true, _spent` |

- 왜 오브젝트만 리스폰: 오브젝트를 게이트로 쓰지 않으므로(§A-1) 리스폰돼도 진행이 깨지지 않음. 타일은 게이트/테마에 얽혀 있어 고정.

---

# Part B — 레벨 디자인 문법 (전 구역 공통)

## B-1. 구역 표준 구성 (5요소)

모든 구역은 아래 5개를 최소 1개씩 갖는다. 시작의 숲이 이 문법의 기준점(reference implementation).

| 요소 | 정의 | 시작의 숲 예 |
|---|---|---|
| **허브** | 채집·조합·귀환의 중심. 스폰/솥단지/휴식 | 남서 연못가(S·C·U) |
| **게이트** | 진행을 잠그는 장치. 아래 타입 분류 참조 | G1 개울, G2 덤불, G3 밤길 |
| **보상 포켓** | 게이트 우회 아닌, 메인 동선 옆 채집 밀집 구역 | 풀 언덕(g 지대) |
| **비밀 1개** | 필수 아님, 관찰력 보상. 도감/플레이버 아이템 | (제안) 연못 남동 구석 숨은 꽃다발 스팟 → D18 힌트 |
| **랜드마크 실루엣** | 멀리서 방향 잡는 시각 앵커 | 세계수, 마루 케른`2`, 표석`3` |

- 원칙: **"허브에서 랜드마크가 보이고, 랜드마크로 가는 길에 게이트가 있고, 게이트 옆에 보상 포켓이 있다."** 플레이어가 길을 잃지 않으면서 탐험하는 최소 문법.

## B-2. 게이트 타입 분류

| 타입 | 정의 | 열쇠 | MVP 예 | 구현 시그널(handoff-m2) |
|---|---|---|---|---|
| **배치형** | 아이템을 타일에 놓아 지형 변경 | 조합물 배치 | G1 디딤돌 | `stepping_stone_placed(cell)` |
| **사용형** | 아이템을 오브젝트에 사용 | 아이템 소모+오브젝트 반응 | G2 물→덤불 | `item_used_on_object(item_id, object)` |
| **시간형** | game_time 조건 충족 | 시간 경과/스킵 | G3 밤 꽃길 | (M4) game_time 조건 + CanvasModulate |
| **체인형** | 다단계 조합 결과를 최종 배치 | 조합 체인 | G4 세계수 심기 | `world_tree_planted(cell)` |
| *(향후) Whisper형* | 오브젝트에 속삭임 부여로 개방 | Whisper 재화 | 2구역 수정 꽃 | (M4+) `whisper_applied` |
| *(향후) NPC형* | 대화/조건 충족으로 개방 | NPC 요구 | 2구역 엘프 | (미정) |

- 설계 규칙: **한 구역에 같은 타입 게이트 2개 연속 금지** (학습 후 반복은 지루). 시작의 숲은 배치→사용→시간으로 매번 새 조작.

## B-3. Layer 1 나머지 4구역 스케치

원본 연결 그래프(**심장이 허브**):
```
              [2] 고요의 화원
                   |
[4] 푸른 절벽길 — [3] 생명의 심장 — [5] 정화의 계곡
                   |
              [1] 시작의 숲
```
- 진행: [1]→[3]에서 Whisper 해금 → [3]에서 각 방향 확장. [5]는 진행 순서 변경 시 다른 경험(replayability).

**[3] 생명의 심장 (허브)** — 거대 생명나무가 맵 중앙을 관통, 4방향에 봄·여름·가을·겨울 오브젝트. 핵심은 Fusion Field(정해진 타일에 3개 이상 조합)와 Whisper 튜토리얼(에너지→마력→생명). 게이트는 **체인형**(4계절 재료를 특정 순서로 부여하면 가지가 살아남). 아트가이드 §3.1: 4계절 액센트 램프. B-1의 허브가 맵 전체 스케일로 확대된 형태.

**[2] 고요의 화원 (심장 북)** — 반쯤 무너진 붉은 꽃 신전. **비대칭 맵으로 시야 유도**(일부러 돌아가게) + 나비 추적 퍼즐(특정 아이템 소지 시 나비가 유도). 게이트는 **Whisper형**(꽃에 속삭이면 수정 드랍). 액센트=적/분홍. 물 반사 연출은 정적 스프라이트 눈속임(GDD §3.2 경고 반영).

**[4] 푸른 절벽길 (심장 서)** — 수직 이동·퍼즐. 이동식 나무 플랫폼(타이밍), 석탑 반응장치(**사용형**: 아이템 꽂으면 길 개방), 일부 1-way. 높이 표현은 아트가이드 벽/높이 단위 32px 활용. 액센트=한랭 청회색, 어두운 앰비언트+국소 광원.

**[5] 정화의 계곡 (심장 동)** — 첫 이상현상·분위기 전환. Whisper 이상 반응(부정 피드백=타일 뒤틀림)이 Balance 시스템 첫 노출. 왜곡 루프 길은 폴리싱 비용 큼 → **MVP/초기 제외 권장**(GDD §3.2), 도입 시 텔레포트 이음새로. 액센트=채도 튄 시안/마젠타, RGB 오프셋 셰이더.

## B-4. 구역당 권장 타일 수 / 이동 시간 기준

| 지표 | 기준 | 근거 |
|---|---|---|
| 튜토리얼 구역(1구역) | 40×40, walkable ≈ 650~700칸 | 이 문서 기준. 40~60분 분량 |
| 일반 구역(2·4·5) | 30×30 ~ 40×40, walkable 400~700칸 | 심장 허브 경유 이동이 있으므로 개별 구역은 다소 압축 |
| 허브 구역(3 심장) | 48×48 이상 | 4방향 확장 분기 수용 |
| 허브→게이트 도보 | 편도 ≤ 60초(walk 속도 기준) | 막혔을 때 재료 찾아 왕복이 스트레스 안 되게 |
| 게이트 간 간격 | 도보 2~4분 분량의 채집/탐험 | 게이트 밀도가 너무 높으면 퍼즐 피로, 낮으면 지루 |

---

# Part C — 구현 노트 (M4 dev agent용)

## C-1. ASCII 맵 → 타일 배치 파싱

**제안 파일 2개** (기획 수정 = 텍스트 수정, Godot 안 열어도 됨):

`game/data/map_layout.txt` — Part A §A-1의 40행 텍스트를 그대로 저장(colon/ruler 없이 40자×40행).

`game/data/map_legend.json` — 기호 → (tileset source, object scene) 매핑:
```json
{
  "tiles": {
    "G": {"source": 2, "tile_id": "T2A"},
    "g": {"source": 2, "tile_id": "T2A", "variants": ["T2B","T2C","T2D"], "variant_random": true},
    "D": {"source": 1, "tile_id": "T1"},
    "M": {"source": 4, "tile_id": "T4", "speed_mult": 0.6},
    "W": {"source": 5, "tile_id": "T5A", "walkable": false},
    "w": {"source": 5, "tile_id": "T5B", "walkable": false},
    "m": {"source": 5, "tile_id": "T5B", "walkable": false, "glow": "violet"},
    "V": {"source": 0, "tile_id": "T0", "walkable": false, "void": true},
    "S": {"source": 2, "tile_id": "T2A", "spawn": true},
    "K": {"source": 5, "tile_id": "T5A", "walkable": false, "place_slot": "D14"},
    "N": {"source": 2, "tile_id": "T2A", "gate": "G3_night", "walkable_when": "night"}
  },
  "objects": {
    "C": {"scene": "cauldron.tscn"},
    "U": {"scene": "rest_stump.tscn"},
    "B": {"scene": "bush_dry.tscn", "object_id": "bush_dry"},
    "O": {"scene": "world_tree.tscn", "gatherable": {"item_id": "I9", "unique": true}},
    "T": {"scene": "tree.tscn", "gatherable": {"item_id": "I4"}, "variants": ["O2A","O2B","O2C","O2D","O2E","O2F"]},
    "F": {"scene": "flower.tscn", "gatherable": {"item_id": "I5"}, "variants": ["O1A","O1B","O1C","O1D","O1E"]},
    "R": {"scene": "rock.tscn", "gatherable": {"item_id": "I6"}},
    "s": {"scene": "stone.tscn", "gatherable": {"item_id": "I8"}}
  },
  "landmarks": {
    "1": "world_tree", "2": "cairn", "3": "gate_hint_G3", "4": "tutorial_tree"
  }
}
```
- source-id는 handoff-m2의 `SOURCE_TO_TILE_ID`(source id == tile id) 규약과 일치시킬 것. VOID = source 0.
- **파서**(`MapBuilder` 확장, handoff-m2에 이미 존재): 텍스트 (col,row)를 읽어 (col,row)를 Godot isometric cell로 매핑, tiles는 `set_cell`, objects는 씬 인스턴스를 `YSortLayer`에 추가(바닥 다이아몬드 중심 origin, 아트가이드 §1.2). `g`/`T`/`F` variant는 셀 좌표 해시로 결정론적 랜덤(세이브 재현성).
- 랜드마크 숫자 셀은 바닥 타일 = 그 지대 base(G/g) + 별도 마커/힌트 Area2D.

## C-2. 게이트 트리거 씬 구조

공통: **Area2D + GameState 시그널**. handoff-m2에 배치/사용/심기 시그널이 이미 라이브 → M4는 그걸 **listen**만 하면 됨.

**G1 (배치형)** — 물 갭은 map_layout의 W 밴드 그대로. 디딤돌 배치는 handoff-m2 프레임워크 완성됨(D14 on T5A/T5B → source 1로 스왑, `stepping_stone_placed(cell)`). M4 할 일: (a) 실제 물 갭 오써링(완료, §A-1), (b) 물 위 디딤돌 전용 아트로 `STEPPING_STONE_SOURCE` 교체(현재 T1 흙 재활용, 코드 TODO).

**G2 (사용형)** — 마른 덤불에 `Gatherable`(`object_id="bush_dry"`, use-only) 부여(handoff-m2 테스트 버시 존재). `GameState.item_used_on_object(item_id, object)` 수신 → item_id=="I7" && object_id=="bush_dry"이면: 개화 애니메이션 재생 + 덤불 셀 충돌 해제(walkable로) + 통로 개방.

**G3 (시간형)** — N 셀에 Area2D. `game_time`이 저녁~새벽이면 꽃길 발광+통행 허용, 낮이면 꽃 닫힘 스프라이트+충돌 유지. `_process`에서 game_time 상태 변화 감시(폴링 대신 GameState의 시간대 변경 시그널 권장 — M4에서 `game_phase_changed(phase)` 추가 제안).

**G4 (체인형)** — 세계수 O0에 `Gatherable`(`unique=true, item_id="I9"`) → 채집 후 잔존. 어린 세계수(D22)를 VOID(T0)에 배치 → handoff-m2 프레임워크가 `world_tree_planted(cell)` emit → M4는 여기에 클리어 컷신 훅.

## C-3. 낮/밤 구현

- **시간원**: `GameState.game_time`(실시간 15분 = 게임 하루). 낮 9분 / 저녁~새벽 6분(확정 스펙). `game_time`을 0.0~1.0 정규화하거나 초 단위 누적 → phase 계산.
- **색 연출**: 스프라이트에 시간대 굽지 말고(아트가이드 §2·§3) **CanvasModulate** 색 커브로 전역 틴트. 제안 키프레임:

| phase | 실시간 구간 | CanvasModulate 색(대략) | 비고 |
|---|---|---|---|
| 낮 | 0:00~9:00 | `#faf5e6`~`#e8dfc8` (크림/따뜻) | 기본 |
| 저녁 | 9:00~11:00 | `#b59268`→`#6b4a9e` (갈→보라) 램프 | 전환 |
| 밤~새벽 | 11:00~15:00 | `#3a2a5c` base 어둡게 + 보라 발광 강조 | 세계수맵 개방, G3 통행 |

- 발광 오브젝트(세계수·신비의 물·밤 꽃길)는 **additive blend 레이어 분리**(아트가이드 §2) → 밤에 CanvasModulate로 base가 어두워질 때 발광만 살아남. 세계수맵 base는 아트가이드대로 어둡게+보라 램프.
- **그루터기 휴식(Rest Stump)**: U 상호작용 → 앉기 모션 → 화면 페이드 아웃 → `game_time`을 **다음 저녁 시작점으로 세팅** → 페이드 인. (다음 "낮"이 아니라 다음 "저녁"으로 점프 = 확정 스펙. G3 밤 게이트를 즉시 이용 가능하게.) 구현: `GameState.skip_to_next_evening()` 신설 제안 + 페이드 트랜지션.
- **CanvasModulate ≠ 발광 죽임 주의**: additive glow 레이어는 CanvasModulate 영향 밖(별도 CanvasLayer 또는 material)로 두어 밤에 발광이 오히려 도드라지게.

---

## 부록 — 원본/상위 문서와의 모순 점검

| 확인 항목 | 결과 |
|---|---|
| 원본 "흙타일 없음"(세계수 접근로) | 접근로(row8~13)에 D(흙길) 0개 — 준수 |
| 원본 "세계수 뒤 신비의 물" | m을 세계수(row2~3) 북쪽(row0~1)=뒤에 배치 — 준수 |
| 원본 "세계수 가까울수록 나무 감소" | 세계수맵 나무는 가장자리(row4~6)만, 중앙 sparse — 준수 |
| recipes-v1 게이트 순서 G1→G2→G3→G4 | flood-fill로 강제 증명(§A-5) — 준수 |
| recipes-v1 "순환 의존 없음" | 시간 게이트가 재료 게이트 뒤 — 준수 |
| 아트가이드 "팔레트 안 늘리고 엔진 틴트" | 낮/밤 CanvasModulate(C-3) — 준수 |
| handoff-m2 시그널 3종 | G1/G2/G4가 각 시그널에 매핑(C-2) — 준수 |
| 확정 시간 스펙(15분/스킵/힌트) | §0·A-6·A-2·C-3 반영 — 준수 |

*v1.0 — 이 문서가 시작의 숲 레벨 디자인 단일 기준. 나머지 4구역은 착수 시점에 각 절 확장.*
