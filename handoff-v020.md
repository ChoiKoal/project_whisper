# Project Whisper — v0.2.0 Handoff (아트/UI 스프린트)

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`
> Builds on v0.1.3 (clean tree). 게임플레이/로직 불변 — **비주얼/UI만** 손봄.
> Uncommitted (project rule: do NOT git commit).

오너 피드백("인벤토리 안도 이상하고, 들고있는것은 뭔지 모르겠슴. 게임 기본 UI도 좀 더
신경써야될 것 같아")에 대응. 58개 아이템이 전부 똑같은 초록 사각형이던 문제,
들고있는 것 표시가 좌하단 텍스트 한 줄이던 문제, 민무늬 다크박스 패널, 타일 다이아
아웃라인이 너무 강해 바닥이 체커보드로 읽히던 문제를 전부 처리.

---

## A. 아이템 아이콘 — 58개 고유 48×48 픽셀 아이콘

**생성 방식**: 결정론적 프로그램 생성. 신규 파일 `tools_gen_icons.js`(순수 Node, 내장
zlib PNG 인코더 — 기존 `tools_gen_art.js`와 동일 파이프라인). `assets/icons/<id>.png`
로 58개 출력. 팔레트는 아트가이드 §3의 22색 램프 + 소수 액센트(핑크/골드) 한정.
모든 아이콘: 투명 배경, selout 아웃라인(**순수 검정 없음** — 면색보다 어두운 동일계열
1px), 우상단 소프트 라이트, 볼드한 단순 실루엣.

- **채집 I1–I9**: 흙 mound / 풀 tuft / 진흙 blob(광택) / 나무 log(나이테) / 꽃 5-petal /
  바위 faceted / 물 teardrop / 돌 pebble pair / 세계수 정수 **발광 보라 오브**(글로우+스파클).
- **크래프트 D01–D49**: 각기 다른 실루엣. **패밀리 큐 공유**:
  - 보라-글로우 패밀리(생명수 D19 / 빛나는새싹 D20 / 정령꽃 D21 / 어린세계수 D22 /
    축복받은가지 D47 / 등불꽃 D48 / 생명의정원 D49) — 뒤 글로우 + 스파클.
  - 목재 패밀리(판자 D23 / 울타리 D24 / 바구니 D26 / 낚싯대 D27 / 나무다리 D33 /
    새집 D43 / 목재 D12 …) — 갈색 램프.
  - 석재 패밀리(석기 D11 / 벽돌 D13 / 조약돌 D31 / 돌탑 D45 / 벽 D46 …) — 회색 램프.
  - 식물/꽃 패밀리(씨앗·새싹·묘목·클로버·수련·연꽃·화환·꽃다발 …).
- **D06(나무)는 I4의 alias** → `assets/icons/D06.png`는 I4.png와 바이트 동일(스펙: "D06
  alias resolves to I4's icon").

**ItemDB 연동**: `ItemDB.icon(id) -> Texture2D`(scripts/core/item_db.gd). alias 통해
resolve(D06→I4), `res://assets/icons/<rid>.png` 로드, resolved-id 캐시. **파일 없으면
카테고리색 정사각형 fallback**(`_fallback_square`, ImageTexture) — 방어적, UI가 절대
null/blank 슬롯을 안 보이게. (items.json에 아트보다 먼저 아이템이 추가되는 미래 대비.)

**커버리지 통계**: 58 파일 / 57 고유 해시(중복은 D06==I4 alias 1쌍뿐). 비-alias 57개
전부 바이트 유니크. 누락 0.

## B. 인벤토리 UI 재설계 (`scripts/ui/inventory_ui.gd`, 코드-빌드 CanvasLayer)

- **타이틀 스크린 스타일 패널**: 라운드 다크(#2a2a33) + 1px 보라 보더(#9e7ad9) +
  섀도우 + 패딩. 타이틀바 "인벤토리  N종".
- **슬롯 그리드**: 6열, 56×56 슬롯(스크롤). 각 슬롯 = 실제 아이콘(nearest 필터,
  aspect-fit) + **우하단 카운트 뱃지**(다크 pill 위 크림 텍스트).
- **선택 슬롯**: 보라 보더 하이라이트.
- **디테일 페인**(우측): 큰 아이콘(96) + 이름·수량 + **flavor 텍스트**(월드빌딩 텍스트가
  드디어 게임 내에서 보임) + **들기/내려놓기 버튼**(들고 있으면 "내려놓기"로 토글).
- **입력**: 화살표 상하좌우 = 그리드 이동(좌우 ±1, 상하 ±6열), Enter = 선택 아이템
  들기/내려놓기 토글, I/ESC 닫기. 마우스: 클릭 선택, **더블클릭 들기**(0.35s).
- `Inventory.changed` 시그널로 rebuild. held item은 기존 `InteractionController.set_held_item`
  로 push(불변 API).

## C. 들고 있는 것 HUD (같은 파일, 좌하단)

- **64×64 슬롯 박스**(패널 스타일) + 옆에 이름·수량 라벨. 아이콘은 실제 아이템 아이콘.
- **빈 상태**: 딤 보더(dashed 대용 — StyleBoxFlat엔 dash 없어 딤 보더로 근사) + 박스 안
  "빈 손".
- **컨텍스트 힌트**: 들고 있는 아이템이 근처 유효 타깃에 작용 가능하면 박스 위에 작은
  힌트 텍스트("E: 배치" / "E: 사용"). 매 프레임 `InteractionController.held_action_hint()`
  조회(신규 메서드).

## D. 일반 UI 일관성 패스

- **Time HUD**(`time_hud.gd`, 우상단): 패널에 보라 보더 + 섀도우 추가. phase 글리프
  (☀/☾) + "저녁 · 1일차" 유지.
- **Fusion UI**(`fusion_ui.gd`): 입력/결과 슬롯 및 재료 스트립의 ColorRect →
  **실제 아이콘 TextureRect**. 슬롯 패널에 보라 보더(40% 알파). 결과 슬롯도 실제
  아이콘으로.
- **Codex UI**(`codex_ui.gd`): 발견 항목 = 실제 아이콘. **미발견 = 실제 아이콘의
  darkened 실루엣**(modulate 근-검정 틴트) — 스펙대로. 엔트리 패널에 보라 보더(발견=35%,
  미발견=12% 알파).
- **인터랙션 프롬프트**(`interaction_controller.gd`): 하이라이트된 타깃 위에 떠 있는
  작은 다크 pill + 크림 텍스트 + 보라 보더. `interact` 액션이 이 프레임에 할 행동에 따라
  "E 채집" / "E 조합" / "E 사용" / "E 배치". 월드 공간(feedback layer 자식)에 lazy 생성,
  타깃 없으면 숨김.
- **Pause 메뉴**(`pause_menu.gd`): 버튼 컬럼을 라운드 다크 + 보라 보더 프레임 안에
  배치, 버튼도 타이틀 스크린 스타일 박스(hover/focus 시 보라 강조). 핸들러 불변.

## E. 바닥 가독성 (`tools_gen_art.js` `makeTile`)

- 타일 다이아 per-tile 아웃라인이 체커보드로 읽히던 문제: `makeTile`에 **edge blend**
  추가 — 선언된 edge 색을 fill 쪽으로 60% 블렌드(대비를 원본의 ~40%로). 지형이
  체커보드가 아닌 유기적으로 읽힘.
- **VOID(T0) / 신비수(T5M)은 `hardEdge:true`로 제외** — 보라 rim은 Whisper 세계관의
  의도된 시각 시그니처라 유지.
- 크기/토폴로지/커스텀데이터 **불변**(비주얼만). 결정론적 재생성 → M4 tile-count,
  1600셀 assert, 세이브 무영향.
- 재생성 후 실제 바이트 변한 파일은 8개(t1_dirt, t2a/b/c/d, t4_mud, t5a/b_water)만.
  edge 오버레이·오브젝트·캐릭터·VOID·신비수는 바이트 동일(생성기의 해당 코드 미변경).
  변경 8개만 `assets/tiles/`에 반영. 채집 타깃 보라 펄스 하이라이트는 그대로.

---

## 하니스 업데이트

기존 하니스는 옛 UI 내부(category-color 사각형)를 assert하지 않았음 → 게임플레이/로직
assert 약화 없이 **전부 그대로 통과**. UI 아이콘은 데이터 주도 렌더라 로직 무관.

**신규 하니스**: `scenes/dev/m8_icon_coverage.{gd,tscn}` — 아이콘 커버리지 검사:
1. items.json의 모든 비-alias id가 디스크에 아이콘 PNG 보유.
2. `ItemDB.icon(id)`가 모든 id(alias 포함)에 non-null, D06→I4 동일 텍스처.
3. 57개 canonical 아이콘 파일이 전부 바이트 유니크(허용 중복은 D06.png==I4.png alias뿐).

## 검증 tails

### Import (에러 0)
```
Godot --headless --import .  → SCRIPT ERROR/Parse Error 0. 아이콘 58개 .import 생성.
```

### 메인 씬 헤드리스 (런타임 에러 0)
```
title.tscn --quit-after 120           → clean
starting_grove.tscn --quit-after 400  → clean
```

### 하니스 (전부 초록, exit 0)
```
== m2_test_harness   :: === RESULT: PASS (0 failures) ===
== m2_integration    :: === RESULT: PASS (0 failures) ===
== m3_test_harness   :: === RESULT: PASS (0 failures) ===
== m4_test_harness   :: === RESULT: PASS (0 failures) ===
== m5_test_harness   :: === RESULT: PASS (0 failures) ===
== m6a_test_harness  :: === RESULT: PASS (0 failures) ===
== e2e_playthrough   :: === RESULT: PASS (0 failures) ===
== m7_title_flow     :: === RESULT: PASS (0 failures) ===
== m8_icon_coverage  :: === RESULT: PASS (0 failures) ===   (신규)
```
m8 상세(8/8): items.json 로드 / 57+1 split / 모든 canonical 아이콘 PNG 존재 /
ItemDB.icon() all non-null / D06→I4 동일 / 57개 파일 바이트-유니크 / distinct 해시 57 /
D06.png==I4.png.

### 버전 범프
`project.godot config/version="0.2.0"`; `export_presets.cfg` product/short/version 모두
`0.2.0`.

### 익스포트 검증 플로우 (스펙대로)
1. Linux preset의 `exclude_filter` 임시 클리어 → 테스트 빌드 `/tmp`로 익스포트.
2. **EXPORTED 바이너리로 m7 실행** → 통과(데이터-intact assert 포함):
```
=== M7 TITLE FLOW HARNESS ===    (exported ProjectWhisper.arm64)
[PASS] title screen built (새로 시작 present)
[PASS] grove reached after 새로 시작
[PASS] map tiles present (export data intact)
[PASS] ItemDB/RecipeDB loaded (export data intact)
[PASS] survived 90 frames in grove (new game)
[PASS] save_game() succeeded from pause menu
[PASS] save file exists on disk
[PASS] returned to title; 이어하기 present
[PASS] grove reached after 이어하기
[PASS] survived 60 frames in grove (continue)
=== RESULT: PASS (0 failures) ===
```
3. `exclude_filter` 복원 후 파이널 빌드.

### 파이널 익스포트 (export_templates 4.5.stable)
```
export/ProjectWhisper-win64-v0.2.0.zip          34,084,816 B   (exe embed_pck)
export/ProjectWhisper-macos-v0.2.0.zip          62,417,924 B   (릴리스 .app 번들)
export/ProjectWhisper-macos-DEBUG-v0.2.0.zip    67,119,714 B   (디버그)
export/linux/ProjectWhisper.arm64               63,370,728 B  + ProjectWhisper.pck 272,776 B
```
- win zip = `ProjectWhisper.exe` 1엔트리. macOS zip = `Project Whisper.app/Contents/...`
  정상 번들. linux arm64 헤드리스 부팅 확인(Godot Engine v4.5.stable, 에러 없음).
- 익스포트시 `gio/kioclient5/gvfs-trash` 경고는 컨테이너에 휴지통 데몬 없어 나는 무해.

### git commit 하지 않음.

---

## File map (new/changed in v0.2.0)
```
game/
  project.godot                          # version 0.1.3 → 0.2.0
  export_presets.cfg                     # product/short/version → 0.2.0
  tools_gen_icons.js          (new)      # 58 아이콘 생성기
  tools_gen_art.js                       # makeTile edge-blend(soft) + VOID/신비수 hardEdge
  scripts/core/item_db.gd                # + icon(id) + _fallback_square + 아이콘 캐시
  scripts/ui/inventory_ui.gd             # 전면 재작성: 그리드 + 디테일 페인 + held HUD + 힌트
  scripts/ui/fusion_ui.gd                # ColorRect → 아이콘 TextureRect, 슬롯 보라 보더
  scripts/ui/codex_ui.gd                 # 아이콘 + 미발견 darkened 실루엣, 엔트리 보더
  scripts/ui/time_hud.gd                 # 패널 보라 보더 + 섀도우
  scripts/ui/pause_menu.gd               # 프레임 패널 + 버튼 스타일
  scripts/world/interaction_controller.gd# + held_action_hint() + floating "E …" 프롬프트
  assets/icons/<id>.png       (new 58)   # 48×48 아이템 아이콘 (+ .import)
  assets/tiles/{t1_dirt,t2a,t2b,t2c,t2d,t4_mud,t5a_water,t5b_water2}.png  # soft edges (regen)
  scenes/dev/m8_icon_coverage.{gd,tscn}  (new)  # 아이콘 커버리지 하니스
```

## Deviations / notes
- **빈 손 박스 "dashed border"**: Godot StyleBoxFlat엔 점선 보더가 없어 딤(50% 알파)
  보더로 근사. 시각 의도(비어 있음) 동일.
- **아이콘 fallback**은 파일 존재 시 절대 안 쓰임(전 58개 존재). 방어 코드로만 유지.
- **m8은 소스 PNG를 읽어** 바이트-유니크를 검사 → `scenes/dev/*`(익스포트 제외)에서만
  의미. 익스포트 빌드의 데이터-intact는 m7이 커버.
- 게임 로직/세이브 스키마/맵 토폴로지/타일 규격 **불변**. 이 스프린트는 순수 비주얼/UI.
```
