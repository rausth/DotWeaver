import Foundation
import DotWeaverKit

struct CLICommands {
    static func run() {
        let arguments = CommandLine.arguments
        
        guard arguments.count > 1 else {
            printUsage()
            exit(0)
        }
        
        let command = arguments[1]
        let subArguments = Array(arguments.dropFirst(2))
        
        switch command {
        case "add":
            addCommand(args: subArguments)
        case "remove", "rm":
            removeCommand(args: subArguments)
        case "status":
            statusCommand(args: subArguments)
        case "list", "ls":
            listCommand(args: subArguments)
        case "vault":
            vaultCommand(args: subArguments)
        case "--help", "-h", "help":
            printUsage()
        default:
            print("Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    }
    
    static func printUsage() {
        print("""
        DotWeaver CLI (dw) - Sophisticated Dotfiles Manager
        
        Usage:
          dw add <file>            Add a dotfile to management
          dw remove <file>         Remove a dotfile from management
          dw status                Show sync status and recent activity
          dw list                  List managed dotfiles
          dw vault <file>          Toggle a file's 'secret' status
          dw --help                Show this help message
        
        Examples:
          dw add ~/.zshrc
          dw vault ~/.ssh/config
        """)
    }
    
    static func addCommand(args: [String]) {
        guard let path = args.first else {
            print("❌ Error: Please specify a file to add.")
            exit(1)
        }
        
        var state = StateManager.loadState()
        
        let fullPath = (path as NSString).expandingTildeInPath
        
        if !FileManager.default.fileExists(atPath: fullPath) {
            print("❌ Error: File does not exist at \(fullPath)")
            exit(1)
        }

        if state.dotfiles.contains(where: { $0.path == path }) {
            print("💡 Info: '\(path)' is already being monitored.")
            exit(0)
        }
        
        let newDotfile = Dotfile(path: path)
        state.dotfiles.append(newDotfile)
        state.recentActivity.insert(ActivityLog(message: "CLI: Added \(path)", type: .add), at: 0)
        
        StateManager.saveState(state)
        print("✅ Success: '\(path)' is now being monitored.")
    }
    
    static func removeCommand(args: [String]) {
        guard let path = args.first else {
            print("❌ Error: Please specify a file to remove.")
            exit(1)
        }
        
        var state = StateManager.loadState()
        
        guard let index = state.dotfiles.firstIndex(where: { $0.path == path }) else {
            print("❌ Error: '\(path)' is not a monitored file.")
            exit(1)
        }
        
        state.dotfiles.remove(at: index)
        state.recentActivity.insert(ActivityLog(message: "CLI: Removed \(path)", type: .system), at: 0)
        
        StateManager.saveState(state)
        print("✅ Success: Stopped monitoring '\(path)'.")
    }
    
    static func statusCommand(args: [String]) {
        let state = StateManager.loadState()
        let lastSync = state.recentActivity.first(where: { $0.type == .sync })?.timestamp
        
        print("Sophisticated Sync Status:")
        print("--------------------------")
        print("Provider: \(state.selectedProvider.title)")
        print("Active Files: \(state.dotfiles.count)")
        print("Vaulted: \(state.dotfiles.filter(\.isSecret).count)")
        
        if let lastSync = lastSync {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            print("Last Sync: \(formatter.localizedString(for: lastSync, relativeTo: Date()))")
        } else {
            print("Last Sync: Never")
        }
        
        print("\nRecent Activity:")
        for (index, log) in state.recentActivity.prefix(5).enumerated() {
            print("  \(index + 1). [\(log.type.rawValue.capitalized)] \(log.message)")
        }
    }
    
    static func listCommand(args: [String]) {
        let state = StateManager.loadState()
        
        print("💎 Managed Dotfiles (\(state.dotfiles.count)):")
        
        if state.dotfiles.isEmpty {
            print("  No files are currently being monitored. Use 'dw add <file>' to begin.")
            return
        }
        
        for file in state.dotfiles {
            let secretTag = file.isSecret ? " (vaulted)" : ""
            print("  ▸ \(file.path)\(secretTag)")
        }
    }
    
    static func vaultCommand(args: [String]) {
        guard let path = args.first else {
            print("❌ Error: Please specify a file to vault/unvault.")
            exit(1)
        }
        
        var state = StateManager.loadState()
        
        guard let index = state.dotfiles.firstIndex(where: { $0.path == path }) else {
            print("❌ Error: '\(path)' is not a monitored file.")
            exit(1)
        }
        
        state.dotfiles[index].isSecret.toggle()
        let isNowSecret = state.dotfiles[index].isSecret
        let action = isNowSecret ? "vaulted" : "unvaulted"
        
        state.recentActivity.insert(ActivityLog(message: "CLI: \(action) \(path)", type: .system), at: 0)
        
        StateManager.saveState(state)
        print("✅ Success: '\(path)' has been \(action).")
    }
}
