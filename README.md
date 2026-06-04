# DotWeaver

DotWeaver is a native macOS dotfiles manager for synchronizing development configuration across machines. It combines a SwiftUI menu bar app, a full `dw` command-line interface, provider-backed storage, encrypted secret handling, snapshots, conflict resolution, and release packaging with Sparkle support.

Current status: **v1.0.0 release candidate**. Core app, CLI, sync providers, security hardening, local release packaging, and appcast generation are implemented.

## Requirements

- macOS 15 or newer
- Xcode command line tools
- Swift Package Manager
- Optional: Git, provider desktop sync clients, mounted remote folders, or `curl` credentials for native protocol providers

## Core Features

- Native SwiftUI macOS app with menu bar workflow
- Full `dw` CLI for terminal and automation use
- Folder-backed sync for iCloud, OneDrive, Google Drive, Dropbox, WebDAV, SFTP, FTPS, and S3-compatible storage
- Native Protocol mode for WebDAV, SFTP, FTPS, and S3-compatible endpoints through system `curl`
- Git provider with local repository storage plus optional `pull` / `push`
- Conflict detection and resolution against provider-stored copies
- Snapshot create, list, restore, delete, and provider snapshot sync
- Machine identity, manifests, and per-file version history
- AES.GCM vault encryption for sensitive files before provider storage
- Biometric/device-owner gates for vaulted sync, snapshot restore, and credential reads
- Security-scoped bookmarks for GUI-selected files and provider folders
- Hook policy disabled by default, audited when skipped or executed
- Sparkle framework integration, appcast generation, and universal app/CLI packaging

## Provider Model

DotWeaver stores managed data inside the selected provider root:

```text
<provider folder>/.dotweaver/files/
<provider folder>/.dotweaver/manifests/
<provider folder>/.dotweaver/versions/
<provider folder>/.dotweaver/snapshots/
```

Provider behavior:

| Provider | Transport |
| --- | --- |
| Git | Local repository folder, optional remote `pull` / `push` |
| iCloud, OneDrive, Google Drive, Dropbox | Desktop sync folder selected by user |
| WebDAV, SFTP, FTPS, S3 | Mounted/synchronized folder or Native Protocol endpoint |

Native Protocol mode delegates transfer to system `curl`. DotWeaver does not store native protocol passwords. Use SSH keys, `.netrc`, endpoint tokens, or provider credential helpers.

## Build And Run

Build local release artifacts:

```bash
script/build_local.sh
```

Open the generated app:

```bash
open dist/release/DotWeaver.app
```

Run tests:

```bash
swift test
```

## CLI

The app bundle includes the `dw` executable at:

```text
DotWeaver.app/Contents/MacOS/dw
```

Install from the app:

1. Open DotWeaver.
2. Open Settings.
3. Go to CLI.
4. Click **Install 'dw' to PATH**.

Manual symlink examples:

```bash
# Apple Silicon default user package path
sudo ln -sf /Applications/DotWeaver.app/Contents/MacOS/dw /opt/homebrew/bin/dw

# Intel/common Unix path
sudo ln -sf /Applications/DotWeaver.app/Contents/MacOS/dw /usr/local/bin/dw
```

Common commands:

```bash
dw add ~/.zshrc
dw list
dw status
dw sync
dw vault ~/.ssh/id_ed25519
dw snapshot create before-terminal-change
dw snapshot list
dw conflicts list
dw doctor
```

Provider configuration:

```bash
dw provider list
dw provider set onedrive
dw provider folder ~/OneDrive

dw provider transport webdav native
dw native config webdav --endpoint https://example.com/webdav/dotweaver/

dw git config --path ~/dotfiles --remote git@github.com:example/dotfiles.git --branch main
dw git status
dw git push
```

Interop:

```bash
dw interop mackup import ~/.mackup.cfg --dry-run
dw interop mackup import ~/.mackup.cfg
dw interop chezmoi import ~/.local/share/chezmoi --dry-run
dw interop chezmoi export ~/.local/share/chezmoi --force
```

Inspect full CLI surface:

```bash
dw --help
```

## Security

DotWeaver’s security model is local-first:

- Vaulted files are encrypted with AES.GCM before provider storage.
- Vault master key is stored in macOS Keychain and wrapped with Secure Enclave when available.
- Unsupported hardware falls back to Keychain storage with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- GUI-selected files and provider folders are persisted with security-scoped bookmarks.
- Symlink paths and non-home local paths are rejected during sync, snapshot, and restore operations.
- Native Protocol endpoints reject unsupported URL schemes and embedded password formats.
- Hooks are disabled by default and restricted to zsh scripts under `~/.dotweaver/hooks`.
- Audit logs record sync, hook, snapshot, and security-relevant events.
- No telemetry or analytics are collected.

See [Security Policy](Docs/SECURITY.md) and [Security Audit Notes](Docs/SECURITY_AUDIT.md).

## Release Packaging

Create local universal app and CLI artifacts:

```bash
script/package_release.sh --local
script/generate_appcast.sh
```

Generated outputs:

```text
dist/release/DotWeaver.app
dist/artifacts/DotWeaver-1.0.0-macOS-universal.zip
dist/artifacts/dw-1.0.0-macOS-universal.tar.gz
dist/artifacts/SHA256SUMS.txt
appcast.xml
```

Production notarization requires:

- Apple Developer Program membership
- Developer ID Application certificate
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- Sparkle EdDSA key pair
- Hosted release assets and appcast

Hosted Sparkle validation:

```bash
APPCAST_URL=https://github.com/rausth/DotWeaver/releases/latest/download/appcast.xml \
script/validate_hosted_sparkle.sh
```

See [Notarization](Docs/wiki/Notarization.md) and [Release Process](Docs/wiki/Release-Process.md).

## Verification Baseline

Current baseline used for release-candidate verification:

```bash
swift test
script/smoke_provider_matrix.sh
script/validate_release_local.sh
script/smoke_app_ui.sh
```

Expected result: tests pass, all providers pass isolated smoke validation, release artifacts are generated, app signature verifies, appcast validates, checksums match, and the app launches.

## Documentation

- [Project Status](Docs/PROJECT_STATUS.md)
- [Provider Setup](Docs/wiki/Provider-Setup.md)
- [Quick Start](Docs/wiki/Quick-Start.md)
- [Security Policy](Docs/SECURITY.md)
- [Notarization](Docs/wiki/Notarization.md)
- [Release Process](Docs/wiki/Release-Process.md)
- [Changelog](Docs/CHANGELOG.md)

## License

DotWeaver is licensed under the MIT License. See [LICENSE](LICENSE).
