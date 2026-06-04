import SwiftUI
import DotWeaverKit

struct ConflictResolutionView: View {
    let conflictedFiles: [Dotfile]
    @State private var selectedFile: Dotfile?
    @State private var resolution: ConflictStrategy = .lastModifiedWins
    @State private var resolvedFileIDs: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: DotfilesViewModel

    private var unresolvedFiles: [Dotfile] {
        conflictedFiles.filter { !resolvedFileIDs.contains($0.id) }
    }
    
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
                        Text("\(unresolvedFiles.count) file(s) require your attention before syncing can continue.")
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
                    List(unresolvedFiles, selection: $selectedFile) { file in
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
                                    DiffPanel(title: "Local Version", content: localContent(for: file), color: .blue)
                                        .frame(width: geometry.size.width / 2)
                                    
                                    Divider().opacity(0.5)
                                    
                                    DiffPanel(title: "Stored Version", content: storedContent(for: file), color: .purple)
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
        do {
            try resolve(file: file)
            resolvedFileIDs.insert(file.id)
            selectedFile = unresolvedFiles.first
            viewModel.statusMessage = "Conflict resolved for \((file.path as NSString).lastPathComponent)"

            if unresolvedFiles.isEmpty {
                dismiss()
            }
        } catch {
            viewModel.statusMessage = "Conflict resolution failed: \(error.localizedDescription)"
        }
    }

    private func resolve(file: Dotfile) throws {
        let localURL = localURL(for: file)
        let storedURL = try storedURL(for: file)

        switch resolution {
        case .localWins:
            try writeStoredFile(from: localURL, to: storedURL, file: file)
        case .remoteWins:
            try restoreStoredFile(from: storedURL, to: localURL)
        case .lastModifiedWins:
            let localDate = modificationDate(at: localURL) ?? .distantPast
            let storedDate = modificationDate(at: storedURL) ?? .distantPast
            if localDate >= storedDate {
                try writeStoredFile(from: localURL, to: storedURL, file: file)
            } else {
                try restoreStoredFile(from: storedURL, to: localURL)
            }
        case .manual:
            throw NSError(
                domain: "DotWeaver.ConflictResolution",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Select a concrete resolution strategy before applying."]
            )
        }
    }

    private func localContent(for file: Dotfile) -> String {
        readText(at: localURL(for: file))
    }

    private func storedContent(for file: Dotfile) -> String {
        do {
            return readText(at: try storedURL(for: file))
        } catch {
            return "Stored version unavailable: \(error.localizedDescription)"
        }
    }

    private func localURL(for file: Dotfile) -> URL {
        URL(fileURLWithPath: (file.path as NSString).expandingTildeInPath)
    }

    private func storedURL(for file: Dotfile) throws -> URL {
        let rootPath = storageRootPath().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty else {
            throw NSError(
                domain: "DotWeaver.ConflictResolution",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Storage folder is not configured."]
            )
        }

        return SyncStoragePaths.remoteFileURL(
            forLocalFile: localURL(for: file),
            storageRoot: URL(fileURLWithPath: (rootPath as NSString).expandingTildeInPath)
        )
    }

    private func storageRootPath() -> String {
        viewModel.selectedProvider == .git ? viewModel.gitLocalPath : viewModel.cloudSyncPath
    }

    private func readText(at url: URL) -> String {
        do {
            let data = try VaultCrypto.decryptIfNeeded(Data(contentsOf: url))
            return String(data: data, encoding: .utf8) ?? "<binary file>"
        } catch {
            return "Unable to read \(url.path): \(error.localizedDescription)"
        }
    }

    private func writeStoredFile(from source: URL, to destination: URL, file: Dotfile) throws {
        let data = try Data(contentsOf: source)
        let storedData = file.isSecret ? try VaultCrypto.encrypt(data, originalPath: file.path) : data
        try writeStoredData(storedData, to: destination)
    }

    private func restoreStoredFile(from source: URL, to destination: URL) throws {
        let data = try VaultCrypto.decryptIfNeeded(Data(contentsOf: source))
        try SyncPathSecurity.writeFileAtomically(data, to: destination)
    }

    private func writeStoredData(_ data: Data, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try data.write(to: destination, options: .atomic)
    }

    private func modificationDate(at url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
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
