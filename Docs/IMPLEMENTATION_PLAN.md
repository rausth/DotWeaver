# DotWeaver - Implementation Plan

**Version:** 1.0  
**Date:** May 28, 2026  
**Status:** Active

## 1. Project Overview

**Project Name:** DotWeaver  
**Project Type:** Native macOS Application + CLI Tool  
**Team Size:** 2-3 developers (1 lead + 1-2 contributors)  
**Timeline:** 12 weeks (3 months)  
**Methodology:** Agile with 2-week sprints

## 2. Development Phases

### Phase 1: Foundation (Weeks 1-3)

**Goal:** Establish core architecture and basic functionality

**Deliverables:**
- [ ] Project scaffolding with Swift Package Manager
- [ ] MVVM architecture with Dependency Injection
- [ ] Core data models (`Dotfile`, `SyncStatus`, `ConflictStrategy`)
- [ ] `SyncProviderProtocol` definition
- [ ] Git provider implementation (MVP)
- [ ] Basic SwiftUI navigation structure
- [ ] Unit test infrastructure

**Key Tasks:**
1. Set up GitHub repository with proper branching strategy (`main`, `develop`, feature branches)
2. Configure CI/CD pipeline (GitHub Actions) with build, test, and lint stages
3. Implement `DotfilesViewModel` with `@MainActor` and published properties
4. Create mock providers for testing
5. Build initial UI shell (sidebar + detail view)

**Success Criteria:**
- Clean build with zero warnings
- 80% unit test coverage on core models
- Git sync working end-to-end in demo environment

---

### Phase 2: Core Providers (Weeks 4-6)

**Goal:** Implement all storage providers with bidirectional sync

**Deliverables:**
- [ ] iCloud Drive provider
- [ ] OneDrive provider (folder-based)
- [ ] Google Drive provider (folder-based)
- [ ] Dropbox provider (folder-based)
- [ ] WebDAV provider with authentication
- [ ] SFTP provider with SSH key support
- [ ] FTPS provider
- [ ] S3 provider (basic)
- [ ] Conflict detection and resolution UI

**Key Tasks:**
1. Implement `CredentialManager` with Keychain integration
2. Add `BiometricAuthenticator` with Touch ID / Face ID
3. Create provider-specific configuration views
4. Build conflict resolution interface (manual merge)
5. Add progress indicators and error handling

**Success Criteria:**
- All 9 providers passing integration tests
- Biometric authentication working on M-series Macs
- Conflict resolution UI tested with simulated conflicts

---

### Phase 3: Polish & Advanced Features (Weeks 7-9)

**Goal:** Add templates, editor, CLI, and security hardening

**Deliverables:**
- [ ] Template engine (Chezmoi-style variable substitution)
- [ ] Integrated file editor with syntax highlighting
- [ ] Full CLI implementation (`dotweaver` command)
- [ ] Secure Enclave optional key for signing
- [ ] Status bar menu (macOS menu bar extra)
- [ ] Onboarding flow with permission explanations
- [ ] Homebrew formula and tap

**Key Tasks:**
1. Implement `TemplateEngine` with variable substitution
2. Build `FileEditorView` with basic syntax highlighting
3. Create CLI using Swift Argument Parser
4. Add Secure Enclave key generation and signing
5. Implement Sparkle auto-update framework
6. Write comprehensive user documentation

**Success Criteria:**
- Template rendering tested with 20+ template files
- CLI commands documented and tested
- Homebrew installation tested on clean macOS 15 VM

---

### Phase 4: Testing, Security & Release (Weeks 10-12)

**Goal:** Comprehensive testing, security audit, and public release

**Deliverables:**
- [ ] Full test suite (unit + integration + UI)
- [ ] Security audit and penetration testing
- [ ] Performance profiling and optimization
- [ ] App Store / notarization preparation
- [ ] Public documentation and website
- [ ] v1.0.0 release

**Key Tasks:**
1. Achieve 85%+ code coverage
2. Conduct security review (Keychain, network, sandbox)
3. Performance testing with 500+ dotfiles
4. Beta testing with 10-20 external users
5. Prepare App Store listing and screenshots
6. Create release announcement and blog post

**Success Criteria:**
- Zero critical security findings
- App launches in < 2 seconds on M1 Mac
- Beta users report no data loss or sync corruption

## 3. Sprint Breakdown

| Sprint | Weeks | Focus | Key User Stories |
|--------|-------|-------|------------------|
| 1 | 1-2 | Project Setup | "As a developer, I can build and run the app locally" |
| 2 | 3-4 | Git Provider MVP | "As a user, I can sync dotfiles with a Git repository" |
| 3 | 5-6 | Cloud Providers | "As a user, I can sync with iCloud, OneDrive, and Dropbox" |
| 4 | 7-8 | Remote & Security | "As a user, I can use SFTP/WebDAV with biometric auth" |
| 5 | 9-10 | Polish & CLI | "As a power user, I can use the CLI for automation" |
| 6 | 11-12 | Release | "As a user, I can install via Homebrew and receive updates" |

## 4. Risk Management

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| macOS Sandbox restrictions block file access | Medium | High | Early sandbox testing; clear user permission flow |
| Secure Enclave not available on all Macs | Low | Medium | Make Secure Enclave features optional with fallback |
| Provider API changes (OneDrive, Google Drive) | Medium | Medium | Abstract provider interfaces; monitor API deprecations |
| Performance issues with large dotfile sets | Low | Medium | Implement incremental sync; add progress indicators |
| App Store rejection | Low | High | Follow Apple guidelines; prepare for direct distribution |

## 5. Resource Requirements

**Development Tools:**
- Xcode 16+
- Swift 6.0
- Git + GitHub
- Homebrew (for distribution testing)

**Testing Infrastructure:**
- GitHub Actions (CI/CD)
- macOS 15 virtual machines (for testing)
- Physical M-series Mac (for Secure Enclave / Touch ID testing)

**External Services (for testing):**
- Test Git repository
- Test WebDAV server
- Test S3 bucket
- Test SFTP server

## 6. Definition of Done

A feature is considered "done" when:
- [ ] Code is written and peer-reviewed
- [ ] Unit tests pass with > 80% coverage
- [ ] Integration tests pass
- [ ] Documentation is updated
- [ ] Feature is demonstrated in sprint review
- [ ] No critical or high-severity bugs remain

## 7. Post-Release Roadmap (v1.1+)

- [ ] Passkey support for provider authentication
- [ ] Encrypted dotfile content (end-to-end encryption)
- [ ] Team/shared dotfile repositories
- [ ] VS Code extension for editing
- [ ] Windows/Linux CLI client (cross-platform)

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-28 | Project Team | Initial implementation plan |
