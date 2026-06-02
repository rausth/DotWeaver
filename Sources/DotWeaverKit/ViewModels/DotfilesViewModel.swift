import Foundation
import SwiftUI

@MainActor
public final class DotfilesViewModel: ObservableObject {
    @Published public var dotfiles: [Dotfile] = [] { didSet { save() } }
    @Published public var selectedProvider: SyncProvider = .git { didSet { save() } }
    @Published public var statusMessage: String = ""
    @Published public var isSyncing: Bool = false
    @Published public var recentActivity: [ActivityLog] = [] { didSet { if !recentActivity.isEmpty { save() } } }

    // App Configurations
    @Published public var cloudSyncPath: String = "" { didSet { save() } }
    @Published public var gitLocalPath: String = "" { didSet { save() } }
    @Published public var gitRemoteUrl: String = "" { didSet { save() } }
    @Published public var gitBranch: String = "main" { didSet { save() } }
    @Published public var gitSshKeyPath: String = "~/.ssh/id_ed25519" { didSet { save() } }
    @Published public var gitHost: String = "GitHub" { didSet { save() } }

    private let providers: [SyncProvider: SyncProviderProtocol]
    private var watchers: [String: FileWatcher] = [:]

    public convenience init() {
        let defaultProviders: [SyncProvider: SyncProviderProtocol] = [
            .git: GitProvider(),
            .icloud: iCloudProvider(),
            .onedrive: OneDriveProvider(),
            .googledrive: GoogleDriveProvider(),
            .dropbox: DropboxProvider(),
            .webdav: WebDAVProvider(),
            .sftp: SFTPProvider(),
            .ftps: FTPSProvider(),
            .s3: S3Provider()
        ]
        self.init(providers: defaultProviders)
    }

    init(providers: [SyncProvider: SyncProviderProtocol]) {
        self.providers = providers
        load()
    }

    public func save() {
        let state = AppState(
            dotfiles: dotfiles,
            selectedProvider: selectedProvider,
            recentActivity: recentActivity,
            cloudSyncPath: cloudSyncPath,
            gitLocalPath: gitLocalPath,
            gitRemoteUrl: gitRemoteUrl,
            gitBranch: gitBranch,
            gitSshKeyPath: gitSshKeyPath,
            gitHost: gitHost
        )
        StateManager.saveState(state)
    }

    private func load() {
        let state = StateManager.loadState()
        
        self.dotfiles = state.dotfiles
        self.selectedProvider = state.selectedProvider
        self.recentActivity = state.recentActivity
        self.cloudSyncPath = state.cloudSyncPath
        self.gitLocalPath = state.gitLocalPath
        self.gitRemoteUrl = state.gitRemoteUrl
        self.gitBranch = state.gitBranch
        self.gitSshKeyPath = state.gitSshKeyPath
        self.gitHost = state.gitHost
        
        // Add a log entry for startup if it's not a fresh state
        if !state.recentActivity.isEmpty {
             addActivityLog(message: "DotWeaver loaded previous state", type: .system)
        }
       
        // Ensure watchers are active on load
        startWatchingDotfiles()
    }
    
    public func syncBidirectional() async {
        isSyncing = true
        defer { isSyncing = false }
        
        guard let provider = providers[selectedProvider] else {
            statusMessage = "Provider not available"
            return
        }
        
        // Execute pre-sync hooks
        for dotfile in dotfiles {
            if let hook = dotfile.preSyncHook, !hook.isEmpty {
                executeShellCommand(hook)
            }
        }
        
        do {
            let updated = try await provider.syncBidirectional(dotfiles: dotfiles)
            self.dotfiles = updated
            statusMessage = "✅ Sync completed successfully"
            addActivityLog(message: "Synchronized with \(selectedProvider.title)", type: .sync)
            
            // Execute post-sync hooks
            for dotfile in self.dotfiles {
                if let hook = dotfile.postSyncHook, !hook.isEmpty {
                    executeShellCommand(hook)
                }
            }
            
            startWatchingDotfiles()
            save()
        } catch {
            statusMessage = "❌ Sync failed: \(error.localizedDescription)"
        }
    }
    
    private func executeShellCommand(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    print("Hook error: \(errorMessage)")
                }
            }
        } catch {
            print("Failed to run hook: \(error.localizedDescription)")
        }
    }
    
    public func startWatchingDotfiles() {
        // Stop existing watchers
        for watcher in watchers.values {
            watcher.stop()
        }
        watchers.removeAll()
        
        // Start new watchers for monitored files
        for dotfile in dotfiles where dotfile.isMonitored {
            let watcher = FileWatcher(path: dotfile.path) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleFileChange(at: dotfile.path)
                }
            }
            watcher.start()
            watchers[dotfile.path] = watcher
        }
    }
    
    private func handleFileChange(at path: String) {
        if let index = dotfiles.firstIndex(where: { $0.path == path }) {
            dotfiles[index].status = .modified
            addActivityLog(message: "Local change detected: \((path as NSString).lastPathComponent)", type: .edit)
            // Save is handled by didSet
        }
    }
    
    public func addActivityLog(message: String, type: ActivityType) {
        let log = ActivityLog(message: message, type: type)
        recentActivity.insert(log, at: 0)
        if recentActivity.count > 50 {
            recentActivity.removeLast()
        }
        // Save is handled by didSet
    }
    
    public func toggleSecret(for file: Dotfile) {
        if let index = dotfiles.firstIndex(where: { $0.id == file.id }) {
            dotfiles[index].isSecret.toggle()
            let status = dotfiles[index].isSecret ? "vaulted" : "unvaulted"
            addActivityLog(message: "File \((file.path as NSString).lastPathComponent) \(status)", type: .system)
            // Save is handled by didSet
        }
    }
    
    public func removeFile(id: UUID) {
        if let index = dotfiles.firstIndex(where: { $0.id == id }) {
            let fileName = (dotfiles[index].path as NSString).lastPathComponent
            dotfiles.remove(at: index)
            addActivityLog(message: "Stopped monitoring \(fileName)", type: .system)
            // Save is handled by didSet
        }
    }
    
    public func toggleMonitoring(id: UUID) {
        if let index = dotfiles.firstIndex(where: { $0.id == id }) {
            dotfiles[index].isMonitored.toggle()
            let fileName = (dotfiles[index].path as NSString).lastPathComponent
            if dotfiles[index].isMonitored {
                addActivityLog(message: "Started monitoring \(fileName)", type: .add)
                startWatchingDotfiles()
            } else {
                addActivityLog(message: "Paused monitoring \(fileName)", type: .system)
            }
            // Save is handled by didSet
        }
    }
    
    public func runDoctor() async {
        statusMessage = "🩺 Running System Doctor..."
        addActivityLog(message: "Started System Doctor checkup", type: .system)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        var issuesFound = 0
        let fm = FileManager.default
        
        for i in 0..<dotfiles.count {
            let path = (dotfiles[i].path as NSString).expandingTildeInPath
            if !fm.fileExists(atPath: path) {
                dotfiles[i].status = .error
                issuesFound += 1
            }
        }
        
        if issuesFound > 0 {
            statusMessage = "🩺 Doctor found \(issuesFound) broken file paths."
            addActivityLog(message: "Doctor found \(issuesFound) issues", type: .system)
        } else {
            statusMessage = "🩺 System is healthy. All files found."
            addActivityLog(message: "System Doctor: All checks passed", type: .system)
        }
        save()
    }
}
