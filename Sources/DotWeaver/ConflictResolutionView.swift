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
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Comparison Diff")
                                            .font(.headline)
                                        Text(diffSummary(for: file))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Picker("Strategy", selection: $resolution) {
                                        ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                                            Text(strategy.description).tag(strategy)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 250)
                                    .accessibilityLabel("Conflict resolution strategy")
                                }
                                Text(strategyHelpText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.black.opacity(0.1))
                            
                            Divider().opacity(0.5)
                            
                            // Diff Viewer Content
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    DiffPanel(
                                        title: "Local Version",
                                        content: localContent(for: file),
                                        comparisonContent: storedContent(for: file),
                                        color: .blue
                                    )
                                    .frame(width: geometry.size.width / 2)
                                    
                                    Divider().opacity(0.5)
                                    
                                    DiffPanel(
                                        title: "Stored Version",
                                        content: storedContent(for: file),
                                        comparisonContent: localContent(for: file),
                                        color: .purple
                                    )
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
                                .keyboardShortcut(.cancelAction)
                                Button("Apply Resolution") {
                                    applyResolution(for: file)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .disabled(resolution == .manual)
                                .keyboardShortcut(.defaultAction)
                                .accessibilityLabel("Apply selected conflict resolution")
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

    private var strategyHelpText: String {
        switch resolution {
        case .localWins:
            return "Local version will overwrite the stored version."
        case .remoteWins:
            return "Stored version will restore over the local file."
        case .lastModifiedWins:
            return "The newest file by modification date will be kept."
        case .manual:
            return "Manual merge is not applied automatically. Edit one side, then choose a concrete strategy."
        }
    }

    private func diffSummary(for file: Dotfile) -> String {
        let local = localContent(for: file).splitForDiff()
        let stored = storedContent(for: file).splitForDiff()
        let changed = zipPadded(local, stored).filter { $0 != $1 }.count
        return "\(changed) changed line(s) • \(local.count) local / \(stored.count) stored"
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
    let comparisonContent: String
    let color: Color

    private var lines: [DiffLine] {
        let current = content.splitForDiff()
        let comparison = comparisonContent.splitForDiff()
        return zipPadded(current, comparison).enumerated().map { index, pair in
            DiffLine(number: index + 1, text: pair.0, isChanged: pair.0 != pair.1)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Spacer()
                Text("\(lines.filter(\.isChanged).count) changed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        DiffLineRow(line: line, color: color)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("\(title) diff")
        }
        .background(Color.black.opacity(0.2))
    }
}

private struct DiffLine: Identifiable {
    let id = UUID()
    let number: Int
    let text: String
    let isChanged: Bool
}

private struct DiffLineRow: View {
    let line: DiffLine
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(line.number)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
                .textSelection(.enabled)
            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.85))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(line.isChanged ? color.opacity(0.16) : Color.clear)
    }
}

private func zipPadded(_ left: [String], _ right: [String]) -> [(String, String)] {
    let count = max(left.count, right.count)
    return (0..<count).map { index in
        (index < left.count ? left[index] : "", index < right.count ? right[index] : "")
    }
}

private extension String {
    func splitForDiff() -> [String] {
        components(separatedBy: .newlines)
    }
}
