import SwiftUI
import DotWeaverKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = true
    
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
                    
                    if autoSyncEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync interval: \(Int(syncInterval/60)) minutes")
                                .foregroundStyle(.secondary)
                            Slider(value: $syncInterval, in: 60...3600, step: 60)
                                .tint(.blue)
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
                    
                    Text("This provider will be used to store your managed dotfiles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Primary Storage")
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
                } else if viewModel.selectedProvider == .icloud || viewModel.selectedProvider == .dropbox || viewModel.selectedProvider == .googledrive || viewModel.selectedProvider == .onedrive {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: viewModel.selectedProvider))
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)
                                
                                Text(viewModel.selectedProvider.title)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: selectCloudFolder) {
                                    Label("Change Folder", systemImage: "folder.badge.plus")
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if !viewModel.cloudSyncPath.isEmpty {
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
                        Text("Cloud Configuration")
                            .font(.headline)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .tabItem {
                Label("Storage", systemImage: "externaldrive.fill")
            }
            
            // Security Settings
            Form {
                Section {
                    Toggle("Require biometric authentication", isOn: $biometricEnabled)
                        .toggleStyle(.switch)
                        .help("Require Touch ID or Face ID to access credentials")
                    
                    Text("When enabled, you'll need to authenticate with Touch ID or Face ID to sync or access stored credentials.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } header: {
                    Text("Authentication")
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
                        Label("Install 'dw' to /usr/local/bin", systemImage: "terminal.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
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
            viewModel.gitLocalPath = url.path
        }
        #endif
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
        let installPath = "/usr/local/bin/dw"
        
        let script = "do shell script \"mkdir -p /usr/local/bin && ln -sf '\(cliPath)' '\(installPath)'\" with administrator privileges"
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("Error installing CLI: \(error)")
        } else {
            viewModel.statusMessage = "✅ CLI 'dw' installed to /usr/local/bin"
        }
        #endif
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
