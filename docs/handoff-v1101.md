# handoff — v1.10.1 (홈 섬 언더사이드 아트 개선 — 부유섬 암반화)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.10.1
- 태그 v1.10.1 → main. GH 릴리스 zip 2종(win64 + macOS) 첨부.
- 태스크 #257. KOAL 인게임 스크린샷 피드백 마감.
- **비주얼 온리 — 게임 로직/데이터/세이브 스키마 무변경. 세이브 100% 호환.**

## 문제 (KOAL 판정)
홈 섬(L0, 31×25) 하단 "다이오라마 언더사이드"가 **평평한 흙색 삼각형 웨지**로 렌더 →
부유섬 암반으로 안 읽힘. 추가로 톱니 바닥 외곽과 언더사이드 상단 폭이 **좌우에서 안 맞아
갭 발생**(스커트/언더사이드가 옛 21×17 중심 폭 가정, 31×25 확장 후 미추종).

### 근본 원인
`_build_shard_underside`(v0.5d)가 span(섬 전체 스크린 폭 1856px)짜리 슬래브를 **섬 바닥 꼭짓점
(y≈800, 톱니 최하단)** 에 top-center 앵커. 그 y에서 섬 실폭은 ~256px뿐 → 슬래브 넓은 상단
1856px가 양쪽으로 ~560px씩 허공에 튀어나오고, 톱니 외곽을 전혀 추종하지 않아 큰 갭.

## 개선 (인게임 `cliff_gen.gd`/`map_loader.gd` + 컴포지터 `tools_overview_home.js` 미러 동일)

### 1. 외곽 추종 top_profile (갭 0)
`make_underside(span, depth, salt, top_profile)` 로 시그니처 확장(옵션, 미공급 시 legacy).
- `top_profile[x]` = 그 컬럼 위 섬 **하부 rim 타일의 최고(min-y) 지점**. rim 없는 컬럼은 −1 →
  암반 미출력. 렌더 top edge가 톱니 실루엣을 정확히 추종.
- 각 rim 타일의 **두 하부 다이아 엣지(SW+SE)를 iso 기울기 0.5px/px 로 트레이스** (꼭짓점 flat
  선이 아니라 대각). → 톱니 바닥·이끼 립이 타일 하부 엣지에 픽셀 단위로 맞물림.
- 앵커 재설계: 이미지 상단 = 섬 **최고 하부 rim**(가장 넓은 하부 실루엣) − TILE_HALF_H,
  depth = (바닥꼭짓점 − 상단) + 0.34·span(매달린 꼬리). 슬래브가 섬 전폭을 덮고 아래로 감쇠.

### 2. 불규칙 암반 실루엣 (직선 테이퍼 금지)
- **층계식**: ty를 4단 shelf로 양자화 → 지층 4밴드(밝은 노출암→어두운 심부암), 교대 층 대비,
  shelf 경계 얇은 seam(퇴적층감). 상단은 완만·하단 1/3만 테이퍼 (`1 − 0.72·stepT^1.6`).
- 노이즈 텍스처 유지 + 층별 wobble/jag로 들쭉날쭉 외곽.

### 3. 디테일
- **매달린 암괴·종유석 2~4개**(salt 결정, 비대칭 배치): 명암 있는 3D 릴리프(좌면 라이트/우면
  섀도)로 렌더 — 검은 삼각형 아님. 종유석은 하단 은은 보라 팁.
- **보라 발광**(속삭임 테마 `Color8(150,118,214)`): tail 하단부 **둥근 측면 에지에만** 미세(≤0.30)
  — 중앙 빔 아님(초기 시안의 "스포트라이트" 아티팩트 제거).
- 이끼/잔디 립: 톱니 바닥 밑 첫 4행에 한 줄.
- **떨어져 나가는 부유 암편**: 기존 debris islet 5개 톤 통일 유지(무변경).

### 4. 인게임+컴포지터 동시 정합 (렌더=인게임)
`cliff_gen.gd`(암반 생성)·`map_loader.gd`(top_profile 산출·앵커)와 `tools_overview_home.js`
미러가 **동일 로직**. `--capsule` 모드 신규(섬 중심 1.8배 크롭 1920×1080, 언더사이드 프레임인).
- **다른 레이어 스커트/에이프런 무변경**(가이드 준수). 톱니 스텝 사이의 작은 하늘 삼각형은
  에이프런-레벨 기존 특성(v1.10.0에도 존재, 본 변경으로 오히려 축소) — 스코프 외.

## 검증 (v1.10.1 릴리스 구간 실측)
- **하네스**: run_sweep 전체 그린 — **65/65 (SWEEP COMPLETE, exit 0)**. v050c(언더사이드/에이프런/
  데브리 assert) PASS — aprons=31, underside=present, debris=5. v142 홈 레이아웃(코어 좌표 불변·
  homedeco 20) PASS(0 failures). e2e_playthrough PASS(0 failures).
- **실 PCK 스모크**(preset.2「Linux arm64」 exclude_filter 임시 해제 → `--export-pack` dev 포함
  pack **7,802,276 B** → 각 하네스 `--main-pack` 구동 → 프리셋 원복, 트리 클린 확인):
  e2e_playthrough + v142_home_layout 모두 **PASS (0 failures)**.
- **미러 파리티**: top_profile 산출(sloped tracing, min-y/컬럼)이 GDScript/JS 동일.

## 프리뷰 (3종 재렌더)
- `/workspace/group/preview-home.png` (1600×722) — 오버뷰
- `/workspace/group/preview-home-hero.png` (1214×938) — 아치+다이스(언더사이드 프레임 밖, 무변경)
- `/workspace/group/preview-home-capsule.png` (1920×1080) — 섬 중심 1.8배, 언더사이드 프레임인
- `dist/apple-ready/screenshots/capsule-candidate-home.png` 갱신

## 남은 리스크
- 톱니 스텝 사이 소형 하늘 삼각형(에이프런-레벨, 기존): 부유섬 read 저해 미미, 스커트 불변
  규칙상 미터치. 후속 개선 시 에이프런 커버리지 확장 별도 태스크 권장.
