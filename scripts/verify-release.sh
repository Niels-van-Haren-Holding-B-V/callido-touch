#!/bin/bash
# Verifies a downloaded Callido Touch release: the Ed25519 signature on SHA256SUMS (made in CI with the
# Callido Touch release key) and the checksums of the files next to it. Needs OpenSSL 3 (brew install openssl@3).
#
#   scripts/verify-release.sh v1.0.0 ~/Downloads     (folder with SHA256SUMS, SHA256SUMS.sig and the .dmg/.zip)
set -euo pipefail
TAG=${1:?tag, e.g. v1.0.0}
DIR=${2:-.}
# The release public key (hex, 32 bytes). Also in README.md and docs/RELEASING.md.
PUBLIC_KEY_HEX=534b6d336c5ec3bc45876cc07a20a9de776be1b130bd554ed44f10275a777e5e

OPENSSL=$(command -v /opt/homebrew/opt/openssl@3/bin/openssl || command -v /usr/local/opt/openssl@3/bin/openssl || command -v openssl)
"$OPENSSL" version | grep -q '^OpenSSL 3' || { echo "needs OpenSSL 3 (brew install openssl@3)" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# Ed25519 SubjectPublicKeyInfo = fixed 12-byte prefix + the raw key
printf '302a300506032b6570032100%s' "$PUBLIC_KEY_HEX" | xxd -r -p > "$tmp/pub.der"
"$OPENSSL" pkey -pubin -inform DER -in "$tmp/pub.der" -out "$tmp/pub.pem"
{ printf 'callido-touch %s\n' "$TAG"; cat "$DIR/SHA256SUMS"; } > "$tmp/message"
"$OPENSSL" pkeyutl -verify -pubin -inkey "$tmp/pub.pem" -rawin -in "$tmp/message" -sigfile "$DIR/SHA256SUMS.sig" >/dev/null \
  || { echo "SIGNATURE INVALID: do not install these files" >&2; exit 1; }
echo "signature ok (callido-touch $TAG)"
(cd "$DIR" && shasum -a 256 -c --ignore-missing SHA256SUMS)
