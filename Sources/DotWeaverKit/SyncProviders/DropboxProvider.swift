import Foundation

final class DropboxProvider: SyncProviderProtocol {
    private let provider: FolderSyncProvider

    let name = SyncProvider.dropbox

    init(storageRootProvider: @escaping () -> String = { StateManager.loadState().cloudSyncPath }) {
        self.provider = FolderSyncProvider(name: .dropbox, storageRootProvider: storageRootProvider)
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
