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

    public init(
        dotfiles: [Dotfile] = [],
        selectedProvider: SyncProvider = .git,
        recentActivity: [ActivityLog] = [ActivityLog(message: "DotWeaver initialized", type: .system)],
        cloudSyncPath: String = "",
        gitLocalPath: String = "",
        gitRemoteUrl: String = "",
        gitBranch: String = "main",
        gitSshKeyPath: String = "~/.ssh/id_ed25519",
        gitHost: String = "GitHub"
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
    }
}


public enum StateManager {
    private static var configURL: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dotweaverDir = appSupport.appendingPathComponent("DotWeaver")
        
        if !fm.fileExists(atPath: dotweaverDir.path) {
            try? fm.createDirectory(at: dotweaverDir, withIntermediateDirectories: true)
        }
        
        return dotweaverDir.appendingPathComponent("config.json")
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
        } catch {
            // In a real app, you might want to handle this error more gracefully
            print("🚨 Failed to save state: \(error.localizedDescription)")
        }
    }
}
