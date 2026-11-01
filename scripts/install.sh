#!/bin/bash
# Builds Callido Touch, installs it in /Applications and starts it.
# The first launch from /Applications turns on Open at Login.
#
#   scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

osascript -e 'quit app "Callido Touch"' 2>/dev/null || true
pkill -x CallidoTouch 2>/dev/null || true

rm -rf "/Applications/Callido Touch.app"
ditto "build/Callido Touch.app" "/Applications/Callido Touch.app"
xattr -dr com.apple.quarantine "/Applications/Callido Touch.app" 2>/dev/null || true

open "/Applications/Callido Touch.app"
echo "Installed /Applications/Callido Touch.app"
