import SwiftUI
import DotWeaverKit

struct ConflictResolutionView: View {
    let conflictedFiles: [Dotfile]
    @State private var selectedFile: Dotfile?
    @State private var resolution: ConflictStrategy = .lastModifiedWins
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Banner
                HStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conflict Resolution")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(conflictedFiles.count) file(s) require your attention before syncing can continue.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(20)
                .background(.ultraThinMaterial)
                
                Divider().opacity(0.5)
                
                // Main Content
                HStack(spacing: 0) {
                    // List
                    List(conflictedFiles, selection: $selectedFile) { file in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text((file.path as NSString).lastPathComponent)
                                    .font(.headline)
                                Text(file.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .tag(file)
                    }
                    .listStyle(.sidebar)
                    .frame(width: 250)
                    
                    Divider().opacity(0.5)
                    
                    // Detail
                    if let file = selectedFile {
                        VStack(spacing: 0) {
                            // Diff Viewer Header
                            HStack {
                                Text("Comparison Diff")
                                    .font(.headline)
                                Spacer()
                                Picker("Strategy", selection: $resolution) {
                                    ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                                        Text(strategy.description).tag(strategy)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 250)
                            }
                            .padding()
                            .background(Color.black.opacity(0.1))
                            
                            Divider().opacity(0.5)
                            
                            // Diff Viewer Content
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    DiffPanel(title: "Local Version", content: getMockLocalContent(for: file), color: .blue)
                                        .frame(width: geometry.size.width / 2)
                                    
                                    Divider().opacity(0.5)
                                    
                                    DiffPanel(title: "Cloud Version", content: getMockRemoteContent(for: file), color: .purple)
                                        .frame(width: geometry.size.width / 2)
                                }
                            }
                            
                            Divider().opacity(0.5)
                            
                            // Action Bar
                            HStack {
                                Spacer()
                                Button("Cancel") {
                                    selectedFile = nil
                                }
                                Button("Apply Resolution") {
                                    applyResolution(for: file)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                            .padding()
                            .background(Color.black.opacity(0.1))
                        }
                        .background(.ultraThinMaterial)
                    } else {
                        ContentUnavailableView(
                            "No File Selected",
                            systemImage: "arrow.left.arrow.right",
                            description: Text("Select a conflicted file from the sidebar to view the differences.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(width: 900, height: 600)
    }
    
    private func applyResolution(for file: Dotfile) {
        print("Applying \(resolution) to \(file.path)")
        selectedFile = nil
        if conflictedFiles.isEmpty { dismiss() }
    }
    
    // Mocks for visual demonstration since full provider diff logic isn't wired yet
    private func getMockLocalContent(for file: Dotfile) -> String {
        return """
        # Local changes
        export PATH="/usr/local/bin:$PATH"
        alias gs="git status"
        alias ga="git add ."
        alias gc="git commit -m"
        """
    }
    
    private func getMockRemoteContent(for file: Dotfile) -> String {
        return """
        # Remote changes from another Mac
        export PATH="/opt/homebrew/bin:$PATH"
        alias gs="git status"
        alias gd="git diff"
        """
    }
}

struct DiffPanel: View {
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.1))
            
            ScrollView {
                Text(content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.8))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.opacity(0.2))
    }
}
