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

## Release Assets

```text
DotWeaver-<version>-macOS-universal.zip
DotWeaver-<version>-macOS-arm64.zip
DotWeaver-<version>-macOS-x86_64.zip
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

Provide Sparkle keys through GitHub Actions secrets:

```bash
gh secret set SPARKLE_PUBLIC_ED_KEY --body "<public-key>"
gh secret set SPARKLE_PRIVATE_KEY < /path/to/dotweaver-sparkle-private-key.txt
```

Do not commit the private key file.

## Validation

Before tagging a release, run local validation:

```bash
swift test
script/validate_release_local.sh
```

Validation checks release artifact generation, local appcast structure, Sparkle signature metadata when configured, checksums, codesign verification, rpath, and CLI help.

For production distribution, configure both Sparkle key secrets before tagging the release. Apple notarization secrets are separate and only needed when notarization is in scope.
