import SwiftUI
import DotWeaverKit

struct FileEditorView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @State private var content: String = ""
    @State private var filePath: String = ""
    @State private var isModified: Bool = false
    @State private var showingSaveAlert: Bool = false
    @State private var showingMetadata = false
    @Environment(\.dismiss) private var dismiss
    
    let initialPath: String?
    
    init(path: String? = nil) {
        self.initialPath = path
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $content)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(8)
                .onChange(of: content) { _, _ in
                    isModified = true
                }
            
            Divider()
            
            // Status bar
            HStack {
                Text(filePath.isEmpty ? "New File" : filePath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Text("\(content.split(separator: "\n").count) lines")
                Text("•")
                Text("\(content.count) chars")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .background(.ultraThinMaterial)
        .navigationTitle(filePath.isEmpty ? "Untitled" : (filePath as NSString).lastPathComponent)
        .navigationSubtitle(isModified ? "Edited" : "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingMetadata = true }) {
                    Label("Info", systemImage: "info.circle")
                }
                .popover(isPresented: $showingMetadata) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("File Metadata")
                            .font(.headline)
                        
                        if let index = viewModel.dotfiles.firstIndex(where: { $0.path == filePath }) {
                            TextField("Group", text: Binding(
                                get: { viewModel.dotfiles[index].group ?? "" },
                                set: { viewModel.dotfiles[index].group = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tags (comma separated)")
                                    .font(.caption)
                                TextField("e.g. work, config", text: Binding(
                                    get: { viewModel.dotfiles[index].tags.joined(separator: ", ") },
                                    set: { viewModel.dotfiles[index].tags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pre-sync Hook Script")
                                    .font(.caption)
                                TextField("Path under ~/.dotweaver/hooks", text: Binding(
                                    get: { viewModel.dotfiles[index].preSyncHook ?? "" },
                                    set: { viewModel.dotfiles[index].preSyncHook = $0.isEmpty ? nil : $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Post-sync Hook Script")
                                    .font(.caption)
                                TextField("Path under ~/.dotweaver/hooks", text: Binding(
                                    get: { viewModel.dotfiles[index].postSyncHook ?? "" },
                                    set: { viewModel.dotfiles[index].postSyncHook = $0.isEmpty ? nil : $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        } else {
                            Text("Save the file to edit metadata.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(width: 300)
                    .background(.ultraThinMaterial)
                }

                Button(action: saveFile) {
                    Label("Save Changes", systemImage: "checkmark.circle.fill")
                }
                .keyboardShortcut("s", modifiers: .command)
                .help("Save changes to the current file (Cmd+S)")
                .disabled(!isModified || filePath.isEmpty)
                
                Button(action: { showingSaveAlert = true }) {
                    Label("Save As...", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Save a copy of this file to a new location")
            }
        }
        .onAppear {
            if let path = initialPath {
                loadFile(path: path)
            }
        }
        .alert("Save As", isPresented: $showingSaveAlert) {
            TextField("File path", text: $filePath)
            Button("Cancel", role: .cancel) { }
            Button("Save") { saveFile() }
        } message: {
            Text("Enter the full path to save the file")
        }
    }
    
    private func loadFile(path: String) {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        do {
            try SyncPathSecurity.validateLocalFile(url)
            content = try String(contentsOf: url, encoding: .utf8)
            filePath = path
            isModified = false
        } catch {
            content = "Error loading file \(path): \(error.localizedDescription)\n\nExpanded path: \(url.path)"
        }
    }
    
    private func saveFile() {
        guard !filePath.isEmpty else { return }
        let url = URL(fileURLWithPath: (filePath as NSString).expandingTildeInPath)
        
        do {
            guard let data = content.data(using: .utf8) else {
                throw NSError(domain: "DotWeaver.FileEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode file content"])
            }
            try SyncPathSecurity.writeFileAtomically(data, to: url)
            isModified = false
        } catch {
            print("Error saving file: \(error)")
        }
    }
}
