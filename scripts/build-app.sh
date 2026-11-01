#!/bin/bash
# Builds "Callido Touch.app" into ./build.
#
#   scripts/build-app.sh                 ad-hoc signed (fine for your own Mac)
#   SIGN_IDENTITY="Callido Touch Signing" scripts/build-app.sh
#   UNIVERSAL=1 scripts/build-app.sh     arm64 + x86_64 (needs full Xcode)
#
# macOS ties the Accessibility and Input Monitoring permissions to the code signature.
# Ad hoc, every rebuild is a "new" app and the permissions have to be granted again.
# Release builds are signed with the stable Callido Touch certificate (see docs/RELEASING.md),
# so the permissions survive updates.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null | sed 's/^v//' || echo 0.0.0)}"
APP="build/Callido Touch.app"

ARCH_FLAGS=()
[ "${UNIVERSAL:-0}" = 1 ] && ARCH_FLAGS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}"
BIN="$(swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}" --show-bin-path)/CallidoTouch"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CallidoTouch"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

SIGN_ARGS=(--force --options runtime --timestamp=none --identifier nl.callido.touch --sign "${SIGN_IDENTITY:--}")
[ -n "${SIGN_KEYCHAIN:-}" ] && SIGN_ARGS+=(--keychain "$SIGN_KEYCHAIN")
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($VERSION, signed by ${SIGN_IDENTITY:-ad hoc})"
