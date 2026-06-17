import Foundation

public struct DotignoreMatcher: Sendable {
    private let rules: [Rule]

    public init(contents: String) {
        self.rules = contents
            .components(separatedBy: .newlines)
            .compactMap(Rule.init(raw:))
    }

    public var isEmpty: Bool { rules.isEmpty }

    public func ignores(path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let relative: String
        if url.path == home {
            relative = ""
        } else if url.path.hasPrefix(home + "/") {
            relative = String(url.path.dropFirst(home.count + 1))
        } else {
            relative = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        var ignored = false
        for rule in rules where rule.matches(relativePath: relative, basename: url.lastPathComponent) {
            ignored = !rule.isNegated
        }
        return ignored
    }

    public static func load(providerRootPath: String?) -> DotignoreMatcher {
        for url in candidateURLs(providerRootPath: providerRootPath) {
            if let contents = try? String(contentsOf: url, encoding: .utf8) {
                return DotignoreMatcher(contents: contents)
            }
        }
        return DotignoreMatcher(contents: "")
    }

    private static func candidateURLs(providerRootPath: String?) -> [URL] {
        var urls = [StateManager.appSupportDirectory.appendingPathComponent(".dotignore")]
        if let providerRootPath, !providerRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            urls.insert(
                URL(fileURLWithPath: (providerRootPath as NSString).expandingTildeInPath)
                    .appendingPathComponent(".dotignore"),
                at: 0
            )
        }
        return urls
    }
}

private struct Rule: Sendable {
    let pattern: String
    let isNegated: Bool
    let matchesDirectory: Bool

    init?(raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("#") else { return nil }
        let negated = value.hasPrefix("!")
        if negated { value.removeFirst() }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !value.isEmpty else { return nil }
        self.pattern = value
        self.isNegated = negated
        self.matchesDirectory = raw.hasSuffix("/")
    }

    func matches(relativePath: String, basename: String) -> Bool {
        let normalized = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if matchesDirectory, normalized.hasPrefix(pattern + "/") { return true }
        if fnmatch(pattern, normalized, FNM_PATHNAME) == 0 { return true }
        if !pattern.contains("/"), fnmatch(pattern, basename, 0) == 0 { return true }
        if !pattern.contains("/"), normalized.split(separator: "/").contains(where: { fnmatch(pattern, String($0), 0) == 0 }) { return true }
        return false
    }
}
