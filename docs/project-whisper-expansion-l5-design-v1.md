# Project Whisper — 확장 기획 EX-L5: 제5세계 「신성의 세계」 확장 설계 v1.0

> 작성: Kana (레벨·콘텐츠 디자인 담당) / 2026-07-08
> 대상: **Layer 5(신성) 확장 — 신규 구역 「침묵의 종탑」** (40×40, 구역 1개)
> **확장 기획 5부작의 최종(5/5).** 마지막 레이어의 마지막 확장 구역 — 서사 밀도 최고.
> **스코프 선언: 이 문서는 설계(기획)만 확정한다. 구현은 금지** — KOAL은 전 레이어 확장의 **기획 선행**만 지시했다. 데이터/맵/코드 반영은 별도 구현 마일스톤이 이 문서와 생성 스크립트를 소비해 수행.
> 상위/Canon:
> - **L5 구역 프레임 원안**: `docs/project-whisper-layer5-design-v1.md`(구역 1 = 응답 없는 대성당, 40×40, 게이트 = 꺼진 등불 길 배치→생명의 샘 재정화 사용→침묵의 회랑 성가 소지→대제단 봉헌 "응답", 채집 S1~S7, 조합 D177~D218, 퍼즐 축 = **봉헌/응답**, 무드 = 상아/백은 + 잿빛 + 호박빛 잔불). 본 확장은 대제단 위로 이어지는 **종탑 상층**을 신설한다. 구역 표준 5요소·게이트 타입 분류·"한 구역 같은 타입 2연속 금지"는 `docs/project-whisper-level-design-v1.md` Part B 계승.
> - **L5 심화 정본**: `docs/project-whisper-layer5-design-v1.md` — 응답 없는 대성당의 정체성(신이 응답받지 못해 시듦, "정화 = 되살리는 게 아니라 처음으로 대답해주는 것"), 생명(Vita) Whisper 첫 등장, 3속성(에너지/마력/생명) 컬미네이션(D186 "응답"). **종탑 = 신이 마지막으로 목소리를 낸 곳** — 그 뒤로 울리지 않은 종. **종을 다시 울리는 것 = 세계에게 보내는 가장 큰 대답**(대성당 "응답"의 정점).
> - **직전 산출 정본 포맷**: `docs/project-whisper-expansion-l4-design-v1.md` — Part A(맵·게이트·BFS·재료 도달성·페이싱) / Part B(원소·레시피·무결성) / Part C(재사용·구현·컷신) 3부 구조 + 증명 방식(BFS 순서 강제 + 재료 도달성 이중 증명) + 분할 작성 패턴을 그대로 계승. `tools/l4x_*`를 `tools/l5x_*`로 복제·적응.
> - **데이터 정합**: `game/data/recipes.json`(총 **220 레시피**) · `game/data/items.json`(S1~S7=L5 채집). **EX-L1이 D222~D254를 예약**(자연) · **EX-L2가 D255~D277을 예약**(과학) · **EX-L3가 D278~D300을 예약**(기계) · **EX-L4가 D301~D323을 예약**(마법) → **EX-L5 신규 조합 산출 = D324~**(연속). **신규 채집 = S8~S12**(L5 기존 S1~S7 뒤 연속). 모든 신규 항목 `layer:5` 병기.
> - **공간 감사**: `tools/tools_spatial_audit.py`(L2~L5 커버) 문법 계승 **`tools/l5x_bfs.py`**(신규 구역 전용 BFS)로 순서 강제 재현 증명. 맵/레시피 표는 **파이썬 생성**(`tools/l5x_map_gen.py`·`tools/l5x_recipes.py`) — 손 타이핑 금지.
> - **NPC 문법**: `docs/project-whisper-gameplay-pass-v1.md` §1(잔재 NPC = 레이어당 1~2기, 3유형 퀘스트 체인, 정답 아이템명 직접 호명 금지). **신규 구역 잔재 NPC 1기(종지기의 그림자)**.
> - **재화**: `docs/project-whisper-economy-design-v1.md`(3속성 = 에너지/마력/**생명**) · `docs/project-whisper-endgame-design-v1.md`(빛의 문·E1/E2·Balance 4축). L5 구역 1이 생명 Whisper를 처음 준다. 본 구역이 **생명 Whisper 재획득처**를 제공하고, GB4 재타종("응답")에서 **3속성 전부를 소비(sink)**해 엔딩 Balance를 대비(idempotent).
> - **세계관**: `docs/project-whisper-storyline-v1.md` — L5 신성 설계 사상 **믿음(信)**, 멸망 방식 **"피조물의 신뢰 상실 → 신의 힘 소멸"**. 종탑 = 신이 **마지막으로 응답한(목소리를 낸) 자리**, 그 뒤로 아무도 울리지 않아 침묵한 종. 종을 다시 울림 = 대성당 "응답"의 컬미네이션(가장 큰 대답).
> 상태: **EX-L5 설계 완료** — 「침묵의 종탑」 단일 기준(Part A·B·C). 구현 에이전트는 이 문서 + 생성 스크립트를 소비한다. 변경은 이 파일 갱신으로만. **확장 5부작(자연/과학/기계/마법/신성) 완결.**

---

## 0. 이 문서가 결정하는 것 (요약)

| # | 결정 | 근거 |
|---|---|---|
| 1 | L5를 **신규 구역 「침묵의 종탑」**(40×40)으로 확장. 대성당(구역 1) 대제단 위로 이어지는 **종탑 상층** — 신이 마지막으로 목소리를 낸 곳, 그 뒤로 울리지 않은 종이 걸린 정점. 무너진 종탑 계단, 흐려진 종음 결계, 세 울림 종, 종지기의 그림자와 종탑 정점의 큰 종. 대성당이 "신에게 처음으로 대답한 곳"이었다면, 종탑은 **그 대답을 세계 전체가 듣도록 종으로 울리는 곳**(L5 정체성 = 응답의 극한) | layer5 원안 프레임 + 스토리라인 "믿음→신뢰 상실→소멸" 계승. 구역 1 대제단 "응답" 이후, 그 응답을 **가장 큰 소리로 세계에 보내는** 다음 심화. 마지막 확장 구역답게 엔딩(빛의 문)·진상 조각·"응답" 주제와 직결 |
| 2 | 게이트는 구역 1·L1~L5 문법 계승 — **void(바래 사라진 허공) 벽 + 2칸 병목 + 고도차(경사로)**로 물리 강제. 종탑 층 사이가 허공으로 갈라져 우회 차단. 게이트 4종(타입 비반복): **GB1 무너진 종탑 계단**(배치/종석 잔교)→**GB2 흐려진 종음 결계**(사용/정음의 물)→**GB3 타종 울림 순서 퍼즐**(순서 있는 미니 퍼즐, **신규 술어 `chime_ordered`**)→**GB4 큰 종 재타종**(체인·3속성 소비·컷신) | level-design B-2 게이트 타입 분류("같은 타입 2연속 금지") 준수. §A-6 BFS로 순서 강제 증명(`l5x_bfs.py`, `ORDER-FORCED: PASS`) |
| 3 | 신규 채집 **5종**: S8 종 파편·S9 종탑 밧줄·S10 울림 청동·S11 잔향 가루 + **S12 신의 마지막 음(유니크)**. 신규 조합 **23종**(EX-L5-R01~R23, 산출 D324~D346) | L5 기존 S1~S7 뒤 연속, EX-L4 예약 D323 뒤 연속. 기존 220 레시피 + **EX-L1·L2·L3·L4 예약분(33+23+23+23=102쌍) 대비 페어 중복 0**·내부 중복 0·softlock 0 실측(§B-3) |
| 4 | **생명 Whisper 재획득처**(잔향 성수반 F, idempotent `add_vita`) + **GB4 재타종에서 3속성 소비(sink, `whisper_cost {energy,mana,vita} 각1`)**. 마지막 확장답게 **3속성 완결의 속성=생명** 재확보처를 종탑에 두되, 최종 재타종("응답")은 **세 속삭임 전부를 종에 실어 세계에 보내는** 구조 | economy 3속성 + endgame Balance. 생명=L5 신성 첫 등장 속성. GB4 = 구역 1 D186 "응답"(3속성 소비)의 컬미네이션 계승. 신규 재화 0(vita=이미 L5 구역 1에서 WhisperCurrency 자릿수 구현) |
| 5 | **진상 조각 서사 최종장 1점** — 「신의 마지막 기록」(신이 마지막으로 목소리를 낸 그 순간, 무엇을 말했는지의 기록). 잔재 NPC = **아직도 종을 지키는 종지기의 그림자**. L1~L5 유산 조각(세계수/로그/로봇/마법사 잔영/석상 → 대성당 마지막 기도) 계보에 **종탑 신의 마지막 음 조각** 추가 = 진상 서사의 정점 | gameplay-pass §1 잔재 NPC 문법 + endgame 진상 조각 구조. 구역당 NPC 1기. 종지기 그림자의 마지막 타종 = 스토리라인 진상 회수 문법의 최종장 |
| 6 | **§A-6 공간 도달성 표 = 필수 계약** — 각 게이트 열쇠 재료의 채집 소스가 게이트 **前** 지대임을 좌표로 명시(L2 기름 사고 재발 방지 — 설계 단계에서 증명). BFS 순서 증명 + 재료 도달성 스크립트 실측 포함 | L2 구역 1 기름 softlock 전례. `l5x_bfs.py`(순서 강제) + `l5x_recipes.py`(재료 누적 지대 논증) 이중 증명 |
| 7 | 진입: **대성당(구역 1) 대제단 곁, 종탑으로 이어지는 계단 → 종탑 착지** → 종탑 남쪽 스폰 (19,39). **L5 구역 1 정화 후 개방**(대제단 봉헌 "응답" 완료 = 종탑 계단 활성 — 검토·명시). 왕래는 홈/구역 포탈 패턴 재사용(§Part C) | 구역 1과 물리 연결(대제단 위 종탑). 왕래는 홈/구역 포탈 패턴 재사용 |

---

# Part A — 「침묵의 종탑」 40×40 타일 설계

## A-1. 컨셉

대성당에서 대제단에 "응답"을 봉헌한 방랑자가, 대제단 곁 종탑 계단을 따라 오르는 곳. **대성당 위로 이어지는 종탑 상층 — 신이 마지막으로 목소리를 낸 자리**다. 대성당이 "신에게 처음으로 대답해 준 곳"이었다면, 그 대답을 **세계 전체가 듣도록 종으로 울리는 곳**이 종탑이다. 신이 마지막으로 낸 그 소리는, 아무도 종을 다시 울리지 않아 오래 침묵했다. 방랑자는 **무너진 종탑 층 사이를 종석 잔교로 한 마디씩 이어** 정점의 큰 종에 올라, 침묵하던 종을 **마지막으로 한 번, 세계 전체가 듣도록 다시 울린다**.

대성당이 "처음으로 대답한 곳(응답의 시작)"이었다면, 종탑은 그 위에서 **응답을 세계에 보내는 곳** — 종 파편·종탑 밧줄·울림 청동이 주역이 되는, L5 안의 상층 **타종 챕터**다. 구역 1의 상아/백은 + 잿빛 + 호박빛 잔불 무드를 그대로 이어받되, 여기는 **종탑 상층(고도 +0~+2)** 위에서 벌어진다. 스토리라인의 "믿음→신뢰 상실→소멸"이 화면 안에서 뒤집힌다: 여기가 바로 **신이 마지막으로 목소리를 낸 뒤 아무도 응답하지 않아 침묵한 종탑**이며, 방랑자가 종을 다시 울리는 것이 **다섯 세계 전체의 컬미네이션**이다.

무드: 구역 1 상아/백은 base 위에 **바래 사라진 허공(desaturate void) + 종탑 정점 큰 종의 호박빛 잔불 발광**. 종탑을 오를수록(북으로 = 정점의 큰 종, 고도 +2) 발밑의 허공이 넓어지고 큰 종의 호박빛이 따뜻해지는 CanvasModulate 커브. **엔진 틴트(CanvasModulate) + 리컬러**로 팔레트를 늘리지 않고 표현(아트가이드 §2·§3). 단, **"상층 고도 +1~2"는 이 구역에서 실제 height를 사용**(구역 1의 이중 고도 시스템 계승 — `l5x_map_height.txt`로 착지 0 / 상층 회랑 +1 / 정점 +2 직렬화). 고도차(0→+1, +1→+2)를 GB2·GB4 병목이 겸해 강제(구역 1 방식 계승). L5는 색이 빠진 세계 — 종탑은 **소리마저 빠진 세계**(침묵)이며, 정화가 그 침묵을 종소리로 되돌린다.

**진입점**: 대성당 대제단(row 0~3 O 블록) 곁, 종탑으로 이어지는 계단 → 침묵의 종탑 남쪽 스폰 (19,39). 대성당 클리어(대제단 봉헌 "응답" = `layer5_purified`) 후 개방(종탑 계단에 호박빛 잔불이 다시 돌기 시작 = 개방 신호). 왕래는 홈/구역 포탈 패턴 재사용(§Part C).

## A-2. ASCII 맵 (40행 × 40열)

- **좌표 규약**: `(col, row)`, 좌상단 = (0,0). row 0 = **북(종탑 정점 / 큰 종 = 재타종 지점, 고도 +2)**, row 39 = **남(대성당 연결 착지 스폰, 고도 0)**. col 0 = 서.
- **읽는 방향**: 플레이어는 아래(남, 대성당에서 착지)에서 위(북, 정점의 큰 종)로 **종탑 층을 한 마디씩 이으며** 오른다. 구역 1의 수직 순례 문법 계승(남 스폰→북 정점).
- 아래 40자×40행은 **`tools/l5x_map_gen.py`가 생성**(구역 사각형·병목·채집 배치를 코드화, 손 타이핑 금지) → 그대로 `game/data/l5x_map_layout.txt`가 된다. 고도는 **`game/data/l5x_map_height.txt`**(O/H=2, C/Q=1, 경사로 `/`, 그 외 0)로 함께 산출. ruler/행번호는 문서 표기용, 파일엔 제외.

```
col: 0         1         2         3
     0123456789012345678901234567890123456789
  0  VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
  1  VVVVVVVVVVVVOOOzOOOOOOOzOOOOVVVVVVVVVVVV
  2  VVVVVVVVVVVVOOOOOOO1oOOOOOOOVVVVVVVVVVVV
  3  VVVVVVVVVVVVOsOOOOOHOOOOOOsOVVVVVVVVVVVV
  4  VVVVVVVVVVVVOOjOOO//OOOOjOOOVVVVVVVVVVVV
  5  VVVVVVVVVVVVOOOOOOOOOOOOOOOOVVVVVVVVVVVV
  6  VVVVVVVVVVVVVVVVVVLLVVVVVVVVVVVVVVVVVVVV
  7  VVVVVVVVVVVVVVVVVVCCVVVVVVVVVVVVVVVVVVVV
  8  VVVVVVVVVVVVVVVVVVCCVVVVVVVVVVVVVVVVVVVV
  9  VVVVVVVVCCCCCCCCCCCCCCCCCCCCCCCCVVVVVVVV
 10  VVVVVVVVCCCCCCCCCCCNCCCCCCCCCCCCVVVVVVVV
 11  VVVVVVVVCCCCzCCCCCCCC5CCCCCzCCCCVVVVVVVV
 12  VVVVVVVVCCCCCCyCCCCyCCCCyCCCCCCCVVVVVVVV
 13  VVVVVVVVCCCsCCCCCCCCCCCCCCCCsCCCVVVVVVVV
 14  VVVVVVVVCCjCCCCCdCCCCCCdCCCCCjCCVVVVVVVV
 15  VVVVVVVVCCCCCCCCCCCCCCCCCCCCCCCCVVVVVVVV
 16  VVVVVVVVVVVVVVVVVVeeVVVVVVVVVVVVVVVVVVVV
 17  VVVVVVVVVVVVVVVVVV//VVVVVVVVVVVVVVVVVVVV
 18  VVVVVVVVVVVVVVVVVEQQVVVVVVVVVVVVVVVVVVVV
 19  VVVVVVVVQQQQQQQQQQQQQQQQQQQQQQQQVVVVVVVV
 20  VVVVVVVVQQQQQQQQQQQ2QQQQQQQQQQQQVVVVVVVV
 21  VVVVVVVVQQsQFQQQQQQQQQQQQQQ3QQQQVVVVVVVV
 22  VVVVVVVVQQQQQQjQQQQQQQQQQQsQQQQQVVVVVVVV
 23  VVVVVVVVQQQdQQQQQQQQQQzQQQQQQQQQVVVVVVVV
 24  VVVVVVVVQQQQQQQxzQQQQQQxQQQQQjQQVVVVVVVV
 25  VVVVVVVVQQQQdQQQQQQQQQQQjQQQQQQQVVVVVVVV
 26  VVVVVVVVQdQQQQQQQQQQsQQQQQQQzQQQVVVVVVVV
 27  VVVVVVVVQQQQQQQQQQQQQQQQQQQQQQQQVVVVVVVV
 28  VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV
 29  VVVVVVVVVVVVVVVVVVggVVVVVVVVVVVVVVVVVVVV
 30  VVVVVVVVAAAAAAAAAXAAAAAAAAAAAAAAVVVVVVVV
 31  VVVVVVVVAAAsAAAAAAAAAAAAsAAAAAAAVVVVVVVV
 32  VVVVVVVVAAAAAAjAAAAAAAAAAAAAzAAAVVVVVVVV
 33  VVVVVVVVAAzAAAAAAAAAAAAAAAAAAAzAVVVVVVVV
 34  VVVVVVVVAAAAAjAAAAAAAAAAAAAjAAAAVVVVVVVV
 35  VVVVVVVVAsAAAAAAdAAAAAAdAAAAAAAAVVVVVVVV
 36  VVVVVVVVAAAA4AAAAAAAAAAAAAsAAAAAVVVVVVVV
 37  VVVVVVVVVVVVVVVVVVASAVVVVVVVVVVVVVVVVVVV
```

> **주의**: 위 발췌 표기는 문서 가독용 축약이다. **정본 40×40 좌표·심볼은 `tools/l5x_map_gen.py` 산출(`game/data/l5x_map_layout.txt`)이 유일 기준**이며(row 규약·랜드마크 배치 포함), §A-6 BFS 검증 통과 확정본(전 게이트 개방+부적 walkable = **700칸**, orphan 0, 균열 severed 0)이다. `y`(타종 종 슬롯 3개, 울림 순서 있음)·`N`(종지기 그림자)은 GB3 앞 타종 울림 퍼즐실 지대에 놓여 인접 상호작용.
