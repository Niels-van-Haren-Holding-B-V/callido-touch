#!/bin/bash
# Writes SHA256SUMS for the release files in a directory.
# Usage: scripts/assemble-release.sh <directory>
set -euo pipefail
dir=${1:?release directory}
cd "$dir"
files=(CallidoTouch.dmg CallidoTouch.zip)
for f in "${files[@]}"; do [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }; done
shasum -a 256 "${files[@]}" > SHA256SUMS
cat SHA256SUMS
