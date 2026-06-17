import Foundation

struct SyncProviderCapabilities: OptionSet, Sendable {
    let rawValue: Int

    static let managedFileSync = SyncProviderCapabilities(rawValue: 1 << 0)
    static let remoteRepositorySync = SyncProviderCapabilities(rawValue: 1 << 1)
    static let machineDiscovery = SyncProviderCapabilities(rawValue: 1 << 2)
}

@MainActor
protocol SyncProviderProtocol {
    var name: SyncProvider { get }
    var capabilities: SyncProviderCapabilities { get }
    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile]
    func sync(dotfiles: [Dotfile]) async throws
    func pull() async throws
    func push() async throws
    func status() async throws -> [Dotfile]
    func listMachines() async throws -> [MachineIdentity]
}

extension SyncProviderProtocol {
    var capabilities: SyncProviderCapabilities { [.managedFileSync] }

    func pull() async throws {
        throw SyncError.configurationMissing("\(name.title) does not support repository pull")
    }

    func push() async throws {
        throw SyncError.configurationMissing("\(name.title) does not support repository push")
    }

    func status() async throws -> [Dotfile] {
        []
    }

    func listMachines() async throws -> [MachineIdentity] {
        []
    }
}
