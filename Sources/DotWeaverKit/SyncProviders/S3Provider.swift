import Foundation

class S3Provider: SyncProviderProtocol {
    let name = SyncProvider.s3
    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] { dotfiles.map { var d = $0; d.status = .synced; return d } }
    func sync(dotfiles: [Dotfile]) async throws {}
    func pull() async throws {}
    func push() async throws {}
    func status() async throws -> [Dotfile] { [] }
}
