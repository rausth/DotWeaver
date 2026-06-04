import Foundation

public enum SyncAuditLog {
    public static func record(_ message: String, metadata: [String: String] = [:]) {
        let entry = AuditEntry(timestamp: Date(), message: message, metadata: metadata)
        let url = auditURL()

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(entry)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.write(contentsOf: Data("\n".utf8))
                try handle.close()
            } else {
                try (data + Data("\n".utf8)).write(to: url, options: .atomic)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            print("Audit log write failed: \(error.localizedDescription)")
        }
    }

    private static func auditURL() -> URL {
        StateManager.appSupportDirectory.appendingPathComponent("audit.jsonl")
    }
}

private struct AuditEntry: Codable {
    let timestamp: Date
    let message: String
    let metadata: [String: String]
}
