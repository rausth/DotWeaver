import Foundation

public enum SecurityScopedBookmarks {
    private static let store = SecurityScopedBookmarkStore()

    public static func register(_ url: URL) throws {
        #if os(macOS)
        let standardized = url.standardizedFileURL
        let data = try standardized.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        var state = StateManager.loadState()
        state.securityScopedBookmarks[standardized.path] = data
        StateManager.saveState(state)
        startAccessing(standardized)
        SyncAuditLog.record("Stored security-scoped bookmark", metadata: ["path": standardized.path])
        #endif
    }

    public static func restoreAccess() {
        #if os(macOS)
        for (path, data) in StateManager.loadState().securityScopedBookmarks {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
                startAccessing(url.standardizedFileURL)
                if isStale {
                    try register(url)
                }
            } catch {
                SyncAuditLog.record("Failed to restore security-scoped bookmark", metadata: ["path": path, "error": error.localizedDescription])
            }
        }
        #endif
    }

    public static func hasStoredAccess(for url: URL) -> Bool {
        #if os(macOS)
        let path = url.standardizedFileURL.path
        return store.contains(path)
        #else
        return true
        #endif
    }

    private static func startAccessing(_ url: URL) {
        #if os(macOS)
        let standardized = url.standardizedFileURL
        if standardized.startAccessingSecurityScopedResource() {
            store.insert(standardized.path)
        }
        #endif
    }
}

private final class SecurityScopedBookmarkStore: @unchecked Sendable {
    private let lock = NSLock()
    private var activePaths = Set<String>()

    func insert(_ path: String) {
        lock.lock()
        activePaths.insert(path)
        lock.unlock()
    }

    func contains(_ path: String) -> Bool {
        lock.lock()
        let result = activePaths.contains { path == $0 || path.hasPrefix($0 + "/") }
        lock.unlock()
        return result
    }
}
