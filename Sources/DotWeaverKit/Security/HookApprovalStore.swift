import CryptoKit
import Foundation

public enum HookApprovalStore {
    public static func approve(scriptPath: String) throws -> HookApproval {
        let url = URL(fileURLWithPath: (scriptPath as NSString).expandingTildeInPath).standardizedFileURL
        try validateHookURL(url)
        let approval = HookApproval(path: url.path, sha256: try sha256(url), approvedAt: Date())
        var approvals = loadApprovals()
        approvals[url.path] = approval
        try saveApprovals(approvals)
        SyncAuditLog.record("Approved hook script", metadata: ["hook": url.path, "sha256": approval.sha256])
        return approval
    }

    public static func validateApproved(scriptPath: String) throws -> URL {
        let url = URL(fileURLWithPath: (scriptPath as NSString).expandingTildeInPath).standardizedFileURL
        try validateHookURL(url)
        let currentHash = try sha256(url)
        guard let approval = loadApprovals()[url.path], approval.sha256 == currentHash else {
            throw SyncError.configurationMissing("Hook not approved or hash changed: \(url.path). Run dw hooks approve \(url.path)")
        }
        return url
    }

    public static func loadApprovals() -> [String: HookApproval] {
        guard let data = try? Data(contentsOf: approvalsURL()),
              let approvals = try? JSONDecoder.dotWeaver.decode([String: HookApproval].self, from: data) else {
            return [:]
        }
        return approvals
    }

    static func sha256(_ url: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: url))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func validateHookURL(_ url: URL) throws {
        let hookRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dotweaver/hooks", isDirectory: true)
            .standardizedFileURL
        try SyncPathSecurity.validateLocalFile(url)
        try SyncPathSecurity.ensureContained(url, in: hookRoot)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw SyncError.fileNotFound(url.path)
        }
    }

    private static func saveApprovals(_ approvals: [String: HookApproval]) throws {
        let url = approvalsURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONEncoder.pretty.encode(approvals).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func approvalsURL() -> URL {
        StateManager.appSupportDirectory.appendingPathComponent("hook-approvals.json")
    }
}

public struct HookApproval: Codable, Sendable, Hashable {
    public let path: String
    public let sha256: String
    public let approvedAt: Date
}
