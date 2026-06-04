import Foundation

final class FolderSyncProvider: SyncProviderProtocol {
    let name: SyncProvider

    private let storageRootProvider: () -> String
    private let namespace = ".dotweaver/files"

    init(name: SyncProvider, storageRootProvider: @escaping () -> String) {
        self.name = name
        self.storageRootProvider = storageRootProvider
    }

    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] {
        let storageRoot = try resolvedStorageRoot()
        let fm = FileManager.default
        try fm.createSecureDirectory(at: storageRoot.appendingPathComponent(namespace))
        try writeMachineManifest(under: storageRoot)

        var updatedDotfiles = dotfiles

        for index in updatedDotfiles.indices {
            var dotfile = updatedDotfiles[index]
            let localURL = URL(fileURLWithPath: dotfile.path.expandingTilde())
            let remoteURL = storageURL(for: localURL, under: storageRoot)
            try SyncPathSecurity.validateLocalFile(localURL)
            try SyncPathSecurity.ensureContained(remoteURL, in: storageRoot)

            do {
                try sync(dotfile: dotfile, localURL: localURL, remoteURL: remoteURL, storageRoot: storageRoot)
                dotfile.status = .synced
                dotfile.lastSynced = Date()
                dotfile.lastLocalModified = modificationDate(at: localURL)
                dotfile.lastRemoteModified = modificationDate(at: remoteURL)
                try writeVersion(dotfile: dotfile, localURL: localURL, remoteURL: remoteURL, storageRoot: storageRoot)
            } catch let syncError as SyncError {
                if case .conflictDetected = syncError {
                    dotfile.status = .conflict
                    updatedDotfiles[index] = dotfile
                    throw SyncError.conflictDetected([dotfile])
                }

                dotfile.status = .error
                updatedDotfiles[index] = dotfile
                throw syncError
            } catch {
                dotfile.status = .error
                updatedDotfiles[index] = dotfile
                throw error
            }

            updatedDotfiles[index] = dotfile
        }

        try writeFilesManifest(dotfiles: updatedDotfiles, under: storageRoot)
        SyncAuditLog.record("Synchronized provider folder", metadata: ["provider": name.rawValue, "files": "\(updatedDotfiles.count)"])
        return updatedDotfiles
    }

    func sync(dotfiles: [Dotfile]) async throws {
        _ = try await syncBidirectional(dotfiles: dotfiles)
    }

    func pull() async throws {
        throw SyncError.configurationMissing("Pull requires managed dotfile metadata")
    }

    func push() async throws {
        throw SyncError.configurationMissing("Push requires managed dotfile metadata")
    }

    func status() async throws -> [Dotfile] {
        []
    }

    private func resolvedStorageRoot() throws -> URL {
        let configuredPath = storageRootProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configuredPath.isEmpty else {
            throw SyncError.configurationMissing("\(name.title) folder not configured")
        }

        let url = URL(fileURLWithPath: configuredPath.expandingTilde())
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SyncError.fileNotFound(url.path)
        }

        return url
    }

    private func sync(dotfile: Dotfile, localURL: URL, remoteURL: URL, storageRoot: URL) throws {
        let fm = FileManager.default
        let localExists = fm.fileExists(atPath: localURL.path)
        let remoteExists = fm.fileExists(atPath: remoteURL.path)

        switch (localExists, remoteExists) {
        case (true, false):
            try writeStoredFile(from: localURL, to: remoteURL, dotfile: dotfile)
        case (false, true):
            try restoreStoredFile(from: remoteURL, to: localURL)
        case (false, false):
            throw SyncError.fileNotFound(localURL.path)
        case (true, true):
            try resolveExistingFiles(dotfile: dotfile, localURL: localURL, remoteURL: remoteURL)
        }
    }

    private func resolveExistingFiles(dotfile: Dotfile, localURL: URL, remoteURL: URL) throws {
        switch dotfile.conflictStrategy {
        case .localWins:
            try writeStoredFile(from: localURL, to: remoteURL, dotfile: dotfile)
        case .remoteWins:
            try restoreStoredFile(from: remoteURL, to: localURL)
        case .manual:
            if try !filesAreEqual(localURL, remoteURL, isSecret: dotfile.isSecret) {
                throw SyncError.conflictDetected([])
            }
        case .lastModifiedWins:
            let localDate = modificationDate(at: localURL) ?? .distantPast
            let remoteDate = modificationDate(at: remoteURL) ?? .distantPast

            if abs(localDate.timeIntervalSince(remoteDate)) < 1 {
                return
            }

            if localDate > remoteDate {
                try writeStoredFile(from: localURL, to: remoteURL, dotfile: dotfile)
            } else {
                try restoreStoredFile(from: remoteURL, to: localURL)
            }
        }
    }

    private func writeStoredFile(from source: URL, to destination: URL, dotfile: Dotfile) throws {
        let data = try Data(contentsOf: source)
        let storedData = dotfile.isSecret ? try VaultCrypto.encrypt(data, originalPath: dotfile.path) : data
        try writeData(storedData, to: destination)
    }

    private func restoreStoredFile(from source: URL, to destination: URL) throws {
        let data = try Data(contentsOf: source)
        let restoredData = try VaultCrypto.decryptIfNeeded(data)
        try writeData(restoredData, to: destination)
    }

    private func writeData(_ data: Data, to destination: URL) throws {
        let fm = FileManager.default
        try SyncPathSecurity.ensureContained(destination, in: destination.deletingLastPathComponent())
        try fm.createSecureDirectory(at: destination.deletingLastPathComponent())

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        try data.write(to: destination, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    private func storageURL(for localURL: URL, under storageRoot: URL) -> URL {
        SyncStoragePaths.remoteFileURL(forLocalFile: localURL, storageRoot: storageRoot)
    }

    private func modificationDate(at url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func filesAreEqual(_ lhs: URL, _ rhs: URL, isSecret: Bool) throws -> Bool {
        let left = try Data(contentsOf: lhs)
        let stored = try Data(contentsOf: rhs)
        let right = isSecret ? try VaultCrypto.decryptIfNeeded(stored) : stored
        return left == right
    }

    private func writeMachineManifest(under storageRoot: URL) throws {
        let identity = try MachineIdentity.current()
        let url = storageRoot
            .appendingPathComponent(".dotweaver/manifests/machines")
            .appendingPathComponent(identity.id + ".json")
        try SyncPathSecurity.ensureContained(url, in: storageRoot)
        try FileManager.default.createSecureDirectory(at: url.deletingLastPathComponent())
        try JSONEncoder.pretty.encode(identity).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func writeFilesManifest(dotfiles: [Dotfile], under storageRoot: URL) throws {
        let identity = try MachineIdentity.current()
        let entries = dotfiles.map { dotfile in
            FileManifestEntry(
                path: dotfile.path,
                relativeStoragePath: SyncStoragePaths.relativeStoragePath(
                    for: URL(fileURLWithPath: dotfile.path.expandingTilde())
                ),
                isSecret: dotfile.isSecret,
                status: dotfile.status.rawValue,
                lastSynced: dotfile.lastSynced
            )
        }
        let manifest = FilesManifest(machineID: identity.id, updatedAt: Date(), files: entries)
        let url = storageRoot.appendingPathComponent(".dotweaver/manifests/files.json")
        try SyncPathSecurity.ensureContained(url, in: storageRoot)
        try FileManager.default.createSecureDirectory(at: url.deletingLastPathComponent())
        try JSONEncoder.pretty.encode(manifest).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func writeVersion(dotfile: Dotfile, localURL: URL, remoteURL: URL, storageRoot: URL) throws {
        let identity = try MachineIdentity.current()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let versionID = formatter.string(from: Date()) + "-" + identity.id
        let relativePath = SyncStoragePaths.relativeStoragePath(for: localURL)
        let versionRoot = storageRoot
            .appendingPathComponent(".dotweaver/versions")
            .appendingPathComponent(relativePath.urlSafeBase64())
            .appendingPathComponent(versionID)
        let blobURL = versionRoot.appendingPathComponent("content.bin")
        let manifestURL = versionRoot.appendingPathComponent("manifest.json")

        try SyncPathSecurity.ensureContained(blobURL, in: storageRoot)
        try FileManager.default.createSecureDirectory(at: versionRoot)
        try FileManager.default.copyItemReplacingExisting(at: remoteURL, to: blobURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: blobURL.path)

        let manifest = VersionManifest(
            id: versionID,
            machineID: identity.id,
            path: dotfile.path,
            relativeStoragePath: relativePath,
            provider: name.rawValue,
            isSecret: dotfile.isSecret,
            createdAt: Date(),
            localModifiedAt: modificationDate(at: localURL),
            storedModifiedAt: modificationDate(at: remoteURL)
        )
        try JSONEncoder.pretty.encode(manifest).write(to: manifestURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: manifestURL.path)
    }
}

private extension String {
    func expandingTilde() -> String {
        (self as NSString).expandingTildeInPath
    }
}

public enum SyncStoragePaths {
    public static let namespace = ".dotweaver/files"

    public static func remoteFileURL(forLocalFile localURL: URL, storageRoot: URL) -> URL {
        storageRoot
            .appendingPathComponent(namespace)
            .appendingPathComponent(relativeStoragePath(for: localURL))
    }

    public static func relativeStoragePath(for localURL: URL) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let localPath = localURL.standardizedFileURL.path

        if localPath == homePath {
            return "home"
        }

        if localPath.hasPrefix(homePath + "/") {
            return String(localPath.dropFirst(homePath.count + 1))
        }

        return "absolute/" + localPath.urlSafeBase64()
    }
}

extension String {
    func urlSafeBase64() -> String {
        Data(utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct FilesManifest: Codable {
    let machineID: String
    let updatedAt: Date
    let files: [FileManifestEntry]
}

private struct FileManifestEntry: Codable {
    let path: String
    let relativeStoragePath: String
    let isSecret: Bool
    let status: String
    let lastSynced: Date?
}

private struct VersionManifest: Codable {
    let id: String
    let machineID: String
    let path: String
    let relativeStoragePath: String
    let provider: String
    let isSecret: Bool
    let createdAt: Date
    let localModifiedAt: Date?
    let storedModifiedAt: Date?
}

private extension FileManager {
    func createSecureDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    func copyItemReplacingExisting(at source: URL, to destination: URL) throws {
        if fileExists(atPath: destination.path) {
            try removeItem(at: destination)
        }
        try copyItem(at: source, to: destination)
    }
}
