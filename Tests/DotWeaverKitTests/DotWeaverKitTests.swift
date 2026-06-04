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

    @MainActor
    func testFolderProviderCopiesLocalFileToCloudFolder() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let cloudRoot = tempRoot.appendingPathComponent("OneDrive")
        let localFile = tempRoot.appendingPathComponent(".zshrc")

        try FileManager.default.createDirectory(at: cloudRoot, withIntermediateDirectories: true)
        try "export TEST=1\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = OneDriveProvider(storageRootProvider: { cloudRoot.path })
        let result = try await provider.syncBidirectional(dotfiles: [
            Dotfile(path: localFile.path)
        ])

        let storedFiles = try files(under: cloudRoot.appendingPathComponent(".dotweaver/files"))
        XCTAssertEqual(result.first?.status, .synced)
        XCTAssertEqual(storedFiles.count, 1)
        XCTAssertEqual(try String(contentsOf: storedFiles[0], encoding: .utf8), "export TEST=1\n")
    }

    @MainActor
    func testFolderProviderRestoresMissingLocalFileFromCloudFolder() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let cloudRoot = tempRoot.appendingPathComponent("Dropbox")
        let localFile = tempRoot.appendingPathComponent(".vimrc")
        let provider = DropboxProvider(storageRootProvider: { cloudRoot.path })

        try FileManager.default.createDirectory(at: cloudRoot, withIntermediateDirectories: true)
        try "set number\n".write(to: localFile, atomically: true, encoding: .utf8)
        _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])

        try FileManager.default.removeItem(at: localFile)
        _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])

        XCTAssertEqual(try String(contentsOf: localFile, encoding: .utf8), "set number\n")
    }

    @MainActor
    func testSharedProviderNamespaceRestoresSameTargetPathAcrossMachines() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let storageRoot = tempRoot.appendingPathComponent("SharedOneDrive")
        let localFile = tempRoot.appendingPathComponent(".config/tool/settings.toml")
        let dotfile = Dotfile(path: localFile.path)

        try FileManager.default.createDirectory(at: localFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        try "machine = \"A\"\n".write(to: localFile, atomically: true, encoding: .utf8)

        let providerA = OneDriveProvider(storageRootProvider: { storageRoot.path })
        _ = try await providerA.syncBidirectional(dotfiles: [dotfile])

        try FileManager.default.removeItem(at: localFile)

        let providerB = OneDriveProvider(storageRootProvider: { storageRoot.path })
        _ = try await providerB.syncBidirectional(dotfiles: [dotfile])

        XCTAssertEqual(try String(contentsOf: localFile, encoding: .utf8), "machine = \"A\"\n")
    }

    @MainActor
    func testRemoteNamedProvidersUseRealFolderStorage() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let storageRoot = tempRoot.appendingPathComponent("S3")
        let localFile = tempRoot.appendingPathComponent(".gitconfig")

        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        try "[user]\n\tname = Test\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = S3Provider(storageRootProvider: { storageRoot.path })
        let result = try await provider.syncBidirectional(dotfiles: [
            Dotfile(path: localFile.path)
        ])

        let storedFiles = try files(under: storageRoot.appendingPathComponent(".dotweaver/files"))
        XCTAssertEqual(result.first?.status, .synced)
        XCTAssertEqual(storedFiles.count, 1)
        XCTAssertEqual(try String(contentsOf: storedFiles[0], encoding: .utf8), "[user]\n\tname = Test\n")
    }

    @MainActor
    func testNativeProtocolModeRequiresEndpointConfiguration() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let localFile = tempRoot.appendingPathComponent(".zshrc")
        try "export TEST=1\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = WebDAVProvider(
            modeProvider: { .native },
            configProvider: { NativeProviderConfig() }
        )

        do {
            _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])
            XCTFail("Native mode must require endpoint configuration")
        } catch SyncError.configurationMissing {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testNativeProtocolRejectsUnsafeEndpointConfiguration() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let localFile = tempRoot.appendingPathComponent(".zshrc")
        try "export TEST=1\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = WebDAVProvider(
            modeProvider: { .native },
            configProvider: { NativeProviderConfig(endpoint: "file:///tmp/dotweaver", username: "user:password") }
        )

        do {
            _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])
            XCTFail("Native mode must reject unsafe endpoint configuration")
        } catch SyncError.configurationMissing {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPathContainmentRejectsTraversal() throws {
        let root = try makeTemporaryDirectory()
        let escaped = root.appendingPathComponent("../escape.txt")

        do {
            try SyncPathSecurity.ensureContained(escaped, in: root)
            XCTFail("Path traversal must be rejected")
        } catch SyncError.invalidPath {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPathContainmentRejectsSymlinkEscape() throws {
        let root = try makeTemporaryDirectory()
        let outside = try makeTemporaryDirectory()
        let symlink = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)
        let escaped = symlink.appendingPathComponent("escape.txt")

        do {
            try SyncPathSecurity.ensureContained(escaped, in: root)
            XCTFail("Symlink escape must be rejected")
        } catch SyncError.invalidPath {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testNativeProtocolRejectsPlainHTTPWebDAVEndpoint() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let localFile = tempRoot.appendingPathComponent(".zshrc")
        try "export TEST=1\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = WebDAVProvider(
            modeProvider: { .native },
            configProvider: { NativeProviderConfig(endpoint: "http://example.com/dotweaver/") }
        )

        do {
            _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])
            XCTFail("Native WebDAV mode must reject plaintext HTTP endpoints")
        } catch SyncError.configurationMissing {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testNativeProtocolRejectsEmbeddedURLCredentials() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let localFile = tempRoot.appendingPathComponent(".zshrc")
        try "export TEST=1\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = SFTPProvider(
            modeProvider: { .native },
            configProvider: { NativeProviderConfig(endpoint: "sftp://user:password@example.com/dotweaver/") }
        )

        do {
            _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])
            XCTFail("Native endpoints must reject embedded credentials")
        } catch SyncError.configurationMissing {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testVaultedProviderStoresEncryptedAndRestoresPlaintext() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let storageRoot = tempRoot.appendingPathComponent("OneDrive")
        let localFile = tempRoot.appendingPathComponent(".secret")

        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        try "TOKEN=secret\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = OneDriveProvider(storageRootProvider: { storageRoot.path })
        _ = try await provider.syncBidirectional(dotfiles: [
            Dotfile(path: localFile.path, isSecret: true)
        ])

        let storedFiles = try files(under: storageRoot.appendingPathComponent(".dotweaver/files"))
        let storedData = try Data(contentsOf: storedFiles[0])
        XCTAssertTrue(VaultCrypto.isEncrypted(storedData))
        XCTAssertNotEqual(String(data: storedData, encoding: .utf8), "TOKEN=secret\n")

        try FileManager.default.removeItem(at: localFile)
        _ = try await provider.syncBidirectional(dotfiles: [
            Dotfile(path: localFile.path, isSecret: true)
        ])

        XCTAssertEqual(try String(contentsOf: localFile, encoding: .utf8), "TOKEN=secret\n")
    }

    @MainActor
    func testProviderStoredFilesUsePrivatePermissions() async throws {
        let tempRoot = try makeTemporaryDirectory()
        let storageRoot = tempRoot.appendingPathComponent("Provider")
        let localFile = tempRoot.appendingPathComponent(".zshrc")

        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        try "export TEST=1\n".write(to: localFile, atomically: true, encoding: .utf8)

        let provider = OneDriveProvider(storageRootProvider: { storageRoot.path })
        _ = try await provider.syncBidirectional(dotfiles: [Dotfile(path: localFile.path)])

        let storedFiles = try files(under: storageRoot.appendingPathComponent(".dotweaver/files"))
        XCTAssertEqual(try posixPermissions(storedFiles[0]), 0o600)
        XCTAssertEqual(try posixPermissions(storageRoot.appendingPathComponent(".dotweaver/files")), 0o700)
    }

    func testSnapshotPreservesNestedPathAndSyncsToProviderFolder() throws {
        let tempRoot = try makeTemporaryDirectory()
        let providerRoot = tempRoot.appendingPathComponent("Provider")
        let nestedDir = tempRoot.appendingPathComponent(".config/app")
        let localFile = nestedDir.appendingPathComponent("config.toml")

        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try "enabled = true\n".write(to: localFile, atomically: true, encoding: .utf8)

        let manager = SnapshotManager()
        let snapshot = try manager.createSnapshot(
            dotfiles: [Dotfile(path: localFile.path)],
            name: "nested-test-\(UUID().uuidString)",
            providerRootPath: providerRoot.path
        )

        XCTAssertEqual(snapshot.entries.first?.originalPath, localFile.path)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: providerRoot
                    .appendingPathComponent(".dotweaver/snapshots")
                    .appendingPathComponent(snapshot.machineID)
                    .path
            )
        )

        try FileManager.default.removeItem(at: localFile)
        try manager.restoreSnapshot(snapshot)

        XCTAssertEqual(try String(contentsOf: localFile, encoding: .utf8), "enabled = true\n")
    }

    func testMackupConfigImportMapsCommonSections() throws {
        let tempRoot = try makeTemporaryDirectory()
        let config = tempRoot.appendingPathComponent("app.cfg")
        try """
        [configuration_files]
        .zshrc

        [xdg_configuration_files]
        starship.toml

        [library_files]
        Preferences/com.example.app.plist
        """.write(to: config, atomically: true, encoding: .utf8)

        let imported = try DotfileInterop.importMackupConfig(from: config)
        XCTAssertEqual(imported.map(\.path), [
            "~/.zshrc",
            "~/.config/starship.toml",
            "~/Library/Preferences/com.example.app.plist"
        ])
        XCTAssertEqual(imported.first?.group, "mackup")
    }

    func testChezmoiImportAndExportCommonDotPaths() throws {
        let tempRoot = try makeTemporaryDirectory()
        let sourceRoot = tempRoot.appendingPathComponent("chezmoi")
        let nested = sourceRoot.appendingPathComponent("dot_config")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "export TEST=1\n".write(to: sourceRoot.appendingPathComponent("dot_zshrc"), atomically: true, encoding: .utf8)
        try "add_newline = true\n".write(to: nested.appendingPathComponent("starship.toml"), atomically: true, encoding: .utf8)

        let imported = try DotfileInterop.importChezmoiSource(from: sourceRoot)
        XCTAssertEqual(imported.map(\.path), ["~/.config/starship.toml", "~/.zshrc"])

        let localFile = tempRoot.appendingPathComponent(".gitconfig")
        try "[user]\n\tname = Test\n".write(to: localFile, atomically: true, encoding: .utf8)
        let exportRoot = tempRoot.appendingPathComponent("export")
        let count = try DotfileInterop.exportChezmoiSource(
            dotfiles: [Dotfile(path: localFile.path)],
            to: exportRoot
        )

        XCTAssertEqual(count, 1)
        XCTAssertEqual(DotfileInterop.chezmoiSourcePath(forTargetPath: "~/.gitconfig"), "dot_gitconfig")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: exportRoot
                    .appendingPathComponent(DotfileInterop.chezmoiSourcePath(forTargetPath: localFile.path))
                    .path
            )
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DotWeaverTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func files(under url: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil
        )

        return try XCTUnwrap(enumerator?.compactMap { item in
            let url = item as? URL
            var isDirectory: ObjCBool = false
            if let url, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                return url
            }
            return nil
        })
    }

    private func posixPermissions(_ url: URL) throws -> Int {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
    }
}
