import Foundation

final class iCloudProvider: SyncProviderProtocol {
    private let provider: FolderSyncProvider

    let name = SyncProvider.icloud

    init(storageRootProvider: @escaping () -> String = {
        let configuredPath = StateManager.loadState().cloudSyncPath
        if !configuredPath.isEmpty {
            return configuredPath
        }

        return FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .path ?? ""
    }) {
        self.provider = FolderSyncProvider(name: .icloud, storageRootProvider: storageRootProvider)
    }

    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] {
        try await provider.syncBidirectional(dotfiles: dotfiles)
    }

    func sync(dotfiles: [Dotfile]) async throws {
        try await provider.sync(dotfiles: dotfiles)
    }

    func pull() async throws {
        try await provider.pull()
    }

    func push() async throws {
        try await provider.push()
    }

    func status() async throws -> [Dotfile] {
        try await provider.status()
    }
}
