# WH-HARVEST-001 — 채집 손맛·발견 루프 기획 + HarvestActionState 모듈 (카나 제출)

- 제출: 2026-09-16 / 대상: 루비(통합), 멤쵸(QA 참조)
- 소스 패킷: WH-TEAM-001-source-and-specs.zip
  sha256 `a5596c664100cbb5d366313691368b76236f0fdd0db403ffbbb368617dc89fd7`
- 기준 HEAD: `c25cf55` (루비 미커밋 통합분과 별개, 순수 모듈이라 충돌면 없음)

## 1. 실제 플레이 명세 (재질 3종)

공통 원칙: 입력→예비동작→접촉→획득→회복이 **한 호흡**이고, 반복을 느리게
만들지 않는다. 클릭 수·재료량·레시피·필수 도구 불변(WH-TEAM-001 계약).
아래 시간값은 전부 **임시 튜닝값** — 실플레이 검수로 조정하는 출발점이며
측정된 정답이 아니다.

### 꽃/풀 (flora) — "가볍게 딴다"
- 입력: E/탭 → 방랑자가 대상 방향으로 반보 기울며 손을 뻗음 (예비 ~90ms)
- 접촉: 손이 닿는 프레임에 reach_contact. 식물이 잡아당긴 방향으로 휘었다가
  놓임 (스프링백 ~180ms). 꽃잎/잎 파편 소량
- 획득: 접촉 직후 take_commit → 재료 아이콘이 획득 위치에서 떠올라 HUD로
  흡수 (~250ms). 표기는 실제 amount
- 소리: 가벼운 식물성 마찰음 (기존 gather_pop 대체, 재질별 분리)
- 회복: 동작 총합 ~350ms 안에서 다음 입력 가능. 연속 채집이 리듬이 되게

### 바위 (rock) — "부순다는 확신"
- 입력: E/탭 → 몸을 대상으로 돌리며 지팡이/손 스윙 (예비 ~140ms)
- 접촉: 명확한 타격 프레임에 reach_contact. 돌소리 + 적은 파편 + 대상
  1프레임 밝아짐. 화면 흔들림은 없음(저감 설정 존중)
- 획득: take_commit → 바위가 파편으로 해체 (~200ms), 자리가 비고 통행
  가능해짐 (기존 충돌 해제 계약 보존 — 이 모듈 밖, 루비 소유)
- 소리: 돌 타격→붕괴 2단. flora와 즉시 구분되게
- 회복: 총합 ~450ms

### 나무 (wood) — "무게가 있는 대상"
- 입력: E/탭 → 예비 스윙 (~160ms)
- 접촉: 줄기 접촉음(목질 노크) + 잎 전체가 별도로 흔들림(줄기와 잎의
  2단 반응 — 재질 구분의 핵심). 잎 파편 소량
- 획득: take_commit → 목재 획득 표시. v1은 지급량/도구/그루터기/다단타
  없음 — 짧은 액션과 연출의 연결만 (후속 실험은 별도 승인)
- 회복: 총합 ~500ms. 셋 중 가장 무겁게, 그러나 노동은 아니게

### 취소 정책 (전 재질 공통)
- 접촉(=commit) 전 이동/ESC/다른 대상 탭 → 액션 취소, **지급 0**
- commit 후에는 어떤 개입(씬 전환·세이브·연출 끊김)에도 **지급 정확히 1회**,
  롤백·재지급 없음
- 대상 교체 탭은 빠른 연속 채집으로 취급 — 이전 미commit 액션 자동 취소

### 손맛의 목적
"삭제 버튼"을 "행동"으로 바꾼다: 내 입력에 대상이 물리적으로 반응하고,
재질마다 소리·움직임이 다르고, 결과가 자리(빈 공간·파편·통행)로 남는다.
자막 없이도 꽃/돌/나무가 구분되는 것(수용 기준 E)이 판정선이다.

## 2. 첫 발견 구간 (행동→호기심 연결)

첫 세션 5분 안에 "합치면 뭐가 나올까"가 자가발화해야 한다:
1. P0~Q2 구간에서 첫 채집 2종(흙·물)은 위 액션만으로 충분히 기분 좋게
2. **첫 조합 성공(진흙)만 평소보다 분명한 발견 연출** — 솥의 반응 확대,
   도감 새 슬롯 강조. 이후 반복 조합은 간결하게 (같은 팝업 반복 금지)
3. 새 재료 획득 시 도감에 **관계 단서 1개**만 노출 (예: 진흙 옆 "…이걸
   마르게 하면?") — 정답 전체 공개 금지, 미발견 조합은 실루엣만
4. 조합 결과물이 배치 가능하면 획득 직후 배치 후보로 1회 제안 —
   "발견한 것은 내 세계의 일부가 된다"를 첫 시간 안에 체험

## 3. HarvestActionState 모듈 (신규 파일 3종)

- `game/scripts/gameplay/harvest_action_state.gd` — RefCounted 순수 상태 모듈
- `game/scenes/dev/harvest_action_state_harness.gd` / `.tscn` — 계약 하네스
- 기준 HEAD `c25cf55`에 동명 경로 없음 확인 (신규, 충돌 없음)

### API (납품 시그니처)
- `begin(target_key: String, material_kind: String) -> Dictionary`
  {ok, token:int, reason}. kind는 "flora"|"rock"|"wood" 화이트리스트.
  target_key는 외부 제공 world/target/respawn 세대 식별자, Node 참조 없음
- `reach_contact(token: int) -> {ok, reason}` — reserved에서만
- `take_commit(token: int) -> {ok, granted, reason}` — **granted=true는
  액션당 정확히 1회.** 상태를 반환/훅 이전에 원자 확정, 재진입 가드
- `cancel(token: int) -> {ok, reason}` — commit 후에는
  `cannot_cancel_after_commit` 거부
- `finish(token: int) -> {ok, reward_granted, reason}` — commit 없이
  finish되면 reward_granted=false (연출 중단 시 미지급 근거)
- `reset(reason: String) -> {had_active, was_committed_unfinished}` —
  씬 전환/앱 중단. 전 토큰 무효화, commit 사실은 불변
- `inspect_state() -> Dictionary` — 직렬화 가능 원시값만

### 통합 계약 (루비 몫, 명시)
- 지급 실행: `take_commit`이 granted=true를 준 그 지점에서 지급 시퀀스를
  **한 번에**. 순서 계약 (루비 검수 반영): **노드 가드(_spent 등) 확정 →
  Inventory.add → 기타 emit → queue_free 예약.** Inventory.add 내부도
  item_added/changed를 동기 emit하므로 "add 직후 가드"로는 재진입 창이
  남는다 — 가드는 반드시 add 진입 이전. 모듈은 허가만 발급하고 지급
  자체·영속화·거래 판정은 통합 책임
- 대상 소멸/거리 이탈/대화 잠금 → cancel 또는 reset 호출은 통합 판단
- respawn 세대는 target_key에 인코딩해 넘길 것 (구세대 토큰 자동 무효)

## 4. 검증 결과

- **파이썬 참조 모델(동일 계약 1:1): RED 1건(구현 전) → GREEN 31/31**
  (red-log.txt / green-log.txt 첨부). 케이스: 정상 경로, 잘못된 순서,
  접촉 전/후 취소, commit 없는 finish, 같은 대상 연타, 대상 교체(미commit/
  commit 후), stale/위조 토큰, unknown kind, reset(앱 중단), finish 후
  재시작, **같은 콜스택 재진입 중복 commit 차단**, 직렬화
- **Godot 실행: 미실행.** 이 환경에 Godot 바이너리가 없다. 하네스
  (`harvest_action_state_harness.tscn`, headless 실행 시 종료코드=실패 수)는
  참조 모델과 케이스 1:1이며, 루비 환경에서 1회 실행이 GDScript 문법·API
  차이를 확정한다. 파이썬 GREEN을 Godot PASS로 간주하지 말 것

## 5. 미검증 범위 / 비변경 확약

- 미검증: GDScript 실행(상기), 실게임 연결(지급·소리·애니메이션·충돌 해제),
  모바일 실기기 입력, 재미(§1 튜닝값은 전부 실플레이 검수 대상)
- 비변경: 기존 Gatherable/InteractionController/GameState/Inventory/
  SaveManager/TouchController/아트 파일 무수정. 재료량·레시피·게이트·
  리스폰 정책 무변경. 공유 브랜치 push 없음 (로컬 브랜치 커밋만)
