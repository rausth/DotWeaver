import CryptoKit
import Foundation

public enum SyncAuditLog {
    private static let maxBytes = 1_048_576

    public static func record(_ message: String, metadata: [String: String] = [:]) {
        let url = auditURL()

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try rotateIfNeeded(url)
            let previousHash = lastEntryHash(at: url)
            let entry = try AuditEntry(
                timestamp: Date(),
                message: message,
                metadata: metadata,
                previousHash: previousHash,
                entryHash: ""
            ).signed()
            let data = try JSONEncoder.dotWeaverAudit.encode(entry)
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

    private static func rotateIfNeeded(_ url: URL) throws {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
              size.intValue >= maxBytes else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rotated = url.deletingLastPathComponent()
            .appendingPathComponent("audit-\(formatter.string(from: Date())).jsonl")
        try FileManager.default.moveItem(at: url, to: rotated)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: rotated.path)
    }

    private static func lastEntryHash(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
            .split(separator: "\n")
            .reversed()
            .compactMap { line -> String? in
                guard let data = line.data(using: .utf8),
                      let entry = try? JSONDecoder.dotWeaver.decode(AuditEntry.self, from: data) else { return nil }
                return entry.entryHash
            }
            .first
    }

    private static func auditURL() -> URL {
        StateManager.appSupportDirectory.appendingPathComponent("audit.jsonl")
    }
}

public struct AuditEntry: Codable, Sendable {
    public let timestamp: Date
    public let message: String
    public let metadata: [String: String]
    public let previousHash: String?
    public let entryHash: String

    func signed() throws -> AuditEntry {
        let unsigned = AuditEntry(
            timestamp: timestamp,
            message: message,
            metadata: metadata,
            previousHash: previousHash,
            entryHash: ""
        )
        let data = try JSONEncoder.dotWeaverAudit.encode(unsigned)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return AuditEntry(timestamp: timestamp, message: message, metadata: metadata, previousHash: previousHash, entryHash: hash)
    }
}

private extension JSONEncoder {
    static var dotWeaverAudit: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
