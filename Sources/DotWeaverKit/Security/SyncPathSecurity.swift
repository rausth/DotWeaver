import Foundation

public enum SyncPathSecurity {
    public static func validateLocalFile(_ url: URL) throws {
        let standardized = url.standardizedFileURL
        let path = standardized.path
        guard path.hasPrefix("/") else {
            throw SyncError.invalidPath(path)
        }

        if !SecurityPolicy.allowsUnsafeLocalPaths {
            let homePath = FileManager.default.homeDirectoryForCurrentUser
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
            let parentPath = standardized
                .deletingLastPathComponent()
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path
            let resolvedPath = standardized
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path

            guard parentPath == homePath || parentPath.hasPrefix(homePath + "/"),
                  resolvedPath == homePath || resolvedPath.hasPrefix(homePath + "/") else {
                throw SyncError.invalidPath("Local file must be inside the user home directory: \(path)")
            }
        }

        let values = try? standardized.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true {
            throw SyncError.invalidPath("Symbolic links are not allowed: \(path)")
        }
    }

    public static func ensureContained(_ child: URL, in root: URL) throws {
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let standardizedChild = child.standardizedFileURL
        let childPath: String
        if FileManager.default.fileExists(atPath: standardizedChild.path) {
            childPath = standardizedChild.resolvingSymlinksInPath().path
        } else {
            childPath = standardizedChild
                .deletingLastPathComponent()
                .resolvingSymlinksInPath()
                .appendingPathComponent(standardizedChild.lastPathComponent)
                .path
        }
        guard childPath == rootPath || childPath.hasPrefix(rootPath + "/") else {
            throw SyncError.invalidPath("Path escapes storage root: \(childPath)")
        }
    }

    public static func writeFileAtomically(_ data: Data, to destination: URL) throws {
        try validateLocalFile(destination)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    public static func secureTemporaryFile(prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return directory.appendingPathComponent("payload.bin")
    }
}
