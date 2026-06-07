import Foundation
import DotWeaverKit

struct CLICommands {
    static func run(arguments: [String] = CommandLine.arguments) async {
        guard arguments.count > 1 else {
            printUsage()
            return
        }

        let command = arguments[1]
        let args = Array(arguments.dropFirst(2))

        do {
            switch command {
            case "add": try add(args)
            case "remove", "rm": try remove(args)
            case "status": status()
            case "list", "ls": list(args)
            case "vault": try vault(args)
            case "sync": await sync()
            case "provider": try provider(args)
            case "git": try await git(args)
            case "native": try native(args)
            case "snapshot", "snapshots": try await snapshot(args)
            case "doctor": doctor()
            case "metadata": try metadata(args)
            case "hooks": try hooks(args)
            case "monitor": try monitor(args)
            case "cat": try cat(args)
            case "edit": try edit(args)
            case "conflicts": try conflicts(args)
            case "machine": try machine()
            case "versions": try versions(args)
            case "template", "templates": try template(args)
            case "interop": try interop(args)
            case "--help", "-h", "help": printUsage()
            default:
                print("Unknown command: \(command)")
                printUsage()
                exit(1)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        DotWeaver CLI (dw)

        Files:
          dw add <file> [--group <name>] [--tag <tag>] [--strategy <lastModifiedWins|localWins|remoteWins|manual>]
          dw remove <file>
          dw list [--all]
          dw status
          dw vault <file>
          dw monitor <file> <on|off>
          dw metadata <file> [--group <name>] [--tag <tag>] [--pre-hook <script>] [--post-hook <script>] [--strategy <strategy>]
          dw cat <file>
          dw edit <file>

        Sync/providers:
          dw sync
          dw provider list
          dw provider set <provider>
          dw provider folder <path>
          dw provider transport <provider> <folder|native>
          dw native config <provider> --endpoint <url> [--username <user>]
          dw git config [--path <repo>] [--remote <url>] [--branch <branch>] [--ssh-key <path>] [--host <name>]
          dw git pull
          dw git push
          dw git status

        Snapshots/conflicts:
          dw snapshot list
          dw snapshot create <name>
          dw snapshot restore <id-or-name>
          dw snapshot delete <id-or-name>
          dw conflicts list
          dw conflicts resolve <file> <local|stored|newest>

        System:
          dw doctor
          dw hooks <on|off>
          dw machine
          dw versions <file>
          dw versions restore <file> <version-id>
          dw templates list
          dw templates apply <oh-my-zsh|starship|vim>
          dw interop mackup import <config-file> [--dry-run]
          dw interop chezmoi import <source-dir> [--dry-run]
          dw interop chezmoi export <source-dir> [--force]
        """)
    }

    static func add(_ args: [String]) throws {
        guard let path = args.first else { throw CLIError.message("Specify file") }
        let fullPath = expand(path)
        let url = URL(fileURLWithPath: fullPath)
        try SyncPathSecurity.validateLocalFile(url)
        guard FileManager.default.fileExists(atPath: fullPath) else { throw CLIError.message("File not found: \(fullPath)") }

        var state = StateManager.loadState()
        guard !state.dotfiles.contains(where: { expand($0.path) == fullPath }) else {
            print("Already monitored: \(path)")
            return
        }

        var dotfile = Dotfile(path: path)
        applyDotfileOptions(&dotfile, args: Array(args.dropFirst()))
        state.dotfiles.append(dotfile)
        state.recentActivity.insert(ActivityLog(message: "CLI: Added \(path)", type: .add), at: 0)
        StateManager.saveState(state)
        print("Added: \(path)")
    }

    static func remove(_ args: [String]) throws {
        guard let path = args.first else { throw CLIError.message("Specify file") }
        var state = StateManager.loadState()
        guard let index = state.dotfiles.firstIndex(where: { $0.path == path || expand($0.path) == expand(path) }) else {
            throw CLIError.message("Not monitored: \(path)")
        }
        state.dotfiles.remove(at: index)
        state.recentActivity.insert(ActivityLog(message: "CLI: Removed \(path)", type: .system), at: 0)
        StateManager.saveState(state)
        print("Removed: \(path)")
    }

    static func status() {
        let state = StateManager.loadState()
        print("Provider: \(state.selectedProvider.title)")
        print("Transport: \(transportMode(for: state.selectedProvider, state: state).title)")
        print("Active files: \(state.dotfiles.filter(\.isMonitored).count)")
        print("Total files: \(state.dotfiles.count)")
        print("Vaulted: \(state.dotfiles.filter(\.isSecret).count)")
        print("Cloud path: \(state.cloudSyncPath.isEmpty ? "-" : state.cloudSyncPath)")
        print("Git path: \(state.gitLocalPath.isEmpty ? "-" : state.gitLocalPath)")
        print("Hooks: \(SecurityPolicy.hooksEnabled ? "enabled" : "disabled")")
        if let lastSync = state.recentActivity.first(where: { $0.type == .sync })?.timestamp {
            print("Last sync: \(lastSync)")
        } else {
            print("Last sync: never")
        }
    }

    static func list(_ args: [String]) {
        let includeAll = args.contains("--all")
        let files = StateManager.loadState().dotfiles.filter { includeAll || $0.isMonitored }
        if files.isEmpty {
            print("No monitored files")
            return
        }
        for file in files {
            let flags = [
                file.isMonitored ? "monitored" : "paused",
                file.isSecret ? "vaulted" : nil,
                file.group.map { "group=\($0)" },
                file.tags.isEmpty ? nil : "tags=\(file.tags.joined(separator: ","))",
                "status=\(file.status.rawValue)"
            ].compactMap { $0 }.joined(separator: " ")
            print("\(file.path) [\(flags)]")
        }
    }

    static func vault(_ args: [String]) throws {
        guard let path = args.first else { throw CLIError.message("Specify file") }
        var state = StateManager.loadState()
        guard let index = state.dotfiles.firstIndex(where: { $0.path == path || expand($0.path) == expand(path) }) else {
            throw CLIError.message("Not monitored: \(path)")
        }
        state.dotfiles[index].isSecret.toggle()
        let action = state.dotfiles[index].isSecret ? "vaulted" : "unvaulted"
        state.recentActivity.insert(ActivityLog(message: "CLI: \(action) \(path)", type: .system), at: 0)
        StateManager.saveState(state)
        SyncAuditLog.record("CLI toggled vault", metadata: ["file": path, "status": action])
        print("\(path): \(action)")
    }

    static func sync() async {
        let viewModel = await MainActor.run { DotfilesViewModel() }
        await viewModel.syncBidirectional()
        let message = await MainActor.run { viewModel.statusMessage }
        print(message)
    }

    static func provider(_ args: [String]) throws {
        guard let sub = args.first else { throw CLIError.message("provider requires subcommand") }
        var state = StateManager.loadState()
        switch sub {
        case "list":
            for provider in SyncProvider.allCases {
                let selected = provider == state.selectedProvider ? "*" : " "
                print("\(selected) \(provider.rawValue) - \(provider.title) [\(transportMode(for: provider, state: state).rawValue)]")
            }
        case "set":
            let provider = try parseProvider(requiredArg(args, 1, "provider"))
            state.selectedProvider = provider
            state.recentActivity.insert(ActivityLog(message: "CLI: Selected provider \(provider.title)", type: .system), at: 0)
            StateManager.saveState(state)
            print("Provider: \(provider.title)")
        case "folder":
            let path = try requiredArg(args, 1, "folder path")
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expand(path), isDirectory: &isDirectory), isDirectory.boolValue else {
                throw CLIError.message("Folder not found: \(expand(path))")
            }
            state.cloudSyncPath = path
            StateManager.saveState(state)
            print("Folder: \(path)")
        case "transport":
            let provider = try parseProvider(requiredArg(args, 1, "provider"))
            let mode = try parseMode(requiredArg(args, 2, "folder|native"))
            state.providerTransportModes[provider] = mode
            StateManager.saveState(state)
            print("\(provider.title) transport: \(mode.title)")
        default:
            throw CLIError.message("Unknown provider subcommand: \(sub)")
        }
    }

    static func git(_ args: [String]) async throws {
        guard let subcommand = args.first else {
            throw CLIError.message("Usage: dw git <config|pull|push|status>")
        }

        switch subcommand {
        case "config":
            var state = StateManager.loadState()
            state.gitLocalPath = optionValue("--path", in: args) ?? state.gitLocalPath
            state.gitRemoteUrl = optionValue("--remote", in: args) ?? state.gitRemoteUrl
            state.gitBranch = optionValue("--branch", in: args) ?? state.gitBranch
            state.gitSshKeyPath = optionValue("--ssh-key", in: args) ?? state.gitSshKeyPath
            state.gitHost = optionValue("--host", in: args) ?? state.gitHost
            StateManager.saveState(state)
            print("Git config updated")
        case "pull":
            let state = StateManager.loadState()
            guard !state.gitRemoteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CLIError.message("Git remote URL not configured")
            }
            _ = try runConfiguredGit(["pull", "origin", try validatedGitBranch(state.gitBranch)])
            print("Git pull complete")
        case "push":
            let state = StateManager.loadState()
            guard !state.gitRemoteUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CLIError.message("Git remote URL not configured")
            }
            try stageAndCommitConfiguredGitIfNeeded()
            _ = try runConfiguredGit(["push", "origin", try validatedGitBranch(state.gitBranch)])
            print("Git push complete")
        case "status":
            let output = try runConfiguredGit(["status", "--short"])
            print(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Git working tree clean" : output)
        default:
            throw CLIError.message("Unknown git subcommand: \(subcommand)")
        }
    }

    static func native(_ args: [String]) throws {
        guard args.first == "config" else { throw CLIError.message("Usage: dw native config <provider> --endpoint <url> [--username <user>]") }
        let provider = try parseProvider(requiredArg(args, 1, "provider"))
        var state = StateManager.loadState()
        var config = state.nativeProviderConfigs[provider] ?? NativeProviderConfig()
        config.endpoint = optionValue("--endpoint", in: args) ?? config.endpoint
        config.username = optionValue("--username", in: args) ?? config.username
        state.nativeProviderConfigs[provider] = config
        state.providerTransportModes[provider] = .native
        StateManager.saveState(state)
        print("\(provider.title) native endpoint: \(config.endpoint)")
    }

    static func snapshot(_ args: [String]) async throws {
        guard let sub = args.first else { throw CLIError.message("snapshot requires subcommand") }
        let manager = SnapshotManager()
        switch sub {
        case "list":
            for snapshot in manager.listSnapshots() {
                print("\(snapshot.id.uuidString) \(snapshot.name) files=\(snapshot.fileCount) machine=\(snapshot.machineID) date=\(snapshot.date)")
            }
        case "create":
            let name = try requiredArg(args, 1, "snapshot name")
            let state = StateManager.loadState()
            let snapshot = try manager.createSnapshot(dotfiles: state.dotfiles, name: name, providerRootPath: currentProviderRootPath(state))
            print("Snapshot: \(snapshot.id.uuidString) \(snapshot.name)")
        case "restore":
            let snapshot = try findSnapshot(requiredArg(args, 1, "snapshot id-or-name"), manager: manager)
            if SecurityPolicy.requiresBiometricAuthentication {
                _ = try await BiometricAuthenticator.shared.authenticate(reason: "Authenticate to restore snapshot")
            }
            try manager.restoreSnapshot(snapshot)
            print("Restored: \(snapshot.name)")
        case "delete":
            let snapshot = try findSnapshot(requiredArg(args, 1, "snapshot id-or-name"), manager: manager)
            try manager.deleteSnapshot(snapshot)
            print("Deleted: \(snapshot.name)")
        default:
            throw CLIError.message("Unknown snapshot subcommand: \(sub)")
        }
    }

    static func doctor() {
        let state = StateManager.loadState()
        var issues = 0
        for file in state.dotfiles {
            if !FileManager.default.fileExists(atPath: expand(file.path)) {
                issues += 1
                print("Missing: \(file.path)")
            }
        }
        print(issues == 0 ? "System healthy" : "Issues: \(issues)")
    }

    static func metadata(_ args: [String]) throws {
        guard let path = args.first else { throw CLIError.message("Specify file") }
        var state = StateManager.loadState()
        guard let index = state.dotfiles.firstIndex(where: { $0.path == path || expand($0.path) == expand(path) }) else {
            throw CLIError.message("Not monitored: \(path)")
        }
        applyDotfileOptions(&state.dotfiles[index], args: Array(args.dropFirst()))
        StateManager.saveState(state)
        print("Metadata updated: \(path)")
    }

    static func hooks(_ args: [String]) throws {
        let value = try requiredArg(args, 0, "on|off")
        switch value {
        case "on", "enable", "enabled":
            SecurityPolicy.setHooksEnabled(true)
            print("Hooks enabled")
        case "off", "disable", "disabled":
            SecurityPolicy.setHooksEnabled(false)
            print("Hooks disabled")
        default:
            throw CLIError.message("Use on or off")
        }
    }

    static func monitor(_ args: [String]) throws {
        let path = try requiredArg(args, 0, "file")
        let value = try requiredArg(args, 1, "on|off")
        var state = StateManager.loadState()
        guard let index = state.dotfiles.firstIndex(where: { $0.path == path || expand($0.path) == expand(path) }) else {
            throw CLIError.message("Not monitored: \(path)")
        }
        state.dotfiles[index].isMonitored = ["on", "enable", "enabled"].contains(value)
        StateManager.saveState(state)
        print("\(path): \(state.dotfiles[index].isMonitored ? "monitored" : "paused")")
    }

    static func cat(_ args: [String]) throws {
        let file = try monitoredFile(requiredArg(args, 0, "file"))
        let url = URL(fileURLWithPath: expand(file.path))
        try SyncPathSecurity.validateLocalFile(url)
        let data = try Data(contentsOf: url)
        print(String(data: data, encoding: .utf8) ?? "<binary>")
    }

    static func edit(_ args: [String]) throws {
        let file = try monitoredFile(requiredArg(args, 0, "file"))
        let url = URL(fileURLWithPath: expand(file.path))
        try SyncPathSecurity.validateLocalFile(url)
        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "vi"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [editor, url.path]
        try process.run()
        process.waitUntilExit()
        print("Edited: \(file.path)")
    }

    static func conflicts(_ args: [String]) throws {
        guard let sub = args.first else { throw CLIError.message("conflicts requires subcommand") }
        switch sub {
        case "list":
            let conflicts = StateManager.loadState().dotfiles.filter { $0.status == .conflict }
            if conflicts.isEmpty { print("No conflicts") }
            for file in conflicts { print(file.path) }
        case "resolve":
            let path = try requiredArg(args, 1, "file")
            let strategy = try requiredArg(args, 2, "local|stored|newest")
            try resolveConflict(path: path, strategy: strategy)
        default:
            throw CLIError.message("Unknown conflicts subcommand: \(sub)")
        }
    }

    static func machine() throws {
        let identity = try MachineIdentity.current()
        print("ID: \(identity.id)")
        print("Host: \(identity.hostname)")
        print("User: \(identity.userName)")
        print("OS: \(identity.osVersion)")
        print("Arch: \(identity.architecture)")
    }

    static func versions(_ args: [String]) throws {
        if args.first == "restore" {
            let path = try requiredArg(args, 1, "file")
            let versionID = try requiredArg(args, 2, "version-id")
            try restoreVersion(path: path, versionID: versionID)
            return
        }

        let file = try monitoredFile(requiredArg(args, 0, "file"))
        let state = StateManager.loadState()
        guard let root = currentProviderRootPath(state), !root.isEmpty else { throw CLIError.message("Provider root not configured") }
        let relative = SyncStoragePaths.relativeStoragePath(for: URL(fileURLWithPath: expand(file.path))).urlSafeBase64()
        let folder = URL(fileURLWithPath: expand(root)).appendingPathComponent(".dotweaver/versions").appendingPathComponent(relative)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            print("No versions")
            return
        }
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            print(entry.lastPathComponent)
        }
    }

    static func template(_ args: [String]) throws {
        guard let sub = args.first else { throw CLIError.message("template requires subcommand") }
        switch sub {
        case "list":
            for template in builtInTemplates {
                print("\(template.key) -> \(template.path)")
            }
        case "apply":
            let key = try requiredArg(args, 1, "template key")
            guard let template = builtInTemplates.first(where: { $0.key == key }) else {
                throw CLIError.message("Unknown template: \(key)")
            }
            let url = URL(fileURLWithPath: expand(template.path))
            guard let data = template.content.data(using: .utf8) else {
                throw CLIError.message("Unable to encode template content")
            }
            try SyncPathSecurity.writeFileAtomically(data, to: url)
            if !StateManager.loadState().dotfiles.contains(where: { $0.path == template.path }) {
                try add([template.path])
            }
            print("Applied: \(template.key)")
        default:
            throw CLIError.message("Unknown template subcommand: \(sub)")
        }
    }

    static func interop(_ args: [String]) throws {
        let tool = try requiredArg(args, 0, "mackup|chezmoi")
        let action = try requiredArg(args, 1, "import|export")
        let dryRun = args.contains("--dry-run")

        switch (tool, action) {
        case ("mackup", "import"):
            let path = try requiredArg(args, 2, "config file")
            let url = URL(fileURLWithPath: expand(path))
            let imported = try DotfileInterop.importMackupConfig(from: url)
            try printOrSaveImported(imported, dryRun: dryRun, label: "Mackup")
        case ("chezmoi", "import"):
            let path = try requiredArg(args, 2, "source directory")
            let url = URL(fileURLWithPath: expand(path))
            let imported = try DotfileInterop.importChezmoiSource(from: url)
            try printOrSaveImported(imported, dryRun: dryRun, label: "chezmoi")
        case ("chezmoi", "export"):
            let path = try requiredArg(args, 2, "source directory")
            let url = URL(fileURLWithPath: expand(path))
            let exported = try DotfileInterop.exportChezmoiSource(
                dotfiles: StateManager.loadState().dotfiles,
                to: url,
                overwrite: args.contains("--force")
            )
            print("Exported \(exported) files to chezmoi source")
        default:
            throw CLIError.message("Usage: dw interop <mackup|chezmoi> <import|export>")
        }
    }
}

private enum CLIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        }
    }
}

private struct CLITemplate {
    let key: String
    let path: String
    let content: String
}

private let builtInTemplates = [
    CLITemplate(key: "oh-my-zsh", path: "~/.zshrc", content: "# Oh My Zsh configuration\nexport ZSH=\"$HOME/.oh-my-zsh\"\nZSH_THEME=\"robbyrussell\"\nplugins=(git)\nsource $ZSH/oh-my-zsh.sh\n"),
    CLITemplate(key: "starship", path: "~/.config/starship.toml", content: "[character]\nsuccess_symbol = \"[->](bold green)\"\nerror_symbol = \"[->](bold red)\"\n"),
    CLITemplate(key: "vim", path: "~/.vimrc", content: "set number\nset relativenumber\nset expandtab\nset tabstop=4\nset shiftwidth=4\nsyntax on\n")
]

private func requiredArg(_ args: [String], _ index: Int, _ name: String) throws -> String {
    guard args.indices.contains(index) else { throw CLIError.message("Missing \(name)") }
    return args[index]
}

private func optionValue(_ option: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: option), args.indices.contains(index + 1) else { return nil }
    return args[index + 1]
}

private func expand(_ path: String) -> String {
    (path as NSString).expandingTildeInPath
}

private func parseProvider(_ raw: String) throws -> SyncProvider {
    guard let provider = SyncProvider(rawValue: raw.lowercased()) else {
        throw CLIError.message("Unknown provider: \(raw)")
    }
    return provider
}

private func parseMode(_ raw: String) throws -> ProviderTransportMode {
    switch raw.lowercased() {
    case "folder", "mount", "sync", "mount-sync": return .folder
    case "native", "protocol": return .native
    default: throw CLIError.message("Unknown transport: \(raw)")
    }
}

private func parseStrategy(_ raw: String) throws -> ConflictStrategy {
    guard let strategy = ConflictStrategy(rawValue: raw) else {
        throw CLIError.message("Unknown strategy: \(raw)")
    }
    return strategy
}

private func transportMode(for provider: SyncProvider, state: AppState) -> ProviderTransportMode {
    state.providerTransportModes[provider] ?? .folder
}

private func currentProviderRootPath(_ state: AppState) -> String? {
    state.selectedProvider == .git ? state.gitLocalPath : state.cloudSyncPath
}

private func runConfiguredGit(_ arguments: [String]) throws -> String {
    let repositoryPath = StateManager.loadState().gitLocalPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !repositoryPath.isEmpty else {
        throw CLIError.message("Git repository path not configured")
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["-C", repositoryPath] + arguments

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw CLIError.message(errorOutput.isEmpty ? output : errorOutput)
    }
    return output
}

private func stageAndCommitConfiguredGitIfNeeded() throws {
    _ = try runConfiguredGit(["add", ".dotweaver"])
    let status = try runConfiguredGit(["status", "--porcelain", ".dotweaver"])
    guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return
    }
    _ = try runConfiguredGit(["commit", "-m", "Sync dotfiles"])
}

private func validatedGitBranch(_ rawBranch: String) throws -> String {
    let branch = rawBranch.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !branch.isEmpty,
          !branch.hasPrefix("-"),
          branch.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          branch.rangeOfCharacter(from: .controlCharacters) == nil else {
        throw CLIError.message("Invalid Git branch")
    }
    return branch
}

private func monitoredFile(_ path: String) throws -> Dotfile {
    let state = StateManager.loadState()
    guard let file = state.dotfiles.first(where: { $0.path == path || expand($0.path) == expand(path) }) else {
        throw CLIError.message("Not monitored: \(path)")
    }
    return file
}

private func applyDotfileOptions(_ dotfile: inout Dotfile, args: [String]) {
    if let group = optionValue("--group", in: args) { dotfile.group = group }
    if let tag = optionValue("--tag", in: args), !dotfile.tags.contains(tag) { dotfile.tags.append(tag) }
    if let hook = optionValue("--pre-hook", in: args) { dotfile.preSyncHook = hook }
    if let hook = optionValue("--post-hook", in: args) { dotfile.postSyncHook = hook }
    if let rawStrategy = optionValue("--strategy", in: args),
       let strategy = try? parseStrategy(rawStrategy) {
        dotfile.conflictStrategy = strategy
    }
}

private func findSnapshot(_ idOrName: String, manager: SnapshotManager) throws -> Snapshot {
    let snapshots = manager.listSnapshots()
    if let snapshot = snapshots.first(where: { $0.id.uuidString == idOrName || $0.name == idOrName }) {
        return snapshot
    }
    throw CLIError.message("Snapshot not found: \(idOrName)")
}

private func resolveConflict(path: String, strategy: String) throws {
    var state = StateManager.loadState()
    guard let index = state.dotfiles.firstIndex(where: { $0.path == path || expand($0.path) == expand(path) }) else {
        throw CLIError.message("Not monitored: \(path)")
    }
    guard let root = currentProviderRootPath(state), !root.isEmpty else { throw CLIError.message("Provider root not configured") }

    let localURL = URL(fileURLWithPath: expand(state.dotfiles[index].path))
    let storageRoot = URL(fileURLWithPath: expand(root))
    let storedURL = SyncStoragePaths.remoteFileURL(forLocalFile: localURL, storageRoot: storageRoot)
    let fm = FileManager.default
    try SyncPathSecurity.validateLocalFile(localURL)
    try SyncPathSecurity.ensureContained(storedURL, in: storageRoot)

    switch strategy {
    case "local":
        let data = try Data(contentsOf: localURL)
        let storedData = state.dotfiles[index].isSecret ? try VaultCrypto.encrypt(data, originalPath: state.dotfiles[index].path) : data
        try fm.createDirectory(at: storedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try storedData.write(to: storedURL, options: .atomic)
    case "stored":
        let data = try VaultCrypto.decryptIfNeeded(Data(contentsOf: storedURL))
        try SyncPathSecurity.writeFileAtomically(data, to: localURL)
    case "newest":
        let localDate = (try? fm.attributesOfItem(atPath: localURL.path)[.modificationDate] as? Date) ?? .distantPast
        let storedDate = (try? fm.attributesOfItem(atPath: storedURL.path)[.modificationDate] as? Date) ?? .distantPast
        try resolveConflict(path: path, strategy: localDate >= storedDate ? "local" : "stored")
        return
    default:
        throw CLIError.message("Use local, stored, or newest")
    }

    state.dotfiles[index].status = .synced
    state.recentActivity.insert(ActivityLog(message: "CLI: Resolved conflict \(path)", type: .sync), at: 0)
    StateManager.saveState(state)
    print("Resolved: \(path)")
}

private func restoreVersion(path: String, versionID: String) throws {
    let file = try monitoredFile(path)
    let state = StateManager.loadState()
    guard let root = currentProviderRootPath(state), !root.isEmpty else { throw CLIError.message("Provider root not configured") }

    let relative = SyncStoragePaths.relativeStoragePath(for: URL(fileURLWithPath: expand(file.path))).urlSafeBase64()
    let contentURL = URL(fileURLWithPath: expand(root))
        .appendingPathComponent(".dotweaver/versions")
        .appendingPathComponent(relative)
        .appendingPathComponent(versionID)
        .appendingPathComponent("content.bin")
    let storageRoot = URL(fileURLWithPath: expand(root))
    try SyncPathSecurity.ensureContained(contentURL, in: storageRoot)

    guard FileManager.default.fileExists(atPath: contentURL.path) else {
        throw CLIError.message("Version not found: \(versionID)")
    }

    let localURL = URL(fileURLWithPath: expand(file.path))
    try SyncPathSecurity.validateLocalFile(localURL)
    let data = try VaultCrypto.decryptIfNeeded(Data(contentsOf: contentURL))
    try SyncPathSecurity.writeFileAtomically(data, to: localURL)
    SyncAuditLog.record("CLI restored version", metadata: ["file": file.path, "version": versionID])
    print("Restored version \(versionID) -> \(file.path)")
}

private func printOrSaveImported(_ imported: [Dotfile], dryRun: Bool, label: String) throws {
    if dryRun {
        if imported.isEmpty {
            print("No \(label) files found")
            return
        }
        for file in imported {
            print(file.path)
        }
        return
    }

    var state = StateManager.loadState()
    let before = state.dotfiles.count
    state.dotfiles = DotfileInterop.merge(imported, into: state.dotfiles)
    let added = state.dotfiles.count - before
    state.recentActivity.insert(ActivityLog(message: "CLI: Imported \(added) \(label) files", type: .add), at: 0)
    StateManager.saveState(state)
    print("Imported \(added) \(label) files")
}

private extension String {
    func urlSafeBase64() -> String {
        Data(utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
