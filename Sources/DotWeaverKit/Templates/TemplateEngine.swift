import Foundation

public actor TemplateEngine {
    public static let shared = TemplateEngine()
    private var variables: [String: String]

    public init(context: TemplateContext = .current()) {
        self.variables = context.variables
    }
    
    public func setVariable(_ key: String, value: String) {
        variables[key] = value
    }
    
    public func render(template: String) async throws -> String {
        var result = template
        
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{ \(key) }}", with: value)
            result = result.replacingOccurrences(of: "{{ \(key)}}", with: value)
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return try await renderVaultPlaceholders(in: result)
    }
    
    public func renderFile(at path: String) async throws -> String {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return try await render(template: content)
    }
    
    public func renderFiles(in directory: String) async throws -> [(path: String, content: String)] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: directory)
        
        var rendered: [(path: String, content: String)] = []
        for filename in contents {
            let filePath = (directory as NSString).appendingPathComponent(filename)
            guard fileManager.isReadableFile(atPath: filePath) else { continue }
            let content = try await renderFile(at: filePath)
            rendered.append((path: filePath, content: content))
        }
        return rendered
    }

    private func renderVaultPlaceholders(in template: String) async throws -> String {
        let pattern = #"\{\{\s*vault\s+\"([^\"]+)\"\s*\}\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        var result = template
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed()
        for match in matches {
            guard let tokenRange = Range(match.range(at: 1), in: template),
                  let fullRange = Range(match.range(at: 0), in: result) else { continue }
            let token = String(template[tokenRange])
            let secret = try await resolveVaultToken(token)
            result.replaceSubrange(fullRange, with: secret)
        }
        return result
    }

    private func resolveVaultToken(_ token: String) async throws -> String {
        let separators = CharacterSet(charactersIn: ".:")
        let parts = token.components(separatedBy: separators)
        guard parts.count >= 2,
              let provider = SyncProvider(rawValue: parts[0].lowercased()) else {
            throw SyncError.configurationMissing("Vault placeholder must use provider.account")
        }
        let account = parts.dropFirst().joined(separator: ".")
        return try await CredentialManager.shared.getPassword(for: provider, account: account) ?? ""
    }
}

public struct TemplateContext: Sendable {
    public let variables: [String: String]

    public static func current(state: AppState = StateManager.loadState()) -> TemplateContext {
        let identity = try? MachineIdentity.current()
        let syncRoot = state.selectedProvider == .git ? state.gitLocalPath : state.cloudSyncPath
        var values: [String: String] = [
            "USER": NSUserName(),
            "USERNAME": identity?.userName ?? NSUserName(),
            "HOME": NSHomeDirectory(),
            "HOSTNAME": identity?.hostname ?? ProcessInfo.processInfo.hostName,
            "DATE": ISO8601DateFormatter().string(from: Date()),
            "MACHINE_ID": identity?.id ?? "",
            "OS_VERSION": identity?.osVersion ?? ProcessInfo.processInfo.operatingSystemVersionString,
            "ARCHITECTURE": identity?.architecture ?? "unknown",
            "PROVIDER": state.selectedProvider.rawValue,
            "SYNC_ROOT": syncRoot
        ]
        for (key, value) in values {
            values[key.lowercased()] = value
        }
        return TemplateContext(variables: values)
    }
}
