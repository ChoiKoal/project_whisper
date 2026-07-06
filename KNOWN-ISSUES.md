# Project Whisper — 알려진 이슈 (v0.6.0, Layer 2 — 터미널 게이트 스테이션 기준)

작성: 2026-07-05 · Godot 4.5.stable · 정직하게 수집(핸드오프 M4/M5/M6a + M6b 패키징·E2E QA 과정에서 발견).
갱신: 2026-07-05 · v0.1.1 — 독립 QA(220/0)가 최우선 폴리시로 지목한 2건 해결(아래 "해결됨(v0.1.1)" 참조).
갱신: 2026-07-05 · v0.1.2 — macOS 릴리스 크래시 원인 후보 하드닝 + 타이틀 화면 미화(아래 참조).
갱신: 2026-07-06 · v0.6.0 — Layer 2(과학의 세계, 「꺼진 관문 기지」) 추가. L2 한정 알려진 항목은 아래 "🔬 Layer 2 (v0.6.0)" 절 참조.
갱신: 2026-07-06 · v0.6.1 — 안정화 스윕. 릴리스-경로 정적 감사(assert 0건·set_script 타입정합·FileAccess null가드·export 필터) 클린 + 버그 2건 수정(아래 "✅ 해결됨(v0.6.1)" 참조). 신규 sweep_harness로 비정규 경로(클리어 전 귀환/컷신 중 이동/G3·G4 거부) 커버.

심각도 태그
- 🔴 **게임진행** — 클리어/저장 등 진행에 영향을 줄 수 있음
- 🟡 **체감** — 진행은 되지만 플레이 감각/명확성을 해침
- 🟢 **외관** — 순수하게 보기/마감 문제 (플레이스홀더 포함)

현재 🔴 진행-차단(블로커)은 **없음**. Layer 1 전체 클리어 체인(씨앗→디딤돌→생명수→빛나는 새싹→어린 세계수→식수→클리어)과 Layer 2 전력 게이트 체인(전지→브리지 / 랜턴→정전 / 퓨즈→차폐문+에너지 / 파워코어→정화)과 저장/로드/NG+(두 레이어 리셋)는 **master E2E 하네스(양 레이어 완주)** 에서 모두 PASS.

---

## 🔬 Layer 2 (v0.6.0) — 정직하게 수집

Layer 2 「꺼진 관문 기지」(과학의 세계)는 홈 science 포탈 → terminal_station으로 진입. 콘텐츠 요약: 신규 원소 J1~J7(7) + 조합물 D62~D102(41) = 아이템 48종, 레시피 42종(L2-R01~R42, L2-R23은 J7 반환), 아이콘 48종, 전력 퍼즐 4종(G1 배터리·브리지 / G2 퓨즈·차폐문 / G3 네온 랜턴·정전 / G4 파워코어·정화), 에너지 Whisper(G2 보상, whisper_cost로 파워코어에 소모). master E2E가 title→home→L1 완주→귀환→science 진입→G1~G4→L2 정화→machine flickering→재진입 지속→세이브/로드→NG+(양 레이어 리셋, union에서 3레시피 계승)까지 완주 검증.

- 🟡 **G4 파워코어 = D68+D68(코어 조각 2개) + 에너지 1** (2-입력 시스템 유지). 설계 Part B의 "D68+에너지"를 기존 2-입력 조합 규칙과 정합시키기 위해 코어 조각 2개로 구현(레시피 `_note` 문서화). 스펙 의도(에너지 재화 소모)는 whisper_cost로 완전히 반영됨 — 기능 갭 아님, 조합 UI에서 같은 재료 2개를 요구한다는 표기 뉘앙스만 존재.
- 🟡 **레시피 총계 = 104 (L1 62 + L2 42).** 브리프 초기의 "112" 근사치와 다름 — Part B가 L2 42종을 명시(L2-R23이 J7 반환이라 신규 조합물은 41). 데이터 기준값은 42/104가 정답이며 verify_recipes가 이 기준으로 PASS.
- 🟢 **L2 아트는 절차생성 아이콘/오브젝트 유지.** J1~J7·D62~D102 아이콘 48종은 과학 팔레트(금속 회색/시안 발광/네온)로 tools_gen_icons가 생성한 절차 아트. 최종 손그림 패스 이전 상태(홈 섬 아트와 동일 성격의 캐리오버).
- 🟢 **정전 병목(G3) = 국소 암전 오버레이 + 병목 벽 콜리전 토글.** 실제 라이팅이 아니라 화면 가장자리 암전 연출 + StaticBody 벽 on/off. 랜턴(D65) 소지 판정으로 통행 — 기능적으로 완결이나 "빛으로 어둠을 민다"는 물리 라이팅 연출은 TODO.
- 🟢 **preview-l2-powered.png = 오프라인 컴포지터 렌더.** 인게임 SubViewport 캡처가 --headless(더미 드라이버)에서 불가하므로, 홈/그로브 프리뷰와 동일하게 pngjs로 맵 데이터를 오프라인 프로젝션. post-G4 점등 상태(브리지·차폐문 시안 발광, 가로등·관제탑·발전기 ON)를 근사 표현 — 실제 게임 렌더와 픽셀 동일하지 않음(무드 검수용).
- ℹ️ **에너지 Whisper HUD는 보유 시(energy>0)에만 표시.** G2 발전기 수리 보상으로 +1 획득한 순간부터 좌상단 패널 노출. 미보유 시 완전 숨김(의도된 동작; L1과 톤 일관).

---

## 🔴 macOS 릴리스 크래시 — "새로 시작" 시 SIGSEGV (진범 확정: export include_filter 누락(data/*.json,*.txt 미포함). v0.1.3에서 필터 추가+export 실빌드 검증 완료)

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

**상태: 진범 확정: export include_filter 누락(data/*.json,*.txt 미포함). v0.1.3에서 필터 추가+export 실빌드 검증 완료.** macOS 실기 없이 검증 불가하므로 grove ready-체인의
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

## ✅ 해결됨 (v1.0.3) — L2 기름 채집 softlock + 전 레이어 공간 진행 감사

- **[해결·🔴진행] Layer 2 기름(J5) 채집 불가로 인한 진짜 softlock.** KOAL 실플레이 발견. L2 「꺼진 관문 기지」의
  oil_leak(맵 `m` 심볼, gather J5) 소스 4개가 전부 냉각수 협곡(W, row24–26) **북쪽**(11,9)(27,9)(11,12)(26,12)에만
  배치돼 있었다. 스폰 S=(18,32)은 협곡 남쪽이고, 협곡을 건너는 유일 통로 G1 에너지 브리지(B, row23–27)는
  전지 D64를 배전반에 장착해야 열린다. 그런데 전지 = 구리도선(J1+J2) + 정류회로(J4+**J5 기름**)라,
  **기름 없이는 G1을 못 열고 기름은 G1 뒤(북쪽)에만 있는 데드락**. (다른 G1 재료 J1/J2/J4는 남측에 존재.)
- **수정**: `game/data/l2_map_layout.txt` 남측 잔해밭(pre-G1)에 walkable oil_leak `m` 3개를 추가 —
  (12,35)(26,37)(21,38). 전부 기존 `G`(황무지, 워커블) 셀이라 스폰 진입로·브리지 스파인(col17–19) 침범 없음.
  설계 문서 §A-2(byte-identical) + §A-4/§A-6/§B-1/§B-2 동기화(§A-6 softlock 표에 기름 남측 배치 명기).
- **재발 방지**: (a) 신규 `tools/tools_spatial_audit.py` — 전 레이어(L2~L5)에 대해 스폰→게이트 순차 BFS로
  각 게이트 열쇠의 조합 체인(recipes.json 역추적) gather 원소가 게이트 앞 구역에서 확보 가능한지 전수 검증.
  **감사 결과 총 위반 0**(L2 기름 외 추가 없음, L3/L4/L5 클린). (b) `l2_map_harness`에 협곡 남측 기름 소스
  진행성 어서션 이식 + tile count(m 4→7 / G 401→398) 갱신. 전 하네스 34/34 그린.
- **세이브 호환**: 맵 데이터 추가(리스폰 채집원)일 뿐 세이브 스키마 무변경 — 기존 세이브 그대로 이어짐.

## ✅ 해결됨 (v1.0.2) — 씬 전환 중 버퍼드 입력 널-뷰포트 크래시

- **[해결·🔴진행] 씬 전환 중 입력으로 인한 릴리스 전용 SIGSEGV.** v1.0.1 실플레이 중 발견. macOS 크래시
  리포트: `Viewport::set_input_as_handled()`에서 `KERN_INVALID_ADDRESS`(0x4b8), 콜스택
  `GDScriptFunction::call ← Node::_call_unhandled_input ← Viewport::push_input`. 원인: 씬 전환이
  진행 중일 때 `Input.flush_buffered_events`가 트리에서 이탈 중인 입력-핸들러 노드로 버퍼드 입력을 배달 →
  핸들러의 `get_viewport()`가 null인 상태에서 `set_input_as_handled()` 호출 → 널 역참조. 에디터에서는
  soft-fail이라 릴리스 빌드에서만 크래시(v0.5.2 glow 크래시와 동류). **수정**: (a) 모든
  `_input`/`_unhandled_input` 핸들러 첫 줄에 `if not is_inside_tree(): return` 가드(world/·ui/ 15개
  핸들러), (b) 모든 `get_viewport().set_input_as_handled()` 호출부(27곳)를 널-안전 패턴
  `var vp := get_viewport(); if vp: vp.set_input_as_handled()`으로 교체. 신규 재현 하네스
  `scenes/dev/v102_transition_input_stress`(홈→L1~L5+귀환, 엔딩 프롬프트 열기/취소 전환 직후
  `Input.parse_input_event`로 버퍼드 키/클릭 주입 + 티어다운 프레임 걸쳐 `flush_buffered_events`)로
  검증(34 PASS/0 FAIL). 전 하네스 스위프 34/34 그린 + v102·e2e 실 PCK(`--main-pack`) 검증.

---

## ✅ 해결됨 (v0.6.1) — 안정화 스윕

- **[해결·🔴진행] 클리어 후 홈 섬 시간 정지.** `scripts/world/clear_sequence.gd`의 CS-04 정화 컷신이
  `GameState.time_running=false`로 시간을 멈추고, `cleared` 시그널 emit 전에 **복원하지 않았다**.
  `time_running`은 autoload 플래그라 change_scene(홈 섬)을 넘어가도 잔류 → 홈 섬이 시간 정지 상태로
  부팅(낮/밤 순환 멈춤 + HomeSession이 월드를 영구 락으로 취급, `home_session.gd:97`). L2 정화 컷신
  (`l2_gate_controller.gd`)은 false→true 페어링이 이미 있었으나 L1 클리어 비트만 빠져 있었다. `cleared`
  emit 직전 `time_running=true` 복원. (sweep_harness A절이 클리어 완주 후 복원을 검증.)
- **[해결·🟡체감] 컷신 중 키보드 이동으로 연출 관통.** `scripts/player/player.gd`의 프레임별 프리즈가
  `ui_modal_open()`만 검사 → 컷신(`time_running=false` 또는 `control_lock`) 중 **이동키를 누른 채면 걸어감**
  (v0.5.1 "키 고착" 계열). TouchController는 큐된 경로를 이미 막았지만 매 프레임 새로 읽는 키보드 워크는
  게이트되지 않았다. 프리즈 조건을 `TouchController._world_locked()`와 동일하게(modal OR not time_running
  OR control_locked) 확장하고 `is_world_frozen()` 헬퍼로 추출. (sweep_harness B절이 세 조건 각각 프리즈를 검증.)

정적 감사 결과(수정 불필요, 클린 확인): 전 .gd `assert(` 0건(과거 제거 확인), `set_script` 5곳 전부
노드 타입 정합(quest_marker/ground_jitter=Node2D, cauldron=Sprite2D, backdrop_canvas=Control),
light_pool `scr.new()` 풀 전부 Sprite2D 정합, `FileAccess.open` 8곳 전부 null 가드, export
include_filter(`data/*.json,*.txt`)가 L2 신규 데이터파일 전부 커버(실 PCK `--main-pack` 로드로 재확인).

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
- **macOS 빌드 ad-hoc 서명(v1.0.1~).** v1.0.0까지는 완전 무서명이라 Apple Silicon Gatekeeper가
  "손상되었기 때문에 열 수 없습니다"로 차단 → 오너가 릴리스마다 `xattr -dr com.apple.quarantine`를
  수동 실행해야 했다. v1.0.1부터 빌드 시 `rcodesign`(indygreg/apple-platform-rs, Linux arm64용)로
  **ad-hoc 코드서명**을 붙인다(`tools/postprocess_macos_zip.py` → 유니버설 2슬라이스 ADHOC
  CodeDirectory + 번들 `_CodeSignature/CodeResources`). 이제 xattr 없이 **우클릭 → 열기(최초 1회)**로
  실행된다.
  잔여 제약: Apple **공증(notarization)은 아님**(개발자 인증서·계정 필요) → 최초 실행 시 우클릭→열기
  1회는 여전히 필요. 완전 무경고 실행을 원하면 공증 필요.
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
