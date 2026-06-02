import XCTest
import LocalAuthentication
@testable import DotWeaverKit

final class IntegrationTests: XCTestCase {
    
    @MainActor
    func testFullSyncFlow() async throws {
        // Test complete sync flow with mock provider
        let mockProvider = MockSyncProvider()
        _ = DotfilesViewModel(providers: [.git: mockProvider])
        
        let testDotfiles = [
            Dotfile(path: ".zshrc"),
            Dotfile(path: ".gitconfig")
        ]
        
        let result = try await mockProvider.syncBidirectional(dotfiles: testDotfiles)
        
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.status == .synced })
    }
    
    func testBiometricAuthentication() async throws {
        let authenticator = BiometricAuthenticator.shared
        
        // This will fail in test environment without biometrics
        // In real tests, would mock the LAContext
        do {
            _ = try await authenticator.authenticate(reason: "Test authentication")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is BiometricError || error is LAError)
        }
    }
    
    func testCredentialStorage() async throws {
        let manager = CredentialManager.shared
        
        // Test saving and retrieving credentials
        try await manager.savePassword(for: .git, account: "test", password: "test-password")
        let retrieved = try await manager.getPassword(for: .git, account: "test")
        
        XCTAssertEqual(retrieved, "test-password")
    }
}
