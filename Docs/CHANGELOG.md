# Changelog

All notable changes to DotWeaver will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-28

### Added
- Initial public release of DotWeaver
- Native SwiftUI macOS application with MVVM architecture
- Command-line interface (`dw`) with provider, sync, snapshot, conflict, metadata, hook, template, and system commands
- Bidirectional synchronization with conflict detection and resolution
- Support for 9 storage providers:
  - Git (local repository sync, push/pull via system Git)
  - iCloud Drive
  - OneDrive (folder-based sync)
  - Google Drive (folder-based sync)
  - Dropbox (folder-based sync)
  - WebDAV through a mounted or synchronized folder
  - SFTP through a mounted or synchronized folder
  - FTPS through a mounted or synchronized folder
  - Amazon S3 through a mounted or synchronized folder
- Built-in file editor with syntax highlighting
- Template system with Chezmoi-style variable substitution
- Touch ID / Face ID biometric authentication with passcode fallback
- AES.GCM vault encryption with Keychain-protected master key
- CredentialManager with macOS Keychain integration
- App Sandbox with Home Folder Access only (no Full Disk Access required)
- Status bar menu for quick actions
- Onboarding flow with permission explanations
- Comprehensive test suite (unit + integration)
- GitHub Actions CI/CD with automated builds, tests, and notarization
- Sparkle framework for automatic updates
- Security-scoped bookmarks for GUI-selected files and provider folders

### Security
- Credentials and vault key stored in Keychain with biometric-sensitive access flows
- Remote provider authentication and transport handled by the selected desktop client or mount tool
- No telemetry or analytics collection
- Zero-knowledge architecture (credentials never transmitted)

### Documentation
- Complete README with installation and usage instructions
- API documentation for custom provider development
- Security audit report available upon request

---

## [0.9.0] - 2026-05-15

### Added
- Beta release for internal testing
- Core MVVM architecture with Dependency Injection
- Git and iCloud providers
- Basic SwiftUI interface
- Keychain credential storage
- Initial test suite

### Changed
- Refactored provider architecture to use protocols
- Improved error handling and user feedback

### Fixed
- Memory leak in sync operation
- Race condition in concurrent provider access

---

## [0.5.0] - 2026-04-20

### Added
- Project scaffolding and architecture design
- Proof of concept with Git provider
- Basic CLI structure
- Initial documentation

---

## [Unreleased]

### Added
- Optional Secure Enclave wrapping for the vault master key, with Keychain fallback on unsupported hardware.
- End-to-end Git provider test using a temporary bare remote repository.
- Sparkle dependency, app bundle metadata, universal release packaging, notarization workflow, and appcast generation scripts.

### Planned for v1.1.0
- Passkey authentication for provider login
- Team/shared dotfile repositories
- VS Code extension
- Cross-platform CLI (Windows/Linux)

### Planned for v1.2.0
- Plugin system for custom providers
- Visual diff and merge interface
- Scheduled automatic sync
- Backup and restore functionality

---

## Version History Summary

| Version | Date | Type | Highlights |
|---------|------|------|------------|
| 1.0.0 | 2026-05-28 | Major | Public release, folder-backed providers, biometric auth, vault encryption |
| 0.9.0 | 2026-05-15 | Minor | Beta release, core architecture, Git + iCloud |
| 0.5.0 | 2026-04-20 | Minor | Project start, proof of concept |

---

**Note:** This changelog is automatically updated during the release process. For older versions, see the [Git history](https://github.com/rausth/DotWeaver/commits/main).
