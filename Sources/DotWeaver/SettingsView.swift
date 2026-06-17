import SwiftUI
import DotWeaverKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = true
    @AppStorage("hooksEnabled") private var hooksEnabled: Bool = false
    
    @State private var autoSyncEnabled: Bool = true
    @State private var syncInterval: Double = 300 // 5 minutes
    @State private var notificationsEnabled: Bool = true
    
    var body: some View {
        TabView {
            // General Settings
            Form {
                Section {
                    Toggle("Launch DotWeaver at login", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            if newValue {
                                updateLoginItem(true)
                            }
                        }
                    
                    Text("Toggle to open System Settings and add DotWeaver to your login items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Startup")
                        .font(.headline)
                }

                Section {
                    Toggle("Enable automatic sync", isOn: $autoSyncEnabled)
                        .toggleStyle(.switch)
                        .accessibilityLabel("Enable automatic sync")
                    
                    if autoSyncEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync interval: \(Int(syncInterval/60)) minutes")
                                .foregroundStyle(.secondary)
                            Slider(value: $syncInterval, in: 60...3600, step: 60)
                                .tint(.blue)
                                .accessibilityLabel("Sync interval")
                                .accessibilityValue("\(Int(syncInterval / 60)) minutes")
                        }
                        .padding(.leading, 24)
                        .padding(.top, 4)
                    }
                } header: {
                    Text("Sync Operations")
                        .font(.headline)
                }
                
                Section {
                    Toggle("Show notifications", isOn: $notificationsEnabled)
                        .toggleStyle(.switch)
                } header: {
                    Text("Alerts")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            // Storage Provider Settings
            Form {
                Section {
                    Picker("Primary Provider", selection: $viewModel.selectedProvider) {
                        ForEach(SyncProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedProvider) { _, _ in
                        Task { await viewModel.refreshAvailableMachines() }
                    }
                    
                    Text("This provider will be used to store your managed dotfiles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Primary Storage")
                        .font(.headline)
                }

                Section {
                    Picker("Sync From", selection: $viewModel.selectedSyncMachineID) {
                        Text("This Mac").tag("")
                        ForEach(remoteMachineChoices) { machine in
                            Text(machineLabel(machine)).tag(machine.id)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text(machineHelpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    Button {
                            Task { await viewModel.refreshAvailableMachines() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSyncing)
                        .accessibilityLabel("Refresh available machines")
                    }
                } header: {
                    Text("Machine Source")
                        .font(.headline)
                }
                
                if viewModel.selectedProvider == .git {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Local Repository", systemImage: "folder.fill")
                                    .font(.subheadline.bold())
                                Spacer()
                                Button(action: selectGitLocalFolder) {
                                    Text(viewModel.gitLocalPath.isEmpty ? "Select Path..." : "Change Path")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if !viewModel.gitLocalPath.isEmpty {
                                Text(viewModel.gitLocalPath)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                    } header: {
                        Text("Local Configuration")
                            .font(.headline)
                    }
                    
                    Section {
                        Picker("Git Host", selection: $viewModel.gitHost) {
                            Text("GitHub").tag("GitHub")
                            Text("GitLab").tag("GitLab")
                            Text("Bitbucket").tag("Bitbucket")
                            Text("Custom").tag("Custom")
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                        
                        TextField("Remote URL", text: $viewModel.gitRemoteUrl)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            TextField("Branch", text: $viewModel.gitBranch)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("SSH Key", text: $viewModel.gitSshKeyPath)
                                .textFieldStyle(.roundedBorder)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "network")
                            Text("Remote Configuration")
                        }
                        .font(.headline)
                    } footer: {
                        Text("DotWeaver will keep your local repo synchronized with your chosen host.")
                            .font(.caption)
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Transport", selection: transportBinding(for: viewModel.selectedProvider)) {
                                ForEach(ProviderTransportMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(spacing: 12) {
                                Image(systemName: icon(for: viewModel.selectedProvider))
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)
                                
                                Text(viewModel.selectedProvider.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                if viewModel.transportMode(for: viewModel.selectedProvider) == .folder {
                                    Button(action: selectCloudFolder) {
                                        Label("Change Folder", systemImage: "folder.badge.plus")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if viewModel.transportMode(for: viewModel.selectedProvider) == .native {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Endpoint URL (webdav://, sftp://, ftps://, https://)", text: nativeEndpointBinding(for: viewModel.selectedProvider))
                                        .textFieldStyle(.roundedBorder)

                                    TextField("Username / curl --user value (optional)", text: nativeUsernameBinding(for: viewModel.selectedProvider))
                                        .textFieldStyle(.roundedBorder)

                                    Text("Native mode transfers files over the protocol endpoint with system curl. Passwords are not stored; use SSH keys, .netrc, endpoint tokens, or provider credential helpers.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !viewModel.cloudSyncPath.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Sync Path:")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    
                                    HStack {
                                        Text(viewModel.cloudSyncPath)
                                            .font(.system(.caption, design: .monospaced))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.cloudSyncPath)
                                        }) {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Show in Finder")
                                    }
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                }
                            } else {
                                Text("No folder selected. Click 'Change Folder' to set up synchronization.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Folder Configuration")
                            .font(.headline)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .task {
                await viewModel.refreshAvailableMachines()
            }
            .tabItem {
                Label("Storage", systemImage: "externaldrive.fill")
            }
            
            // Security Settings
            Form {
                Section {
                    Toggle("Require biometric authentication", isOn: $biometricEnabled)
                        .toggleStyle(.switch)
                        .help("Require Touch ID or Face ID to access credentials")
                        .accessibilityLabel("Require biometric authentication")
                    
                    SecurityStatusRow(
                        title: "Vault authentication",
                        isEnabled: biometricEnabled,
                        enabledText: "Biometric gate active",
                        disabledText: "Vaulted sync does not require biometrics"
                    )

                    Text("When enabled, you'll need to authenticate with Touch ID or Face ID to sync or access stored credentials.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Authentication")
                        .font(.headline)
                }

                Section {
                    Toggle("Allow pre/post sync hook scripts", isOn: $hooksEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: hooksEnabled) { _, newValue in
                            SecurityPolicy.setHooksEnabled(newValue)
                        }
                        .accessibilityLabel("Allow pre and post sync hook scripts")

                    SecurityStatusRow(
                        title: "Hook scripts",
                        isEnabled: hooksEnabled,
                        enabledText: "Trusted scripts can run during sync",
                        disabledText: "Hook execution blocked"
                    )

                    Text("Hooks execute zsh script files from ~/.dotweaver/hooks. Keep disabled unless every hook is trusted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Hook Execution")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .tabItem {
                Label("Security", systemImage: "lock.shield.fill")
            }
            
            // CLI Settings
            Form {
                Section {
                    Button(action: installCLI) {
                        Label("Install 'dw' to PATH", systemImage: "terminal.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("settings.installCLI")
                    
                    Text("This will create a symlink to the DotWeaver CLI tool in your system path, allowing you to use the 'dw' command from any terminal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Command Line Interface")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .tabItem {
                Label("CLI", systemImage: "command")
            }
        }
        .frame(width: 550, height: 450)
    }
    
    private func selectCloudFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Sync Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? SecurityScopedBookmarks.register(url)
            viewModel.cloudSyncPath = url.path
        }
        #endif
    }
    
    private func selectGitLocalFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Local Git Repo"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? SecurityScopedBookmarks.register(url)
            viewModel.gitLocalPath = url.path
        }
        #endif
    }

    private func transportBinding(for provider: SyncProvider) -> Binding<ProviderTransportMode> {
        Binding(
            get: { viewModel.transportMode(for: provider) },
            set: { viewModel.setTransportMode($0, for: provider) }
        )
    }

    private func nativeEndpointBinding(for provider: SyncProvider) -> Binding<String> {
        Binding(
            get: { viewModel.nativeConfig(for: provider).endpoint },
            set: {
                var config = viewModel.nativeConfig(for: provider)
                config.endpoint = $0
                viewModel.setNativeConfig(config, for: provider)
            }
        )
    }

    private func nativeUsernameBinding(for provider: SyncProvider) -> Binding<String> {
        Binding(
            get: { viewModel.nativeConfig(for: provider).username },
            set: {
                var config = viewModel.nativeConfig(for: provider)
                config.username = $0
                viewModel.setNativeConfig(config, for: provider)
            }
        )
    }

    private var currentMachineID: String {
        (try? MachineIdentity.current().id) ?? ""
    }

    private var remoteMachineChoices: [MachineIdentity] {
        viewModel.availableMachines.filter { $0.id != currentMachineID }
    }

    private var machineHelpText: String {
        if viewModel.selectedSyncMachineID.isEmpty {
            return "Sync writes and reads this Mac's machine namespace."
        }
        return "Sync reads from the selected Mac and writes this Mac's namespace."
    }

    private func machineLabel(_ machine: MachineIdentity) -> String {
        "\(machine.hostname) • \(machine.architecture)"
    }
    
    private func updateLoginItem(_ enabled: Bool) {
        // Fallback to opening System Settings if API is unavailable or fails
        #if os(macOS)
        let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        NSWorkspace.shared.open(url)
        #endif
    }

    private func installCLI() {
        #if os(macOS)
        let bundlePath = Bundle.main.bundlePath
        let cliPath = "\(bundlePath)/Contents/MacOS/dw"
        #if arch(arm64)
        let installPath = "/opt/homebrew/bin/dw"
        #else
        let installPath = "/usr/local/bin/dw"
        #endif
        let installDir = (installPath as NSString).deletingLastPathComponent
        
        let script = "do shell script \"mkdir -p \(shellQuoted(installDir)) && ln -sf \(shellQuoted(cliPath)) \(shellQuoted(installPath))\" with administrator privileges"
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("Error installing CLI: \(error)")
        } else {
            viewModel.statusMessage = "CLI 'dw' installed to \(installPath)"
        }
        #endif
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
    
    private func icon(for provider: SyncProvider) -> String {
        switch provider {
        case .git: return "arrow.branch"
        case .icloud: return "icloud"
        case .onedrive: return "externaldrive"
        case .googledrive: return "externaldrive.fill"
        case .dropbox: return "shippingbox"
        case .webdav: return "network"
        case .sftp, .ftps: return "server.rack"
        case .s3: return "tray.2"
        }
    }
}

private struct SecurityStatusRow: View {
    let title: String
    let isEnabled: Bool
    let enabledText: String
    let disabledText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isEnabled ? "checkmark.shield.fill" : "xmark.shield.fill")
                .foregroundStyle(isEnabled ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(isEnabled ? enabledText : disabledText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background((isEnabled ? Color.green : Color.gray).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
