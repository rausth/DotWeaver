import Foundation
@testable import DotWeaverKit

class MockSyncProvider: SyncProviderProtocol {
    let name = SyncProvider.git
    
    var shouldFail: Bool = false
    var delay: TimeInterval = 0.1
    
    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldFail {
            throw SyncError.networkError("Mock network failure")
        }
        
        return dotfiles.map { var d = $0; d.status = .synced; d.lastSynced = Date(); return d }
    }
    
    func sync(dotfiles: [Dotfile]) async throws {
        _ = try await syncBidirectional(dotfiles: dotfiles)
    }
    
    func pull() async throws {}
    func push() async throws {}
    func status() async throws -> [Dotfile] { [] }
}
