import Foundation

public struct Snapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let name: String
    public let fileCount: Int
    
    public init(id: UUID = UUID(), date: Date = Date(), name: String, fileCount: Int) {
        self.id = id
        self.date = date
        self.name = name
        self.fileCount = fileCount
    }
}

public final class SnapshotManager: Sendable {
    private let snapshotDir: URL
    
    public init() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        self.snapshotDir = home.appendingPathComponent(".dotweaver/snapshots")
        try? fm.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
    }
    
    public func createSnapshot(dotfiles: [Dotfile], name: String) throws -> Snapshot {
        let fm = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let snapshotFolder = snapshotDir.appendingPathComponent(timestamp)
        try fm.createDirectory(at: snapshotFolder, withIntermediateDirectories: true)
        
        var count = 0
        for file in dotfiles {
            let source = URL(fileURLWithPath: (file.path as NSString).expandingTildeInPath)
            if fm.fileExists(atPath: source.path) {
                let destination = snapshotFolder.appendingPathComponent(source.lastPathComponent)
                try? fm.copyItem(at: source, to: destination)
                count += 1
            }
        }
        
        // Save metadata
        let snapshot = Snapshot(date: Date(), name: name, fileCount: count)
        let metadataUrl = snapshotFolder.appendingPathComponent("metadata.json")
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: metadataUrl)
        
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
        
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for fileUrl in files where fileUrl.lastPathComponent != "metadata.json" {
            let home = fm.homeDirectoryForCurrentUser
            let destination = home.appendingPathComponent(".\(fileUrl.lastPathComponent)")
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: fileUrl, to: destination)
        }
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
        }
    }
}
