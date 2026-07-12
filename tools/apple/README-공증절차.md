# Project Whisper — macOS 공증 절차 (콸 전용, 이 zip 안에서 실행)

이 zip 을 풀면 아래 3개가 한 폴더에 있습니다.

```
ProjectWhisper.app        ← 게임 (현재 ad-hoc 서명 상태)
notarize_local.sh         ← 공증 원커맨드 스크립트
entitlements.plist        ← 하드닝 런타임 권한(최소셋)
README-공증절차.md         ← 이 문서
```

맥에서 **딱 한 줄**이면 서명→공증→staple→검증→배포물(zip/dmg)까지 끝납니다.

---

## 0. 최초 1회만 (자격증명 등록)

> Apple ID / 앱 암호 / Team ID 는 **콸이 자기 맥에서만** 입력합니다.
> 스크립트에는 어떤 값도 저장돼 있지 않습니다.

1. Xcode Command Line Tools (없으면):
   ```bash
   xcode-select --install
   ```
2. **Developer ID Application** 인증서가 키체인에 있는지 확인:
   ```bash
   security find-identity -v -p codesigning
   ```
   `"Developer ID Application: ..."` 줄이 보이면 OK.
   없으면 developer.apple.com → Certificates 에서 발급/다운로드 후 더블클릭.
3. **app-specific password** 발급: appleid.apple.com → 로그인 및 보안 → 앱 암호 → 새로 생성.
4. **Team ID** 확인: developer.apple.com → Membership → Team ID (10자리).
5. notarytool 자격증명을 키체인 프로파일로 저장 (한 줄):
   ```bash
   xcrun notarytool store-credentials whisper-profile \
       --apple-id cjuny814@naver.com \
       --team-id <TEAM_ID> \
       --password <app-specific-password>
   ```

---

## 1. 공증 실행 (매번)

zip 을 푼 폴더에서:

```bash
./notarize_local.sh
```

스크립트가 순서대로 수행합니다:

| 단계 | 내용 |
|---|---|
| 1 | `security find-identity` 로 Developer ID 인증서 **자동 감지** |
| 2 | `codesign --force --deep --options runtime --timestamp --entitlements entitlements.plist` 로 **하드닝 런타임 + Developer ID 재서명** (기존 ad-hoc 덮어씀) |
| 3 | `ditto` 로 공증 제출용 zip 생성 |
| 4 | `xcrun notarytool submit --wait --keychain-profile whisper-profile` → **Apple 공증** (수 분) |
| 5 | `xcrun stapler staple` → 공증 티켓을 .app 에 부착 (오프라인에서도 통과) |
| 6 | `spctl -a -vv` → **Gatekeeper accepted** 확인 |
| 7 | 배포용 `.zip` + `.dmg` 재패키징 |

각 단계 실패 시 원인과 다음 조치를 한국어로 안내합니다.

---

## 2. 완료 확인

```bash
spctl -a -vv ProjectWhisper.app
# → accepted
#   source=Notarized Developer ID
```

- 산출물: `ProjectWhisper-macos-signed.zip`, `ProjectWhisper-macos-signed.dmg`
- **다른 맥**으로 옮겨 더블클릭 → 경고 없이 실행되면 배포 준비 완료.

---

## 자주 나는 문제

- **`Developer ID Application 인증서를 못 찾음`** → 2번 미완료. 인증서 더블클릭으로 키체인 설치.
- **`notarytool` 프로파일 없음** → 0-5 의 `store-credentials` 먼저 실행.
- **공증 거절** → `xcrun notarytool log <submission-id> --keychain-profile whisper-profile` 로 상세 사유 확인 (보통 서명 누락/entitlements 과다).
- **키체인 잠김** → `security unlock-keychain login.keychain` 후 재실행.
