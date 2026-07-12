# handoff — v1.10.0 (L0 허브 확장 — 21×17 → 31×25 + 세계층 방향성 데코)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.10.0 (이미 라이브)
- 태그 v1.10.0 → main. GH 릴리스 zip 2종(win64 + macOS) 첨부.
- 태스크 #254. 4차(최종) 마감: 프리뷰 미러 보강 + handoff.

## 스코프
제0세계(home island) L0 허브를 **21×17 → 31×25**로 확장. **KOAL 승인 포탈 아치 구도(v1.4.2 복원)
셀 좌표를 픽셀 단위로 그대로 보존**하고, 주변으로만 실루엣을 확장해 허브다운 밀도·장소감·
세계층 방향성을 부여. 신규 순수 장식(homedeco) 소품 추가. **게임플레이/데이터/게이트/세이브
스키마 무변경** — 확장은 지면 승격 + 지면 위 비-블로킹 장식뿐.

## 레이아웃 확장 (31×25) — 코어 좌표 불변 증명
staggered(STACKED) 투영: `local = ((c + 0.5·(r&1))·128, r·32)`. 월드 좌표는 **절대 셀
인덱스의 선형함수**이므로, 코어 셀의 (c,r) 인덱스를 그대로 두면 `cell_center_world` 반환값이
픽셀 단위로 동일 → 아치 어서션 전부 불변 통과.

확장 규칙: **기존 콘텐츠 셀의 (c,r) 인덱스를 이동시키지 않는다.**
- 우측(c 증가)·하단(r 증가) 신규 셀 추가 → 인덱스 무이동.
- 상단/좌측은 기존 V 패딩 셀(고정 인덱스)을 V→지면(D)으로 승격해 실루엣만 확장.
  V→지면은 세이브 클램프에 무해(지면→V는 절대 없음).

### 보존 코어 좌표 (변경 0) — v142 하네스 (g) 상수 assert 로 회귀 봉쇄
| 요소 | 심볼 | (c, r) | 월드(하네스 실측) |
|---|---|---|---|
| 포탈1 잎/자연 | 1 | (7, 5) | (1024, 192) |
| 포탈2 데이터/과학 | 2 | (9, 4) | (1216, 160) |
| 포탈3 태엽/기계 (중앙 최상단) | 3 | (10, 3) | (1408, 128) |
| 포탈4 서고/마법 | 4 | (12, 4) | (1600, 160) |
| 포탈5 종/신성 | 5 | (13, 5) | (1792, 192) |
| 스폰(다이스) | S | (10, 9) | (1408, 320) |
| 관측석 | Y | (14, 11) | — |
| 솥 | C | (7, 12) | (960, 416) |

아치 불변 실측(하네스 (a)/(g)): P3 최상단(y=128 < P2/P4 y=160 < P1/P5 y=192), P1/P5·P2/P4
X대칭 완전(Σ오프셋 0), 1→5 좌→우 오름차순, 솥 다이스 좌하(rel x=−448 y=+96), 섬 bbox 2.42:1.

## 신규 세계층 방향성 데코 (homedeco) — 지면 위 순수 장식, 보행 가능
legend `kind` 디스패치로 map_loader 무변경 처리(신규 kind: `homedeco` → 공유 L2 spawn 경로 재사용).
전부 비-블로킹(`blocks:false`), offset `[0,-48]`, 진입 apron 셀 (col,row+2)은 보행 가능 유지
(데코는 apron 옆/뒤에만) → 하네스 (d) apron 비간섭.

| 심볼 | 모티프 | l2_id / art | 배치 | glow |
|---|---|---|---|---|
| p | 자연/잎 (P1 앞) | deco_leaf | 이끼 돌·새싹 | — |
| q | 과학/데이터 (P2 앞) | deco_data | 발광 룬 결정 | violet (0.5) |
| k | 기계/태엽 (P3 앞) | deco_gear | 멈춘 톱니 비석 | — |
| b | 마법/서고 (P4 앞) | deco_tome | 부유 룬 서판 | violet (0.4) |
| n | 신성/종 (P5 앞) | deco_bell | 석종·향로 | — |
| o | 빛 웅덩이 | deco_pool | 게이트/제단 시선 유도, 저대비 스캐터 | — |
| x | 비석·잔해 | deco_rubble (+b/c 변주) | 솥·가장자리 저밀도, art_variants 실루엣 변주 | — |

레이아웃 실 배치: 총 **20 데코 셀** (p×2 q×2 k×2 b×2 n×2 o×5 x×5). 부유 파편·하단 그림자는
floating_shard(map_loader)가 슬랩 확장분까지 aprons/underside/debris 자동 확대.

### §㉙ / §㉚ / §㉛ 처리
- **§㉙ 변주**: 잔해(`x`) art_variants(rubble b/c) 결정론적 hash-pick 으로 반복 소품 실루엣 변주.
- **§㉚ 목적 있는 바닥 휴지**: 중앙 다이스 광장(r 7–11)은 넓은 빈 바닥 유지, 데코는 상단 아치
  제단·좌하 솥 구역·가장자리로 분리 배치 → 스폰 광장의 의도된 여백 보존.
- **§㉛ 목표물 대비**: 데코는 전부 저채도·저높이(offset −48, 128px 소품)라 게이트(목표물)
  실루엣 대비를 흐리지 않음. glow 는 데이터/서고만 저강도 violet.

## 컴포지터 미러 갭 전말 (4차 검수에서 발견·수정)
**증상**(카나 검수, preview-home 04:42): 확장 실루엣(31×25)은 반영됐으나 신규 homedeco 오브젝트가
렌더에 전혀 안 보임(빈 흙 타일).

**진단**: 인게임 스폰은 정상, **컴포지터 전용 갭**으로 격리.
- `tools_overview_home.js` 는 SubViewport 리드백 불가(headless dummy 드라이버 프레임버퍼 없음)
  때문에 pngjs 로 게임 렌더를 오프라인 미러하는 컴포지터. 그 **Pass F**가 `C`(솥)/`Y`(관측석)/
  포탈(1–5)만 처리하고 `kind:"homedeco"` 심볼(p/q/k/b/n/o/x)을 **미러하지 않던 누락**.
- 게임 코드(map_loader `_spawn_object`)는 `kind=="homedeco"` → `_spawn_l2_object` 로 정상
  디스패치(art/art_variants/offset/glow 재사용). glow `"violet"` 도 지원(light_pool_violet).

**인게임 스폰 판정(근거)**: v142 하네스에 데코 스폰 카운트 어서션 섹션 **(h)** 추가 후 실행 →
`l2_object_nodes` 에서 `kind:"homedeco"` 노드 카운트 = **20/20 스폰·전부 live**, 7종 l2_id 전부
대표됨. **인게임 스폰 정상** → 게임 버그 아님, **핫픽스 v1.10.1 불필요**.

**수정**: 컴포지터 Pass F 에 homedeco 미러 추가.
- legend.objects `kind:homedeco` 스펙(art/art_variants/offset/glow/glow_scale)을 그대로 합성.
- art_variants 는 `hash2(c,r,11)` 결정 픽(잔해 b/c 변주 재현).
- 접지 그림자(눌린 타원) + violet glow(light_pool_violet, off.y·0.4, glow_scale, nearest-scale) 미러.
- `--hero` 모드 추가: 아치+다이스 줌인 크롭 → preview-home-hero.png
  (home_hero_render.tscn 은 실엔진 SubViewport 리드백이라 headless dummy 드라이버서 hang → 크롭 대체).

## 프리뷰
- /workspace/group/preview-home.png (1600×722) — L0 허브 전체 조감, STACKED staggered.
  20 데코 전부 미러 반영(잎/데이터/태엽/서고/종/빛웅덩이/잔해), 접지 그림자·violet glow 포함.
- /workspace/group/preview-home-hero.png (1214×868) — 아치 5기 + 다이스 제단 줌인.
  **자가 검수: v1.4.2 승인 아치 구도 유지 확인** — 포탈 1→5 좌→우, P3 최상단 중앙, 다이스 중앙,
  솥 좌하. 허브 장소감(§㉙ 잔해 변주·§㉚ 중앙 광장 휴지·§㉛ 저대비 데코 vs 게이트 목표물) 반영.

## 검증
- **전체 스윕 65/65 그린** (run_sweep.sh 프레시 재실행 — .sweep_done 제거 후 전종 재구동).
- **실 배포 PCK 스모크 2종 PASS** (커밋 15414bd 시점 확인: e2e_playthrough + PCK 스모크 0 failures).
- v142 하네스 (a)~(h) 전부 PASS: 아치 대칭·솥 좌하·스폰·apron·비율·**(g) 31×25+코어 불변**·
  **(h) homedeco 20/20 스폰**·(f) 구좌표 세이브 착지.

## 구세이브 호환
확장은 V→지면 승격 + 지면 위 비-블로킹 장식뿐 — 세이브 스키마·플래그·walkable 무변경.
지면→V 축소 없음(세이브 클램프 무해). 하네스 (f) 구-레이아웃 좌표 세이브 로드 → 플레이어 유효
셀 착지(landed (10,9)) 통과.

## 남은 리스크
- 컴포지터는 오프라인 미러(실엔진 아님) — 인게임 진실은 하네스 (h) 카운트 어서션이 봉쇄.
  추후 데코 심볼/art 추가 시 컴포지터 Pass F 와 (h) 기대 카운트 동반 갱신 필요.
- home_hero_render.tscn 은 headless 에서 여전히 hang(SubViewport 리드백) — 히어로 프리뷰는
  `tools_overview_home.js --hero` 크롭이 실사용 경로. 실엔진 스크린샷이 필요하면 GUI 드라이버 필요.
</content>
</invoke>
