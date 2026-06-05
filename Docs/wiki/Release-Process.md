# Release Process

DotWeaver release automation is implemented in `.github/workflows/release.yml`.

## Trigger

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow can also run manually with `workflow_dispatch`.

If Apple signing secrets are absent, the workflow builds ad-hoc signed release artifacts and skips notarization. Sparkle signing uses `SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_KEY` GitHub Actions secrets.

## Workflow

1. Import Developer ID certificate into a temporary keychain when signing secrets are present.
2. Run `swift test`.
3. Run `script/package_release.sh`.
4. Generate `appcast.xml` with `script/generate_appcast.sh`.
5. Publish GitHub release assets.
6. Validate hosted Sparkle appcast and release asset with `script/validate_hosted_sparkle.sh`.

## Release Assets

```text
DotWeaver-<version>-macOS-universal.zip
dw-<version>-macOS-universal.tar.gz
SHA256SUMS.txt
appcast.xml
```

## Sparkle

The app bundle embeds Sparkle via Swift Package Manager. `Info.plist` gets:

```text
SUFeedURL
SUPublicEDKey
SUEnableInstallerLauncherService
```

`script/generate_appcast.sh` writes a GitHub Releases URL into `appcast.xml`. If `SPARKLE_PRIVATE_KEY` or `SPARKLE_PRIVATE_KEY_FILE` is available, it signs the archive with Sparkle `sign_update` and adds `sparkle:edSignature`.

Production app bundles use this stable feed URL by default:

```text
https://github.com/rausth/DotWeaver/releases/latest/download/appcast.xml
```

The appcast item points to the tag-specific app ZIP under GitHub Releases. This keeps the embedded feed URL stable while each appcast entry downloads the exact release artifact.

Generate keys:

```bash
script/generate_sparkle_keys.sh
script/generate_sparkle_keys.sh /tmp/dotweaver-sparkle-private-key.txt
```

If the Sparkle Keychain-backed generator cannot run in an automation host, generate a CI keypair without storing anything in the login keychain:

```bash
script/generate_sparkle_ci_keys.sh /tmp/dotweaver-sparkle-private-key.txt
gh secret set SPARKLE_PUBLIC_ED_KEY --body "<printed-public-key>"
gh secret set SPARKLE_PRIVATE_KEY < /tmp/dotweaver-sparkle-private-key.txt
```

Do not commit the private key file.

## Hosted Validation

After release assets are uploaded:

```bash
APPCAST_URL=https://github.com/rausth/DotWeaver/releases/download/v1.0.0/appcast.xml \
script/validate_hosted_sparkle.sh
```

Validation checks:

- appcast is reachable over HTTPS
- exactly one update item exists
- version matches `VERSION.txt`
- enclosure URL uses HTTPS
- enclosure length is present
- `sparkle:edSignature` is present
- release ZIP is reachable

The release workflow runs this check after publishing assets.

For production distribution, configure both Sparkle key secrets before tagging the release. Apple notarization secrets are separate and only needed when notarization is in scope.
