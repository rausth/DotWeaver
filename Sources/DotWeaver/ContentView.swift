import SwiftUI
import DotWeaverKit

enum NavigationItem: Hashable {
    case dashboard
    case files
    case templates
    case snapshots
    case providers
}

struct MeshBackground: View {
    @State private var t: Float = 0.0
    
    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [sin(t)*0.1, 0.5], [0.5, 0.5 + cos(t)*0.1], [1 - sin(t)*0.1, 0.5],
            [0, 1], [0.5, 1], [1, 1]
        ], colors: [
            .black, Color(red: 0.0, green: 0.1, blue: 0.3).opacity(0.8), .black,
            Color(red: 0.1, green: 0.0, blue: 0.2).opacity(0.6), .black, Color(red: 0.0, green: 0.2, blue: 0.2).opacity(0.7),
            .black, Color(red: 0.0, green: 0.05, blue: 0.2).opacity(0.8), .black
        ])
        .ignoresSafeArea()
        .background(Color(red: 0.005, green: 0.005, blue: 0.01))
        .onAppear {
            withAnimation(.easeInOut(duration: 10.0).repeatForever(autoreverses: true)) {
                t = .pi
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

enum DotWeaverAssets {
    static func brandIcon() -> NSImage? {
        if let image = NSImage(named: "dotweaver-icon") {
            return image
        }

        guard let url = Bundle.module.url(forResource: "dotweaver-icon", withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    static func menuBarIcon() -> NSImage? {
        guard let image = brandIcon()?.copy() as? NSImage else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }
}

struct DotWeaverBrandIcon: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = DotWeaverAssets.brandIcon() {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(6, size * 0.18), style: .continuous))
        .shadow(color: Color.blue.opacity(0.35), radius: size * 0.18)
    }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var selectedItem: NavigationItem? = .dashboard
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    DotWeaverBrandIcon(size: 76)
                        .padding(.top, 40)
                    
                    VStack(spacing: 2) {
                        Text("DotWeaver").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text("SOPHISTICATED SYNC").font(.system(size: 9, weight: .black)).foregroundStyle(.secondary).tracking(0.8).opacity(0.6)
                    }
                }
                .padding(.bottom, 36)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("MAIN MENU").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary.opacity(0.7)).padding(.leading, 16).padding(.bottom, 4)
                    SidebarButton(item: .dashboard, title: "Dashboard", icon: "square.grid.2x2.fill", selection: $selectedItem)
                    SidebarButton(item: .files, title: "Monitored Files", icon: "checklist", selection: $selectedItem)
                    SidebarButton(item: .templates, title: "Template Gallery", icon: "wand.and.stars", selection: $selectedItem)
                    SidebarButton(item: .snapshots, title: "Snapshots", icon: "clock.arrow.circlepath", selection: $selectedItem)
                    SidebarButton(item: .providers, title: "Sync Providers", icon: "cloud.fill", selection: $selectedItem)
                }.padding(.horizontal, 12)
                
                Spacer()
                
                VStack(spacing: 0) {
                    Divider().opacity(0.15)
                    FooterButton(title: "System Doctor", icon: "stethoscope") { 
                        selectedItem = .dashboard
                        Task { await viewModel.runDoctor() } 
                    }
                    Divider().opacity(0.15)
                    FooterButton(title: "Settings", icon: "gearshape.fill") {
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }
                }
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea())
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
        } detail: {
            NavigationStack(path: $path) {
                ZStack {
                    MeshBackground()
                    Group {
                        switch selectedItem {
                        case .dashboard: DashboardView()
                        case .files: MonitoredFilesView(path: $path)
                        case .templates: TemplatesView()
                        case .snapshots: SnapshotsView()
                        case .providers: ProvidersView()
                        case .none: ContentUnavailableView("Select an item", systemImage: "cursorarrow.click")
                        }
                    }.transition(.opacity)
                }
                .navigationDestination(for: String.self) { filePath in FileEditorView(path: filePath) }
            }
            .onChange(of: selectedItem) { _, _ in path = NavigationPath() }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.startWatchingDotfiles()
        }
    }
}

struct SidebarButton: View {
    let item: NavigationItem
    let title: String
    let icon: String
    @Binding var selection: NavigationItem?
    @State private var isHovered = false
    
    var isSelected: Bool { selection == item }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selection = item
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.8))
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar.\(String(describing: item))")
        .onHover { hovering in isHovered = hovering }
    }
}

struct FooterButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 14, weight: .medium))
                Spacer()
                if title == "Settings" {
                    Image(systemName: "chevron.right").font(.system(size: 10)).opacity(0.4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .foregroundStyle(.secondary)
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    
    var monitoredCount: Int {
        viewModel.dotfiles.filter { $0.isMonitored }.count
    }
    
    var modifiedCount: Int {
        viewModel.dotfiles.filter { $0.status == .modified }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overview")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Welcome back! Your environment is looking sharp.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        Task { await viewModel.syncBidirectional() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                                .animation(viewModel.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isSyncing)
                            Text(viewModel.isSyncing ? "Syncing..." : "Sync Now")
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                    .disabled(viewModel.isSyncing)
                    .accessibilityIdentifier("dashboard.syncNow")
                }
                
                // Cards
                HStack(spacing: 24) {
                    DashboardCard(
                        title: "Monitored Files",
                        value: "\(monitoredCount)",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    DashboardCard(
                        title: "Pending Changes",
                        value: "\(modifiedCount)",
                        icon: "pencil.and.outline",
                        color: .orange
                    )
                    
                    DashboardCard(
                        title: "Current Provider",
                        value: viewModel.selectedProvider.title,
                        icon: "cloud.fill",
                        color: .purple
                    )
                }
                
                if !viewModel.statusMessage.isEmpty {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text(viewModel.statusMessage)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(12)
                }
                
                // System Status
                VStack(alignment: .leading, spacing: 16) {
                    Text("System Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 40) {
                        StatusIndicator(title: "Agent", status: .active)
                        StatusIndicator(title: "Watcher", status: .active)
                        StatusIndicator(title: "Cloud Connection", status: viewModel.selectedProvider == .git ? .inactive : .active)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        if viewModel.recentActivity.isEmpty {
                            Text("No recent activity")
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.recentActivity.prefix(5)) { log in
                                ActivityLogRow(log: log)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .padding(40)
        }
    }
}

enum ComponentStatus {
    case active, inactive, error
    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .gray
        case .error: return .red
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let status: ComponentStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .shadow(color: status.color.opacity(0.5), radius: 4, x: 0, y: 0)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActivityLogRow: View {
    let log: ActivityLog
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch log.type {
        case .sync: return "arrow.triangle.2.circlepath"
        case .edit: return "pencil"
        case .add: return "plus"
        case .system: return "gearshape"
        }
    }
    
    private var iconColor: Color {
        switch log.type {
        case .sync: return .blue
        case .edit: return .orange
        case .add: return .green
        case .system: return .purple
        }
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .padding(12)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                
                Spacer()
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, idealHeight: 180, maxHeight: 180, alignment: .leading)
        .background(Color(white: 0.1).opacity(0.6))
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isHovered ? color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct MonitoredFilesView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    @Binding var path: NavigationPath
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Monitored Files")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: addFiles) {
                    Label("Add File", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                .accessibilityIdentifier("files.addFile")
            }
            .padding(40)
            
            Divider().opacity(0.1)
            
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search files...", text: $searchText).textFieldStyle(.plain)
                    .accessibilityIdentifier("files.search")
            }
            .padding(16)
            .background(Color.black.opacity(0.2)).background(.ultraThinMaterial)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 40).padding(.vertical, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    let groupedFiles = Dictionary(grouping: viewModel.dotfiles, by: { $0.group ?? "Uncategorized" })
                    let sortedGroups = groupedFiles.keys.sorted { a, b in
                        if a == "Uncategorized" { return false }
                        if b == "Uncategorized" { return true }
                        return a < b
                    }
                    
                    ForEach(sortedGroups, id: \.self) { groupName in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(groupName.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary).tracking(1.2)
                                Spacer()
                                Text("\(groupedFiles[groupName]?.count ?? 0) files").font(.caption2).foregroundStyle(.secondary)
                            }.padding(.horizontal, 4)
                            
                            VStack(spacing: 14) {
                                ForEach(groupedFiles[groupName] ?? []) { file in
                                    if searchText.isEmpty || file.path.localizedCaseInsensitiveContains(searchText) {
                                        FileRowGlass(file: file, path: $path)
                                    }
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
    }
    
    private func addFiles() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = true
        panel.prompt = "Add to DotWeaver"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK {
                    for url in panel.urls {
                        DispatchQueue.main.async {
                            monitor(url)
                        }
                    }
                }
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
            if panel.runModal() == .OK {
                for url in panel.urls {
                    monitor(url)
                }
            }
        }
        #endif
    }

    private func monitor(_ url: URL) {
        do {
            try SyncPathSecurity.validateLocalFile(url)
            try SecurityScopedBookmarks.register(url)
            let newFile = Dotfile(path: url.path, status: .synced, conflictStrategy: .lastModifiedWins, isMonitored: true)
            if !viewModel.dotfiles.contains(where: { $0.path == url.path }) {
                viewModel.dotfiles.append(newFile)
                viewModel.addActivityLog(message: "Added \((url.path as NSString).lastPathComponent) to monitoring", type: .add)
                viewModel.save()
            }
        } catch {
            viewModel.statusMessage = "Cannot monitor \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

struct FileRowGlass: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    let file: Dotfile
    @Binding var path: NavigationPath
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            Toggle("", isOn: Binding(get: { file.isMonitored }, set: { _ in viewModel.toggleMonitoring(id: file.id) }))
                .toggleStyle(.checkbox).labelsHidden()
            
            let (icon, color) = iconForFile(file.path)
            Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text((file.path as NSString).lastPathComponent).font(.system(size: 16, weight: .semibold, design: .monospaced)).foregroundColor(.white)
                    if file.isSecret {
                        Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.orange).help("This file is encrypted in the vault")
                    }
                }
                Text(file.path).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            
            HStack(spacing: 12) {
                if file.isMonitored { statusBadge(for: file.status) }
                else { Text("Ignored").font(.caption).padding(.horizontal, 10).padding(.vertical, 6).background(Color.gray.opacity(0.15)).foregroundStyle(.gray).cornerRadius(8) }
                
                Button(action: { path.append(file.path) }) {
                    Image(systemName: "square.and.pencil").foregroundStyle(.primary).padding(10).background(Color.white.opacity(isHovering ? 0.12 : 0.06)).cornerRadius(8)
                }.buttonStyle(.plain).help("Edit File").accessibilityIdentifier("files.edit.\(file.id.uuidString)")

                Button(role: .destructive, action: { withAnimation { viewModel.removeFile(id: file.id) } }) {
                    Image(systemName: "trash").foregroundStyle(.red).padding(10).background(Color.red.opacity(isHovering ? 0.12 : 0.06)).cornerRadius(8)
                }.buttonStyle(.plain).help("Stop Monitoring").accessibilityIdentifier("files.remove.\(file.id.uuidString)")
            }.opacity(isHovering ? 1 : 0)
        }
        .padding(.vertical, 14).padding(.horizontal, 20)
        .background(Color(white: 0.1).opacity(0.4)).background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .accessibilityIdentifier("files.row.\(file.id.uuidString)")
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering } }
    }
    
    private func iconForFile(_ path: String) -> (String, Color) {
        if path.contains(".git") { return ("git", .orange) }
        if path.contains(".zsh") || path.contains(".bash") { return ("terminal.fill", .green) }
        if path.contains(".vim") || path.contains("nvim") { return ("leaf.fill", .green) }
        if path.contains(".toml") || path.contains(".json") || path.contains(".yaml") { return ("gearshape.fill", .gray) }
        return ("doc.text.fill", .blue)
    }
    
    @ViewBuilder
    private func statusBadge(for status: SyncStatus) -> some View {
        let (icon, color, text) = {
            switch status {
            case .synced: return ("checkmark.circle.fill", Color.green, "Synced")
            case .modified: return ("pencil.circle.fill", Color.orange, "Modified")
            case .conflict: return ("xmark.circle.fill", Color.red, "Conflict")
            case .error: return ("exclamationmark.triangle.fill", Color.red, "Error")
            }
        }()
        
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .fontWeight(.bold)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .cornerRadius(8)
    }
}

struct ProvidersView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    
    let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Storage Providers")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Select and configure where your dotfiles will be stored securely.")
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(SyncProvider.allCases) { provider in
                        ProviderCard(
                            provider: provider,
                            isSelected: viewModel.selectedProvider == provider
                        ) {
                            selectProvider(provider)
                        }
                    }
                }
            }
            .padding(40)
        }
        .accessibilityIdentifier("providers.view")
    }
    
    private func selectProvider(_ provider: SyncProvider) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            viewModel.selectedProvider = provider
        }
        
        if provider != .git {
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Set as \(provider.title) Folder"
            panel.message = "Choose your \(provider.title) folder to sync dotfiles."
            
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            var defaultUrl = home
            
            switch provider {
            case .dropbox:
                let path = home.appendingPathComponent("Dropbox")
                if fm.fileExists(atPath: path.path) { defaultUrl = path }
            case .onedrive:
                let path = home.appendingPathComponent("OneDrive")
                if fm.fileExists(atPath: path.path) { defaultUrl = path }
            case .googledrive:
                let path1 = home.appendingPathComponent("Google Drive")
                let path2 = home.appendingPathComponent("My Drive")
                if fm.fileExists(atPath: path1.path) { defaultUrl = path1 }
                else if fm.fileExists(atPath: path2.path) { defaultUrl = path2 }
            case .icloud:
                if let icloudUrl = fm.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
                    defaultUrl = icloudUrl
                }
            case .webdav, .sftp, .ftps, .s3:
                defaultUrl = home
            default:
                break
            }
            
            panel.directoryURL = defaultUrl
            
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { response in
                    if response == .OK, let url = panel.url {
                        DispatchQueue.main.async {
                            try? SecurityScopedBookmarks.register(url)
                            viewModel.cloudSyncPath = url.path
                            viewModel.statusMessage = "\(provider.title) folder linked successfully!"
                            viewModel.save()
                        }
                    }
                }
            } else {
                NSApp.activate(ignoringOtherApps: true)
                if panel.runModal() == .OK, let url = panel.url {
                    try? SecurityScopedBookmarks.register(url)
                    viewModel.cloudSyncPath = url.path
                    viewModel.statusMessage = "\(provider.title) folder linked successfully!"
                    viewModel.save()
                }
            }
            #endif
        }
    }
}

struct ProviderCard: View {
    let provider: SyncProvider
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon(for: provider))
                    .font(.system(size: 40))
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(provider.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(isSelected ? Color.blue.opacity(0.4) : Color.clear)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("providers.card.\(provider.rawValue)")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
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
