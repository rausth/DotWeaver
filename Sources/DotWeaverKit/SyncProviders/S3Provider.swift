import Foundation

final class S3Provider: SyncProviderProtocol {
    private let folderProvider: FolderSyncProvider
    private let nativeProvider: NativeProtocolProvider
    private let modeProvider: () -> ProviderTransportMode

    let name = SyncProvider.s3

    init(
        storageRootProvider: @escaping () -> String = { StateManager.loadState().cloudSyncPath },
        modeProvider: @escaping () -> ProviderTransportMode = { StateManager.loadState().providerTransportModes[.s3] ?? .folder },
        configProvider: @escaping () -> NativeProviderConfig = { StateManager.loadState().nativeProviderConfigs[.s3] ?? NativeProviderConfig() }
    ) {
        self.folderProvider = FolderSyncProvider(name: .s3, storageRootProvider: storageRootProvider)
        self.nativeProvider = NativeProtocolProvider(name: .s3, configProvider: configProvider)
        self.modeProvider = modeProvider
    }

    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] {
        try await selectedProvider().syncBidirectional(dotfiles: dotfiles)
    }

    func sync(dotfiles: [Dotfile]) async throws {
        try await selectedProvider().sync(dotfiles: dotfiles)
    }

    func pull() async throws {
        try await selectedProvider().pull()
    }

    func push() async throws {
        try await selectedProvider().push()
    }

    func status() async throws -> [Dotfile] {
        try await selectedProvider().status()
    }

    private func selectedProvider() -> SyncProviderProtocol {
        modeProvider() == .native ? nativeProvider : folderProvider
    }
}
