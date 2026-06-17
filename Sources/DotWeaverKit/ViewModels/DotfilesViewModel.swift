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
    @Published public var providerTransportModes: [SyncProvider: ProviderTransportMode] = [:] { didSet { save() } }
    @Published public var nativeProviderConfigs: [SyncProvider: NativeProviderConfig] = [:] { didSet { save() } }
    @Published public var selectedSyncMachineID: String = "" { didSet { save() } }
    @Published public var availableMachines: [MachineIdentity] = []

    private let providers: [SyncProvider: SyncProviderProtocol]
    private var watchers: [String: FileWatcher] = [:]
    private var isLoadingState = false
    private var securityScopedBookmarks: [String: Data] = [:]
    private var pendingSaveTask: Task<Void, Never>?
    private var pendingChangedPaths: Set<String> = []
    private var pendingChangeTask: Task<Void, Never>?

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
        guard !isLoadingState else { return }
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        guard !isLoadingState else { return }
        StateManager.saveState(currentState())
    }

    private func load() {
        let state = StateManager.loadState()
        isLoadingState = true
        apply(state)
        isLoadingState = false
        self.availableMachines = (try? [MachineIdentity.current()]) ?? []
        SecurityScopedBookmarks.restoreAccess()
        
        // Add a log entry for startup if it's not a fresh state
        if !state.recentActivity.isEmpty {
             addActivityLog(message: "DotWeaver loaded previous state", type: .system)
        }
       
        // Ensure watchers are active on load
        startWatchingDotfiles()
    }

    private func apply(_ state: AppState) {
        self.dotfiles = state.dotfiles
        self.selectedProvider = state.selectedProvider
        self.recentActivity = state.recentActivity
        self.cloudSyncPath = state.cloudSyncPath
        self.gitLocalPath = state.gitLocalPath
        self.gitRemoteUrl = state.gitRemoteUrl
        self.gitBranch = state.gitBranch
        self.gitSshKeyPath = state.gitSshKeyPath
        self.gitHost = state.gitHost
        self.providerTransportModes = state.providerTransportModes
        self.nativeProviderConfigs = state.nativeProviderConfigs
        self.selectedSyncMachineID = state.selectedSyncMachineID
        self.securityScopedBookmarks = state.securityScopedBookmarks
    }

    private func currentState() -> AppState {
        AppState(
            dotfiles: dotfiles,
            selectedProvider: selectedProvider,
            recentActivity: recentActivity,
            cloudSyncPath: cloudSyncPath,
            gitLocalPath: gitLocalPath,
            gitRemoteUrl: gitRemoteUrl,
            gitBranch: gitBranch,
            gitSshKeyPath: gitSshKeyPath,
            gitHost: gitHost,
            providerTransportModes: providerTransportModes,
            nativeProviderConfigs: nativeProviderConfigs,
            selectedSyncMachineID: selectedSyncMachineID,
            securityScopedBookmarks: mergedSecurityScopedBookmarks()
        )
    }

    private func mergedSecurityScopedBookmarks() -> [String: Data] {
        securityScopedBookmarks
    }

    public var selectedSyncMachineLabel: String {
        if selectedSyncMachineID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "This Mac"
        }
        return availableMachines.first(where: { $0.id == selectedSyncMachineID })?.hostname ?? "Selected Mac"
    }

    public func useThisMachineForSync() {
        selectedSyncMachineID = ""
    }

    public func refreshAvailableMachines() async {
        guard let provider = providers[selectedProvider], provider.capabilities.contains(.machineDiscovery) else {
            setAvailableMachinesIfChanged((try? [MachineIdentity.current()]) ?? [])
            return
        }

        do {
            let machines = try await provider.listMachines()
            var refreshedMachines = machines
            let currentID = try MachineIdentity.current().id
            let selected = selectedSyncMachineID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !selected.isEmpty && !machines.contains(where: { $0.id == selected }) {
                selectedSyncMachineID = ""
            }
            if !refreshedMachines.contains(where: { $0.id == currentID }),
               let current = try? MachineIdentity.current() {
                refreshedMachines.insert(current, at: 0)
            }
            setAvailableMachinesIfChanged(refreshedMachines)
        } catch {
            if let current = try? MachineIdentity.current() {
                setAvailableMachinesIfChanged([current])
            }
            statusMessage = "Could not load machines: \(error.localizedDescription)"
        }
    }
    
    public func syncBidirectional() async {
        isSyncing = true
        defer { isSyncing = false }
        
        guard let provider = providers[selectedProvider] else {
            statusMessage = "Provider not available"
            return
        }
        
        if dotfiles.contains(where: \.isSecret), SecurityPolicy.requiresBiometricAuthentication {
            do {
                _ = try await BiometricAuthenticator.shared.authenticate(reason: "Authenticate to sync vaulted files")
                addActivityLog(message: "Biometric authentication accepted for vaulted sync", type: .system)
                SyncAuditLog.record("Biometric authentication accepted for vaulted sync")
            } catch {
                statusMessage = "❌ Authentication failed: \(error.localizedDescription)"
                SyncAuditLog.record("Biometric authentication failed for vaulted sync")
                return
            }
        }

        let matcher = DotignoreMatcher.load(providerRootPath: currentProviderRootPath())
        let syncableDotfiles = dotfiles.filter { dotfile in
            guard matcher.ignores(path: dotfile.path) else { return true }
            SyncAuditLog.record("Skipped ignored dotfile", metadata: ["file": dotfile.path])
            return false
        }

        for dotfile in syncableDotfiles {
            if let hook = dotfile.preSyncHook, !hook.isEmpty {
                executeHook(hook, phase: "pre-sync", filePath: dotfile.path)
            }
        }
        
        do {
            let updated = try await provider.syncBidirectional(dotfiles: syncableDotfiles)
            setDotfilesIfChanged(mergeSyncedDotfiles(updated))
            statusMessage = "✅ Sync completed successfully"
            addActivityLog(message: "Synchronized with \(selectedProvider.title) from \(selectedSyncMachineLabel)", type: .sync)
            await refreshAvailableMachines()
            
            // Execute post-sync hooks
            for dotfile in updated {
                if let hook = dotfile.postSyncHook, !hook.isEmpty {
                    executeHook(hook, phase: "post-sync", filePath: dotfile.path)
                }
            }
            
            startWatchingDotfiles()
            save()
        } catch {
            statusMessage = "❌ Sync failed: \(error.localizedDescription)"
            SyncAuditLog.record("Sync failed", metadata: ["provider": selectedProvider.rawValue, "error": error.localizedDescription])
        }
    }
    
    private func executeHook(_ command: String, phase: String, filePath: String) {
        guard SecurityPolicy.hooksEnabled else {
            addActivityLog(message: "Skipped disabled \(phase) hook for \((filePath as NSString).lastPathComponent)", type: .system)
            SyncAuditLog.record("Skipped disabled hook", metadata: ["phase": phase, "file": filePath])
            return
        }

        do {
            let hookURL = try validatedHookScript(command)
            SyncAuditLog.record("Executing hook", metadata: ["phase": phase, "file": filePath, "hook": hookURL.path])
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [hookURL.path, filePath, phase]
            process.environment = [
                "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "SHELL": "/bin/zsh",
                "DOTWEAVER_HOOK_PHASE": phase,
                "DOTWEAVER_FILE_PATH": filePath
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMessage = String(data: errorData, encoding: .utf8) {
                    print("Hook error: \(errorMessage)")
                    SyncAuditLog.record("Hook failed", metadata: ["phase": phase, "file": filePath, "error": errorMessage])
                }
            } else {
                SyncAuditLog.record("Hook completed", metadata: ["phase": phase, "file": filePath])
            }
        } catch {
            print("Failed to run hook: \(error.localizedDescription)")
            SyncAuditLog.record("Hook launch failed", metadata: ["phase": phase, "file": filePath, "error": error.localizedDescription])
        }
    }

    private func validatedHookScript(_ rawPath: String) throws -> URL {
        try HookApprovalStore.validateApproved(scriptPath: rawPath)
    }
    
    public func startWatchingDotfiles() {
        let monitoredPaths = Set(dotfiles.filter(\.isMonitored).map(\.path))
        guard Set(watchers.keys) != monitoredPaths else { return }

        for (path, watcher) in watchers where !monitoredPaths.contains(path) {
            watcher.stop()
            watchers.removeValue(forKey: path)
        }

        for path in monitoredPaths where watchers[path] == nil {
            let watcher = FileWatcher(path: path) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleFileChange(at: path)
                }
            }
            watcher.start()
            watchers[path] = watcher
        }
    }
    
    private func handleFileChange(at path: String) {
        pendingChangedPaths.insert(path)
        pendingChangeTask?.cancel()
        pendingChangeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.flushPendingFileChanges()
        }
    }

    private func flushPendingFileChanges() {
        let changedPaths = pendingChangedPaths
        pendingChangedPaths.removeAll()
        pendingChangeTask = nil
        guard !changedPaths.isEmpty else { return }

        var updated = dotfiles
        var changedFileNames: [String] = []
        for path in changedPaths {
            guard let index = updated.firstIndex(where: { $0.path == path }), updated[index].status != .modified else { continue }
            updated[index].status = .modified
            changedFileNames.append((path as NSString).lastPathComponent)
        }

        setDotfilesIfChanged(updated)
        for fileName in changedFileNames.sorted() {
            addActivityLog(message: "Local change detected: \(fileName)", type: .edit)
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

    private func currentProviderRootPath() -> String? {
        selectedProvider == .git ? gitLocalPath : cloudSyncPath
    }

    private func setDotfilesIfChanged(_ updated: [Dotfile]) {
        guard dotfiles != updated else { return }
        dotfiles = updated
    }

    private func setAvailableMachinesIfChanged(_ updated: [MachineIdentity]) {
        guard availableMachines != updated else { return }
        availableMachines = updated
    }

    private func mergeSyncedDotfiles(_ synced: [Dotfile]) -> [Dotfile] {
        var merged = dotfiles
        for dotfile in synced {
            if let index = merged.firstIndex(where: { $0.id == dotfile.id }) {
                merged[index] = dotfile
            } else {
                merged.append(dotfile)
            }
        }
        return merged
    }

    public func transportMode(for provider: SyncProvider) -> ProviderTransportMode {
        providerTransportModes[provider] ?? .folder
    }

    public func setTransportMode(_ mode: ProviderTransportMode, for provider: SyncProvider) {
        providerTransportModes[provider] = mode
    }

    public func nativeConfig(for provider: SyncProvider) -> NativeProviderConfig {
        nativeProviderConfigs[provider] ?? NativeProviderConfig()
    }

    public func setNativeConfig(_ config: NativeProviderConfig, for provider: SyncProvider) {
        nativeProviderConfigs[provider] = config
    }
    
    public func toggleSecret(for file: Dotfile) {
        if let index = dotfiles.firstIndex(where: { $0.id == file.id }) {
            dotfiles[index].isSecret.toggle()
            let status = dotfiles[index].isSecret ? "vaulted" : "unvaulted"
            addActivityLog(message: "File \((file.path as NSString).lastPathComponent) \(status)", type: .system)
            SyncAuditLog.record("Toggled vault status", metadata: ["file": file.path, "status": status])
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
