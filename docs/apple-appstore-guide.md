# Mac App Store 배포 가이드 — Project Whisper

이 문서는 **Project Whisper 를 Mac App Store(MAS)에 올리는 전 과정**을, 콸이 처음부터
그대로 따라할 수 있게 단계별로 정리한다. 서명·패키징·업로드는 모두 **콸의 맥**에서
수행하며(리눅스 빌드 호스트는 ad-hoc 서명 zip 까지만 만든다), Apple 크리덴셜은 이 리포에
저장하지 않는다.

> **두 배포 트랙이 있다.** 이 문서는 **트랙 B(Mac App Store)** 다.
> 트랙 A(Developer ID 직접배포·공증)는 `docs/apple-notarization-guide.md` 참고.
> 두 트랙의 차이 요약표는 맨 아래 §7 에 있다. 하나만 해도 배포는 가능하다 —
> MAS 는 검색/자동업데이트/결제가 붙지만 심사가 있고, Developer ID 는 심사 없이
> 즉시 배포되지만 사용자가 직접 dmg 를 받는다.

핵심 값 (미리 확인):

| 항목 | 값 |
|---|---|
| 번들 ID | `com.koalstudio.projectwhisper` (export preset·postprocess 실제값과 일치 확인됨) |
| 앱 이름 | Project Whisper |
| 플랫폼 | macOS |
| 카테고리 | 게임(Games) |
| 현재 버전 | 1.9.1 |
| Apple ID(예시) | cjuny814@naver.com |

준비물 (이 리포가 제공):

- `dist/apple-ready/ProjectWhisper-apple-ready-v1.9.1.zip` → 안의 `ProjectWhisper.app`
  (v1.9.1, 커스텀 아이콘·Info.plist 반영, 현재 ad-hoc 서명 → MAS 인증서로 재서명 예정)
- `tools/apple/entitlements-mas.plist` (App Sandbox 포함 최소 entitlements)
- `tools/build_mas_pkg_local.sh` (재서명 → .pkg 패키징 원커맨드)
- `dist/apple-ready/screenshots/*.png` (1280×800 스크린샷 후보 5장 — 업로드용 초안)

---

## 0. 사전 준비 (최초 1회)

1. **Apple Developer Program 가입** (연 $99). developer.apple.com → Account.
2. **Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```
   (전체 Xcode 도 있으면 좋지만, CLT + Transporter 만으로 이 가이드는 완주 가능.)
3. **Transporter.app** 설치: Mac App Store 에서 "Transporter" 검색 → 무료 설치.
   (빌드 .pkg 를 App Store Connect 로 올리는 공식 도구.)

---

## 1. developer.apple.com — 식별자·인증서·프로파일

### 1-1. App ID(Identifier) 등록
1. developer.apple.com → **Certificates, Identifiers & Profiles** → **Identifiers** → **＋**.
2. **App IDs** → **App** 선택.
3. **Bundle ID = Explicit**, 값에 **`com.koalstudio.projectwhisper`** 입력
   (반드시 이 값. 빌드의 `CFBundleIdentifier` 와 정확히 일치해야 업로드가 붙는다).
4. Description: `Project Whisper`. Capabilities 는 **아무것도 켜지 않는다**
   (이 게임은 게임센터/인앱결제/푸시/iCloud 등을 쓰지 않음). 저장.

### 1-2. 인증서 2종 발급
MAS 는 **앱 서명용**과 **설치관리자(.pkg) 서명용** 인증서가 각각 필요하다.

1. **Identifiers 옆 Certificates → ＋**.
2. **Apple Distribution** 선택 → (Xcode 가 있으면 자동, 없으면) CSR 생성 후 업로드 →
   발급 → 다운로드 → 더블클릭으로 로그인 키체인에 설치.
   - (구 명칭 "3rd Party Mac Developer Application" — 스크립트는 두 명칭 모두 인식.)
3. 다시 **Certificates → ＋** → **Mac Installer Distribution**
   (= "3rd Party Mac Developer Installer") 발급 → 다운로드 → 더블클릭 설치.

> CSR(인증서 서명 요청) 만드는 법(Xcode 없이): **키체인 접근.app → 인증서 지원 →
> 인증 기관에서 인증서 요청** → 이메일 입력, "디스크에 저장" → 생긴 `.certSigningRequest`
> 를 위 발급 화면에 업로드.

설치 확인:
```bash
security find-identity -v            # "Apple Distribution: ..." 보여야 함
security find-identity -v -p basic   # "3rd Party Mac Developer Installer: ..." 도 확인
```

### 1-3. Provisioning Profile (macOS App Store)
1. **Profiles → ＋** → Distribution 아래 **Mac App Store** 선택.
2. App ID = `com.koalstudio.projectwhisper` 선택.
3. 위에서 만든 **Apple Distribution** 인증서 선택.
4. 이름(예: `ProjectWhisper_MAS`) → 생성 → **다운로드**
   (`.provisionprofile` 파일. 경로를 빌드 스크립트 2번째 인자로 넘긴다).

---

## 2. App Store Connect — 앱 레코드 만들기

appstoreconnect.apple.com → **나의 앱 → ＋ → 신규 앱**.

1. **플랫폼: macOS** 체크.
2. **이름**: `Project Whisper` (스토어 표시명; 전 세계 유일).
3. **기본 언어**: 한국어(또는 영어).
4. **번들 ID**: 드롭다운에서 `com.koalstudio.projectwhisper` 선택
   (1-1 에서 등록해야 목록에 뜬다).
5. **SKU**: 내부 관리용 임의 문자열(예: `PW-MACOS-001`). 공개되지 않음.
6. **사용자 액세스**: 전체(기본).

앱 레코드가 생기면 아래 메타데이터를 채운다:

- **앱 정보**: 카테고리 = **게임** (2차 카테고리 선택 가능, 예: 어드벤처/캐주얼).
- **연령 등급(App Store 등급)**: 설문 응답 → 폭력/성적 표현 등 해당 없음 위주로
  응답하면 낮은 등급. (이 게임은 폭력/선정성 없음.)
- **가격 및 사용 범위**: **무료** 또는 유료 티어 선택. 판매 지역 선택.
- **개인정보 처리방침 URL**: 필수. 게임이 데이터를 수집하지 않아도 URL 은 있어야 함
  (간단한 "데이터를 수집하지 않습니다" 페이지라도 준비).
- **앱 개인정보 보호(App Privacy)**: "데이터를 수집하지 않음" 으로 선언
  (오프라인 싱글플레이·네트워크 미사용·수집 없음 — entitlements 에 network 없음과 일치).

### 2-1. 스크린샷
- macOS 스크린샷 허용 규격(정확히 이 중 하나여야 함):
  **1280×800 / 1440×900 / 2560×1600 / 2880×1800**.
- 최소 1장, 권장 5장(최대 10장).
- 이 리포가 **1280×800 후보 5장**을 미리 만들어 둠:
  `dist/apple-ready/screenshots/01-title.png … 05-art.png`
  (01 타이틀·02 홈 아일랜드 실렌더는 그대로 써도 무방, 03~05 는 필요시 실제 플레이
  화면으로 교체 권장 — 규격만 맞추면 됨).
- 실제 플레이 캡처로 교체하려면: 맥에서 게임 실행 → `⌘⇧4` 로 영역 캡처 후 위 규격에
  맞게 리사이즈, 또는 리눅스 호스트의 `tools/make_mas_screenshots.py` 로 재생성.

---

## 3. 빌드 업로드 (.pkg → Transporter)

### 3-1. .pkg 만들기 (콸 맥에서)
apple-ready zip 을 풀고, `1-3` 에서 받은 프로파일 경로를 넘겨 실행:

```bash
# 리포 루트에서(또는 apple-ready 를 푼 폴더에서 app 경로만 맞추면 됨)
./tools/build_mas_pkg_local.sh \
    dist/apple-ready/ProjectWhisper.app \
    ~/Downloads/ProjectWhisper_MAS.provisionprofile
```

스크립트가 순서대로:

| 단계 | 내용 |
|---|---|
| 1 | 인증서 2종 **자동 감지** (Apple Distribution + Mac Installer Distribution) |
| 2 | 프로파일을 `.app/Contents/embedded.provisionprofile` 로 임베드 |
| 3 | `codesign --entitlements entitlements-mas.plist` 로 **샌드박스 + Apple Distribution 재서명** |
| 4 | `codesign -d --entitlements` 로 **app-sandbox 적용 검증** |
| 5 | `productbuild --component ... --sign` 으로 서명된 **`ProjectWhisper-mas.pkg`** 생성 |

각 단계 실패 시 원인을 한국어로 안내한다(인증서 없음/키체인 잠김/프로파일 App ID 불일치 등).

### 3-2. Transporter 로 업로드
1. **Transporter.app** 실행 → Apple ID 로그인.
2. 생성된 `ProjectWhisper-mas.pkg` 를 창에 **끌어다 놓기**.
3. Transporter 가 자동 검증(sandbox·entitlements·서명·아이콘 등) → **전송(Deliver)**.
   - (CLI 대안:
     `xcrun altool --upload-app -f ProjectWhisper-mas.pkg -t macos --apple-id <APPLE_ID> --password <app-specific-pw>`)
4. 업로드 성공 후 App Store Connect 에서 **처리(Processing)** 상태 → 수 분~수십 분 후
   빌드가 "빌드" 섹션에 나타난다.

### 3-3. 빌드 선택
App Store Connect → 해당 앱 버전 → **빌드** 섹션에서 방금 올린 빌드 선택.
(수출 규정 암호화 질문이 뜨면: 표준 암호화만 사용/해당 없음으로 응답.)

---

## 4. 심사 제출

1. 버전 정보(설명·키워드·지원 URL·마케팅 URL(선택))·스크린샷·빌드가 모두 채워졌는지 확인.
2. **심사를 위해 제출(Submit for Review)**.
3. 상태: 심사 대기(Waiting) → 심사 중(In Review) → 승인(Approved)/거절(Rejected).
   보통 1~3일.

---

## 5. 게임 심사 유의사항 (리젝 예방)

- **샌드박스 크래시가 최대 리스크.** MAS 빌드는 App Sandbox 하에서 돌아가며 `user://` 가
  `~/Library/Containers/com.koalstudio.projectwhisper/Data/...` 로 리다이렉트된다.
  → 이 게임은 세이브를 **`user://save1.json` + `user://audio.cfg`** 로만 쓰고
  절대경로/외부 파일 접근이 없어(감사 완료) 컨테이너에서 그대로 동작한다. 제출 전
  **콸 맥에서 .pkg 를 로컬 설치→실행→새 게임→세이브→종료→이어하기**로 한 번 확인하면 안전.
- **최소 기능성(Guideline 4.2)**: "빈 껍데기/데모" 로 보이면 거절. Project Whisper 는
  5레이어·엔딩·NG+ 가 있는 완결 게임이므로 문제 없으나, 설명/스크린샷이 실제 플레이를
  충분히 보여주게 한다.
- **메타데이터 정합(2.3)**: 스크린샷·설명이 실제 빌드와 일치해야 한다. 아직 없는 기능을
  광고하지 말 것.
- **개인정보(5.1)**: "데이터 수집 없음" 선언이 실제와 일치(네트워크 entitlement 없음)해야 함.
- **저작권/에셋**: 사용한 폰트·에셋 라이선스 확인(리포 `CREDITS.md`).

---

## 6. 리젝 대비 팁

- 거절 사유는 **Resolution Center** 에 상세히 온다. 그대로 읽고 지적 항목만 고쳐 재제출.
- **샌드박스 관련 거절**이면: 크래시 로그(리뷰어가 첨부) 확인 → 해당 파일 접근이 컨테이너
  밖을 노렸는지 점검. 이 게임은 해당 없음이 확인됐지만, 새 기능 추가 시 재점검.
- **entitlements 과다** 지적이면: `entitlements-mas.plist` 에서 안 쓰는 권한 제거
  (현재 app-sandbox + disable-library-validation 최소셋이라 여지 적음).
- **빌드가 안 뜰 때**: 번들 ID/버전 중복, 아이콘 누락, 서명 불일치가 흔한 원인.
  Transporter 업로드 시점의 검증 메시지가 1차 단서.
- 메타데이터/스크린샷만 고치는 재제출은 빌드 재업로드 불필요(빠름).

---

## 7. 트랙 A(공증 직접배포) vs 트랙 B(Mac App Store) 차이 요약

| 항목 | 트랙 A — Developer ID + 공증 | 트랙 B — Mac App Store |
|---|---|---|
| 문서 | `docs/apple-notarization-guide.md` | 이 문서 |
| 스크립트 | `tools/notarize_local.sh` | `tools/build_mas_pkg_local.sh` |
| entitlements | `tools/apple/entitlements.plist` (샌드박스 **없음**) | `tools/apple/entitlements-mas.plist` (**App Sandbox 필수**) |
| 인증서 | Developer ID Application (1종) | Apple Distribution + Mac Installer Distribution (2종) |
| Provisioning Profile | 불필요 | **필요** (macOS App Store 프로파일) |
| 산출물 | 공증+staple 된 `.zip` / `.dmg` | 서명된 `.pkg` (→ Transporter 업로드) |
| Apple 심사 | **없음** (공증은 자동 악성코드 스캔) | **있음** (사람 리뷰, 1~3일) |
| 배포 경로 | 콸이 직접 파일 배포(웹/직링크) | App Store 검색·설치·자동 업데이트 |
| 결제/내부 결제 | Apple 관여 없음(외부 결제 자유) | App Store 결제 정책 적용 |
| 샌드박스 | 없음(더 자유로움) | 필수(파일 접근 컨테이너 격리) |
| 최초 도달 속도 | 빠름(심사 없음) | 느림(심사 대기) |

> 세이브 경로는 **양쪽 트랙 모두 호환**된다. 트랙 A 는 샌드박스가 없어 그대로,
> 트랙 B 는 App Sandbox 가 `user://` 를 컨테이너로 리다이렉트하지만 게임이 절대경로를
> 쓰지 않아 코드 변경 없이 동작한다(감사 완료).
