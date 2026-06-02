import SwiftUI
import DotWeaverKit

struct SnapshotsView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @State private var snapshots: [Snapshot] = []
    @State private var isCreatingSnapshot = false
    @State private var snapshotName = ""
    @State private var statusMessage = ""
    
    let manager = SnapshotManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snapshots")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Roll back your environment to a previous state.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { isCreatingSnapshot = true }) {
                    Label("Take Snapshot", systemImage: "camera.shutter.button.fill")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(32)
            
            Divider().opacity(0.3)
            
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(statusMessage.contains("failed") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundStyle(statusMessage.contains("failed") ? .red : .green)
            }
            
            if snapshots.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .opacity(0.3)
                    Text("No snapshots found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Create your first snapshot to secure your environment's state.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(snapshots) { snapshot in
                            SnapshotRow(snapshot: snapshot, restoreAction: {
                                restore(snapshot)
                            }, deleteAction: {
                                delete(snapshot)
                            })
                        }
                    }
                    .padding(32)
                }
            }
        }
        .onAppear(perform: loadSnapshots)
        .sheet(isPresented: $isCreatingSnapshot) {
            VStack(spacing: 20) {
                Text("New Snapshot")
                    .font(.headline)
                
                TextField("Snapshot Name", text: $snapshotName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                HStack {
                    Button("Cancel") {
                        isCreatingSnapshot = false
                        snapshotName = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create") {
                        create()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(snapshotName.isEmpty)
                }
            }
            .padding(40)
            .frame(width: 350)
            .background(.ultraThinMaterial)
        }
    }
    
    private func loadSnapshots() {
        snapshots = manager.listSnapshots()
    }
    
    private func create() {
        do {
            _ = try manager.createSnapshot(dotfiles: viewModel.dotfiles, name: snapshotName)
            loadSnapshots()
            isCreatingSnapshot = false
            snapshotName = ""
            statusMessage = "Snapshot created successfully"
            viewModel.addActivityLog(message: "Created snapshot: \(snapshotName)", type: .add)
        } catch {
            statusMessage = "Failed to create snapshot: \(error.localizedDescription)"
        }
    }
    
    private func restore(_ snapshot: Snapshot) {
        do {
            try manager.restoreSnapshot(snapshot)
            statusMessage = "Restored snapshot successfully"
            viewModel.addActivityLog(message: "Restored snapshot: \(snapshot.name)", type: .sync)
        } catch {
            statusMessage = "Failed to restore: \(error.localizedDescription)"
        }
    }
    
    private func delete(_ snapshot: Snapshot) {
        do {
            try manager.deleteSnapshot(snapshot)
            loadSnapshots()
            statusMessage = "Deleted snapshot"
        } catch {
            statusMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }
}

struct SnapshotRow: View {
    let snapshot: Snapshot
    let restoreAction: () -> Void
    let deleteAction: () -> Void
    @State private var isHovering = false
    @State private var showingConfirm = false
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                HStack(spacing: 12) {
                    Label("\(snapshot.fileCount) files", systemImage: "doc.on.doc")
                    Text(snapshot.date, style: .date)
                    Text(snapshot.date, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showingConfirm = true }) {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .foregroundStyle(.blue)
                .cornerRadius(8)
                
                Button(action: deleteAction) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isHovering ? 0.2 : 0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .confirmationDialog("Restore Snapshot?", isPresented: $showingConfirm) {
            Button("Restore and Overwrite Local Files", role: .destructive) {
                restoreAction()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will replace your current local files with the ones from this snapshot. This action cannot be undone.")
        }
    }
}
