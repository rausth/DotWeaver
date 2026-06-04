# Notarization

DotWeaver uses direct macOS distribution outside the App Store. Release builds must be Developer ID signed, submitted to Apple notarization, stapled, then archived.

## Required Apple Assets

- Active Apple Developer Program membership.
- Developer ID Application certificate exported as `.p12`.
- Apple Team ID.
- Apple ID with App Store Connect access.
- App-specific password for the Apple ID.
- Bundle identifier: `com.rausth.DotWeaver`.

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `MACOS_CERTIFICATE_P12_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the `.p12` export |
| `DEVELOPER_ID_APPLICATION` | Full codesign identity, for example `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID` | Apple ID used by `notarytool` |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for notarization |
| `SPARKLE_PUBLIC_ED_KEY` | Public EdDSA key embedded in `Info.plist` |
| `SPARKLE_PRIVATE_KEY` | Private EdDSA key used to sign Sparkle update archives |

## Sparkle Keys

Generate or print the Sparkle public key:

```bash
swift build
script/generate_sparkle_keys.sh
```

Export the private key for CI:

```bash
script/generate_sparkle_keys.sh /tmp/dotweaver-sparkle-private-key.txt
```

Use the printed public key as `SPARKLE_PUBLIC_ED_KEY`. Store the exported private key file contents as `SPARKLE_PRIVATE_KEY`.

Never commit the Sparkle private key. Use GitHub Actions secrets or a local secure store.

## Local Build

```bash
script/package_release.sh --local
```

This creates:

```text
dist/release/DotWeaver.app
dist/artifacts/DotWeaver-<version>-macOS-universal.zip
dist/artifacts/dw-<version>-macOS-universal.tar.gz
dist/artifacts/SHA256SUMS.txt
```

Without `DEVELOPER_ID_APPLICATION`, local builds use ad-hoc signing and cannot be notarized.

## Production Notarization

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)"
export APPLE_ID="apple-id@example.com"
export APPLE_TEAM_ID="TEAMID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export SPARKLE_PUBLIC_ED_KEY="public-key"
export NOTARIZE=1

script/package_release.sh
```

The script:

1. Builds arm64 and x86_64 binaries.
2. Creates universal app and CLI binaries.
3. Embeds `Sparkle.framework`.
4. Writes `Info.plist` with `SUFeedURL` and `SUPublicEDKey`.
5. Signs with hardened runtime and `DotWeaver.entitlements`.
6. Uploads the zip with `xcrun notarytool submit --wait`.
7. Staples and validates the notarization ticket.
8. Recreates the release zip after stapling.

## Sparkle Hosted Update Validation

After GitHub release assets exist:

```bash
APPCAST_URL=https://github.com/rausth/DotWeaver/releases/download/v1.0.0/appcast.xml \
script/validate_hosted_sparkle.sh
```

This verifies the hosted appcast and release ZIP that Sparkle will fetch. It does not need Apple credentials, but it does require the signed appcast and ZIP to be already published.

## Verification

```bash
codesign --verify --deep --strict --verbose=2 dist/release/DotWeaver.app
xcrun stapler validate dist/release/DotWeaver.app
spctl --assess --type execute --verbose dist/release/DotWeaver.app
```
