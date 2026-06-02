import Foundation

class OneDriveProvider: SyncProviderProtocol {
    let name = SyncProvider.onedrive
    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] { dotfiles.map { var d = $0; d.status = .synced; return d } }
    func sync(dotfiles: [Dotfile]) async throws {}
    func pull() async throws {}
    func push() async throws {}
    func status() async throws -> [Dotfile] { [] }
}
