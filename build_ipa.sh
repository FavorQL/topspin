#!/usr/bin/env bash
#
# Builds Topspin.app for a real iPhone and packages it as an unsigned .ipa.
#
# Requirements: macOS with Xcode 15+ and XcodeGen (brew install xcodegen).
#
# Usage:
#   ./build_ipa.sh              # unsigned IPA, sign it later with Sideloadly
#   ./build_ipa.sh --signed     # signed IPA, needs a Team ID + signing identity
#
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found. Install it with: brew install xcodegen" >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "error: Xcode command line tools not found. Install Xcode from the App Store." >&2
  exit 1
fi

echo "==> Generating Topspin.xcodeproj"
xcodegen generate

SIGNING_ARGS=(
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
)

if [[ "${1:-}" == "--signed" ]]; then
  TEAM_ID="${TEAM_ID:-}"
  if [[ -z "$TEAM_ID" ]]; then
    echo "error: --signed needs TEAM_ID. Find it with: security find-identity -v -p codesigning" >&2
    echo "       then run:  TEAM_ID=ABCDE12345 ./build_ipa.sh --signed" >&2
    exit 1
  fi
  echo "==> Signing with team $TEAM_ID"
  SIGNING_ARGS=(
    DEVELOPMENT_TEAM="$TEAM_ID"
    CODE_SIGN_STYLE=Automatic
    -allowProvisioningUpdates
  )
fi

echo "==> Building Release for iphoneos"
xcodebuild \
  -project Topspin.xcodeproj \
  -scheme Topspin \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  "${SIGNING_ARGS[@]}" \
  build

APP_PATH="build/Build/Products/Release-iphoneos/Topspin.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: build produced no app at $APP_PATH" >&2
  exit 1
fi

echo "==> Packaging IPA"
rm -rf Payload Topspin-unsigned.ipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry Topspin-unsigned.ipa Payload
rm -rf Payload

echo
echo "Done -> $(pwd)/Topspin-unsigned.ipa"
echo
echo "Next: install it with Sideloadly (https://sideloadly.io) or AltStore."
echo "Drag the IPA in, enter your Apple ID, and it will be signed and pushed to your device."
