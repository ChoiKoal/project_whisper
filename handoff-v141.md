# Handoff — v1.4.1 (KOAL 실플레이 리포트 3건: 렌더 방위·솥 이펙트·가림 순서)

Status: DONE(코드/아트/하네스/프리뷰). 세이브 100% 호환(게임 로직 변경 = 릿지 벽 시각 정렬뿐,
데이터/충돌 스키마 무변경). 릴리스 빌드/업로드 상태는 STATUS.md 최신 항목 참조.

## 무엇을 했나
KOAL 실플레이에서 발견된 3건 수정.

### BUG 1 (핵심) — 렌더 ↔ 인게임 맵 방위 불일치 (전 레이어)
오버뷰 프리뷰(tools_overview_*.js)의 맵 방위가 인게임과 달랐다(L0 홈·L1 숲 확인).

- **3자 대조**:
  - (a) 데이터: `game/data/map_layout.txt` — row(파일 위→아래) / col(왼→오).
  - (b) 인게임 투영: `game/scripts/world/map_loader.gd`는 Godot `TileMapLayer.map_to_local` 사용.
    타일셋 `game/data/whisper_tileset.tres`: `tile_shape=1`(ISOMETRIC), **`tile_layout=0`(STACKED)**,
    **`tile_offset_axis=0`(HORIZONTAL)**, `tile_size=(128,64)`. → Godot 공식(4.5 소스 확인):
    `local = ((col + 0.5·(row&1) + 0.5)·128, (row·0.5 + 0.5)·64)` = **staggered/offset 배치**
    (col=화면 수평/동, row=아래로 반칸씩 stagger, 홀수 row 반칸 우측).
  - (c) 컴포지터: `tools_overview_*.js`의 `cellLocal(c,r)`가 **diamond** `[(c-r)·64,(c+r)·32]`.
- **판정**: (b)STACKED ↔ (c)diamond가 서로 다른 iso 규칙 → 컴포지터가 게임 대비 **~45° 회전
  (축 반사 포함)**. (a)레이아웃 ↔ (b)인게임은 정합. 즉 **(b)–(c) 쌍이 뒤집혀 있었다**.
- **정정 원칙**(게임 데이터+인게임=정본)대로 **컴포지터를 게임에 일치** — 6종 전부:
  - `cellLocal`을 STACKED로 교체: `[(c + ((r&1)?0.5:0))·TW, r·HH]` (home, l1, l2, l3, l4, l5).
  - 오브젝트 y-sort 정렬키 `depth: c+r`(diamond) → 화면 Y(`baseY`, 세계수는 `cy`)로 교정.
    (STACKED에선 화면 Y = `row·32` 이므로 row 기준 정렬이 정본; c+r은 diamond 전제라 오정렬.)
  - `tools_overview_home.js` 데브리/중심 좌표를 diamond 상수식 → `cellLocal()` 호출로 교정.
- 재렌더 후 랜드마크 정합 확인(인게임 방위 기준):
  - L1: 세계수·연못 = top-center(북), 강(W) = 수평 밴드, 솥 = 중앙-좌.
  - L2: 관제탑 = 북 / 스폰 = 남 (설계 "남→북 수직 여정"), 시안 에너지선 수평.
  - L3 대시계탑 = 북, L5 종탑 = 북, 벽 = staggered 수평 밴드.
- **게임 코드/데이터 무변경** → 세이브·하네스 영향 0. (인게임 투영 자체는 레이아웃과 정합이라
  게임 픽스 불필요.)

### BUG 2 — 솥단지 발광 오브 "동그라미 둥둥"
v1.4.0 솥 리사이즈 후 개구부(림)+발광 링이 몸통 위로 떠 detached halo로 보임.

- 원인: `game/tools_gen_home_objects.js` `cauldron()` 지오메트리 — 몸통 어깨 반경 `bellyR(0)≈0.86·rx`
  가 림 폭 `rx`보다 좁고, 몸통 시작 y = `shoulderY+ry`(림 아래)라 림↔몸통 사이 목 간극 → 개구부 부양.
- 수정: 어깨 반경 = 림 폭(`base` 0.86→1.00, bulge 계수 소폭 조정), 몸통 시작 y = `shoulderY`(=topY,
  림 밑면과 연속), `botY = shoulderY+h` 정합. → `assets/objects/cauldron.png` / `cauldron_bubble.png` 재생성.
- 전 레이어 커버: L2~L5 조합대는 v1.1.0 GP-1 이후 **동일 솥 아트 + 색만 다른 light_pool**
  (홈/L1 보라 / L2 시안 / L3 주황 / L4 금 / L5 앰버) 재사용 → 단일 아트 픽스로 4종 불꽃색 전부 해결.
  light_pool 오프셋 `(0,-8)`은 개구부(topY 무변)에 여전히 정렬.

### BUG 3 — 벽 뒤 나무 뚫림 (y-sort)
벽(내부 릿지 바위벽) 북쪽(뒤)에 있어야 할 나무가 벽을 뚫고 앞에 그려짐.

- 원인: 릿지 벽 스프라이트가 타일맵 자식의 **고정 z=`RIDGE_Z`(3)**에 놓여, YSortLayer(z5)의
  나무/오브젝트에게 **위치와 무관하게 항상** 짐 → 어떤 나무든 벽 위로 그려짐.
- 수정: `game/scripts/world/map_loader.gd` `_build_ridges()` — 릿지 벽 스프라이트를 **YSortLayer(`_ysort`)에
  편입**, `y_sort_enabled=true`, 노드 `position = cell_center_world(cell)`(접지점 = 나무 발밑과 동일 기준),
  아트는 `offset = (-64, TILE_HALF_H - th)`로 위로 들어올림(벽 밑면이 셀 하단 rim에 접지). → 화면 Y로
  나무와 정렬(벽 북쪽=뒤/가려짐, 벽 남쪽=앞/보임). `_ysort==null`(테스트) 시 기존 고정-z 오버레이 폴백.
- 참고: 나무 스프라이트 offset(-110/-116/-105)은 이미 발밑 앵커(centered 230px 트리 → 발이 셀 중심),
  세계수 offset(0,-238)@scale .72도 발 = 셀 중심으로 정합. y-sort 정렬키(노드 position.y = 셀 중심)는
  벽·나무 공통.

## 신규/변경 파일
- `game/tools_overview_{home,l1,l2,l3,l4,l5}.js` — cellLocal STACKED 교체 + y-sort 키 교정 (+home 중심/데브리).
- `game/tools_gen_home_objects.js` — 솥 지오메트리 (어깨/몸통 시작/botY).
- `game/assets/objects/cauldron.png`, `cauldron_bubble.png` — 재생성.
- `game/scripts/world/map_loader.gd` — `_build_ridges` YSort 편입.
- `game/scenes/dev/v141_ysort_harness.{gd,tscn}` — 신규 가림 하네스 (9/9 PASS).
- `game/project.godot`, `game/export_presets.cfg` — 버전 1.4.0→1.4.1.
- `KNOWN-ISSUES.md`, `STATUS.md`, `handoff-v141.md`.
- 프리뷰 재렌더: `/workspace/group/preview-{home,l1,l2,l3,l4,l5}.png`.

## 검증
- `v141_ysort_harness` 9/9 PASS (YSort 편입·접지 앵커·가림 불변식 북=뒤/남=앞·나무 발밑 앵커).
- 전 하네스 스위프(tools/run_sweep.sh) — .sweep_done 클리어 후 전체 재실행.
- 프리뷰 6종 재렌더 → 인게임 방위와 랜드마크 정합 확인(위 BUG 1 서술).

## 다음
- (선택) 컴포지터의 홈 floating-shard underside/aprons는 diamond 시절 기하 잔재가 일부 남음
  (underside 뾰족 taper). 타일/오브젝트/포탈 방위는 정합이며 장식 요소라 v1.4.1 범위 밖. 후속 폴리시 후보.
- 인게임 릿지 벽 외 다른 고정-z 시각요소(절벽 스커트 등)의 y-sort 재검토는 필요 시 별도.
