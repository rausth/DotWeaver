import Foundation

public struct MachineIdentity: Codable, Sendable {
    public let id: String
    public let hostname: String
    public let userName: String
    public let osVersion: String
    public let architecture: String
    public let createdAt: Date

    public static func current() throws -> MachineIdentity {
        let url = identityURL()
        if let data = try? Data(contentsOf: url),
           let identity = try? JSONDecoder().decode(MachineIdentity.self, from: data) {
            return identity
        }

        let identity = MachineIdentity(
            id: UUID().uuidString,
            hostname: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            userName: NSUserName(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: ProcessInfo.processInfo.machineHardwareName,
            createdAt: Date()
        )

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONEncoder.pretty.encode(identity).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return identity
    }

    private static func identityURL() -> URL {
        StateManager.appSupportDirectory.appendingPathComponent("machine.json")
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
