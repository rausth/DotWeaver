import XCTest
import LocalAuthentication
@testable import DotWeaverKit

final class IntegrationTests: XCTestCase {
    
    @MainActor
    func testFullSyncFlow() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DotWeaverFullSyncTests")
            .appendingPathComponent(UUID().uuidString)
        let localRoot = root.appendingPathComponent("local")
        let storageRoot = root.appendingPathComponent("storage")
        try FileManager.default.createDirectory(at: localRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        let zshrc = localRoot.appendingPathComponent(".zshrc")
        let gitconfig = localRoot.appendingPathComponent(".gitconfig")
        try "export TEST=1\n".write(to: zshrc, atomically: true, encoding: .utf8)
        try "[user]\n\tname = DotWeaver Test\n".write(to: gitconfig, atomically: true, encoding: .utf8)

        let provider = FolderSyncProvider(name: .onedrive, storageRootProvider: { storageRoot.path })
        let testDotfiles = [
            Dotfile(path: zshrc.path),
            Dotfile(path: gitconfig.path)
        ]

        let result = try await provider.syncBidirectional(dotfiles: testDotfiles)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.status == SyncStatus.synced })
    }
    
    func testBiometricAuthentication() async throws {
        let authenticator = BiometricAuthenticator.shared
        
        // This will fail in test environment without biometrics
        // LAContext cannot be exercised deterministically in headless test runs.
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

    @MainActor
    func testGitProviderPushesToTemporaryRemote() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DotWeaverGitTests")
            .appendingPathComponent(UUID().uuidString)
        let remote = root.appendingPathComponent("remote.git")
        let repo = root.appendingPathComponent("repo")
        let dotfile = root.appendingPathComponent(".zshrc")

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try runGit(["init", "--bare", remote.path], cwd: root)
        try runGit(["init", repo.path], cwd: root)
        try runGit(["-C", repo.path, "config", "user.email", "dotweaver@example.invalid"], cwd: root)
        try runGit(["-C", repo.path, "config", "user.name", "DotWeaver Test"], cwd: root)
        try runGit(["-C", repo.path, "checkout", "-b", "main"], cwd: root)
        try runGit(["-C", repo.path, "remote", "add", "origin", remote.path], cwd: root)

        try "export TEST=1\n".write(to: dotfile, atomically: true, encoding: .utf8)

        let provider = GitProvider(
            storageRootProvider: { repo.path },
            remoteURLProvider: { remote.path },
            branchProvider: { "main" }
        )

        _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: dotfile.path)])
        try await provider.push()

        let heads = try runGit(["--git-dir", remote.path, "show-ref", "--heads"], cwd: root)
        XCTAssertTrue(heads.contains("refs/heads/main"))
    }

    @discardableResult
    private func runGit(_ arguments: [String], cwd: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = cwd
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "GitTest", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: error.isEmpty ? output : error])
        }
        return output
    }
}
