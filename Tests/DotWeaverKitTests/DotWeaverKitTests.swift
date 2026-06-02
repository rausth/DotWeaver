import XCTest
@testable import DotWeaverKit

final class DotWeaverKitTests: XCTestCase {
    
    func testDotfileCreation() {
        let dotfile = Dotfile(path: ".zshrc")
        XCTAssertEqual(dotfile.path, ".zshrc")
        XCTAssertEqual(dotfile.status, .synced)
    }
    
    func testSyncProviderEnum() {
        XCTAssertEqual(SyncProvider.git.title, "Git")
        XCTAssertEqual(SyncProvider.icloud.title, "iCloud Drive")
        XCTAssertEqual(SyncProvider.sftp.title, "SFTP")
    }
    
    func testConflictStrategy() {
        XCTAssertEqual(ConflictStrategy.lastModifiedWins.description, "Use most recently modified version")
        XCTAssertEqual(ConflictStrategy.allCases.count, 4)
    }
    
    @MainActor
    func testProviderProtocol() {
        let provider: SyncProviderProtocol = GitProvider()
        XCTAssertEqual(provider.name, .git)
    }
}
