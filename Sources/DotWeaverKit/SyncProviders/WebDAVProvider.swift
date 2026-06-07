import Foundation

final class WebDAVProvider: SyncProviderProtocol {
    private let folderProvider: FolderSyncProvider
    private let nativeProvider: NativeProtocolProvider
    private let modeProvider: () -> ProviderTransportMode

    let name = SyncProvider.webdav

    init(
        storageRootProvider: @escaping () -> String = { StateManager.loadState().cloudSyncPath },
        modeProvider: @escaping () -> ProviderTransportMode = { StateManager.loadState().providerTransportModes[.webdav] ?? .folder },
        configProvider: @escaping () -> NativeProviderConfig = { StateManager.loadState().nativeProviderConfigs[.webdav] ?? NativeProviderConfig() }
    ) {
        self.folderProvider = FolderSyncProvider(name: .webdav, storageRootProvider: storageRootProvider)
        self.nativeProvider = NativeProtocolProvider(name: .webdav, configProvider: configProvider)
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

    func listMachines() async throws -> [MachineIdentity] {
        try await selectedProvider().listMachines()
    }

    private func selectedProvider() -> SyncProviderProtocol {
        modeProvider() == .native ? nativeProvider : folderProvider
    }
}
