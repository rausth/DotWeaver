import Foundation

final class GitProvider: SyncProviderProtocol {
    let name = SyncProvider.git

    private let storageRootProvider: () -> String
    private let remoteURLProvider: () -> String
    private let branchProvider: () -> String
    private let folderProvider: FolderSyncProvider

    init(
        storageRootProvider: @escaping () -> String = { StateManager.loadState().gitLocalPath },
        remoteURLProvider: @escaping () -> String = { StateManager.loadState().gitRemoteUrl },
        branchProvider: @escaping () -> String = { StateManager.loadState().gitBranch }
    ) {
        self.storageRootProvider = storageRootProvider
        self.remoteURLProvider = remoteURLProvider
        self.branchProvider = branchProvider
        self.folderProvider = FolderSyncProvider(name: .git, storageRootProvider: storageRootProvider)
    }

    private var remoteURL: String {
        remoteURLProvider()
    }

    func syncBidirectional(dotfiles: [Dotfile]) async throws -> [Dotfile] {
        guard !storageRootProvider().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SyncError.configurationMissing("Git repository path not configured")
        }

        return try await folderProvider.syncBidirectional(dotfiles: dotfiles)
    }

    func sync(dotfiles: [Dotfile]) async throws {
        _ = try await syncBidirectional(dotfiles: dotfiles)
    }

    func pull() async throws {
        guard !remoteURL.isEmpty else {
            throw SyncError.configurationMissing("Git remote URL not configured")
        }

        let branch = try validatedBranch()
        try runGit(["pull", "origin", branch])
    }

    func push() async throws {
        guard !remoteURL.isEmpty else {
            throw SyncError.configurationMissing("Git remote URL not configured")
        }

        let branch = try validatedBranch()
        try stageAndCommitIfNeeded()
        try runGit(["push", "origin", branch])
    }

    func status() async throws -> [Dotfile] {
        []
    }

    private func stageAndCommitIfNeeded() throws {
        try runGit(["add", SyncStoragePaths.namespace])
        let status = try runGit(["status", "--porcelain", SyncStoragePaths.namespace])
        guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        try runGit(["commit", "-m", "Sync dotfiles"])
    }

    private func validatedBranch() throws -> String {
        let branch = branchProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty,
              !branch.hasPrefix("-"),
              branch.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              branch.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw SyncError.configurationMissing("Invalid Git branch")
        }
        return branch
    }

    @discardableResult
    private func runGit(_ arguments: [String]) throws -> String {
        let repositoryPath = storageRootProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repositoryPath.isEmpty else {
            throw SyncError.configurationMissing("Git repository path not configured")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repositoryPath] + arguments

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
}
