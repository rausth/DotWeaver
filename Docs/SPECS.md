# DotWeaver - Technical Specifications

**Version:** 1.0  
**Date:** May 28, 2026

## 1. Architecture Overview

### 1.1 High-Level Architecture
DotWeaver follows a **modular, layered architecture** optimized for macOS native development:

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   SwiftUI    │  │   Menu Bar   │  │   CLI (Argument  │  │
│  │    Views     │  │   Extra      │  │   Parser)        │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Application Layer                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              DotfilesViewModel (@MainActor)          │   │
│  │  • State Management  • Sync Orchestration            │   │
│  │  • Conflict Resolution • Provider Coordination       │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      Domain Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Models     │  │  Protocols   │  │   Services       │  │
│  │ (Dotfile,    │  │ (SyncProvider│  │ (CredentialMgr,  │  │
│  │  SyncStatus) │  │  Protocol)   │  │  BiometricAuth)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   Infrastructure Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Keychain   │  │  Network     │  │   File System    │  │
│  │   Services   │  │  (URLSession,│  │   (FileManager,  │  │
│  │              │  │   SSH)       │  │    Sandbox)      │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Design Patterns
- **MVVM (Model-View-ViewModel)**: Core UI pattern with `@MainActor` ViewModels
- **Dependency Injection**: Constructor-based injection for all providers and services
- **Protocol-Oriented Programming**: `SyncProviderProtocol` for pluggable backends
- **Actor Model**: Thread-safe credential and authentication management
- **Repository Pattern**: Abstracted data access for dotfiles and sync state

## 2. Technology Stack

| Layer | Technology | Version | Rationale |
|-------|------------|---------|-----------|
| **Language** | Swift | 6.0 | Modern concurrency, type safety, native performance |
| **UI Framework** | SwiftUI | macOS 14+ | Declarative UI, native integration, Dark Mode support |
| **Architecture** | MVVM + Actors | - | Testability, thread safety, state management |
| **Security** | Keychain Services, LocalAuthentication, CryptoKit, Secure Enclave | - | Secure Enclave-wrapped vault key when available, Keychain fallback, biometric auth, AES.GCM encryption |
| **Networking** | URLSession, NIO SSH (optional) | - | Native async networking, certificate pinning |
| **Testing** | XCTest, Swift Testing | - | Unit, integration, and UI testing |
| **Build System** | Swift Package Manager | 6.0 | Single source of truth, multi-target support |
| **CI/CD** | GitHub Actions | - | Automated builds, tests, notarization, releases |
| **Distribution** | Direct Download, Sparkle | - | GitHub release download and automatic updates |

## 3. Data Models

### 3.1 Core Entities

```swift
struct Dotfile: Identifiable, Codable {
    let id: UUID
    var path: String                    // Relative path (e.g., ".zshrc")
    var lastLocalModified: Date?
    var lastRemoteModified: Date?
    var lastSynced: Date?
    var status: SyncStatus
    var conflictStrategy: ConflictStrategy
}

enum SyncStatus: String, Codable {
    case synced, modified, conflict, error, pending
}

enum ConflictStrategy: String, Codable, CaseIterable {
    case lastModifiedWins
    case localWins
    case remoteWins
    case manual
}
```

### 3.2 Provider Configuration

Each provider implements `SyncProviderProtocol` with:
- Configuration stored in UserDefaults (non-sensitive)
- Credentials stored in Keychain with biometric protection
- Vault master key wrapped by Secure Enclave when available, with Keychain-only fallback

## 4. Security Architecture

### 4.1 Credential Storage Flow
```
User Action (e.g., Sync)
        ↓
BiometricAuthenticator.authenticate()
        ↓
CredentialManager.getPassword()
        ↓
Keychain Services
        ↓
Vault master key / provider credential
```

### 4.2 Provider Transport
- Git push/pull uses the system `git` binary and the configured repository remote.
- iCloud, OneDrive, Google Drive, and Dropbox rely on their desktop sync folders.
- WebDAV, SFTP, FTPS, and S3 support user-provided mounted/synchronized folders.
- WebDAV, SFTP, FTPS, and S3 also support Native Protocol mode through system `curl`.
- Embedded SDK/native-library clients are future work.

### 4.3 Sandbox Entitlements
```xml
com.apple.security.app-sandbox: true
com.apple.security.files.user-home.read-write: true
com.apple.security.network.client: true
```

## 5. Concurrency Model

- **Main Actor**: All UI updates and ViewModel state
- **Background Actors**: CredentialManager, SecureEnclaveManager
- **Task Groups**: Parallel provider operations during multi-provider sync
- **Async/Await**: All I/O operations (network, file system, Keychain)

## 6. Testing Strategy

| Test Type | Framework | Coverage Target | Location |
|-----------|-----------|-----------------|----------|
| Unit Tests | XCTest | 85%+ | `Tests/DotWeaverKitTests/` |
| Integration Tests | XCTest + Mocks | Provider interfaces | `Tests/DotWeaverKitTests/` |
| UI Tests | XCUITest | Critical flows | `Tests/DotWeaverUITests/` |
| Snapshot Tests | Swift-SnapshotTesting | Views | `Tests/DotWeaverKitTests/` |

## 7. Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| App Launch | < 1.5s | Time to first interactive UI |
| Sync (50 files) | < 10s | End-to-end sync completion |
| Memory (idle) | < 80 MB | Xcode Instruments |
| Memory (syncing) | < 150 MB | Xcode Instruments |
| CPU (idle) | < 2% | Activity Monitor |

## 8. Deployment Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   GitHub    │────▶│ GitHub Actions│────▶│ Notarization │
│  (Source)   │     │  (CI/CD)      │     │  + Stapling  │
└─────────────┘     └──────────────┘     └──────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ GitHub Releases │
                    │ app zip + CLI   │
                    └─────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
       ┌─────────────┐                ┌──────────────┐
       │   Direct    │                │  Auto-Update │
       │  Download   │                │   (Sparkle)  │
       └─────────────┘                └──────────────┘
```

---

**Document Control**

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-05-28 | Initial technical specification |
