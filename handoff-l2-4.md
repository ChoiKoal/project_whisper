# handoff-l2-4 — Layer 2 데이터 (아이템/레시피/아이콘/채집)

> v0.6.0-wip L2-4. 기준: `docs/project-whisper-layer2-design-v1.md` Part B/C.
> 상태: **L2-4 done.** 릴리스 없음(0.6.0 미상승 — L2-6 담당).

## 감사(audit) 결과
- 죽은 L2-4 에이전트가 남긴 것: J1~J7 + D62~D69 + 레시피 L2-R01~R08(게이트 체인)이 **817c16e에 이미 커밋**됨(working tree clean). 재작업 대상 = D70~D102 + L2-R09~R42 + 아이콘 48종.
- L2-R08 재조정: 커밋본은 `D68+D68`(코어 조각 2개) + `whisper_cost{energy:1}`로 구현됨(Part B의 "D68+에너지"를 2-입력 시스템 유지하며 반영, `_note` 문서화). Part B L2-R07 플레이버 "아직 하나가 모자라다"와 정합 → **유지**. D68 플레이버만 Part B 문구로 갱신.

## 작업 내역
### 1. items.json — D62~D102 완비
- D70~D102 (33 레코드) 추가. 전부 `layer:2`, category `craft`, Part B 플레이버 그대로.
- placement 클래스 부여(Part B (e)): decor/structure + `blocks`/`glows`. `on` 타일 = L2 지상 6종(L2T-M/C/c/G/A/m) + 홈 지상(T1/T2A-D/T0) — 홈·L2 양쪽 배치 가능(Part B (c)(e) "홈/Layer 2에 놓아").
- D68 플레이버 Part B 문구로 갱신.
- **아이템 총계: 117 레코드**(116 canonical + D06 alias). Layer-2 = J1~J7(7) + D62~D102(41) = 48.

### 2. recipes.json — L2-R01~R42 전종
- L2-R09~R42 (34 레시피) 추가. Part B 표와 1:1(재료/산출/힌트).
- **L2-R23 = J7 반환**(회로 태워 재 얻는 우회 채집, 새 아이템 없음).
- Part B가 QA에서 재조정한 페어 반영: 네온관 J6+**D71**, 빈 액자 D70+**J3**, 녹슨 훈장 J1+**J5**, 위성 안테나 D70+**D62** — 중복 페어 0.
- **레시피 총계: 104**(L1 62 + L2 42). *주: 브리프의 "112"는 근사치; Part B는 L2 42종을 명시(L2-R23이 J7 반환이라 신규 아이템 41).*

### 3. 아이콘 48종 (tools_gen_icons.js 확장)
- 과학 팔레트 추가(§C-1): navy #1a2438 / steel 램프 #5a6472·#3a4452·#222a38 / cyan #2fbfa8·#4ad9c8 / neon / amber / ash.
- J1~J7 + D62~D102 painter 48개 신규(전원 발광 아이템=cyanBehind, 폐허=무광 금속). `cyanSpark` 헬퍼.
- `node tools_gen_icons.js` → 117 PNG (68 L1 + 48 L2 + D06 alias). **byte-uniqueness: D06==I4 외 전부 유니크.**
- m8 하네스 확장: 68 L1 + 48 L2 + 1 alias split, L2 아이콘 real-file(비-fallback) assert, 116 유니크 해시. **m8 PASS.**

### 4. 채집 소스 배선
- L2-3에서 이미 완비 확인: `l2_map_legend.json` objects가 J1(debris/oil m-adjacent J5)·J2/J4(parts_box, `_l2_gather_item_id` 셀패리티 분기)·J3(glass_dome)·J6(neon gather)·J7(A타일 `gather:J7`) wired. 초기 스폰+리스폰 양쪽에 분기 적용. 추가 배선 불필요.

## 검증
- `python3 tools_verify_recipes.py` → **PASS (0 failures)**, 117 items / 104 recipes / 16 gatherables. 페어중복 0, 도달성 전부 OK, 고립 0.
- m8 아이콘 커버리지 **PASS**, m3 레시피 **PASS(56/56)**, l2_map_harness **PASS**, l2_gates_harness **PASS**.
- `--headless --import` 0 에러.

## L2-5로 넘김
- 흐름(포탈/퀘스트/정화/세이브)은 대부분 L2-3에 이미 존재. L2-5는 검증 + l2_flow_harness + 핸드오프.
