# handoff — v1.8.0 (EX-L4: 부유 서고)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.8.0
- win64 40,173,729 / macos 68,508,430 (rcodesign ad-hoc 서명, verify OK — 2 slice ADHOC-signed, CodeResources sealed)
- 실 배포 PCK(macOS 임베디드) ProjectWhisper.pck = 7,058,520 (dev 씬 제외). Windows 단일 .exe 임베디드 103,679,080.

## 스코프
설계 정본 `docs/project-whisper-expansion-l4-design-v1.md` 구현.
- 신규 존 「부유 서고」(floating_archive, l4a, 40×40) — 마탑(구역 1) 최심부 봉인 재구축(`seal_core_restored`) 후 찢긴 통로로 하강 진입. SCENE_ARCHIVE + archive_purified 플래그 + NG+ 리셋(dormant).
- 실 고도 사용: 착지 0 / 부유 서가 +1 / 최심부 코어 +2 (l4a_map_height.txt). GW2·GW4 병목이 고도차를 겸해 강제(구역 1 방식 계승).
- 게이트 4종(타입 비반복): **GW1 부유 서가 다리**(배치/D302) → **GW2 흐려진 열람 결계**(정화의 물 D304 사용) → **GW3 금서 봉인 순서 퍼즐**(신규 술어 `seal_ordered`, 3서판 순서) → **GW4 금서고 코어 재봉인**(체인·마력 소비 sink·컷신 C-4).
- 데이터: 채집 P8~P12 + 제작 D301~D323. P12「금기 정수」= unique-as-catalyst(존재만 요구·소모 0, `fusion.gd` `_consume_inputs`) → R08 2회 제작→D308 2개→R09(D309) 완주, 유니크 1개로 최종키 도달, softlock 아님.
- 마력 Whisper 재획득처(잔류 열람 결계정 W, idempotent add_mana) + GW4 재봉인 마력 소비(sink) — 엔딩 Balance(4축) 대비.
- 잔재 NPC: 사서 잔영(N-librarian, 3유형 체인 제작 D301/배치/회고, mage_ghost 비게이팅). 진상 조각 「금기 열람 기록판」 추가.

## 검증
- **전체 스윕 61/61 그린** (run_sweep.sh, 신규 l4s_map/l4s_gates/l4s_flow/l4s_unique 4종 포함). game/.sweep_done 제거 완료.
- **실 배포 PCK 3종 검증**(dev 포함 export→--main-pack→프리셋 원복): e2e_playthrough + l4s_flow + l4s_unique 모두 PASS (0 failures).
  - l4s_unique 핵심 수치: A1 P12 미소모(P12 count=1 유지), A2 unique self-pair 레시피 0건·P12 consumer=[EX-L4-R08]뿐, A3 체인 완주→D309 획득 후에도 P12 count=1(촉매 미소모).
- **UID 충돌 실버그 수정**(b7f0337): l4s_flow/l4s_unique 씬 uid가 각 스크립트 uid와 동일(cl4sflowhrn01/cl4suniqhrn01) → export PCK에서 씬이 스크립트로 해석되며 parse 실패(소스 경로 로드에선 잠복). 씬 uid prefix c→b 분리(l4s_map 관례). 소스 경로 로드에선 안 드러나던 export-only 버그였음.
- **tools_spatial_audit.py**: L2~L5 TOTAL VIOLATIONS 0 (게이트 재료 전부 게이트 앞 구역 확보 — softlock 없음).
- **l4x_bfs.py (부유 서고)**: `ORDER-FORCED: PASS` — 전 게이트 개방+부적 walkable = **700칸**, orphan 0, severed 0(부적無 696/부적有 700). 우회 반증(GW2/GW3/GW4 단독 개방 → 후방 도달 X) 성립.

## 프리뷰
- /workspace/group/preview-l4.png (3256×1724) — 부유 서고 전체 조감, STACKED staggered, 신규 존 포함. tools_overview_l4m.js (source 4→l4_amethyst/dark/crack/ramp 재사용, 실 고도 아프론 + 허공 rim).
- /workspace/group/preview-l4-hero.png (1600×1200) — 최심부 금서고 코어(archive_core o + seal_altar H) 줌인, LANCZOS(고해상 캡처 area-avg).
- 아트: §㉙ 실루엣 변주 — reading_wax/forbidden_page/starpage_ink _b/_c 변주 + 잔교/서가/코어 실루엣 상이(단일 구조물 줄반복 없음). §㉚ 바닥 문양 휴지 — 균열 타일(x) 지그재그 밴드 + 빈 부유 파편 리듬으로 바닥 문양 반복 끊음.

## 구세이브 호환
기존 세이브 로드 정상 — archive_purified 플래그 지속, 재진입(정화됨) 시 모든 서고 게이트 즉시 walkable + 정화 컷신 미재생(시그널 재발화 없음), NG+ 리셋 시 archive 플래그 dormant·포탈 라인 불변. reconcile_portal_line 비역행 + _nearest_walkable_world 클램프 + v131_saveregress 그린.

## 빌드 환경 노트
- export 템플릿(4.5.stable)이 컨테이너에 미설치였음 — /workspace/group/tools/export_templates.tpz를 /home/node/.local/share/godot/export_templates/4.5.stable/ 에 추출·설치해야 build_exports.sh 통과. (재빌드 에이전트 참고: 세션 리셋 시 재설치 필요.)
- 버전 범프: project.godot config/version + export_presets.cfg의 product_version/short_version/version 3종 모두 1.8.0.

## 남은 리스크
- 서명은 ad-hoc(공증 notarize 아님) — macOS 첫 실행 시 `xattr -dr com.apple.quarantine ProjectWhisper.app` 필요(릴리스 노트 명시). 기존 릴리스와 동일 정책.
- export 시 gio/kioclient5/gvfs-trash "child process" 에러는 무해(컨테이너에 trash 데몬 부재, 산출물 정상).
- 다음: L0 허브 확장, 스팀 준비, preview-l5 STACKED 재렌더 확인.
