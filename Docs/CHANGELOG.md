# Changelog

All notable changes to DotWeaver will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-05-28

### Added
- Initial public release of DotWeaver
- Native SwiftUI macOS application with MVVM architecture
- Command-line interface (`dotweaver`) with full feature parity
- Bidirectional synchronization with conflict detection and resolution
- Support for 9 storage providers:
  - Git (local and remote repositories)
  - iCloud Drive
  - OneDrive (folder-based sync)
  - Google Drive (folder-based sync)
  - Dropbox (folder-based sync)
  - WebDAV with HTTP Basic Auth
  - SFTP with SSH key authentication
  - FTPS with TLS encryption
  - Amazon S3
- Built-in file editor with syntax highlighting
- Template system with Chezmoi-style variable substitution
- Touch ID / Face ID biometric authentication with passcode fallback
- Secure Enclave optional private key for signing operations
- CredentialManager with macOS Keychain integration and Access Groups
- App Sandbox with Home Folder Access only (no Full Disk Access required)
- Status bar menu for quick actions
- Onboarding flow with permission explanations
- Comprehensive test suite (unit + integration)
- GitHub Actions CI/CD with automated builds, tests, and notarization
- Homebrew formula and tap for easy installation
- Sparkle framework for automatic updates

### Security
- All credentials stored in Keychain with biometric protection
- Certificate pinning for known providers
- TLS 1.3 enforcement for all network communications
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

### Planned for v1.1.0
- Passkey authentication for provider login
- End-to-end encryption for dotfile content
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
| 1.0.0 | 2026-05-28 | Major | Public release, all providers, biometric auth, Secure Enclave |
| 0.9.0 | 2026-05-15 | Minor | Beta release, core architecture, Git + iCloud |
| 0.5.0 | 2026-04-20 | Minor | Project start, proof of concept |

---

**Note:** This changelog is automatically updated during the release process. For older versions, see the [Git history](https://github.com/rausth/DotWeaver/commits/main).
