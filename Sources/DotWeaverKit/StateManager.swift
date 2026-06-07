import Foundation

public struct AppState: Codable {
    public var dotfiles: [Dotfile]
    public var selectedProvider: SyncProvider
    public var recentActivity: [ActivityLog]
    public var cloudSyncPath: String
    public var gitLocalPath: String
    public var gitRemoteUrl: String
    public var gitBranch: String
    public var gitSshKeyPath: String
    public var gitHost: String
    public var providerTransportModes: [SyncProvider: ProviderTransportMode]
    public var nativeProviderConfigs: [SyncProvider: NativeProviderConfig]
    public var selectedSyncMachineID: String
    public var securityScopedBookmarks: [String: Data]

    public init(
        dotfiles: [Dotfile] = [],
        selectedProvider: SyncProvider = .git,
        recentActivity: [ActivityLog] = [ActivityLog(message: "DotWeaver initialized", type: .system)],
        cloudSyncPath: String = "",
        gitLocalPath: String = "",
        gitRemoteUrl: String = "",
        gitBranch: String = "main",
        gitSshKeyPath: String = "~/.ssh/id_ed25519",
        gitHost: String = "GitHub",
        providerTransportModes: [SyncProvider: ProviderTransportMode] = [:],
        nativeProviderConfigs: [SyncProvider: NativeProviderConfig] = [:],
        selectedSyncMachineID: String = "",
        securityScopedBookmarks: [String: Data] = [:]
    ) {
        self.dotfiles = dotfiles
        self.selectedProvider = selectedProvider
        self.recentActivity = recentActivity
        self.cloudSyncPath = cloudSyncPath
        self.gitLocalPath = gitLocalPath
        self.gitRemoteUrl = gitRemoteUrl
        self.gitBranch = gitBranch
        self.gitSshKeyPath = gitSshKeyPath
        self.gitHost = gitHost
        self.providerTransportModes = providerTransportModes
        self.nativeProviderConfigs = nativeProviderConfigs
        self.selectedSyncMachineID = selectedSyncMachineID
        self.securityScopedBookmarks = securityScopedBookmarks
    }

    enum CodingKeys: String, CodingKey {
        case dotfiles
        case selectedProvider
        case recentActivity
        case cloudSyncPath
        case gitLocalPath
        case gitRemoteUrl
        case gitBranch
        case gitSshKeyPath
        case gitHost
        case providerTransportModes
        case nativeProviderConfigs
        case selectedSyncMachineID
        case securityScopedBookmarks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dotfiles = try container.decodeIfPresent([Dotfile].self, forKey: .dotfiles) ?? []
        self.selectedProvider = try container.decodeIfPresent(SyncProvider.self, forKey: .selectedProvider) ?? .git
        self.recentActivity = try container.decodeIfPresent([ActivityLog].self, forKey: .recentActivity) ?? [ActivityLog(message: "DotWeaver initialized", type: .system)]
        self.cloudSyncPath = try container.decodeIfPresent(String.self, forKey: .cloudSyncPath) ?? ""
        self.gitLocalPath = try container.decodeIfPresent(String.self, forKey: .gitLocalPath) ?? ""
        self.gitRemoteUrl = try container.decodeIfPresent(String.self, forKey: .gitRemoteUrl) ?? ""
        self.gitBranch = try container.decodeIfPresent(String.self, forKey: .gitBranch) ?? "main"
        self.gitSshKeyPath = try container.decodeIfPresent(String.self, forKey: .gitSshKeyPath) ?? "~/.ssh/id_ed25519"
        self.gitHost = try container.decodeIfPresent(String.self, forKey: .gitHost) ?? "GitHub"
        self.providerTransportModes = try container.decodeIfPresent([SyncProvider: ProviderTransportMode].self, forKey: .providerTransportModes) ?? [:]
        self.nativeProviderConfigs = try container.decodeIfPresent([SyncProvider: NativeProviderConfig].self, forKey: .nativeProviderConfigs) ?? [:]
        self.selectedSyncMachineID = try container.decodeIfPresent(String.self, forKey: .selectedSyncMachineID) ?? ""
        self.securityScopedBookmarks = try container.decodeIfPresent([String: Data].self, forKey: .securityScopedBookmarks) ?? [:]
    }
}


public enum StateManager {
    public static var appSupportDirectory: URL {
        let fm = FileManager.default
        if let override = ProcessInfo.processInfo.environment["DOTWEAVER_APP_SUPPORT_DIR"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            }
            return url
        }

        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dotweaverDir = appSupport.appendingPathComponent("DotWeaver")
        if !fm.fileExists(atPath: dotweaverDir.path) {
            try? fm.createDirectory(
                at: dotweaverDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        return dotweaverDir
    }

    private static var configURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    public static func loadState() -> AppState {
        guard let data = try? Data(contentsOf: configURL),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return AppState()
        }
        return state
    }

    public static func saveState(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: configURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        } catch {
            // In a real app, you might want to handle this error more gracefully
            print("🚨 Failed to save state: \(error.localizedDescription)")
        }
    }
}
