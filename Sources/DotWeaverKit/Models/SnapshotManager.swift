import Foundation

public struct Snapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let name: String
    public let fileCount: Int
    public let machineID: String
    public let entries: [SnapshotEntry]
    
    public init(id: UUID = UUID(), date: Date = Date(), name: String, fileCount: Int, machineID: String = "", entries: [SnapshotEntry] = []) {
        self.id = id
        self.date = date
        self.name = name
        self.fileCount = fileCount
        self.machineID = machineID
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case name
        case fileCount
        case machineID
        case entries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.name = try container.decode(String.self, forKey: .name)
        self.fileCount = try container.decode(Int.self, forKey: .fileCount)
        self.machineID = try container.decodeIfPresent(String.self, forKey: .machineID) ?? ""
        self.entries = try container.decodeIfPresent([SnapshotEntry].self, forKey: .entries) ?? []
    }
}

public struct SnapshotEntry: Codable, Hashable, Sendable {
    public let originalPath: String
    public let relativeStoragePath: String
    public let isSecret: Bool
}

public final class SnapshotManager: Sendable {
    private let snapshotDir: URL
    
    public init() {
        let fm = FileManager.default
        if let override = ProcessInfo.processInfo.environment["DOTWEAVER_SNAPSHOT_DIR"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.snapshotDir = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        } else {
            let home = fm.homeDirectoryForCurrentUser
            self.snapshotDir = home.appendingPathComponent(".dotweaver/snapshots")
        }
        try? fm.createDirectory(
            at: snapshotDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
    
    public func createSnapshot(dotfiles: [Dotfile], name: String, providerRootPath: String? = nil) throws -> Snapshot {
        let fm = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let snapshotFolder = snapshotDir.appendingPathComponent(timestamp)
        let filesFolder = snapshotFolder.appendingPathComponent("files")
        try fm.createDirectory(
            at: snapshotFolder,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fm.createDirectory(
            at: filesFolder,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        
        var count = 0
        var entries: [SnapshotEntry] = []
        for file in dotfiles {
            let source = URL(fileURLWithPath: (file.path as NSString).expandingTildeInPath)
            if fm.fileExists(atPath: source.path) {
                try SyncPathSecurity.validateLocalFile(source)
                let relativePath = SyncStoragePaths.relativeStoragePath(for: source)
                let destination = filesFolder.appendingPathComponent(relativePath)
                try SyncPathSecurity.ensureContained(destination, in: filesFolder)
                try fm.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                let data = try Data(contentsOf: source)
                let storedData = file.isSecret ? try VaultCrypto.encrypt(data, originalPath: file.path) : data
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try storedData.write(to: destination, options: .atomic)
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
                count += 1
                entries.append(SnapshotEntry(originalPath: source.path, relativeStoragePath: relativePath, isSecret: file.isSecret))
            }
        }
        
        let snapshot = Snapshot(
            date: Date(),
            name: name,
            fileCount: count,
            machineID: try MachineIdentity.current().id,
            entries: entries
        )
        let metadataUrl = snapshotFolder.appendingPathComponent("metadata.json")
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: metadataUrl)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: metadataUrl.path)

        if let providerRootPath, !providerRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try syncSnapshotFolder(snapshotFolder, snapshot: snapshot, providerRootPath: providerRootPath)
        }

        SyncAuditLog.record("Created snapshot", metadata: ["name": name, "files": "\(count)"])
        
        return snapshot
    }
    
    public func listSnapshots() -> [Snapshot] {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: snapshotDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return folders.compactMap { folder in
            let metadataUrl = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataUrl),
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
                return nil
            }
            return snapshot
        }.sorted { $0.date > $1.date }
    }
    
    public func restoreSnapshot(_ snapshot: Snapshot) throws {
        let fm = FileManager.default
        let folders = try fm.contentsOfDirectory(at: snapshotDir, includingPropertiesForKeys: nil)
        guard let folder = folders.first(where: { folder in
            let metadataUrl = folder.appendingPathComponent("metadata.json")
            if let data = try? Data(contentsOf: metadataUrl),
               let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
                return s.id == snapshot.id
            }
            return false
        }) else {
            throw NSError(domain: "SnapshotManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Snapshot folder not found"])
        }
        
        let filesFolder = folder.appendingPathComponent("files")
        for entry in snapshot.entries {
            let fileUrl = filesFolder.appendingPathComponent(entry.relativeStoragePath)
            let destination = URL(fileURLWithPath: entry.originalPath)
            try SyncPathSecurity.validateLocalFile(destination)
            try SyncPathSecurity.ensureContained(fileUrl, in: filesFolder)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            let data = try VaultCrypto.decryptIfNeeded(Data(contentsOf: fileUrl))
            try SyncPathSecurity.writeFileAtomically(data, to: destination)
        }

        SyncAuditLog.record("Restored snapshot", metadata: ["name": snapshot.name, "files": "\(snapshot.fileCount)"])
    }
    
    public func deleteSnapshot(_ snapshot: Snapshot) throws {
        let fm = FileManager.default
        let folders = try fm.contentsOfDirectory(at: snapshotDir, includingPropertiesForKeys: nil)
        if let folder = folders.first(where: { folder in
            let metadataUrl = folder.appendingPathComponent("metadata.json")
            if let data = try? Data(contentsOf: metadataUrl),
               let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
                return s.id == snapshot.id
            }
            return false
        }) {
            try fm.removeItem(at: folder)
            SyncAuditLog.record("Deleted snapshot", metadata: ["name": snapshot.name])
        }
    }

    private func syncSnapshotFolder(_ snapshotFolder: URL, snapshot: Snapshot, providerRootPath: String) throws {
        let providerRoot = URL(fileURLWithPath: (providerRootPath as NSString).expandingTildeInPath)
        let destination = providerRoot
            .appendingPathComponent(".dotweaver/snapshots")
            .appendingPathComponent(snapshot.machineID)
            .appendingPathComponent(snapshotFolder.lastPathComponent)

        try SyncPathSecurity.ensureContained(destination, in: providerRoot)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.copyItem(at: snapshotFolder, to: destination)
    }
}
