# Copilot Instructions for DotWeaver

## Build and test commands

Use Swift Package Manager from the repository root.

```bash
# Build all targets (DotWeaver app, dotweaver CLI, DotWeaverKit)
swift build

# Run all tests
swift test

# Run one test case
swift test --filter DotWeaverKitTests/testDotfileCreation

# Run one test file/class
swift test --filter PerformanceTestSuite

# Run GUI app target
swift run DotWeaver

# Run CLI target
swift run dotweaver --help
```

There is no dedicated lint command configured in this repository.

## Instruction update workflow

- When asked to improve these instructions, inspect the current file and recent repo session history first, then present concrete recommendations before editing.
- If the repo history is sparse, state that limitation explicitly and avoid claiming repeated patterns without evidence.
- After creating or updating instruction guidance, ask about relevant MCP server setup only when the project type clearly suggests one; otherwise skip that question.

## High-level architecture

DotWeaver is a Swift Package with three targets in `Package.swift`:

1. `DotWeaverKit` (core domain, sync abstractions, providers, security, template engine)
2. `DotWeaver` (SwiftUI macOS app)
3. `DotWeaverCLI` (command-line interface)

`DotWeaverKit` is the shared core used by both UI and CLI:

- Domain models: `Dotfile`, `SyncProvider`, `ConflictStrategy`, `SyncError`
- Sync abstraction: `SyncProviderProtocol` (`@MainActor`, async API)
- Provider implementations under `Sources/DotWeaverKit/SyncProviders/*`
- Security actors: `CredentialManager`, `BiometricAuthenticator`
- Template actor: `TemplateEngine`

UI flow:

- `DotWeaverApp.swift` creates a single `DotfilesViewModel` and injects it into `ContentView`.
- `ContentView` and subviews read/write state via `@EnvironmentObject DotfilesViewModel`.
- Sync is triggered from dashboard/menu bar and calls `DotfilesViewModel.syncBidirectional()`.
- `DotfilesViewModel` selects provider from a `SyncProvider -> SyncProviderProtocol` map and replaces the full `[Dotfile]` list with provider output.

CLI flow:

- `Sources/DotWeaverCLI/main.swift` calls `CLICommands.run()`.
- `Commands.swift` performs argument parsing and dispatches command handlers (`init/add/remove/sync/status/list/edit`).

## Key conventions in this repo

### Provider wiring is multi-file and must stay in sync

When adding or changing a sync provider, update all of these surfaces together:

1. `SyncProvider` enum + display title (`Sources/DotWeaverKit/Models/SyncProvider.swift`)
2. Concrete provider implementation conforming to `SyncProviderProtocol` (`Sources/DotWeaverKit/SyncProviders/`)
3. `defaultProviders` map in `DotfilesViewModel` (`Sources/DotWeaverKit/ViewModels/DotfilesViewModel.swift`)
4. Provider icon mapping in UI (`ProviderCard.icon(for:)` in `Sources/DotWeaver/ContentView.swift`)

### Actor and MainActor isolation is intentional

- `SyncProviderProtocol` is `@MainActor`; provider interactions from tests/background contexts must respect actor isolation.
- `CredentialManager`, `BiometricAuthenticator`, and `TemplateEngine` are `actor` singletons; cross-actor calls require `await` and async test methods where needed.

### State update pattern for sync operations

`DotfilesViewModel.syncBidirectional()` is the central orchestration point:

- set `isSyncing = true` with `defer` cleanup
- resolve provider from `selectedProvider`
- call provider `syncBidirectional(dotfiles:)`
- replace `self.dotfiles` with returned value
- write user-visible `statusMessage` for success/failure

New sync-related behavior should keep this end-to-end state transition pattern.

### Tests use provider injection instead of real network providers

- `DotfilesViewModel` has an initializer taking a provider map for tests.
- Current tests use temporary local provider roots, temporary Git remotes, and injected provider maps instead of external service calls.
- Keep unit/integration tests focused on model/viewmodel/protocol behavior; validate real cloud accounts only in manual release testing.
