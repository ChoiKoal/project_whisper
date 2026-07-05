# Project Whisper — 알려진 이슈 (v0.1.2, macOS 크래시 하드닝 + 타이틀 미화 기준)

작성: 2026-07-05 · Godot 4.5.stable · 정직하게 수집(핸드오프 M4/M5/M6a + M6b 패키징·E2E QA 과정에서 발견).
갱신: 2026-07-05 · v0.1.1 — 독립 QA(220/0)가 최우선 폴리시로 지목한 2건 해결(아래 "해결됨(v0.1.1)" 참조).
갱신: 2026-07-05 · v0.1.2 — macOS 릴리스 크래시 원인 후보 하드닝 + 타이틀 화면 미화(아래 참조).

심각도 태그
- 🔴 **게임진행** — 클리어/저장 등 진행에 영향을 줄 수 있음
- 🟡 **체감** — 진행은 되지만 플레이 감각/명확성을 해침
- 🟢 **외관** — 순수하게 보기/마감 문제 (플레이스홀더 포함)

현재 🔴 진행-차단(블로커)은 **없음**. 전체 클리어 체인(씨앗→디딤돌→생명수→빛나는 새싹→어린 세계수→식수→클리어)과 저장/로드/NG+ 는 E2E 하니스에서 모두 PASS.

---

## 🔴 macOS 릴리스 크래시 — "새로 시작" 시 SIGSEGV (원인 후보 하드닝, macOS 검증 대기)

**증상.** 오너 macOS(M1 Pro, macOS 26.5) 릴리스 익스포트(v0.1.1, gl_compatibility, universal)에서
타이틀 → "새로 시작" 누르면 `SIGSEGV KERN_INVALID_ADDRESS at 0x0`. 콜스택(번역):
`SceneTree::_flush_scene_change → Node::_add_child_nocheck → _propagate_ready → GDScriptFunction::call(_ready)
→ Variant::callp → GDScriptFunction::call(nested) → <engine addr> CRASH at null`.
즉 starting_grove 트리의 어떤 `_ready`가 change_scene 플러시 중 다른 GDScript 함수를 호출하고,
그 함수가 **null 엔진 객체의 메서드를 호출** → 릴리스 템플릿은 null-check가 스트립되어 세그폴트
(디버그였다면 스크립트 에러 출력에 그침).

**재현.** linux headless(에디터 바이너리 + **릴리스 익스포트** 둘 다)에서는 재현 안 됨 —
m7_title_flow 하니스(타이틀→새로 시작→grove 90프레임→저장→타이틀로→이어하기→grove 60프레임)가
모두 초록. 즉 null은 **실제 렌더링/맥OS 플랫폼 특이성**에서만 발생한다고 판단.

**상태: 원인 후보 하드닝, macOS 검증 대기.** macOS 실기 없이 검증 불가하므로 grove ready-체인의
**null 엔진 객체 호출 가능 경로를 전수 감사 후 defense-in-depth로 전부 가드**했다. 하드닝 목록:

- **[주 용의자·수정] `scripts/world/map_loader.gd:142-147` (구)** — `map_legend.json` 로드가 bare
  `assert(lf != null, ...)` 뒤 곧바로 `lf.get_as_text()`. `assert`는 릴리스에서 컴파일 아웃되므로
  파일이 없거나 못 읽으면 **null 핸들 역참조 → SIGSEGV**. 이 함수는 `MapLoader._ready()` → change_scene
  플러시 안에서 실행됨. 명시적 `if lf == null` 가드 + 파싱 실패(비-Dictionary)도 빈 legend 폴백으로 처리.
  (같은 함수의 layout 파일은 이미 v0.1.2 이전에 가드돼 있었으나 legend는 빠져 있었음.)
- **[하드닝] `scripts/world/day_night.gd:_ready/_process`** — `GameState.day_fraction()` 앞에 `GameState == null`
  가드. 없으면 낮 틴트로 폴백.
- **[하드닝] `scripts/world/bush_dry.gd:_ready`** — `GameState.item_used_on_object.connect` 앞 GameState 가드.
- **[하드닝] `scripts/ui/time_hud.gd:_ready/_refresh`** — `GameState.day_phase_changed` 등 앞 GameState 가드.
- **[하드닝] `scripts/world/touch_controller.gd:_ready`** — `GameState.stepping_stone_placed.connect` 앞 GameState 가드.
- **[하드닝] `scripts/player/player.gd:_ready`** — `$AnimatedSprite2D` → `get_node_or_null("AnimatedSprite2D")`.
  모든 `_anim` 사용부는 이미 null 가드가 있어, 자식 노드 부재 시 애니메이션 생략으로 degrade.
- **[사전 하드닝·확인] `scripts/world/glow_sprite.gd`** (GameState 가드 + `get_tree()`/그룹 null 가드 + 리페어런트 deferred),
  `scripts/world/night_gate.gd`(GameState 가드), `scripts/world/map_loader.gd` layout 로더/노드 룩업(전부 null-check).
- **[확인·안전] `scripts/world/touch_controller.gd:105` `get_viewport().get_camera_2d()`** — `cam != null` 가드 존재,
  게다가 입력시(_unhandled_input)만 호출 → ready-타임 아님.
- **[확인·안전] `scripts/core/save_manager.gd:260` `_loader.get_tree().current_scene`** — null이면 `_loader.get_parent()`
  폴백 + 저장/로드시에만 호출 → ready-타임 아님.

감사 결론: **grove ready-체인에 null 엔진 객체 메서드 호출이 남은 경로 없음.** 주 용의자는 map_legend 로더의
스트립된 assert(엔진 빌트인 `FileAccess.get_as_text()`가 null에서 역참조 → 콜스택의 `<engine addr> CRASH at null`
형태와 정확히 일치). macOS 실기 재현/검증은 오너 확인 대기.

## ✅ 미화 (v0.1.2)

- **타이틀 화면 리빌드.** `scenes/ui/title.tscn`(스크립트 `scripts/ui/title_menu.gd`)을 분위기 있는 화면으로
  전면 코드-빌드. 야간 그라디언트 하늘 + 아이소 grove 디오라마(잔디 다이아·연못·나무·세계수+바이올렛 글로우·
  가마솥 옆 고양이) + 비네트 + 떠다니는 바이올렛 모트(CPUParticles2D, additive) + 바이올렛 글로우 로고
  ("Project Whisper", additive 이중 레이어 펄스) + cream 서브타이틀(아웃라인, 페이드인) + 라운드 패널 버튼
  (hover/focus 시 바이올렛 필+보더). 버튼/플로우/조건부 표시(이어하기·NG+)는 **불변** — m7 하니스가 검증.
  버전 라벨(우하단)은 `ProjectSettings config/version`에서 읽음(하드코딩 제거).

---

## ✅ 해결됨 (v0.1.1)

- **[해결] G1 다중 디딤돌 안내 부재.** 개울이 3칸 깊이(K 슬롯 세로 3칸)라 디딤돌 하나로는 못 건너
  "왜 안 건너지?" 하고 막히던 첫 유저 이탈 리스크. v0.1.1에서 두 가지 인게임 안내 추가:
  (a) **디딤돌(D14)을 든 동안** 아직 물인 모든 K 슬롯 위에 펄스 다이아몬드 하이라이트(tile_highlight 스타일,
  바이올렛 #9e7ad9)를 표시. (b) **디딤돌 배치 성공 후** 같은 개울에 아직 물 슬롯이 남았으면 배치 칸에
  플로팅 라벨 "아직 물이 깊다… 발판이 더 필요해"를 띄움. (신규 `SteppingSlotHint` 노드 + InteractionController
  훅. m6a 하니스에 하이라이트 표시/해제 어서션 추가. E2E 배치 로직 회귀 없음.)
- **[해결] 밤 글로우 틴트 블리드.** 세계수/신비한 물/밤 꽃봉오리의 additive GlowSprite 가 DayNight
  CanvasModulate 와 같은 캔버스에 있어 밤 색보정이 글로우까지 물들던 문제. v0.1.1에서 전용 `GlowLayer`
  CanvasLayer(layer 1, follow_viewport_enabled)로 분리 — GlowSprite 가 런타임에 global_position 보존하며
  자기 자신을 리페어런트. CanvasModulate 는 자기 캔버스 레이어만 틴트하므로 이제 글로우는 밤에 "확" 빛남.
  day_night.gd 의 (실제와 달랐던) "별도 CanvasLayer" 주석도 실제 구현에 맞게 정정. (m6a 하니스에 글로우가
  CanvasModulate 캔버스의 자손이 아님을 검증하는 어서션 추가.)

---

## 🔴 게임진행

- **없음(블로커 기준).** 진행 영향 *가능성* 관찰 항목이던 **G1 3칸 디딤돌 안내 부재는 v0.1.1에서 해결**
  (위 "해결됨" 참조). (E2E 하니스는 3개를 놓고 건너는 경로까지 검증함.)

## 🟡 체감

- **디딤돌 = 흙(T1) 타일 재활용.** 물 위에 디딤돌을 놓으면 walkable 로 바뀌지만
  시각적으로는 흙 타일(source 1)을 그대로 쓴다. "돌다리"처럼 안 보임 → 전용 "물 위 디딤돌" 스프라이트 TODO.
  (M2부터 이어진 캐리오버 TODO; InteractionController `STEPPING_STONE_SOURCE` 주석 참조.)
- **디딤돌 놓을 때/개울 건널 때 SFX 없음** — 아래 SFX 부재 항목 참조. 배치 성공 피드백이 떠오르는 라벨뿐.

## 🟢 외관

- **플레이스홀더 아트 전반.** 캐릭터/오브젝트/타일 상당수가 절차생성 플레이스홀더(`tools_gen_art.js`).
  최종 아트 패스 이전 상태.
- **라이팅 방향 불일치.** M4 이후 신규 아트는 "우상단 광원"으로 셰이딩하지만, 기존 tree_a/tree_b 는
  여전히 "좌상단 광원". QA 트윅에서 재생성하지 않고 남겨 둠 → 최종 아트 패스에서 통일 필요.
- **플레이어 스케일 1.25 하드코딩.** 스프라이트 시트를 재생성하지 않고 씬에서 1.25배로 키워 둠(살짝 뭉개짐).
- **SFX/BGM 전혀 없음.** 오디오 미구현. 채집/조합/게이트/클리어 전부 무음.
- **macOS 빌드 미서명(unsigned, ad-hoc).** 코드 서명·공증 없음 → 첫 실행 시 Gatekeeper 경고.
  우클릭 → 열기로 우회(실행방법 README 참조). 배포 전 서명/공증 필요.
- **엣지 오버레이는 오토타일이 아니라 스프라이트 오버레이.** 대각선 교차 등 일부 경계에서
  전이가 오토타일만큼 매끄럽지 않을 수 있음(가장 단순·견고한 방식 선택). 기저 타일맵은 안 건드림.

---

## E2E / QA 카베아트 (테스트 성격상 감안할 점)

- **E2E 하니스는 시간을 명시적으로 구동한다.** `GameState.time_running=false` 로 두고 `set_game_time()` 으로
  낮/밤을 결정론적으로 세팅한다(벽시계 드리프트로 4단계 밤 게이트 판정이 흔들리지 않도록).
  실게임은 실시간으로 시간이 흐른다 — 하니스의 시간 진행과 동일하지 않다.
- **대량(BULK) 재료는 일부 `Inventory.add` 로 직접 채운다.** 스펙 허용 범위. 단, 각 *메커니즘*은 최소 1회
  실제 컨트롤러로 수행한다: 실제 타일채집 1회, 실제 오브젝트채집(꽃/바위/물/세계수) 다수,
  실제 배치(디딤돌·어린세계수), 실제 사용(물→마른 덤불), 실제 조합(Fusion API 전 체인),
  실제 길찾기 이동(TouchController.move_to 로 개울 횡단)까지 모두 진짜로 실행·검증한다.
- **클리어 연출은 트윈 최종 콜백에서 cleared 를 확정한다.** 하니스는 실시간 트윈(~6초)을 기다리는 대신
  `mark_cleared()` 를 직접 호출해 결정론적으로 cleared 플래그를 검증한다. 인게임에서는 연출 종료 시 자동 저장.
- **m5 하니스 game_time 허용오차 0.1s** — M6a부터의 기존 이슈(로드 직후 idle 프레임 1개의 델타).
  복원 자체(`set_game_time`)는 정확하며, 0.1s 는 프레임 1개를 허용하는 값(회귀 아님).

## 빌드/패키징 메모

- **내보내기 텍스처 압축(S3TC/BPTC) 프로젝트 설정을 켜야 macOS universal 빌드가 된다.**
  (`rendering/textures/vram_compression/import_s3tc_bptc=true` 로 프로젝트에 추가함.) 안 켜면 macOS export 실패.
- **Linux 빌드는 .pck 분리형**(`embed_pck=false`) — `ProjectWhisper.arm64` 와 `ProjectWhisper.pck` 를
  같은 폴더에 둬야 실행됨. Windows(embed)·macOS(zip 내장)는 단일 파일.
- **개발 씬 제외.** 익스포트 프리셋 `exclude_filter="scenes/dev/*"` 로 테스트 하니스는 빌드에서 빠진다.
