# handoff — v1.9.0 (EX-L5: 침묵의 종탑 / 확장 EX-L1~L5 완결)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.9.0
- win64 40,276,263 / macos 68,608,369 (rcodesign ad-hoc 서명, verify OK — 2 slice ADHOC-signed, CodeResources sealed)
- 실 배포 PCK(macOS 임베디드) ProjectWhisper.pck = 7,209,496 (dev 씬 제외). Windows 단일 .exe 임베디드 103,830,056.
- 태그 v1.9.0 → main @ fc3fdc1 (exl5-belfry fast-forward 머지).

## 스코프
설계 정본 `docs/project-whisper-expansion-l5-design-v1.md` 구현. **확장 EX-L1~L5 완결.**
- 신규 존 「침묵의 종탑」(belfry, l5b, 40×40, spawn (19,39), walkable 696) — 대성당(cathedral) 최심부에서 하강 계단으로 진입. 대성당 정화(belfry 개방 조건) 후 하강 계단 스폰. SCENE_BELFRY + belfry_purified 플래그 + NG+ 리셋(dormant).
- 게이트 4종(타입 비반복): **GB1 종석 잔교**(배치/D325 — 허공 g를 잔교로 walkable화) → **GB2 흐려진 종음 결계**(정음의 물 사용 → 결계문 e 개방) → **GB3 울림 종 순서 퍼즐**(D328·D329·D330, list-key 순서 강제 — 역순/부분 거부, 3종 정순 완성 시 상층문 L 개방) → **GB4 종 봉헌 코어 재봉인**(체인·3속성(energy·mana·vita) 소비 sink·컷신 C-4).
- 데이터: 채집 S8~S12 + 제작 D324~D346. S12「자기-봉헌 유니크」= unique-as-catalyst(존재만 요구·소모 0) → R08 2회 제작→D331 2개→R09(D332「응답의 타종구」) 완주, 유니크 1개로 최종키 도달, softlock 아님.
- 속성 재획득처: 잔향 성수반(vita +1, idempotent) — GB4 3속성 sink 대비. 엔딩 Balance(4축) 정합.
- 잔재 NPC: 종지기 잔영(3유형 체인). 진상 조각 추가.
- 도감 아이콘 28종(S8~S12 채집 + D324~D346 조합) — 청동/녹청 벨메탈 + 상아-은 차임 글로우, byte-unique. m8 카운트 L5 49→77 / 총 409.

## 검증
- **전체 스윕 65/65 그린** (run_sweep.sh, 신규 l5s_map/l5s_gates/l5s_flow/l5s_unique 4종 포함). game/.sweep_done 제거 완료.
- **실 배포 PCK 3종 검증**(dev 포함 export→--main-pack→프리셋 원복): e2e_playthrough + l5s_flow + l5s_unique 모두 **PASS (0 failures)**.
  - PCK 절차: preset.2「Linux arm64」exclude_filter 임시 해제 → `--export-pack` (dev 포함 pack 7,746,584B) → 각 하네스 `--main-pack`으로 구동 → 프리셋 원복(트리 클린 확인).
  - **l5s_unique 핵심 수치**: A1 S12 미소모(R08 제작·재시도 후에도 S12 count=1 유지, S8 정상 1→0), A2 단일 S12로 R08 ×2 → D331 스택 2개(유니크×2 표면모순 해소, S12 여전 1), A3 체인 완주 → D332 획득·D331² 소모(2→0)·3속성 각1 sink(e=0 m=0 v=0) 후에도 **S12 count=1(촉매 drain 0)**.
  - **l5s_flow 핵심**: 미정화 시 하강계단 미스폰(잠김)→정화 후 스폰, GB1~GB4 순차 walkable, GB3 역순·부분 거부·3종 정순 해결, GB4 3속성 부족 시 봉헌 실패·컷신 C-4 중 time_running=false + control_lock 페어링·종료 후 복원, belfry_purified 시그널 발화.
  - **e2e**: 풀 플레이스루 + NG+ 리셋(cleared flag/월드 base ground intact/spawn 복귀/인벤 비움) PASS.
- **tools_spatial_audit.py**: L2~L5 + EX-L1~L5 **TOTAL VIOLATIONS 0** (게이트 재료 전부 게이트 앞 구역 확보 — softlock 없음).
- **l5x_bfs.py (침묵의 종탑)**: `ORDER-FORCED: PASS` — 전 게이트 개방+부적 walkable = **700칸**, orphan 0, severed 0(부적無 696/부적有 700). 우회 반증 성립.

## 프리뷰
- /workspace/group/preview-l5.png (3256×1724) — 침묵의 종탑 전체 조감, STACKED staggered, 신규 존 포함. tools_overview_l5b.js.
- /workspace/group/preview-l5-hero.png (1600×1200) — 종탑 정점 대종(o)+봉헌 목(H) 줌인.
- 아트: §㉙ 실루엣 변주 — 상아/백은 타일셋 + 청동 종체 + 상아-은 차임. §㉚ 바닥 문양 휴지. §㉛ 대종/차임벨 목표물 명도 대비 충족.

## 구세이브 호환
기존 세이브 로드 정상 — belfry_purified 플래그 지속, 재진입(정화됨) 시 종탑 게이트 walkable + 정화 컷신 미재생(시그널 재발화 없음), NG+ 리셋 시 belfry 플래그 dormant·포탈 라인 불변. v131_saveregress 그린.

## 빌드 환경 노트
- export 템플릿(4.5.stable)이 컨테이너에 미설치였음 — /workspace/group/tools/export_templates.tpz를 python zipfile로 추출(unzip 부재), /home/node/.local/share/godot/export_templates/4.5.stable/ 에 설치해야 build_exports.sh 통과. (세션 리셋 시 재설치 필요.)
- **버그 수정(fc3fdc1)**: e09b2ed(버전 커밋)가 project.godot config/version만 1.9.0으로 올리고 **export_presets.cfg 3종(product_version/short_version/application/version)은 1.8.0 잔존** → 빌드 버전 라벨 오표기. v1.9.0으로 정합.

## 남은 리스크
- 서명은 ad-hoc(공증 notarize 아님) — macOS 첫 실행 시 `xattr -dr com.apple.quarantine ProjectWhisper.app` 필요(릴리스 노트 명시). 기존 정책 동일.
- export 시 gio/kioclient5/gvfs-trash "child process" 에러는 무해(컨테이너 trash 데몬 부재, 산출물 정상).
- e2e 종료 시 "ObjectDB instances leaked at exit" WARNING — 하네스 teardown 잔여, exit 0·기능 무영향(기존과 동일).
- 다음: L0 허브 확장, 스팀 준비.
