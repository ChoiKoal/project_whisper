#!/usr/bin/env bash
# =============================================================================
# Project Whisper — macOS 공증(notarization) 원커맨드 스크립트  [콸 로컬 맥 전용]
# =============================================================================
#
# 이 스크립트는 **콸의 맥(Apple Silicon 또는 Intel)에서** 실행합니다.
# 리눅스 빌드 호스트에서는 codesign / notarytool / stapler / spctl / hdiutil 이
# 없으므로 동작하지 않습니다. (rcodesign 로 만든 ad-hoc 서명 zip 을 받아서,
# 진짜 Developer ID 서명 + Apple 공증 + staple 로 승격시키는 단계입니다.)
#
# ─────────────────────────────────────────────────────────────────────────────
# 사전 준비 (최초 1회만)
# ─────────────────────────────────────────────────────────────────────────────
#  1) Xcode Command Line Tools:      xcode-select --install
#  2) "Developer ID Application" 인증서가 로그인 키체인에 설치되어 있어야 함
#       확인:  security find-identity -v -p codesigning
#       (없으면 developer.apple.com → Certificates 에서 발급/다운로드 후 더블클릭)
#  3) app-specific password 발급:  appleid.apple.com → 로그인 및 보안 →
#       앱 암호(App-Specific Passwords) → 새 암호 생성 (예: "whisper-notarize")
#  4) Team ID 확인:  developer.apple.com → Membership → Team ID (10자리, 예: ABCDE12345)
#  5) notarytool 자격증명을 키체인 프로파일로 1회 저장  ← 값은 콸이 직접 입력.
#       아래 명령을 **한 줄로** 실행 (이 스크립트에 하드코딩하지 말 것):
#
#         xcrun notarytool store-credentials whisper-profile \
#             --apple-id cjuny814@naver.com \
#             --team-id <TEAM_ID> \
#             --password <app-specific-password>
#
#       → 이후 이 스크립트는 --keychain-profile whisper-profile 만 참조하므로
#         Apple ID/암호를 다시 물어보지 않습니다. (자격증명은 맥 키체인에만 있음)
#
# ─────────────────────────────────────────────────────────────────────────────
# 사용법
# ─────────────────────────────────────────────────────────────────────────────
#   ./notarize_local.sh                     # 같은 폴더의 ProjectWhisper.app 사용
#   ./notarize_local.sh /path/to/ProjectWhisper.app
#
# apple-ready zip 을 풀면 이 스크립트, entitlements.plist, ProjectWhisper.app 가
# 한 폴더에 있으므로 그냥 `./notarize_local.sh` 한 줄이면 됩니다.
#
# 환경변수(선택):
#   PROFILE   notarytool 키체인 프로파일 이름            (기본: whisper-profile)
#   IDENTITY  서명 인증서 이름. 미지정 시 자동 감지        (기본: 자동)
#   OUT       배포물 접두어                                (기본: ProjectWhisper-macos-signed)
# =============================================================================
set -euo pipefail

APP="${1:-ProjectWhisper.app}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTITLEMENTS="${ENTITLEMENTS:-$HERE/entitlements.plist}"
PROFILE="${PROFILE:-whisper-profile}"
OUT="${OUT:-ProjectWhisper-macos-signed}"

fail() { echo ""; echo "✗ 실패: $*" >&2; exit 1; }
step() { echo ""; echo "▶ $*"; }

# --- 0. 플랫폼/도구 확인 -----------------------------------------------------
[ "$(uname)" = "Darwin" ] || fail "이 스크립트는 macOS 에서만 동작합니다 (현재: $(uname))."
command -v codesign  >/dev/null || fail "codesign 없음 → xcode-select --install 먼저 실행."
command -v xcrun     >/dev/null || fail "xcrun 없음 → Xcode Command Line Tools 설치 필요."
[ -d "$APP" ]          || fail "앱 번들을 찾을 수 없음: $APP"
[ -f "$ENTITLEMENTS" ] || fail "entitlements.plist 없음: $ENTITLEMENTS (zip 을 통째로 풀었는지 확인)."

# --- 1. 서명 아이덴티티 자동 감지 --------------------------------------------
if [ -z "${IDENTITY:-}" ]; then
  step "Developer ID Application 인증서 자동 감지 (security find-identity)"
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
              | grep 'Developer ID Application' | head -n1 \
              | sed -E 's/^[^"]*"([^"]+)".*/\1/')"
  [ -n "$IDENTITY" ] || fail "'Developer ID Application' 인증서를 키체인에서 못 찾음.
     → developer.apple.com 에서 발급/다운로드 후 더블클릭으로 키체인에 설치하세요.
     → 확인:  security find-identity -v -p codesigning"
fi
echo "  서명 아이덴티티: $IDENTITY"

# --- 2. 하드닝 런타임 + Developer ID 서명 ------------------------------------
# --deep: 번들 내부(pck 리소스, _CodeSignature)까지, --options runtime: 하드닝,
# --force: 기존 ad-hoc 서명 덮어쓰기. --timestamp: 공증 필수(보안 타임스탬프).
step "codesign — 하드닝 런타임 + Developer ID 서명"
codesign --force --deep --options runtime --timestamp \
         --entitlements "$ENTITLEMENTS" \
         --sign "$IDENTITY" \
         "$APP" \
  || fail "codesign 실패. 인증서 유효기간/키체인 잠금 여부 확인. (security unlock-keychain 시도)"

step "codesign --verify (서명 무결성 확인)"
codesign --verify --deep --strict --verbose=2 "$APP" \
  || fail "서명 검증 실패 — 번들 내부 파일이 손상되었거나 서명이 일부만 적용됨."

# --- 3. 공증 제출용 zip (ditto 는 심볼릭/권한 보존) --------------------------
SUBMIT_ZIP="$OUT-submit.zip"
step "ditto — 공증 제출용 zip 생성: $SUBMIT_ZIP"
rm -f "$SUBMIT_ZIP"
ditto -c -k --keepParent "$APP" "$SUBMIT_ZIP" \
  || fail "ditto zip 생성 실패."

# --- 4. Apple 공증 (제출 → 대기 → 결과) --------------------------------------
step "xcrun notarytool submit --wait  (Apple 서버 공증, 수 분 소요)"
if ! xcrun notarytool submit "$SUBMIT_ZIP" \
        --keychain-profile "$PROFILE" --wait; then
  echo ""
  echo "  공증 실패/거절. 상세 로그를 보려면 위 출력의 submission id 로:"
  echo "    xcrun notarytool log <submission-id> --keychain-profile $PROFILE"
  echo "  (프로파일 미등록 시: 이 파일 상단 '사전 준비 5)' 의 store-credentials 먼저 실행)"
  fail "notarytool 공증 미통과."
fi

# --- 5. staple (공증 티켓을 .app 에 영구 부착 → 오프라인에서도 Gatekeeper 통과) -
step "xcrun stapler staple — 공증 티켓 부착"
xcrun stapler staple "$APP" \
  || fail "stapler 실패 — 공증은 통과했으나 티켓 부착 실패. 잠시 후 재시도."

# --- 6. Gatekeeper 최종 검증 -------------------------------------------------
step "spctl -a -vv — Gatekeeper 승인 확인"
if spctl -a -vv "$APP" 2>&1 | tee /dev/stderr | grep -q "accepted"; then
  echo "  ✔ Gatekeeper accepted (source=Notarized Developer ID)"
else
  fail "spctl 검증에서 accepted 가 확인되지 않음. 위 출력 확인."
fi
xcrun stapler validate "$APP" \
  || echo "  (경고) stapler validate 실패 — 그래도 spctl accepted 면 배포 가능."

# --- 7. 배포물 재패키징 (zip + dmg) -----------------------------------------
DIST_ZIP="$OUT.zip"
step "배포 zip 생성: $DIST_ZIP"
rm -f "$DIST_ZIP"
ditto -c -k --keepParent "$APP" "$DIST_ZIP"

DMG="$OUT.dmg"
step "배포 dmg 생성 (hdiutil, 맥 전용): $DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # 드래그 설치용 Applications 별칭
rm -f "$DMG"
if hdiutil create -volname "Project Whisper" -srcfolder "$STAGE" \
       -ov -format UDZO "$DMG"; then
  echo "  ✔ dmg 생성 완료"
else
  echo "  (경고) dmg 생성 실패 — zip 배포물($DIST_ZIP)만으로도 배포 가능."
fi
rm -rf "$STAGE"

# --- 완료 --------------------------------------------------------------------
echo ""
echo "============================================================"
echo "✔ 공증 완료. 배포 가능 산출물:"
echo "    - $DIST_ZIP   (공증+staple 된 .app zip)"
[ -f "$DMG" ] && echo "    - $DMG   (드래그 설치 dmg)"
echo ""
echo "  최종 확인:  spctl -a -vv \"$APP\"  → 'accepted / Notarized Developer ID'"
echo "  다른 맥으로 옮겨서 더블클릭 → 경고 없이 실행되면 성공."
echo "============================================================"
