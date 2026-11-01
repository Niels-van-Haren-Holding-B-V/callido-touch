# Releasing Callido Touch

## Cutting a release

1. Update `.github/RELEASE_NOTES.md` ("What's new in x.y.z") in a pull request and merge it.
2. Tag the merge commit on `main` and push the tag:
   ```sh
   git switch main && git pull
   git tag -a v1.2.0 -m "Callido Touch 1.2.0"
   git push origin v1.2.0
   ```
3. The `build` workflow tests, builds a universal app signed with the Callido Touch certificate, packages
   `CallidoTouch.dmg` and `CallidoTouch.zip`, writes `SHA256SUMS`, signs it (`SHA256SUMS.sig`), verifies the
   signature with `scripts/verify-release.sh` and publishes the GitHub Release. The version number comes from the tag.

`main` is protected by the `main` ruleset: no deletion or force push, changes through a pull request, and the
checks `private-check`, `test` and `build` must pass.

## Secrets

| Secret | What | Used by |
| --- | --- | --- |
| `MACOS_SIGNING_P12` | base64 of a PKCS#12 with the self-signed "Callido Touch Signing" code-signing certificate and key | `build` job |
| `MACOS_SIGNING_PASSWORD` | password of that PKCS#12 | `build` job |
| `MACOS_SIGNING_CERT` | the certificate alone (PEM), to trust it on the runner | `build` job |
| `RELEASE_SIGNING_KEY` | Ed25519 private key (PEM) that signs `SHA256SUMS` | `publish` job |
| `PRIVATE_DENYLIST` (optional) | extra regexes for `scripts/check-private.sh` | `private-check` job |

Nobody keeps a copy of the private keys outside GitHub; the local files are deleted after they are stored.

### Code-signing certificate (why it exists)

macOS ties the Accessibility and Input Monitoring permissions to an app's *designated requirement*. An ad-hoc
signed app's requirement is its own hash, so every new build loses the permissions. Signed with a fixed
certificate, the requirement becomes `identifier "nl.callido.touch" and certificate root = H"…"`, which every
release shares. It is not an Apple Developer ID: Gatekeeper still asks for **Open Anyway** on first start.
Notarization would need a paid Apple Developer account.

Creating it (valid 20 years):
```sh
openssl req -x509 -newkey rsa:3072 -nodes -keyout cs.key -out cs.crt -days 7300 \
  -subj "/CN=Callido Touch Signing/O=Callido B.V." \
  -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"
PW=$(openssl rand -hex 24)
openssl pkcs12 -export -inkey cs.key -in cs.crt -name "Callido Touch Signing" -out cs.p12 -passout pass:$PW \
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1
R=Niels-van-Haren-Holding-B-V/callido-touch
base64 -i cs.p12 | gh secret set MACOS_SIGNING_P12 -R $R
printf %s "$PW" | gh secret set MACOS_SIGNING_PASSWORD -R $R
gh secret set MACOS_SIGNING_CERT -R $R < cs.crt
rm -P cs.key cs.p12; rm cs.crt
```
**Replacing it changes the designated requirement**: every user has to grant the permissions once more after
that update. Only do it when the key leaks; say so in the release notes.

### Release key (Ed25519)

The signed data is `callido-touch <tag>\n` followed by `SHA256SUMS`, so a signed list from an old release
cannot pass for a newer tag. The public key is in `scripts/verify-release.sh` and the README.

Creating it (OpenSSL 3):
```sh
openssl genpkey -algorithm ed25519 -out release-signing.pem
gh secret set RELEASE_SIGNING_KEY -R Niels-van-Haren-Holding-B-V/callido-touch < release-signing.pem
openssl pkey -in release-signing.pem -pubout -outform DER | tail -c 32 | xxd -p -c 64   # public key
rm -P release-signing.pem
```
**Rotating:** create a new pair, put the new public key in `scripts/verify-release.sh` and the README in a pull
request, replace the secret, and release. If the private key leaks, do that at once and mark the releases
signed with the old key in their notes.
