# Project Whisper — Steam 출시 가이드 v1.0

> 작성: Kana / 2026-07-05 · 대상: KOAL (스팀 출시 실무 절차)

## 0. 요약 타임라인

```
[지금] MVP 개발 ──> [빌드 안정화] Steamworks 가입+앱 등록 ──> "Coming Soon" 페이지 (출시 최소 2주 전 필수)
──> 빌드 업로드+리뷰 (2~5영업일) ──> 스토어 페이지 리뷰 (2~5영업일) ──> 출시 버튼
```

## 1. Steamworks 계정 & 앱 등록
1. https://partner.steamgames.com → Steamworks 파트너 가입 (개인 가능)
   - 필요: 신분증명, 은행 계좌(수익 수령), 세금 정보(W-8BEN — 한국 개인이면 미국 외 거주자 양식)
2. **Steam Direct 수수료: 앱 1개당 USD $100** (게임 수익 $1,000 도달 시 환급)
3. 결제 후 앱 ID 발급 → 대시보드에서 앱 생성 (이름: Project Whisper — 가칭이면 나중에 변경 가능)

## 2. 스토어 페이지 준비물 (아트 작업 필요 — 미리 리스트업)

| 에셋 | 크기 | 비고 |
|---|---|---|
| 캡슐 (헤더) | 920×430 | 스토어 메인 |
| 캡슐 (소형) | 462×174 / 231×87 | 목록/검색 |
| 캡슐 (세로) | 748×896 | 메인 피처링용 |
| 라이브러리 이미지 | 600×900, 3840×1240 히어로, 로고 PNG | 구매 후 라이브러리 |
| 스크린샷 | 1920×1080, **최소 5장** | 실제 플레이 화면 필수 |
| 트레일러 | 1080p+, 30초~2분 | 없어도 등록 가능하나 있으면 전환율 큰 차이 |
| 설명 텍스트 | 짧은 설명(300자)+긴 설명 | 한국어+영어 최소 2개 언어 권장 |

- 도트 게임은 캡슐 이미지 퀄리티가 클릭률을 좌우함 — 픽셀아트 일러스트 1장은 외주 고려할 것.

## 3. 빌드 업로드 (SteamPipe)

1. 대시보드 → App Admin → Depots 생성: `windows-x64` depot + `macos` depot (플랫폼별 분리)
2. **steamcmd** 로 업로드:
   ```
   steamcmd +login <계정> +run_app_build ../scripts/app_build_<appid>.vdf +quit
   ```
   - `app_build.vdf` / `depot_build.vdf` 스크립트에 빌드 폴더 경로 지정 (Godot export 결과물 폴더 그대로)
3. 대시보드 → SteamPipe → Builds에서 업로드된 빌드를 `default` 브랜치에 지정
4. Launch Options 설정: Windows → `ProjectWhisper.exe`, macOS → `ProjectWhisper.app`

### Godot 쪽 준비
- Windows: `.exe` (embed_pck 켜면 단일 파일) — 서명 없어도 스팀 배포 가능
- macOS: `.app` (zip) — **스팀 클라이언트로 실행되면 공증(notarization) 없이 동작**. 단 스토어 외 배포(dmg 직접 전달)는 우클릭-열기 필요 → 정식 출시 전 Apple Developer($99/년) 가입해서 서명+공증 권장
- 정식 버전에서 도전과제/오버레이 쓰려면 **GodotSteam** (GDExtension) 통합 — MVP 불필요

## 4. 리뷰 & 출시
1. 스토어 페이지 완성 → **리뷰 제출** (2~5영업일) → 통과 시 "Coming Soon" 공개 (출시일 최소 2주 전 필수 — 위시리스트 축적 기간)
2. 빌드 리뷰 제출 (실행 검증, 2~5영업일)
3. 둘 다 통과 + 2주 경과 → 출시 버튼 활성화
4. 가격 책정: 인디 조합 퍼즐 기준 $4.99~9.99 구간 검토 (지역 가격 자동 제안 사용)

## 5. 출시 전 활용 옵션
- **Steam Playtest**: 무료 베타 채널 — 데모 따로 만들 필요 없이 테스터 모집 (MVP 검증에 딱)
- **Next Fest**: 분기별 데모 페스티벌 — 위시리스트 폭증 기회, 데모 빌드 필요
- 커뮤니티 허브는 자동 생성 — 출시 초기 버그 리포트 채널로 활용

## 6. 체크리스트 (MVP → 출시)
- [ ] Steamworks 가입 + $100 + 세금/은행
- [ ] 앱 생성, 캡슐/스크린샷 5장/설명 2개 언어
- [ ] Coming Soon 페이지 리뷰 통과 (출시 2주 전)
- [ ] win/mac depot + steamcmd 업로드 파이프라인
- [ ] (권장) Apple Developer 서명 / (정식) GodotSteam 도전과제
- [ ] Playtest 오픈 → 피드백 → 출시
