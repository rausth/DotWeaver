# DotWeaver - Next Steps

**Date:** June 5, 2026
**Status:** v1.0.0 is released on GitHub. Core app, CLI, sync, security hardening, Sparkle packaging, hosted appcast validation, and website are implemented.

## Complete

- Native SwiftUI macOS app shell
- MVVM state management
- Folder-backed sync engine
- Native protocol transfer mode for WebDAV/SFTP/FTPS/S3 via system `curl`
- Git local repository sync
- Git `pull` / `push` via system Git
- Provider selection for all app providers
- Real conflict comparison and resolution against stored provider copies
- CLI parity commands for files, sync, providers, native config, Git config, snapshots, conflicts, doctor, hooks, templates
- Snapshot create/list/restore/delete
- Snapshot path preservation and provider snapshot sync
- Machine identity, manifests, and version history
- AES.GCM vault encryption for provider-stored secret files
- Biometric/device-owner gates for vaulted sync, snapshot restore, and credential reads
- Hook execution disabled by default with audit entries
- Symlink and storage-root path checks
- Template engine
- File editor
- Unit/integration tests for core sync behavior
- Sparkle appcast generation and universal app/CLI packaging
- Security-scoped bookmarks for GUI-selected files and provider folders
- Local release bundle signing and Sparkle runtime rpath verification
- Isolated provider matrix smoke script for Git and all folder-backed providers
- App launch smoke script with optional Accessibility check
- Local release/appcast validation script
- Hosted Sparkle appcast/release asset validation script and release workflow step
- Hosted v1.0.0 release with signed Sparkle appcast
- DotWeaver app icon integrated into the app sidebar, onboarding, menu bar extra, and release package resource bundle
- Dark professional website on GitHub Pages
- Mackup config import and basic chezmoi source import/export in CLI
- Regression tests for provider permissions, native credential rejection, shared provider restore, and interop parsing

## Provider Model

DotWeaver stores files under:

```text
<provider folder>/.dotweaver/files/machines/<machine-id>/
<provider folder>/.dotweaver/manifests/
<provider folder>/.dotweaver/versions/
<provider folder>/.dotweaver/snapshots/
```

Current providers use this model:

- Git: selected local repository folder, optional remote push/pull
- iCloud, OneDrive, Google Drive, Dropbox: desktop-client sync folders
- WebDAV, SFTP, FTPS, S3: mounted/synchronized local folders or Native Protocol endpoints

Native Protocol mode uses system `curl`; embedded SDK/native-library clients are optional future work if direct SDK integration becomes necessary.

## Remaining Work

| Task | Priority | Status |
|------|----------|--------|
| Live notarization with Apple Developer credentials | High | Pending `MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `DEVELOPER_ID_APPLICATION`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD` |
| External security audit | Medium | Optional before public distribution |
| Full Mackup application preset catalog | Medium | Optional v1.x growth work |
| Advanced chezmoi template/script compatibility | Medium | Optional v1.x growth work |
| Embedded SDK/native-library WebDAV/SFTP/FTPS/S3 clients, if required | Low | Optional future work |

## Verification

Current baseline:

```bash
swift test
script/smoke_provider_matrix.sh
script/validate_release_local.sh
script/smoke_app_ui.sh
APPCAST_URL=https://github.com/rausth/DotWeaver/releases/download/v1.0.0/appcast.xml REQUIRE_SPARKLE_SIGNATURE=1 script/validate_hosted_sparkle.sh
```

Expected result: tests pass, release artifacts are generated, app signature verifies.
