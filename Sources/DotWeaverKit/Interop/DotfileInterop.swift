import Foundation

public enum DotfileInterop {
    public static func importMackupConfig(
        from url: URL,
        group: String? = "mackup",
        tags: [String] = ["mackup"]
    ) throws -> [Dotfile] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let entries = parseMackupINI(contents)
        return entries.map { entry in
            Dotfile(path: entry.path, tags: tags, group: group)
        }
    }

    public static func importChezmoiSource(
        from sourceDirectory: URL,
        group: String? = "chezmoi",
        tags: [String] = ["chezmoi"]
    ) throws -> [Dotfile] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: sourceDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw InteropError.invalidSourceDirectory(sourceDirectory.path)
        }

        let root = try chezmoiRoot(sourceDirectory).standardizedFileURL
        let rootPath = root.path
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var dotfiles: [Dotfile] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true { continue }
            let filePath = fileURL.standardizedFileURL.path
            guard filePath.hasPrefix(rootPath + "/") else { continue }
            let relative = filePath.dropFirst(rootPath.count + 1)
            guard let target = chezmoiTargetPath(from: String(relative)) else { continue }
            dotfiles.append(Dotfile(path: target, tags: tags, group: group))
        }

        return dotfiles.sorted { $0.path < $1.path }
    }

    public static func exportChezmoiSource(
        dotfiles: [Dotfile],
        to sourceDirectory: URL,
        overwrite: Bool = false
    ) throws -> Int {
        let fm = FileManager.default
        try fm.createDirectory(at: sourceDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        var count = 0
        for dotfile in dotfiles where dotfile.isMonitored {
            let localURL = URL(fileURLWithPath: dotfile.path.expandingTildeForInterop())
            try SyncPathSecurity.validateLocalFile(localURL)
            guard fm.fileExists(atPath: localURL.path) else { continue }

            let relative = chezmoiSourcePath(forTargetPath: dotfile.path)
            let destination = sourceDirectory.appendingPathComponent(relative)
            if fm.fileExists(atPath: destination.path), !overwrite {
                throw InteropError.destinationExists(destination.path)
            }

            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: localURL, to: destination)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            count += 1
        }

        return count
    }

    public static func merge(_ imported: [Dotfile], into existing: [Dotfile]) -> [Dotfile] {
        var result = existing
        var seen = Set(existing.map { normalizePath($0.path) })
        for dotfile in imported where !seen.contains(normalizePath(dotfile.path)) {
            result.append(dotfile)
            seen.insert(normalizePath(dotfile.path))
        }
        return result
    }

    public static func chezmoiSourcePath(forTargetPath path: String) -> String {
        let expanded = path.expandingTildeForInterop()
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let relative: String
        if expanded == home {
            relative = ""
        } else if expanded.hasPrefix(home + "/") {
            relative = String(expanded.dropFirst(home.count + 1))
        } else {
            relative = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return relative
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { component in
                component.hasPrefix(".") ? "dot_" + component.dropFirst() : String(component)
            }
            .joined(separator: "/")
    }

    public static func chezmoiTargetPath(from sourcePath: String) -> String? {
        let ignoredPrefixes = ["exact_", "private_", "readonly_", "executable_", "create_", "empty_", "symlink_"]
        let ignoredSuffixes = [".tmpl"]
        let components = sourcePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        guard !components.isEmpty,
              !components[0].hasPrefix(".chezmoi") else {
            return nil
        }

        let mapped = components.map { component -> String in
            var value = component
            for prefix in ignoredPrefixes where value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
            }
            for suffix in ignoredSuffixes where value.hasSuffix(suffix) {
                value = String(value.dropLast(suffix.count))
            }
            if value.hasPrefix("dot_") {
                return "." + value.dropFirst(4)
            }
            return value
        }

        return "~/" + mapped.joined(separator: "/")
    }

    private static func parseMackupINI(_ contents: String) -> [MackupEntry] {
        let sectionPrefixes: [String: String] = [
            "configuration_files": "~/",
            "xdg_configuration_files": "~/.config/",
            "library_files": "~/Library/",
            "application_support_files": "~/Library/Application Support/",
            "mackup": "~/"
        ]

        var currentSection: String?
        var entries: [MackupEntry] = []

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                currentSection = String(line.dropFirst().dropLast()).lowercased()
                continue
            }
            guard let section = currentSection,
                  let prefix = sectionPrefixes[section] else {
                continue
            }
            guard !line.contains("=") else { continue }
            let path = line.hasPrefix("~/") || line.hasPrefix("/") ? line : prefix + line
            entries.append(MackupEntry(path: path))
        }

        return entries
    }

    private static func chezmoiRoot(_ sourceDirectory: URL) throws -> URL {
        let rootFile = sourceDirectory.appendingPathComponent(".chezmoiroot")
        guard FileManager.default.fileExists(atPath: rootFile.path) else {
            return sourceDirectory
        }
        let relative = try String(contentsOf: rootFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relative.isEmpty,
              !relative.hasPrefix("/"),
              !relative.contains("..") else {
            throw InteropError.invalidChezmoiRoot(relative)
        }
        return sourceDirectory.appendingPathComponent(relative)
    }

    private static func normalizePath(_ path: String) -> String {
        path.expandingTildeForInterop()
    }
}

public enum InteropError: LocalizedError {
    case invalidSourceDirectory(String)
    case invalidChezmoiRoot(String)
    case destinationExists(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSourceDirectory(let path):
            return "Interop source directory not found: \(path)"
        case .invalidChezmoiRoot(let path):
            return "Invalid .chezmoiroot value: \(path)"
        case .destinationExists(let path):
            return "Destination exists; use --force to overwrite: \(path)"
        }
    }
}

private struct MackupEntry {
    let path: String
}

private extension String {
    func expandingTildeForInterop() -> String {
        (self as NSString).expandingTildeInPath
    }
}
