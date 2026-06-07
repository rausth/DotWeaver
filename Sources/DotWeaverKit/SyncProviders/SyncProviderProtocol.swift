import Foundation

@MainActor
protocol SyncProviderProtocol {
    var name: SyncProvider { get }
    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile]
    func sync(dotfiles: [Dotfile]) async throws
    func pull() async throws
    func push() async throws
    func status() async throws -> [Dotfile]
    func listMachines() async throws -> [MachineIdentity]
}

extension SyncProviderProtocol {
    func listMachines() async throws -> [MachineIdentity] {
        []
    }
}
