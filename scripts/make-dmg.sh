#!/bin/bash
# Packages "build/Callido Touch.app" into a disk image with an Applications shortcut and the
# app icon as volume icon: open the image, drag Callido Touch to Applications.
#
#   scripts/make-dmg.sh [build/CallidoTouch.dmg]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build/CallidoTouch.dmg}"
STAGE="$(mktemp -d)"
RW="$(mktemp -u).dmg"
MNT="$(mktemp -d)"
trap 'rm -rf "$STAGE" "$RW"; rmdir "$MNT" 2>/dev/null || true' EXIT

ditto "build/Callido Touch.app" "$STAGE/Callido Touch.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
cp assets/AppIcon.icns "$STAGE/.VolumeIcon.icns"

for try in 1 2 3; do
  hdiutil create -volname "Callido Touch" -srcfolder "$STAGE" -format UDRW -ov "$RW" >/dev/null && break
  [ "$try" = 3 ] && { echo "hdiutil create failed" >&2; exit 1; }
  sleep 2
done
# The custom-icon flag does not survive -srcfolder: set it on the mounted volume, then compress.
if hdiutil attach -nobrowse -readwrite -noverify -mountpoint "$MNT" "$RW" >/dev/null; then
  if command -v SetFile >/dev/null 2>&1; then SetFile -a C "$MNT"; SetFile -a V "$MNT/.VolumeIcon.icns"; fi
  hdiutil detach "$MNT" >/dev/null || hdiutil detach -force "$MNT" >/dev/null || true
fi
rm -f "$OUT"
hdiutil convert -quiet "$RW" -format UDZO -o "$OUT"
echo "Created $OUT"
