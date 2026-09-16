# WH-HARVEST-001 — 카나 개발 범위

README.md를 먼저 읽어줘. 이 Git 문서가 이전 채팅 첨부보다 우선한다. 담당 branch `feat/wh-harvest-001-kana`, PR base `collab/whisper-polish`. 각자 머신에서 하위 에이전트 활용 가능. 루비가 아트/현재월드코어를 소유하므로, 이 작업은 **기획 + 순수 action 상태모듈**에 한정한다. 담당 외 파일은 건드리지 않는다.

## 결과물
1. 짧은 실제 플레이 명세: 꽃/풀, 바위, 나무 각각 입력→예비동작→접촉→획득→회복/다음행동, 손맛의목적/취소정책/초기튜닝값/그값이임시임을명시. 클릭수를늘리거나현재재료량/레시피/필수도구를바꾸지않는다. 행위에서다음조합호기심으로이어지는첫플레이구간도작성.
2. `game/scripts/gameplay/harvest_action_state.gd` 신규 RefCounted 순수모듈 후보. 실제저장소에동명파일이있으면덮지말고루비에게경로충돌보고. 별도branch/독립작업공간에서작성해PR로반환.
3. 신규 `game/scenes/dev/harvest_action_state_harness.gd/.tscn` 또는독립테스트프로젝트. 실제Godot RED→GREEN을실행할수있으면로그첨부, 불가하면미실행이라고명시. 실제게임QA와혼동금지.

## 통합 경계
기존 Gatherable/InteractionController/GameState/Inventory/SaveManager/TouchController/아트 파일은 **수정 금지**. 순수모듈은 이를직접참조/호출하지않는다. 루비가모듈을게임에연결하고단일소유상태에서거래·save·physics를검증한다.

초기 API 합의안(제출시정확한시그니처와동작명세포함):
- begin(target_key, material_kind) → 액션token 또는실패. target_key는외부가제공하는world/target/respawn세대를식별, Node참조보관금지.
- reach_contact(token) → 아직유효한action에서접촉상태진입.
- take_commit(token) → 최초한번에만보상commit허가를반환, 그다음호출은거부. 상태를callback/반환이전원자적으로consume하여reentrant중복방지.
- cancel(token) / finish(token) / reset(reason) → 소유action만종료. 이미commit한보상을되돌리거나재허용하지않음.
- inspect_state() → 검증용serializable 상태. 고정전역singleton/파일I/O/효과실행 없음.
명칭개선은가능하나외부side-effect 경계를유지하고정확한API를납품해줘. 보상사실의영속화/거래성공판정은모듈단독해결이아니라루비통합계약으로명시한다.

필수cases: 이전token/대상교체/연타·동시입력/접촉전cancel/commit후cancel/같은frame재진입/finish후재시작/앱중단/unknownkind/잘못된순서. 아트/시점/채집량/에셋복사는하지않는다.

## 제출
WH-HARVEST-001.md, 소스patch/정확한파일목록, 최소재현/RED/GREEN로그, Git base/head SHA, 튜닝값과미검증범위를첨부. 담당 브랜치는 commit/push하고 `collab/whisper-polish` 대상으로 PR을 열어 루비에게 검토·머지를 요청한다. 공유 main/통합브랜치 직접 push·무검증 merge·배포는 금지. PR에 실제 테스트와 미검증을 기록한다.
