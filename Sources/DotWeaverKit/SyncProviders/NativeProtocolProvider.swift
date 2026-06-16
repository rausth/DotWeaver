import Foundation

final class NativeProtocolProvider: SyncProviderProtocol {
    let name: SyncProvider
    let capabilities: SyncProviderCapabilities = [.managedFileSync]

    private let configProvider: () -> NativeProviderConfig
    private let sourceMachineIDProvider: () -> String

    init(
        name: SyncProvider,
        configProvider: @escaping () -> NativeProviderConfig,
        sourceMachineIDProvider: @escaping () -> String = { StateManager.loadState().selectedSyncMachineID }
    ) {
        self.name = name
        self.configProvider = configProvider
        self.sourceMachineIDProvider = sourceMachineIDProvider
    }

    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] {
        let config = try resolvedConfig()
        let currentMachineID = try MachineIdentity.current().id
        let sourceMachineID = resolvedSourceMachineID(currentMachineID: currentMachineID)
        var updated = dotfiles

        for index in updated.indices {
            var dotfile = updated[index]
            let localURL = URL(fileURLWithPath: (dotfile.path as NSString).expandingTildeInPath)
            try SyncPathSecurity.validateLocalFile(localURL)
            let sourceRemoteURL = remoteFileURL(for: localURL, config: config, machineID: sourceMachineID)
            let writeRemoteURL = remoteFileURL(for: localURL, config: config, machineID: currentMachineID)
            let localExists = FileManager.default.fileExists(atPath: localURL.path)
            let remoteExists = try remoteFileExists(sourceRemoteURL, config: config)

            do {
                switch (localExists, remoteExists) {
                case (true, false):
                    try upload(localURL: localURL, remoteURL: writeRemoteURL, dotfile: dotfile, config: config)
                case (false, true):
                    try download(remoteURL: sourceRemoteURL, localURL: localURL, config: config)
                    try upload(localURL: localURL, remoteURL: writeRemoteURL, dotfile: dotfile, config: config)
                case (false, false):
                    throw SyncError.fileNotFound(localURL.path)
                case (true, true):
                    try resolveExisting(dotfile: dotfile, localURL: localURL, sourceRemoteURL: sourceRemoteURL, writeRemoteURL: writeRemoteURL, config: config)
                }

                dotfile.status = .synced
                dotfile.lastSynced = Date()
                dotfile.lastLocalModified = modificationDate(at: localURL)
                dotfile.lastRemoteModified = try remoteModificationDate(sourceRemoteURL, config: config)
                try writeNativeVersion(dotfile: dotfile, localURL: localURL)
                updated[index] = dotfile
            } catch {
                dotfile.status = .error
                updated[index] = dotfile
                throw error
            }
        }

        SyncAuditLog.record(
            "Synchronized native provider",
            metadata: [
                "provider": name.rawValue,
                "files": "\(updated.count)",
                "sourceMachine": sourceMachineID,
                "currentMachine": currentMachineID
            ]
        )
        return updated
    }

    func sync(dotfiles: [Dotfile]) async throws {
        _ = try await syncBidirectional(dotfiles: dotfiles)
    }

    private func resolvedSourceMachineID(currentMachineID: String) -> String {
        let selected = sourceMachineIDProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? currentMachineID : selected
    }

    private func resolveExisting(dotfile: Dotfile, localURL: URL, sourceRemoteURL: URL, writeRemoteURL: URL, config: NativeProviderConfig) throws {
        switch dotfile.conflictStrategy {
        case .localWins:
            try upload(localURL: localURL, remoteURL: writeRemoteURL, dotfile: dotfile, config: config)
        case .remoteWins:
            try download(remoteURL: sourceRemoteURL, localURL: localURL, config: config)
            try upload(localURL: localURL, remoteURL: writeRemoteURL, dotfile: dotfile, config: config)
        case .manual:
            throw SyncError.conflictDetected([dotfile])
        case .lastModifiedWins:
            let localDate = modificationDate(at: localURL) ?? .distantPast
            let remoteDate = try remoteModificationDate(sourceRemoteURL, config: config) ?? .distantPast
            if localDate >= remoteDate {
                try upload(localURL: localURL, remoteURL: writeRemoteURL, dotfile: dotfile, config: config)
            } else {
                try download(remoteURL: sourceRemoteURL, localURL: localURL, config: config)
                try upload(localURL: localURL, remoteURL: writeRemoteURL, dotfile: dotfile, config: config)
            }
        }
    }

    private func upload(localURL: URL, remoteURL: URL, dotfile: Dotfile, config: NativeProviderConfig) throws {
        let uploadURL: URL
        var cleanupURL: URL?

        if dotfile.isSecret {
            let data = try VaultCrypto.encrypt(Data(contentsOf: localURL), originalPath: dotfile.path)
            let tempURL = try SyncPathSecurity.secureTemporaryFile(prefix: "DotWeaverNativeUpload")
            try data.write(to: tempURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)
            uploadURL = tempURL
            cleanupURL = tempURL
        } else {
            uploadURL = localURL
        }

        defer {
            if let cleanupURL {
                try? FileManager.default.removeItem(at: cleanupURL.deletingLastPathComponent())
            }
        }

        _ = try runCurl(["--create-dirs", "--ftp-create-dirs", "-T", uploadURL.path, remoteURL.absoluteString], config: config)
        SyncAuditLog.record("Uploaded native file", metadata: ["provider": name.rawValue, "path": dotfile.path])
    }

    private func download(remoteURL: URL, localURL: URL, config: NativeProviderConfig) throws {
        try SyncPathSecurity.validateLocalFile(localURL)
        let tempURL = try SyncPathSecurity.secureTemporaryFile(prefix: "DotWeaverNativeDownload")
        defer { try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent()) }

        _ = try runCurl(["-o", tempURL.path, remoteURL.absoluteString], config: config)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempURL.path)
        let data = try VaultCrypto.decryptIfNeeded(Data(contentsOf: tempURL))
        try SyncPathSecurity.writeFileAtomically(data, to: localURL)
        SyncAuditLog.record("Downloaded native file", metadata: ["provider": name.rawValue, "path": localURL.path])
    }

    private func remoteFileExists(_ remoteURL: URL, config: NativeProviderConfig) throws -> Bool {
        do {
            _ = try runCurl(["-I", remoteURL.absoluteString], config: config)
            return true
        } catch {
            return false
        }
    }

    private func remoteModificationDate(_ remoteURL: URL, config: NativeProviderConfig) throws -> Date? {
        let output = try? runCurl(["-I", remoteURL.absoluteString], config: config)
        guard let output else { return nil }
        let prefix = "last-modified:"
        guard let line = output
            .components(separatedBy: .newlines)
            .first(where: { $0.lowercased().hasPrefix(prefix) }) else {
            return nil
        }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter.date(from: value)
    }

    private func remoteFileURL(for localURL: URL, config: NativeProviderConfig, machineID: String) -> URL {
        let relativePath = SyncStoragePaths.relativeStoragePath(for: localURL)
        return config.normalizedEndpointURL()
            .appendingPathComponent(SyncStoragePaths.machineFilesNamespace)
            .appendingPathComponent(machineID)
            .appendingPathComponent(relativePath)
    }

    private func resolvedConfig() throws -> NativeProviderConfig {
        let config = configProvider()
        let endpoint = config.normalizedEndpointURL()
        guard !config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let scheme = endpoint.scheme?.lowercased() else {
            throw SyncError.configurationMissing("\(name.title) native endpoint not configured")
        }
        guard allowedSchemes.contains(scheme) else {
            throw SyncError.configurationMissing("\(name.title) native endpoint scheme not allowed: \(scheme)")
        }
        guard endpoint.user == nil, endpoint.password == nil else {
            throw SyncError.configurationMissing("Do not store credentials in native endpoint URLs")
        }
        guard !config.username.contains(":") else {
            throw SyncError.configurationMissing("Do not store native protocol passwords in username configuration")
        }
        return config
    }

    private var allowedSchemes: Set<String> {
        switch name {
        case .webdav:
            return ["https", "webdavs"]
        case .sftp:
            return ["sftp"]
        case .ftps:
            return ["ftps"]
        case .s3:
            return ["https", "s3"]
        case .git, .icloud, .onedrive, .googledrive, .dropbox:
            return []
        }
    }

    private func runCurl(_ arguments: [String], config: NativeProviderConfig) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        var args = [
            "-fS",
            "--connect-timeout", "30",
            "--retry", "3",
            "--retry-delay", "1",
            "--retry-max-time", "60",
            "--retry-all-errors",
            "--netrc-optional"
        ]
        if !config.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--user", config.username]
        }
        args += arguments
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SyncError.networkError(errorOutput.isEmpty ? output : errorOutput)
        }
        return output
    }

    private func modificationDate(at url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func writeNativeVersion(dotfile: Dotfile, localURL: URL) throws {
        let identity = try MachineIdentity.current()
        SyncAuditLog.record(
            "Native version recorded",
            metadata: [
                "provider": name.rawValue,
                "machine": identity.id,
                "path": dotfile.path,
                "relative": SyncStoragePaths.relativeStoragePath(for: localURL)
            ]
        )
    }
}

private extension NativeProviderConfig {
    func normalizedEndpointURL() -> URL {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed.hasSuffix("/") ? trimmed : trimmed + "/") ?? URL(fileURLWithPath: "/")
    }
}
