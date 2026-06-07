import SwiftUI
import DotWeaverKit

@main
struct DotWeaver: App {
    @StateObject private var viewModel = DotfilesViewModel()
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup(id: "main") {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(viewModel)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // Show Dock icon when window opens
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .onDisappear {
                        // Hide Dock icon when window is closed (Cmd+W)
                        NSApp.setActivationPolicy(.accessory)
                    }
            } else {
                OnboardingView()
                    .environmentObject(viewModel)
                    .preferredColorScheme(.dark)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appTermination) {
                Button("Quit DotWeaver") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(replacing: .windowSize) {
                Button("Close Window") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
        
        MenuBarExtra {
            Button("Sync Now") {
                Task {
                    await viewModel.syncBidirectional()
                }
            }
            .disabled(viewModel.isSyncing)
            
            Divider()
            
            Button("Open DotWeaver") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Check for Updates...") {
                updateManager.checkForUpdates()
            }
            .disabled(!updateManager.canCheckForUpdates)
            
            #if os(macOS)
            Button("Settings...") {
                NSApp.setActivationPolicy(.regular)
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            #endif
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            if let image = DotWeaverAssets.menuBarIcon() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityLabel("DotWeaver")
            } else {
                Label("DotWeaver", systemImage: "doc.text.magnifyingglass")
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
        #endif
    }
}
