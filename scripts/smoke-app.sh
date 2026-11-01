#!/bin/bash
# Checks a built "build/Callido Touch.app": bundle layout, signature, both architectures when universal,
# and that the binary starts (dump mode, killed after two seconds; CI has no touch screen).
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/Callido Touch.app"
BIN="$APP/Contents/MacOS/CallidoTouch"

die() { echo "smoke: $*" >&2; exit 1; }
[ -x "$BIN" ] || die "executable missing"
[ -f "$APP/Contents/Resources/AppIcon.icns" ] || die "AppIcon.icns missing"
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")" = nl.callido.touch ] || die "bundle id"
codesign --verify --strict --verbose=2 "$APP" || die "signature does not verify"
if [ "${UNIVERSAL:-0}" = 1 ]; then
  for a in arm64 x86_64; do lipo "$BIN" -verify_arch "$a" || die "no $a slice"; done
fi
"$BIN" --dump --no-seize > "${TMPDIR:-/tmp}/callido-touch-smoke.log" 2>&1 &
pid=$!
sleep 2
kill -0 "$pid" 2>/dev/null || { cat "${TMPDIR:-/tmp}/callido-touch-smoke.log"; die "binary exited early"; }
kill "$pid"; wait "$pid" 2>/dev/null || true
grep -q "Listening for touch screens" "${TMPDIR:-/tmp}/callido-touch-smoke.log" || die "no start-up line"
codesign -d -r- "$APP" 2>&1 | grep designated
echo "smoke: ok"
