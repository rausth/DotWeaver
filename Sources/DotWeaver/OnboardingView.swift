import SwiftUI
import DotWeaverKit

struct OnboardingView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ], colors: [
                .blue.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3),
                .indigo.opacity(0.2), .black, .purple.opacity(0.2),
                .blue.opacity(0.3), .indigo.opacity(0.2), .blue.opacity(0.3)
            ])
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                if currentStep == 0 {
                    stepOne
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else if currentStep == 1 {
                    stepTwo
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else {
                    stepThree
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
                
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.spring()) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Button(currentStep == 2 ? "Get Started" : "Next") {
                        withAnimation(.spring()) {
                            if currentStep == 2 {
                                hasCompletedOnboarding = true
                            } else {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .frame(width: 500)
            }
            .padding(60)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 20)
        }
        .frame(width: 900, height: 700)
    }
    
    var stepOne: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                .shadow(radius: 10)
            
            Text("Welcome to DotWeaver")
                .font(.system(size: 40, weight: .black, design: .rounded))
            
            Text("Sophisticated dotfile synchronization for elite developers. Keep your environment consistent across all your machines.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 500)
        }
    }
    
    var stepTwo: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Select your Provider")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Choose where you want to store your synchronized dotfiles.")
                    .foregroundStyle(.secondary)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                    ForEach(SyncProvider.allCases) { provider in
                        OnboardingProviderCard(provider: provider)
                    }
                }
                .padding(20)
            }
            .background(.black.opacity(0.2))
            .cornerRadius(20)
            .frame(height: 300)
            
            if !viewModel.cloudSyncPath.isEmpty {
                HStack {
                    Image(systemName: "folder.fill")
                    Text(viewModel.cloudSyncPath)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .frame(width: 600)
    }
    
    var stepThree: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .shadow(radius: 10)
            
            Text("Ready to go?")
                .font(.system(size: 40, weight: .black, design: .rounded))
            
            Text("Everything is set up. You can now start adding files to monitoring or explore our template gallery.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(width: 500)
        }
    }
}

struct OnboardingProviderCard: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    let provider: SyncProvider
    
    var isSelected: Bool { viewModel.selectedProvider == provider }
    
    var body: some View {
        Button(action: { selectProvider(provider) }) {
            VStack(spacing: 12) {
                Image(systemName: icon(for: provider))
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(provider.title)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(isSelected ? Color.blue : Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func selectProvider(_ provider: SyncProvider) {
        withAnimation(.spring()) {
            viewModel.selectedProvider = provider
        }
        
        if provider != .git {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Select Sync Folder"
            
            if panel.runModal() == .OK, let url = panel.url {
                viewModel.cloudSyncPath = url.path
            }
        }
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
