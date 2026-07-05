# Handoff — v0.1.2 (macOS 릴리스 크래시 하드닝 + 타이틀 화면 미화)

작성: 2026-07-05 · Godot 4.5.stable · 대상 버전 v0.1.2 · 이전 clean tree: v0.1.1(10075a7)

이 문서는 두 가지를 다룬다:
1. **PART 1** — macOS 릴리스 익스포트에서 "새로 시작" 시 SIGSEGV 크래시의 **원인 후보 전수 감사 + 하드닝**
   (macOS 실기 없이 검증 불가 → defense-in-depth). 각 하드닝 사이트를 file:line + 무엇이 null일 수 있는지 + 추가한 가드로 기록.
2. **PART 2** — 타이틀 화면 코드-리빌드 구조.

마지막에 검증(하니스/익스포트) tail 첨부. **git commit 하지 않음.**

---

## PART 1 — macOS 릴리스 크래시 하드닝

### 크래시 근거 (오너 리포트)
- macOS(M1 Pro, macOS 26.5) 릴리스 익스포트(v0.1.1, gl_compatibility, universal): 타이틀 → "새로 시작" → `SIGSEGV KERN_INVALID_ADDRESS at 0x0`.
- 콜스택(번역): `SceneTree::_flush_scene_change → Node::_add_child_nocheck → _propagate_ready → GDScriptFunction::call(_ready) → Variant::callp → GDScriptFunction::call(nested) → <engine addr> CRASH at null`.
- 해석: starting_grove 의 어떤 `_ready`가 change_scene 플러시 중 GDScript 함수를 호출하고, 그 함수가 **엔진 빌트인을 null에서 호출** → 릴리스 템플릿은 null-check 스트립 → 세그폴트.
- **linux 재현 실패**: headless 에디터 바이너리 + headless **릴리스 익스포트** 둘 다 타이틀→새로 시작→grove 생존. m7_title_flow 하니스 초록. → null은 **실제 렌더링/맥OS 특이성**에서만.

### 감사 방법
starting_grove 트리의 ready 순서(깊이우선, 자식→부모, 트리 순서)를 확정한 뒤, 모든 `_ready`와 거기서 (전이적으로) 호출되는 함수를 전수 감사. 특히:
`get_viewport().get_camera_2d()`(플러시 중 카메라 미등록 → null), `get_tree().current_scene`(플러시 중 NULL), `get_window()`/뷰포트, null 텍스처의 `.get_size()`, `.material`, 오토로드 가정, `get_node_or_null` 결과 미검사, 형제-@onready 순서, **스트립되는 `assert` 뒤 역참조**.

> ready 순서 참고: DayNight → GlowLayer → Ground(MapLoader) → TileHighlight → SteppingSlotHint → Player(+AnimatedSprite/Collision/Camera2D) → YSortLayer → Interaction → ObjectRespawn → TouchController → NightGateGuard → InventoryUI → FusionUI → CodexUI → TimeHUD → ClearSequence → FadeLayer → PauseMenu → GroveSession.
> `MapLoader._ready()`는 `_build_objects/_scatter_objects`를 동기 실행하며, 여기서 spawn되는 노드들(night_gate/world_tree/mystic_water/rest_stump/bush_dry/gatherable/cauldron/glow_sprite)의 `_ready`도 **플러시 안**에서 실행된다.

### 하드닝 사이트 (file:line · 무엇이 null일 수 있나 · 추가한 가드)

**주 용의자 — 수정됨:**

- **`scripts/world/map_loader.gd:145-158` (`_load_data`)** — 무엇이 null: `FileAccess.open(LEGEND_PATH, READ)` 결과 `lf`가 파일 없음/권한 시 null.
  기존 코드는 bare `assert(lf != null, ...)` 뒤 곧바로 `JSON.parse_string(lf.get_as_text())` → `assert`는 **릴리스에서 컴파일 아웃** → **엔진 빌트인 `FileAccess.get_as_text()`를 null에서 호출 → SIGSEGV**. 이 함수는 `MapLoader._ready()` → change_scene 플러시 안에서 실행됨. **콜스택의 `<engine addr> CRASH at null`과 정확히 일치.**
  가드: `if lf == null: push_warning(...); _legend = {}; return`. 추가로 파싱 실패(비-Dictionary)도 `assert` 대신 빈 legend 폴백. legend가 비면 `_build_tiles`가 심볼별 grass 폴백(`set_cell(...,2,...)`)으로 홀 없이 빌드하므로 동작 보존.
  (같은 함수의 layout 파일 로더는 v0.1.2 이전에 이미 `if f == null` 가드됨 — legend만 빠져 있었음.)

**Defense-in-depth 오토로드 가드 (night_gate/glow_sprite와 동일 패턴; ready-타임 접근):**

- **`scripts/world/day_night.gd:27` (`_ready`) / :34 (`_process`)** — null: `GameState` 오토로드 미등록/개명 시. 미가드 시 `.day_fraction()` 역참조.
  가드: `if GameState == null: color = DAY_A; return` (`_ready`), `_process`도 조기 반환.
- **`scripts/world/bush_dry.gd:28` (`_ready`)** — null: `GameState`. 미가드 시 `.item_used_on_object.connect` 역참조.
  가드: `if GameState == null: push_warning(...); return`.
- **`scripts/ui/time_hud.gd:53` (`_ready`) / :62 (`_refresh`)** — null: `GameState`. 미가드 시 `.day_phase_changed` / `.phase()` 역참조.
  가드: 두 함수 모두 `if GameState == null` 조기 반환.
- **`scripts/world/touch_controller.gd:51` (`_ready`)** — null: `GameState`. 미가드 시 `.stepping_stone_placed.connect` 역참조.
  가드: `if GameState == null: push_warning(...); return` (`_build_grid`는 `_loader` 가드 뒤 call_deferred라 안전).

**노드 룩업 하드닝:**

- **`scripts/player/player.gd:41` (`_ready`)** — null: `$AnimatedSprite2D`가 자식 부재 시 `$`는 에러(릴리스에선 null 반환). `_anim`의 모든 사용부(`_update_animation` 등)는 이미 `if _anim == null` 가드가 있음.
  변경: `$AnimatedSprite2D` → `get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D` → 부재 시 애니메이션 생략으로 degrade(크래시 아님).

### 이미 안전한 것으로 확인(변경 없음)
- **`scripts/world/glow_sprite.gd`** — `:39` GameState 가드, `:55` `get_tree()` null 가드, `:60` 그룹 룩업 null 가드, 리페어런트는 call_deferred(플러시 이후).
- **`scripts/world/night_gate.gd:52`** — GameState 가드 존재.
- **`scripts/world/map_loader.gd`** — layout 로더(`if f == null`), `_ysort`/`_feedback`/노드 룩업 전부 null-check, `_place`에서 `_ysort` 가드.
- **`scripts/world/touch_controller.gd:105`** — `get_viewport().get_camera_2d()` 결과 `cam`을 `:106`에서 null-check. 게다가 `_to_world`는 `_unhandled_input`(입력시)에서만 호출 → **ready-타임 아님**.
- **`scripts/core/save_manager.gd:260-261`** — `_loader.get_tree().current_scene`가 null이면 `_loader.get_parent()` 폴백. 저장/로드시에만 호출 → **ready-타임 아님**.
- **interaction_controller / night_gate_guard / object_respawn / grove_session / clear_sequence / world_tree / mystic_water / rest_stump / cauldron / gatherable / stepping_slot_hint / tile_highlight** — `_ready`가 `get_node_or_null`(null-check/self 폴백) 또는 call_deferred/await 후 가드된 setup, 혹은 등록된 오토로드 접근만. ready-타임 null 엔진-객체 호출 경로 없음.

### 감사 결론
grove ready-체인에 **null 엔진 객체 메서드 호출이 남은 경로 없음**. 주 원인 후보는 `map_loader.gd`의 스트립된 legend `assert`(엔진 빌트인이 null에서 역참조 → 콜스택 형태 일치). 나머지는 defense-in-depth. **macOS 실기 재현/검증은 오너 확인 대기** (상태: KNOWN-ISSUES.md "원인 후보 하드닝, macOS 검증 대기").

---

## PART 2 — 타이틀 화면 리빌드

파일: `scenes/ui/title.tscn`(루트 Control + `scripts/ui/title_menu.gd`). 전면 **코드-빌드**(취약한 수기 .tscn 드리프트 없음). 신규 외부 아트/셰이더 없음 — 기존 게임 에셋 + 드로운 프리미티브만.

구조(`_build()` 호출 순서 = z-순서):
1. **`_build_sky()`** — `GradientTexture2D`(수직, #1a1a20 → #2a2a3c)를 full-rect `TextureRect`로.
2. **`_build_iso_backdrop()`** — Node2D "Diorama"(우하단 배치, 1.15배). 6×6 아이소 잔디 다이아 필드(변형 타일 + 연못 코너), 우측 세계수 + `world_tree_glow.png`(additive, 펄스 대상), tree_a/tree_b 나무, 가마솥 + 그 옆 고양이(캐릭터 시트 96×96 idle_SE AtlasTexture), 바이올렛 꽃 스캐터. 모든 에셋 존재 확인됨(`assets/tiles/*`, `assets/objects/*`, `assets/character/character_sheet.png`).
3. **`_build_vignette()`** — 상/하단을 어둡게 하는 `GradientTexture` 워시(셰이더 없이).
4. **`_build_particles()`** — `CPUParticles2D` 22개, 하단에서 위로 천천히 드리프트, 바이올렛(#c8b0ec) additive, 알파 램프로 페이드 인/아웃 → 앰비언트 모트/반딧불.
5. **`_fade_root`(Control)** — 아래 3개를 로드시 함께 페이드인(create_tween, 0.9s).
   - **`_build_title()`** — "Project Whisper" 96px 바이올렛 로고: crisp 본체 위에 스케일 1.04/1.06 additive 저알파 글로우 카피 겹침(글로우는 펄스 대상). 서브타이틀 "속삭임이 세계를 만든다" 26px cream + 아웃라인.
   - **`_build_buttons()`** — 하단 중앙 VBox. `_add_button`으로 라운드 패널 버튼(≥52px, `_btn_style`: #2a2a33 배경 + 바이올렛 보더, hover/focus 시 필+보더 강조, FOCUS_ALL). **버튼/핸들러/조건부 표시 불변**: 새로 시작(항상)/이어하기(`SaveManager.has_save()`)/NG+(has_save && `_save_cleared()`)/종료. 핸들러(`_on_new_game/_on_continue/_on_ng_plus/_on_quit`) 그대로 → m7 하니스 의존성 보존.
   - **`_build_version()`** — 우하단 버전 라벨. `_version_string()`이 `ProjectSettings.get_setting("application/config/version")`에서 읽어 "v" 접두(하드코딩 제거) → project.godot과 절대 드리프트 안 함.
6. 애니메이션: `_process`에서 `_glow_nodes`(세계수 글로우 + 타이틀 글로우)를 sine 펄스(월드 노드/GameState 불필요).

1600×900 디자인 + `canvas_items` stretch로 스케일. 헤드리스 부팅 클린(스크립트 에러/에셋 경고 없음).

---

## 검증 tails

### 1. Headless --import: 에러 0
클래스 등록 진행만 출력, 에러 없음.

### 2. 하니스 (전부 초록, exit 0 · [FAIL] 0)
```
== m2             :: === RESULT: PASS (0 failures) ===
== m2_integration :: === RESULT: PASS (0 failures) ===
== m3             :: === RESULT: PASS (0 failures) ===
== m4             :: === RESULT: PASS (0 failures) ===
== m5             :: === RESULT: PASS (0 failures) ===
== m6a            :: === RESULT: PASS (0 failures) ===
== e2e            :: === RESULT: PASS (0 failures) ===
== m7_title_flow  :: === RESULT: PASS (0 failures) ===
```
m7_title_flow 상세(9/9 PASS): title screen built(새로 시작 present) / grove reached after 새로 시작 / survived 90 frames(new game) / save_game() from pause / save file exists / returned to title 이어하기 present / grove reached after 이어하기 / survived 60 frames(continue).

> **m7_title_flow는 이제 상시 실행 리스트에 포함**(macOS 릴리스 크래시의 영구 회귀 테스트). 실행: `Godot --headless scenes/dev/m7_title_flow.tscn` (exit code = 실패 수).

### 3. 버전 범프
`project.godot` `config/version="0.1.2"`, `export_presets.cfg` product_version/short_version/version 모두 `0.1.2`.

### 4. 익스포트 (export_templates 4.5.stable — tpz에서 설치함)
```
export/ProjectWhisper-win64-v0.1.2.zip          34,050,994 B  (exe 96.8MB, embed_pck)
export/ProjectWhisper-macos-v0.1.2.zip          62,384,338 B  (릴리스, .app 번들)
export/ProjectWhisper-macos-DEBUG-v0.1.2.zip    67,086,128 B  (디버그)
export/linux/ProjectWhisper.arm64               63,370,728 B  + ProjectWhisper.pck 217,832 B
```
- linux arm64 헤드리스 부팅 확인: `Godot Engine v4.5.stable` 로드, 스크립트 에러 없음.
- macOS zip 내용 확인: `Project Whisper.app/Contents/...` 정상 번들.
- 익스포트시 `gio/kioclient5/gvfs-trash` 에러는 컨테이너에 휴지통 데몬 없어서 나는 무해 경고(구 파일 이동 실패).

### 5/6. KNOWN-ISSUES.md 갱신 + 본 핸드오프 작성 완료.

### 7. git commit 하지 않음.
