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

public enum SnapshotLocation: String, Codable, Hashable, Sendable {
    case local
    case provider
}

public struct SnapshotCatalogItem: Identifiable, Hashable, Sendable {
    public var id: UUID { snapshot.id }
    public let snapshot: Snapshot
    public let location: SnapshotLocation
    public let folderPath: String
    public let machine: MachineIdentity?

    public var sourceMachineID: String {
        snapshot.machineID.isEmpty ? (machine?.id ?? "") : snapshot.machineID
    }

    public var sourceMachineLabel: String {
        guard let machine else {
            let id = sourceMachineID
            return id.isEmpty ? "Unknown machine" : "Unknown machine (\(String(id.prefix(8))))"
        }
        return "\(machine.hostname) (\(machine.architecture))"
    }
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
        listLocalSnapshotCatalog().map(\.snapshot)
    }

    public func listSnapshotCatalog(providerRootPath: String? = nil, includeLocal: Bool = true) -> [SnapshotCatalogItem] {
        var items: [SnapshotCatalogItem] = includeLocal ? listLocalSnapshotCatalog() : []
        if let providerRootPath, !providerRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(contentsOf: listProviderSnapshots(providerRootPath: providerRootPath))
        }

        var seen = Set<UUID>()
        return items
            .sorted { lhs, rhs in
                if lhs.snapshot.date == rhs.snapshot.date {
                    return lhs.location.rawValue < rhs.location.rawValue
                }
                return lhs.snapshot.date > rhs.snapshot.date
            }
            .filter { item in
                if seen.contains(item.snapshot.id) { return false }
                seen.insert(item.snapshot.id)
                return true
            }
    }

    public func listProviderSnapshots(providerRootPath: String) -> [SnapshotCatalogItem] {
        let fm = FileManager.default
        let providerRoot = URL(fileURLWithPath: (providerRootPath as NSString).expandingTildeInPath)
        let snapshotsRoot = providerRoot.appendingPathComponent(".dotweaver/snapshots")
        guard fm.fileExists(atPath: snapshotsRoot.path),
              let machineFolders = try? fm.contentsOfDirectory(at: snapshotsRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        let machines = providerMachines(providerRoot: providerRoot)
        return machineFolders.flatMap { machineFolder -> [SnapshotCatalogItem] in
            guard (try? SyncPathSecurity.ensureContained(machineFolder, in: snapshotsRoot)) != nil,
                  let snapshotFolders = try? fm.contentsOfDirectory(at: machineFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                return []
            }
            return snapshotFolders.compactMap { folder in
                guard (try? SyncPathSecurity.ensureContained(folder, in: snapshotsRoot)) != nil else { return nil }
                let metadataUrl = folder.appendingPathComponent("metadata.json")
                guard let data = try? Data(contentsOf: metadataUrl),
                      var snapshot = decodeSnapshot(data) else {
                    return nil
                }
                if snapshot.machineID.isEmpty {
                    snapshot = Snapshot(
                        id: snapshot.id,
                        date: snapshot.date,
                        name: snapshot.name,
                        fileCount: snapshot.fileCount,
                        machineID: machineFolder.lastPathComponent,
                        entries: snapshot.entries
                    )
                }
                return SnapshotCatalogItem(
                    snapshot: snapshot,
                    location: .provider,
                    folderPath: folder.path,
                    machine: machines[snapshot.machineID] ?? machines[machineFolder.lastPathComponent]
                )
            }
        }.sorted { $0.snapshot.date > $1.snapshot.date }
    }

    public func listProviderSnapshotMachines(providerRootPath: String) -> [MachineIdentity] {
        let snapshots = listProviderSnapshots(providerRootPath: providerRootPath)
        var seen = Set<String>()
        return snapshots.compactMap(\.machine).filter { machine in
            if seen.contains(machine.id) { return false }
            seen.insert(machine.id)
            return true
        }.sorted { $0.hostname.localizedCaseInsensitiveCompare($1.hostname) == .orderedAscending }
    }
    
    public func restoreSnapshot(_ snapshot: Snapshot) throws {
        try restoreSnapshot(snapshot, matching: nil)
    }

    public func restoreSnapshot(_ snapshot: Snapshot, matching requestedPath: String?) throws {
        let folder = try snapshotFolder(for: snapshot)
        try restore(snapshot: snapshot, from: folder, matching: requestedPath, location: .local)
    }

    public func restoreSnapshot(_ item: SnapshotCatalogItem, matching requestedPath: String? = nil) throws {
        try restore(snapshot: item.snapshot, from: URL(fileURLWithPath: item.folderPath), matching: requestedPath, location: item.location)
    }
    
    public func deleteSnapshot(_ snapshot: Snapshot) throws {
        if let folder = try? snapshotFolder(for: snapshot) {
            try FileManager.default.removeItem(at: folder)
            SyncAuditLog.record("Deleted snapshot", metadata: ["name": snapshot.name])
        }
    }

    private func listLocalSnapshotCatalog() -> [SnapshotCatalogItem] {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: snapshotDir, includingPropertiesForKeys: nil) else {
            return []
        }
        let current = try? MachineIdentity.current()
        return folders.compactMap { folder in
            let metadataUrl = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataUrl),
                  let snapshot = decodeSnapshot(data) else {
                return nil
            }
            return SnapshotCatalogItem(snapshot: snapshot, location: .local, folderPath: folder.path, machine: current?.id == snapshot.machineID ? current : nil)
        }.sorted { $0.snapshot.date > $1.snapshot.date }
    }

    private func snapshotFolder(for snapshot: Snapshot) throws -> URL {
        guard let item = listLocalSnapshotCatalog().first(where: { $0.snapshot.id == snapshot.id }) else {
            throw NSError(domain: "SnapshotManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Snapshot folder not found"])
        }
        return URL(fileURLWithPath: item.folderPath)
    }

    private func restore(snapshot: Snapshot, from folder: URL, matching requestedPath: String?, location: SnapshotLocation) throws {
        let fm = FileManager.default
        let filesFolder = folder.appendingPathComponent("files")
        try SyncPathSecurity.ensureContained(filesFolder, in: folder)
        let entries = try entriesToRestore(from: snapshot, matching: requestedPath)
        for entry in entries {
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

        SyncAuditLog.record(
            "Restored snapshot",
            metadata: [
                "name": snapshot.name,
                "id": snapshot.id.uuidString,
                "sourceMachine": snapshot.machineID,
                "location": location.rawValue,
                "files": "\(entries.count)"
            ]
        )
    }

    private func entriesToRestore(from snapshot: Snapshot, matching requestedPath: String?) throws -> [SnapshotEntry] {
        guard let requestedPath, !requestedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return snapshot.entries
        }
        let expanded = URL(fileURLWithPath: (requestedPath as NSString).expandingTildeInPath).standardizedFileURL.path
        let matches = snapshot.entries.filter {
            URL(fileURLWithPath: ($0.originalPath as NSString).expandingTildeInPath).standardizedFileURL.path == expanded ||
            $0.originalPath == requestedPath ||
            $0.relativeStoragePath == requestedPath
        }
        guard !matches.isEmpty else {
            throw NSError(domain: "SnapshotManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found in snapshot: \(requestedPath)"])
        }
        return matches
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

    private func providerMachines(providerRoot: URL) -> [String: MachineIdentity] {
        let machinesRoot = providerRoot.appendingPathComponent(".dotweaver/manifests/machines")
        guard let files = try? FileManager.default.contentsOfDirectory(at: machinesRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: files.compactMap { url in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let machine = try? JSONDecoder.dotWeaver.decode(MachineIdentity.self, from: data) else {
                return nil
            }
            return (machine.id, machine)
        })
    }

    private func decodeSnapshot(_ data: Data) -> Snapshot? {
        if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return snapshot
        }
        return try? JSONDecoder.dotWeaver.decode(Snapshot.self, from: data)
    }
}
