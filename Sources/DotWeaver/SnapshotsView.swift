import SwiftUI
import DotWeaverKit

struct SnapshotsView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @State private var snapshotItems: [SnapshotCatalogItem] = []
    @State private var selectedMachineID = ""
    @State private var isCreatingSnapshot = false
    @State private var snapshotName = ""
    @State private var statusMessage = ""
    
    let manager = SnapshotManager()

    private var filteredItems: [SnapshotCatalogItem] {
        guard !selectedMachineID.isEmpty else { return snapshotItems }
        return snapshotItems.filter { $0.sourceMachineID == selectedMachineID }
    }

    private var machineOptions: [SnapshotMachineOption] {
        var seen = Set<String>()
        return snapshotItems.compactMap { item -> SnapshotMachineOption? in
            let id = item.sourceMachineID
            guard !id.isEmpty, !seen.contains(id) else { return nil }
            seen.insert(id)
            return SnapshotMachineOption(id: id, label: item.sourceMachineLabel)
        }.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snapshots")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Restore from this machine or another synced machine.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Source", selection: $selectedMachineID) {
                    Text("All machines").tag("")
                    ForEach(machineOptions) { machine in
                        Text(machine.label).tag(machine.id)
                    }
                }
                .frame(width: 220)
                .accessibilityIdentifier("snapshots.machinePicker")
                Button(action: loadSnapshots) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("snapshots.refresh")
                Button(action: { isCreatingSnapshot = true }) {
                    Label("Take Snapshot", systemImage: "camera.shutter.button.fill")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("snapshots.takeSnapshot")
            }
            .padding(32)
            
            Divider().opacity(0.3)
            
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(statusMessage.contains("Failed") || statusMessage.contains("failed") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundStyle(statusMessage.contains("Failed") || statusMessage.contains("failed") ? .red : .green)
            }
            
            if filteredItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                        .opacity(0.3)
                    Text("No snapshots found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Create a snapshot or configure a provider that contains snapshots from another machine.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredItems) { item in
                            SnapshotRow(item: item, restoreAction: {
                                restore(item)
                            }, deleteAction: item.location == .local ? {
                                delete(item.snapshot)
                            } : nil)
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
                    .accessibilityIdentifier("snapshots.name")
                
                HStack {
                    Button("Cancel") {
                        isCreatingSnapshot = false
                        snapshotName = ""
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("snapshots.cancel")
                    
                    Button("Create") {
                        create()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(snapshotName.isEmpty)
                    .accessibilityIdentifier("snapshots.create")
                }
            }
            .padding(40)
            .frame(width: 350)
            .background(.ultraThinMaterial)
        }
    }
    
    private func loadSnapshots() {
        snapshotItems = manager.listSnapshotCatalog(providerRootPath: currentProviderRootPath(), includeLocal: true)
        if !selectedMachineID.isEmpty && !snapshotItems.contains(where: { $0.sourceMachineID == selectedMachineID }) {
            selectedMachineID = ""
        }
    }
    
    private func create() {
        do {
            let name = snapshotName
            _ = try manager.createSnapshot(dotfiles: viewModel.dotfiles, name: name, providerRootPath: currentProviderRootPath())
            loadSnapshots()
            isCreatingSnapshot = false
            snapshotName = ""
            statusMessage = "Snapshot created successfully"
            viewModel.addActivityLog(message: "Created snapshot: \(name)", type: .add)
        } catch {
            statusMessage = "Failed to create snapshot: \(error.localizedDescription)"
        }
    }
    
    private func restore(_ item: SnapshotCatalogItem) {
        Task {
            do {
                if SecurityPolicy.requiresBiometricAuthentication {
                    _ = try await BiometricAuthenticator.shared.authenticate(reason: "Authenticate to restore snapshot")
                }
                try manager.restoreSnapshot(item)
                await MainActor.run {
                    statusMessage = "Restored snapshot from \(item.sourceMachineLabel)"
                    viewModel.addActivityLog(message: "Restored snapshot: \(item.snapshot.name) from \(item.sourceMachineLabel)", type: .sync)
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Failed to restore: \(error.localizedDescription)"
                }
            }
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

    private func currentProviderRootPath() -> String? {
        viewModel.selectedProvider == .git ? viewModel.gitLocalPath : viewModel.cloudSyncPath
    }
}

struct SnapshotMachineOption: Identifiable {
    let id: String
    let label: String
}

struct SnapshotRow: View {
    let item: SnapshotCatalogItem
    let restoreAction: () -> Void
    let deleteAction: (() -> Void)?
    @State private var isHovering = false
    @State private var showingConfirm = false

    private var snapshot: Snapshot { item.snapshot }
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                
                HStack(spacing: 12) {
                    Label("\(snapshot.fileCount) files", systemImage: "doc.on.doc")
                    Label(item.sourceMachineLabel, systemImage: "desktopcomputer")
                    Text(snapshot.date, style: .date)
                    Text(snapshot.date, style: .time)
                    Text(item.location.rawValue.capitalized)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(item.location == .local ? Color.green.opacity(0.15) : Color.purple.opacity(0.15))
                        .clipShape(Capsule())
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
                
                if let deleteAction {
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
            Text("This will replace your current local files with files from \(item.sourceMachineLabel). This action cannot be undone.")
        }
    }
}
